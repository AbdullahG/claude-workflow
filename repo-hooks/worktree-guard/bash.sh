#!/bin/bash
# PreToolUse: Bash
# Deny shell commands that write into the main checkout. The command is split
# into simple commands; for each one the hook works out which paths it writes
# (redirect targets, operands of rm/mv/cp/..., `sed -i` files, git and package
# manager commands that change the working tree) and resolves them against the
# working directory, following `cd`. Reading from the main checkout is allowed,
# so copying untracked files such as .env into a worktree works.
#
# Heuristic, not a security boundary: paths built from variables or command
# substitution, and files written by scripts or build tools, are not seen.
here=$(dirname "$0")
source "$here/lib.sh"

wg_in_linked_worktree && exit 0

cmd=$(wg_field '.tool_input.command')
[[ -z $cmd ]] && exit 0

US=$'\037'
toks=()
while IFS= read -r t; do toks+=("$t"); done < <(printf '%s\n' "$cmd" | awk -f "$here/tokenize.awk")

cwd=$wg_cwd
targets=()

add() {
  case "$1" in ''|*'$'*|*'`'*) return ;; esac
  targets+=("$(wg_abs "$1" "$cwd")")
}

# Operands of the current command: words that are not options, skipping the
# value of any option listed in $1 (space separated, e.g. "-m -t").
operands() {
  local takes=" $1 " a skip=0 end=0
  ops=()
  for a in "${args[@]}"; do
    if (( skip )); then skip=0; continue; fi
    if (( end )) || [[ $a != -* || $a == - ]]; then ops+=("$a")
    elif [[ $a == -- ]]; then end=1
    elif [[ $takes == *" $a "* ]]; then skip=1
    fi
  done
}

# True when one of the words in "${args[@]}" matches the extended regex $1.
has_arg() { local a; for a in "${args[@]}"; do [[ $a =~ $1 ]] && return 0; done; return 1; }

segment() {
  local w=("${words[@]}") c a k via_xargs=0
  while (( ${#w[@]} )); do
    case "${w[0]}" in
      xargs) via_xargs=1; w=("${w[@]:1}") ;;
      sudo|command|nohup|time|exec|builtin|env) w=("${w[@]:1}") ;;
      -*) [[ ${#w[@]} -gt 1 ]] && w=("${w[@]:1}") || break ;;
      [A-Za-z_]*=*) w=("${w[@]:1}") ;;
      *) break ;;
    esac
  done
  (( ${#w[@]} )) || return 0
  c=${w[0]##*/}
  args=("${w[@]:1}")

  # `... | xargs rm`: the operands arrive on stdin, so assume the working directory.
  if (( via_xargs )); then
    case "$c" in rm|rmdir|unlink|mv|cp|ln|chmod|chown|touch|truncate|sed|perl) add "$cwd"; return 0 ;; esac
  fi

  case "$c" in
    cd|pushd)
      operands ""
      [[ ${ops[0]:-} == - ]] || cwd=$(wg_abs "${ops[0]:-$HOME}" "$cwd") ;;
    rm|rmdir|unlink|shred|tee|mv)
      operands ""; for a in "${ops[@]}"; do add "$a"; done ;;
    touch)
      operands "-t -r -d"; for a in "${ops[@]}"; do add "$a"; done ;;
    mkdir)
      operands "-m"; for a in "${ops[@]}"; do add "$a"; done ;;
    truncate)
      operands "-s -r"; for a in "${ops[@]}"; do add "$a"; done ;;
    chmod|chown|chgrp)
      operands ""; for a in "${ops[@]:1}"; do add "$a"; done ;;
    cp|ln|install|rsync)
      operands "-t -m -o -g -S -e --exclude --include"
      k=0
      while (( k < ${#args[@]} )); do
        [[ ${args[k]} == -t ]] && add "${args[k+1]:-}"
        k=$((k+1))
      done
      if [[ $c == install ]] && has_arg '^-[a-zA-Z]*d'; then
        for a in "${ops[@]}"; do add "$a"; done
      elif (( ${#ops[@]} >= 2 )); then
        add "${ops[${#ops[@]}-1]}"
      fi ;;
    sed)
      if has_arg '^(-[a-zA-Z]*i|--in-place)'; then
        operands "-e -f"
        local files=()
        for a in "${ops[@]}"; do [[ -n $a ]] && files+=("$a"); done
        has_arg '^-(e|f)$' || files=("${files[@]:1}")
        for a in "${files[@]}"; do add "$a"; done
      fi ;;
    perl)
      if has_arg '^-[a-zA-Z]*i'; then
        operands "-e -E -M -I"
        local files=("${ops[@]}")
        has_arg '^-[a-zA-Z]*[eE]$' || files=("${files[@]:1}")
        for a in "${files[@]}"; do add "$a"; done
      fi ;;
    dd)
      for a in "${args[@]}"; do [[ $a == of=* ]] && add "${a#of=}"; done ;;
    find)
      k=0
      while (( k < ${#args[@]} )); do
        case "${args[k]}" in
          -delete) operands ""; add "${ops[0]:-.}"; break ;;
          -exec|-execdir|-ok|-okdir)
            case "${args[k+1]:-}" in rm|rmdir|mv|cp|chmod|chown|touch|truncate|sed|perl)
              operands ""; add "${ops[0]:-.}"; break ;;
            esac ;;
        esac
        k=$((k+1))
      done ;;
    git)
      local gdir=$cwd sub=""
      k=0
      while (( k < ${#args[@]} )); do
        a=${args[k]}
        case "$a" in
          -C) k=$((k+1)); gdir=$(wg_abs "${args[k]:-.}" "$gdir") ;;
          -c|--git-dir|--work-tree|--namespace) k=$((k+1)) ;;
          -*) ;;
          *) sub=$a; break ;;
        esac
        k=$((k+1))
      done
      case "$sub" in
        checkout|switch|restore|reset|clean|rm|mv|stash|apply|am|merge|rebase|cherry-pick|revert|commit) add "$gdir" ;;
      esac ;;
    npm|pnpm|yarn|bun)
      operands ""
      case "${ops[0]:-}" in
        install|i|ci|add|remove|rm|uninstall|un|update|up|upgrade|link) add "$cwd" ;;
        "") [[ $c == yarn ]] && add "$cwd" ;;
      esac ;;
  esac
}

words=()
redirect=0 input=0
for t in "${toks[@]}"; do
  if (( redirect )); then add "$t"; redirect=0; continue; fi
  if (( input )); then input=0; continue; fi
  case "$t" in
    "$US;") segment; words=() ;;
    "$US>") redirect=1 ;;
    "$US<") input=1 ;;
    *) words+=("$t") ;;
  esac
done
segment

for t in "${targets[@]}"; do
  wg_in_main_checkout "$t" && wg_deny "This command writes into the main checkout: $t. Run it inside a worktree instead (cd into the worktree, or use paths under it). Reading from the main checkout is fine, for example copying .env files into a worktree. If the main checkout itself must change, ask the user first."
done
exit 0
