#!/bin/bash
# Install worktree-guard into one repository, or remove it.
#   install.sh [REPO]              copy the hooks into REPO/.claude/hooks/worktree-guard
#                                  and register them in REPO/.claude/settings.json
#   install.sh --uninstall [REPO]  undo both
# REPO defaults to the git repository of the current directory. Running it
# again updates an existing install. Requires git and jq.
set -euo pipefail

src=$(cd "$(dirname "$0")" && pwd)
mode=install
[[ ${1:-} == --uninstall ]] && { mode=uninstall; shift; }

for bin in git jq; do
  command -v "$bin" >/dev/null || { echo "worktree-guard: $bin is required" >&2; exit 1; }
done

repo=$(git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null) \
  || { echo "worktree-guard: ${1:-.} is not inside a git repository" >&2; exit 1; }
dest="$repo/.claude/hooks/worktree-guard"
settings="$repo/.claude/settings.json"

mkdir -p "$repo/.claude"
[[ -f $settings ]] || echo '{}' > "$settings"

# Drop our existing entries (if any), then add them back unless uninstalling.
add='[]'
if [[ $mode == install ]]; then
  add=$(jq -n --arg dir '"$CLAUDE_PROJECT_DIR"/.claude/hooks/worktree-guard' '[
    {matcher: "Agent",                     hooks: [{type: "command", command: ($dir + "/agent.sh")}]},
    {matcher: "Bash",                      hooks: [{type: "command", command: ($dir + "/bash.sh")}]},
    {matcher: "Edit|Write|NotebookEdit",   hooks: [{type: "command", command: ($dir + "/edit.sh")}]}
  ]')
fi
tmp=$(mktemp)
jq --argjson add "$add" '
  .hooks = (.hooks // {})
  | .hooks.PreToolUse = ((.hooks.PreToolUse // [])
      | map(select([.hooks[]?.command // "" | contains("/hooks/worktree-guard/")] | any | not))
      + $add)
  | if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end
  | if .hooks == {} then del(.hooks) else . end
' "$settings" > "$tmp"
mv "$tmp" "$settings"

if [[ $mode == install ]]; then
  mkdir -p "$dest"
  cp "$src"/lib.sh "$src"/agent.sh "$src"/bash.sh "$src"/edit.sh "$src"/tokenize.awk "$dest"/
  chmod +x "$dest"/*.sh
  echo "worktree-guard installed in $repo"
  echo "Commit .claude/hooks/worktree-guard and .claude/settings.json so every worktree and teammate gets it."
  echo "Restart Claude Code sessions in this repo to load the hooks."
else
  rm -rf "$dest"
  echo "worktree-guard removed from $repo"
fi
