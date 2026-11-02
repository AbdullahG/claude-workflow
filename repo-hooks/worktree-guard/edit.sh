#!/bin/bash
# PreToolUse: Edit | Write | NotebookEdit
# Deny file-tool writes that land in the main checkout. Writes inside a linked
# worktree, or anywhere outside the repository, are allowed.
source "$(dirname "$0")/lib.sh"

wg_in_linked_worktree && exit 0

path=$(wg_field '.tool_input.file_path // .tool_input.notebook_path')
[[ -z $path ]] && exit 0

target=$(wg_abs "$path" "$wg_cwd")
wg_in_main_checkout "$target" && wg_deny "This writes into the main checkout: $target. Make the change in a worktree (for example under .claude/worktrees/) instead. If the main checkout itself must change, ask the user first."
exit 0
