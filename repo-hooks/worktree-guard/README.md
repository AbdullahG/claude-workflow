# worktree-guard

Claude Code hooks that keep all work in git worktrees and the main checkout clean. Useful when you run several Claude sessions or subagents on one repository at the same time: each works in its own worktree, nobody overwrites anybody, and the main checkout stays a clean copy of `main` that new worktrees start from.

It is installed **per repository**, not per user, because whether a repo should be worktree-only is a decision about that repo.

## What it does

| Hook | Tool | Rule |
|---|---|---|
| `edit.sh` | Edit, Write, NotebookEdit | Denies writing a file inside the main checkout. Writes inside a linked worktree, or outside the repo, are allowed. |
| `bash.sh` | Bash | Works out which paths a shell command writes and denies the command if any of them is in the main checkout. Reading from the main checkout is allowed, so copying `.env` files into a worktree works. |
| `agent.sh` | Agent | Subagents that can write must use `isolation: "worktree"`. Read-only agents (Explore, Plan, claude-code-guide, statusline-setup) are exempt. In the main checkout it also requires HEAD to match `origin/main`, so a new worktree never starts from a stale base. |

When a session is started inside a linked worktree, the edit and bash guards step aside: that worktree is the place to work.

A denial is not a dead end. Each message tells Claude what to do instead, for example to `cd` into the worktree, to run `git pull --ff-only` on the main checkout, or to ask you.

### Finding the base branch

`agent.sh` uses `main`, looking for `origin/main` first, then a local `main`. If the repo has no `main`, it stops and tells Claude to **ask you** which branch new worktrees should start from, and how to save the answer:

```bash
git config worktreeGuard.baseBranch develop
```

### How `bash.sh` reads a command

It splits the command into simple commands (`;`, `&&`, `|`, newlines, subshells), follows `cd`, skips heredoc bodies and quoted text, and collects what each command writes:

- redirect targets (`>`, `>>`, `&>`; not `2>&1`)
- operands of `rm`, `mv`, `touch`, `mkdir`, `tee`, `truncate`, `chmod`, `chown`
- the destination of `cp`, `ln`, `install`, `rsync`
- files edited in place by `sed -i` and `perl -i`
- `dd of=`, `find -delete` or `find -exec rm`, and `xargs rm` (assumed to touch the working directory)
- the working tree for `git checkout|switch|restore|reset|clean|rm|mv|stash|apply|am|merge|rebase|cherry-pick|revert|commit`
- the working directory for `npm|pnpm|yarn|bun install|add|remove|update`

`git pull`, `git fetch`, `git config` and `git worktree add` stay allowed, so Claude can sync the main checkout and create worktrees.

**It is a guard rail, not a sandbox.** It does not see paths built from variables or `$(...)`, and it cannot know what a script or build tool writes (`npm run build`, `make`, `python script.py`). It catches the plain, common cases, which in practice are almost all of them.

## Install

Requires `git` and `jq` (recent macOS versions ship `jq`; on Linux install it from your package manager).

```bash
git clone https://github.com/AbdullahG/claude-workflow.git
claude-workflow/repo-hooks/worktree-guard/install.sh /path/to/your/repo
```

This copies the hooks into `.claude/hooks/worktree-guard/` and registers them in `.claude/settings.json`. Existing settings and other hooks are kept, and running it again updates the install.

Then **commit** `.claude/hooks/worktree-guard/` and `.claude/settings.json`. Committed hooks come along into every new worktree and to every teammate. Restart Claude Code sessions in that repo to load them.

To remove it: `install.sh --uninstall /path/to/your/repo`.

## Settings

All are optional. Set them for the whole team in the `env` block of `.claude/settings.json`, or for one clone with `git config` (env wins):

| Env (`.claude/settings.json` → `env`) | `git config` | Default | Meaning |
|---|---|---|---|
| `WORKTREE_GUARD_BASE_BRANCH` | `worktreeGuard.baseBranch` | `main` | Branch new worktrees start from. |
| `WORKTREE_GUARD_REMOTE` | `worktreeGuard.remote` | `origin` | Remote that holds the base branch. Without a remote, the local branch is used. |
| `WORKTREE_GUARD_EXEMPT_AGENTS` | `worktreeGuard.exemptAgents` | `Explore Plan claude-code-guide statusline-setup` | Space-separated agent types that may run without a worktree. |
| `WORKTREE_GUARD_WORKTREE_DIRS` | `worktreeGuard.worktreeDirs` | `.claude/worktrees` | Directories inside the repo where writes are always allowed. Linked worktrees anywhere are allowed automatically. |
| `WORKTREE_GUARD_REQUIRE_SYNCED` | `worktreeGuard.requireSynced` | `true` | Require the main checkout to match the base branch before starting a worktree agent. |
| `WORKTREE_GUARD_FETCH_INTERVAL` | `worktreeGuard.fetchInterval` | `300` | Seconds between `git fetch` calls made by `agent.sh`. Offline is fine: it uses the last fetched state. |
| `WORKTREE_GUARD_DISABLE` | `worktreeGuard.disable` | off | Turn every guard off, for example to fix the main checkout yourself in a session. |

Example, team-wide:

```json
{
  "env": {
    "WORKTREE_GUARD_BASE_BRANCH": "develop",
    "WORKTREE_GUARD_EXEMPT_AGENTS": "Explore Plan claude-code-guide statusline-setup code-reviewer"
  }
}
```

## Tests

```bash
repo-hooks/worktree-guard/test.sh
```

It builds throwaway repositories in a temp directory and feeds each hook the JSON Claude Code would send: 61 cases covering edit, bash, agent and install. It runs on the stock macOS `/bin/bash` (3.2).
