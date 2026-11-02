#!/bin/bash
# Shared helpers for the worktree-guard hooks. Sourced by agent.sh, bash.sh
# and edit.sh, never run on its own. Written for bash 3.2 (macOS /bin/bash).
#
# Settings (each optional). Put team-wide values in the "env" block of
# .claude/settings.json, or set them per clone with `git config`:
#   WORKTREE_GUARD_DISABLE=1          git config worktreeGuard.disable true
#   WORKTREE_GUARD_BASE_BRANCH=dev    git config worktreeGuard.baseBranch dev
#   WORKTREE_GUARD_REMOTE=upstream    git config worktreeGuard.remote upstream
#   WORKTREE_GUARD_EXEMPT_AGENTS="Explore Plan"   (worktreeGuard.exemptAgents)
#   WORKTREE_GUARD_WORKTREE_DIRS=".claude/worktrees .worktrees"   (worktreeGuard.worktreeDirs)
#   WORKTREE_GUARD_REQUIRE_SYNCED=false           (worktreeGuard.requireSynced)
#   WORKTREE_GUARD_FETCH_INTERVAL=300             (worktreeGuard.fetchInterval)

wg_input=$(cat)

wg_field() { printf '%s' "$wg_input" | jq -r "($1) // empty" 2>/dev/null; }

wg_deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",
    permissionDecision:"deny", permissionDecisionReason:$r}}'
  exit 0
}

# The repository this session belongs to. Not a git repo: nothing to guard.
wg_root=${CLAUDE_PROJECT_DIR:-$(pwd)}
git -C "$wg_root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
wg_root=$(cd "$wg_root" && pwd)
wg_root_phys=$(cd "$wg_root" && pwd -P)

wg_cwd=$(wg_field '.cwd')
wg_cwd=${wg_cwd:-$(pwd)}

# wg_conf ENV_KEY gitKey default
wg_conf() {
  local name="WORKTREE_GUARD_$1" v
  eval "v=\${$name:-}"
  [[ -z $v ]] && v=$(git -C "$wg_root" config --get "worktreeGuard.$2" 2>/dev/null)
  printf '%s' "${v:-$3}"
}

case "$(wg_conf DISABLE disable "")" in 1|true|yes|on) exit 0 ;; esac

# True when the session itself runs inside a linked worktree (not the main checkout).
wg_in_linked_worktree() {
  local gd cd
  gd=$(git -C "$wg_root" rev-parse --path-format=absolute --git-dir 2>/dev/null)
  cd=$(git -C "$wg_root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  [[ -n $gd && $gd != "$cd" ]]
}

# Collapse //, /./ and /../ in an absolute path without touching the disk.
wg_norm() {
  local part out=() IFS=/
  read -ra parts <<< "$1"
  for part in "${parts[@]}"; do
    case "$part" in
      ''|.) ;;
      ..) [[ ${#out[@]} -gt 0 ]] && unset "out[$(( ${#out[@]} - 1 ))]" ;;
      *) out+=("$part") ;;
    esac
  done
  printf '/%s' "${out[*]}"
}

# Absolute, normalized, physical form of PATH resolved against DIR.
wg_abs() {
  local p=$1 base=$2
  case "$p" in
    "~") p=$HOME ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
    /*) ;;
    *) p="$base/$p" ;;
  esac
  p=$(wg_norm "$p")
  case "$p" in
    "$wg_root") p=$wg_root_phys ;;
    "$wg_root"/*) p="$wg_root_phys${p#"$wg_root"}" ;;
  esac
  printf '%s' "$p"
}

wg_linked_worktrees=$(git -C "$wg_root" worktree list --porcelain 2>/dev/null \
  | sed -n 's/^worktree //p' | tail -n +2)

# True when PATH (absolute, physical) is inside the main checkout and not inside
# a linked worktree or one of the configured worktree directories.
wg_in_main_checkout() {
  local p=$1 wt d
  case "$p" in "$wg_root_phys"|"$wg_root_phys"/*) ;; *) return 1 ;; esac
  while IFS= read -r wt; do
    [[ -z $wt ]] && continue
    case "$p" in "$wt"|"$wt"/*) return 1 ;; esac
  done <<< "$wg_linked_worktrees"
  for d in $(wg_conf WORKTREE_DIRS worktreeDirs ".claude/worktrees"); do
    case "$p" in "$wg_root_phys/$d"/*) return 1 ;; esac
  done
  return 0
}
