#!/usr/bin/env bash
# inbtw guard: blocks changes during a /inbtw turn.
# Skill-scoped hooks stay registered for the rest of the session, so the
# guard keeps a per-session state: "on" while the user is just asking,
# "off" once they send a normal prompt (e.g. "ok, implement it").
# No state file yet = the skill was just loaded this turn = on.

input=$(cat)
deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"inbtw: discussion-only turn, nothing may change (%s). Answer in text; the user will ask for changes in a new message."}}\n' "$1"
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  # Fail safe: without jq, block only the file-editing tools.
  case "$input" in *'"tool_name":"Edit"'*|*'"tool_name":"Write"'*|*'"tool_name":"MultiEdit"'*|*'"tool_name":"NotebookEdit"'*) deny "file edit" ;; esac
  exit 0
fi

event=$(jq -r '.hook_event_name // empty' <<<"$input")
sid=$(jq -r '.session_id // "nosession"' <<<"$input")
state="${TMPDIR:-/tmp}/inbtw-${sid}"

if [ "$event" = "UserPromptSubmit" ]; then
  if jq -r '.prompt // empty' <<<"$input" | grep -qE '^[[:space:]]*/([a-z0-9-]+:)?inbtw\b'; then
    echo on >"$state"
  else
    echo off >"$state"
  fi
  exit 0
fi

tool=$(jq -r '.tool_name // empty' <<<"$input")

if [ "$tool" = "Skill" ]; then
  jq -r '.tool_input.skill // empty' <<<"$input" | grep -qE '(^|:)inbtw$' && echo on >"$state"
  exit 0
fi

[ "$(cat "$state" 2>/dev/null)" = "off" ] && exit 0

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit) deny "file edit" ;;
  Bash)
    cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
    # Ignore harmless redirects before looking for writes.
    clean=$(sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g" <<<"$cmd" | sed -E 's#[0-9]*>&[0-9]##g; s#[0-9]*>>? */dev/null##g; s#[0-9]*>>? *("?\$TMPDIR|/tmp/|/private/tmp/)[^ ;|&]*##g')
    if grep -qE '(^|[;&|(]|\bxargs|\bthen|\bdo)[[:space:]]*(sudo[[:space:]]+)?(rm|mv|cp|mkdir|touch|chmod|chown|ln|tee|truncate|dd|patch)\b' <<<"$clean" \
      || grep -qE '\bsed[[:space:]]+(-[a-zA-Z]*i|--in-place)|\bperl[[:space:]]+-[a-zA-Z]*i' <<<"$clean" \
      || grep -qE '\bgit[[:space:]]+(-C[[:space:]]+[^ ]+[[:space:]]+)?(commit|push|reset|checkout|switch|restore|stash|merge|rebase|cherry-pick|revert|clean|add|rm|mv|apply|am|tag|worktree|pull|init)\b' <<<"$clean" \
      || grep -qE '\b(npm|pnpm|yarn|bun|pip3?|uv|poetry|brew|cargo|go)[[:space:]]+(i|install|add|remove|rm|uninstall|update|upgrade|get)\b' <<<"$clean" \
      || grep -qE '>' <<<"$clean"; then
      deny "mutating shell command"
    fi
    ;;
esac
exit 0
