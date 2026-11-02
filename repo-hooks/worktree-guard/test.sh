#!/bin/bash
# Tests for the worktree-guard hooks. Builds throwaway repositories in a temp
# directory, feeds each hook the JSON Claude Code would send, and checks
# whether it allows or denies. Run: ./test.sh   (needs git and jq)
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export WORKTREE_GUARD_FETCH_INTERVAL=0

git init -q --bare -b main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/repo" 2>/dev/null
R="$tmp/repo"
git -C "$R" commit -q --allow-empty -m init
git -C "$R" push -q origin main
git -C "$R" worktree add -q "$R/.claude/worktrees/wt" -b wt
git -C "$R" worktree add -q "$tmp/sibling" -b sib
W="$R/.claude/worktrees/wt"
S="$tmp/sibling"

pass=0 fail=0
# check NAME EXPECT(allow|deny) HOOK PROJECT_DIR JSON
check() {
  local name=$1 want=$2 hook=$3 proj=$4 json=$5 out got
  out=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR=$proj /bin/bash "$here/$hook" 2>&1)
  if printf '%s' "$out" | grep -q '"permissionDecision": *"deny"'; then got=deny; else got=allow; fi
  if [[ $got == "$want" ]]; then pass=$((pass+1)); printf '  ok    %s\n' "$name"
  else fail=$((fail+1)); printf '  FAIL  %s (wanted %s, got %s)\n%s\n' "$name" "$want" "$got" "$out"; fi
}
bashj() { jq -n --arg c "$1" --arg d "$2" '{cwd:$d, tool_input:{command:$c}}'; }
editj() { jq -n --arg p "$1" --arg d "$2" '{cwd:$d, tool_input:{file_path:$p}}'; }
agentj() { jq -n --arg t "$1" --arg i "$2" --arg d "$R" '{cwd:$d, tool_input:{subagent_type:$t, isolation:$i, prompt:"x"}}'; }

echo "edit.sh"
check "edit in main checkout"             deny  edit.sh "$R" "$(editj "$R/src/a.ts" "$R")"
check "edit relative path from main"      deny  edit.sh "$R" "$(editj "src/a.ts" "$R")"
check "edit in .claude/worktrees"         allow edit.sh "$R" "$(editj "$W/src/a.ts" "$R")"
check "edit in sibling worktree"          allow edit.sh "$R" "$(editj "$S/a.ts" "$R")"
check "edit outside the repo"             allow edit.sh "$R" "$(editj "/tmp/x.md" "$R")"
check "edit escaping a worktree with .."  deny  edit.sh "$R" "$(editj "$W/../../../src/a.ts" "$R")"
check "edit relative path from worktree"  allow edit.sh "$R" "$(editj "src/a.ts" "$W")"
check "session started inside worktree"   allow edit.sh "$W" "$(editj "$W/src/a.ts" "$W")"
WORKTREE_GUARD_DISABLE=1 check "disabled with env (set)" allow edit.sh "$R" "$(editj "$R/a" "$R")"

echo "bash.sh: denied"
for c in \
  "echo x > src/a.ts" \
  "echo x >> $R/a.txt" \
  "rm -rf docs" \
  "cp $W/a.ts $R/b.ts" \
  "mv $R/a $W/a" \
  "sed -i '' 's/a/b/' $R/f.ts" \
  "sed -i 's/a/b/' f.ts" \
  "perl -pi -e 's/a/b/' f.ts" \
  "cd $W && cd $R && touch x" \
  "mkdir -p $R/new/dir" \
  "git -C $R commit -m x" \
  "git checkout -b feature" \
  "npm install" \
  "find . -name '*.log' -delete" \
  "ls | xargs rm" \
  "cat > $R/notes.md <<'EOF'
hello > world
EOF" \
  "cat <<'EOF' > $W/ok.md
body
EOF
rm -rf $R/src" \
  "tee $R/out.txt < /dev/null" \
  "echo x &> $R/log"
do check "$c" deny bash.sh "$R" "$(bashj "$c" "$R")"; done

echo "bash.sh: allowed"
for c in \
  "ls -la; git status" \
  "cat $R/README.md 2>/dev/null" \
  "grep -rn 'a > b' $R/src" \
  "cp $R/.env.local $W/" \
  "cp $R/.env.local $W/.env.local && cp $R/.dev.vars $S/" \
  "cd $W && echo x > src/a.ts" \
  "echo x > /tmp/out.txt" \
  "git -C $R pull --ff-only origin main" \
  "git -C $R fetch && git -C $R worktree add $R/.claude/worktrees/n -b n" \
  "git -C $R config worktreeGuard.baseBranch develop" \
  "npm run build --prefix $W" \
  "find . -name '*.ts' -exec grep -l foo {} \\;" \
  "echo hi 2>&1 | tee /tmp/log" \
  "git -C $W commit -m \"\$(cat <<'EOF'
fix > things
EOF
)\"" \
  "cat <<'EOF' > $W/x.md
rm -rf $R
EOF"
do check "$c" allow bash.sh "$R" "$(bashj "$c" "$R")"; done
check "relative write from a worktree cwd" allow bash.sh "$R" "$(bashj "echo x > a.ts" "$W")"
check "bash in a session started inside worktree" allow bash.sh "$W" "$(bashj "rm -rf src" "$W")"

echo "agent.sh"
check "general-purpose without isolation" deny  agent.sh "$R" "$(agentj general-purpose "")"
check "no subagent_type, no isolation"    deny  agent.sh "$R" "$(jq -n '{tool_input:{prompt:"x"}}')"
check "Explore without isolation"         allow agent.sh "$R" "$(agentj Explore "")"
check "Plan without isolation"            allow agent.sh "$R" "$(agentj Plan "")"
check "with isolation, main in sync"      allow agent.sh "$R" "$(agentj general-purpose worktree)"
git clone -q "$tmp/origin.git" "$tmp/other" 2>/dev/null
git -C "$tmp/other" commit -q --allow-empty -m remote-change && git -C "$tmp/other" push -q origin main
check "main checkout behind origin/main"  deny  agent.sh "$R" "$(agentj general-purpose worktree)"
git -C "$R" pull -q --ff-only origin main
check "after pull"                        allow agent.sh "$R" "$(agentj general-purpose worktree)"
git -C "$R" commit -q --allow-empty -m local
check "main checkout ahead (local work)"  deny  agent.sh "$R" "$(agentj general-purpose worktree)"
WORKTREE_GUARD_REQUIRE_SYNCED=false check "sync check turned off" allow agent.sh "$R" "$(agentj general-purpose worktree)"
WORKTREE_GUARD_EXEMPT_AGENTS="general-purpose" check "custom exempt list" allow agent.sh "$R" "$(agentj general-purpose "")"

# A repository whose only branch is master, with no remote.
M="$tmp/master-repo"
git init -q -b master "$M" && git -C "$M" commit -q --allow-empty -m init
check "no main branch: asks the user"     deny  agent.sh "$M" "$(agentj general-purpose worktree)"
out=$(agentj general-purpose worktree | CLAUDE_PROJECT_DIR=$M /bin/bash "$here/agent.sh")
printf '%s' "$out" | grep -q 'Ask the user which branch' && { pass=$((pass+1)); echo "  ok    deny message tells Claude to ask"; } \
  || { fail=$((fail+1)); echo "  FAIL  deny message tells Claude to ask: $out"; }
git -C "$M" config worktreeGuard.baseBranch master
check "base branch configured"            allow agent.sh "$M" "$(agentj general-purpose worktree)"
check "not a git repository"              allow agent.sh "$tmp" "$(agentj general-purpose "")"

echo "install.sh"
I="$tmp/install-repo"
git init -q -b main "$I"
echo '{"permissions":{"allow":["Bash(ls)"]},"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"other.sh"}]}]}}' > "$I/.claude-settings-seed"
mkdir -p "$I/.claude" && mv "$I/.claude-settings-seed" "$I/.claude/settings.json"
/bin/bash "$here/install.sh" "$I" >/dev/null && /bin/bash "$here/install.sh" "$I" >/dev/null
n=$(jq '[.hooks.PreToolUse[] | select(.hooks[0].command | contains("worktree-guard"))] | length' "$I/.claude/settings.json")
keep=$(jq -r '.hooks.PreToolUse[0].hooks[0].command + " " + .permissions.allow[0]' "$I/.claude/settings.json")
[[ $n == 3 && $keep == "other.sh Bash(ls)" && -x "$I/.claude/hooks/worktree-guard/bash.sh" ]] \
  && { pass=$((pass+1)); echo "  ok    install twice: 3 entries, existing settings kept"; } \
  || { fail=$((fail+1)); echo "  FAIL  install: n=$n keep=$keep"; }
/bin/bash "$here/install.sh" --uninstall "$I" >/dev/null
n=$(jq '[.hooks.PreToolUse[]? | select(.hooks[0].command | contains("worktree-guard"))] | length' "$I/.claude/settings.json")
[[ $n == 0 && ! -e "$I/.claude/hooks/worktree-guard" && $(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$I/.claude/settings.json") == other.sh ]] \
  && { pass=$((pass+1)); echo "  ok    uninstall removes only our entries"; } \
  || { fail=$((fail+1)); echo "  FAIL  uninstall"; }

echo
echo "$pass passed, $fail failed"
(( fail == 0 ))
