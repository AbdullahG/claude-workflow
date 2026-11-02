#!/bin/bash
# PreToolUse: Agent
# 1) Subagents that can write files must run with isolation: "worktree".
#    Read-only agent types (Explore, Plan, ... see EXEMPT_AGENTS) are exempt.
# 2) In the main checkout, HEAD must match the base branch on the remote, so the
#    new worktree does not start from a stale base. The base branch is `main`
#    unless configured; when there is no `main`, the hook asks Claude to ask the
#    user which branch to use and how to save it.
source "$(dirname "$0")/lib.sh"

type=$(wg_field '.tool_input.subagent_type')
type=${type:-general-purpose}
for t in $(wg_conf EXEMPT_AGENTS exemptAgents "Explore Plan claude-code-guide statusline-setup"); do
  [[ $t == "$type" ]] && exit 0
done

iso=$(wg_field '.tool_input.isolation')
[[ $iso != worktree ]] && wg_deny "Agent calls of type \"$type\" must use isolation: \"worktree\" in this repository. Re-run the call with isolation set. (Read-only agent types are exempt: $(wg_conf EXEMPT_AGENTS exemptAgents "Explore Plan claude-code-guide statusline-setup").)"

# From inside a linked worktree the new worktree starts from that worktree's branch, by design.
wg_in_linked_worktree && exit 0
case "$(wg_conf REQUIRE_SYNCED requireSynced true)" in 0|false|no|off) exit 0 ;; esac

remote=$(wg_conf REMOTE remote origin)
branch=$(wg_conf BASE_BRANCH baseBranch "")
git -C "$wg_root" remote get-url "$remote" >/dev/null 2>&1 && has_remote=1 || has_remote=0

# Fetch at most once per FETCH_INTERVAL seconds. Offline is not an error: the
# check below then uses the last fetched state.
if (( has_remote )); then
  stamp="$(git -C "$wg_root" rev-parse --path-format=absolute --git-common-dir)/worktree-guard-last-fetch"
  now=$(date +%s)
  last=$(cat "$stamp" 2>/dev/null || echo 0)
  if (( now - last >= $(wg_conf FETCH_INTERVAL fetchInterval 300) )); then
    git -C "$wg_root" fetch -q "$remote" ${branch:+"$branch"} 2>/dev/null && printf '%s\n' "$now" > "$stamp"
  fi
fi

ref_exists() { git -C "$wg_root" rev-parse --verify -q "$1^{commit}" >/dev/null 2>&1; }
ask="Ask the user which branch new worktrees should start from, then save the answer for this clone with: git -C \"$wg_root\" config worktreeGuard.baseBranch <branch> (or set WORKTREE_GUARD_BASE_BRANCH in the env block of .claude/settings.json for the whole team). Then re-run the Agent call."

if [[ -z $branch ]]; then
  if (( has_remote )) && ref_exists "refs/remotes/$remote/main"; then branch=main
  elif ref_exists refs/heads/main; then branch=main
  else wg_deny "This repository has no \"main\" branch, so the worktree guard does not know which branch is the base. $ask"
  fi
fi

if (( has_remote )) && ref_exists "refs/remotes/$remote/$branch"; then base="$remote/$branch"
elif ref_exists "refs/heads/$branch"; then base=$branch
else wg_deny "The configured base branch \"$branch\" does not exist here. $ask"
fi

head=$(git -C "$wg_root" rev-parse HEAD 2>/dev/null)
want=$(git -C "$wg_root" rev-parse "$base" 2>/dev/null)
if [[ $head != "$want" ]]; then
  behind=$(git -C "$wg_root" rev-list --count "$head..$want")
  ahead=$(git -C "$wg_root" rev-list --count "$want..$head")
  if (( ahead == 0 )); then
    wg_deny "The main checkout is $behind commit(s) behind $base, so a new worktree would start from a stale base. Update it with: git -C \"$wg_root\" pull --ff-only $( ((has_remote)) && printf '%s %s' "$remote" "$branch" ). Then re-run the Agent call."
  fi
  wg_deny "The main checkout is not at $base (behind $behind, ahead $ahead), so a new worktree would not start from $base. Ask the user how to bring the main checkout back to $base before re-running the Agent call. (To turn this check off: git -C \"$wg_root\" config worktreeGuard.requireSynced false.)"
fi
exit 0
