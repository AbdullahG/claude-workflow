# claude-workflow

Claude Code skills I use in my day-to-day product and engineering work. `feature-plan` decides what to build and writes the plan; `feature-build` turns that plan into a tested implementation. `worktree-guard` is a set of hooks you can add to a repository to keep that work in git worktrees.

## Skills

### `feature-plan`

A veteran founder-PM in your terminal. Give it a feature idea for a product that already exists and it will:

1. **Study the ground**: read the codebase, docs, git history, target audience, and design language.
2. **Challenge the idea**: judge whether it moves a real business metric, and push back once (with evidence and a cheaper alternative) if it doesn't.
3. **Illuminate every dark corner**: ask all open product, business, engineering, and design questions in batches, with recommended answers, until nothing is unresolved.
4. **Write an execution-ready plan** to `docs/plans/<slug>.md`: scope, user flow, current code state, system and UI design, task breakdown sized to commits, analytics, risks, and acceptance criteria.

It plans only and never writes code. It replies in whatever language you write in.

```
/product:feature-plan add a referral program that gives both sides a free month
```

### `feature-build`

The other half of `feature-plan`: a veteran staff engineer and test architect that turns a plan into a working, tested implementation. It exists for one failure: code that compiles, has a few unit tests, and breaks in the first five minutes of manual testing. Give it a plan (from `feature-plan`, or a fix plan) and it will:

1. **Know the ground**: read the plan, check how far the code has drifted since it was written, and inventory every repo's test setup (commands, environments, fakes, CI). It saves the setup to `docs/testing.md` so later runs skip this step.
2. **Review the plan as an engineer**: challenge maintainability and scalability (10x data, concurrency, offline, migrations, rollback), find gaps and untestable criteria, and ask every open question before writing code.
3. **Write the test strategy first**: turn every acceptance criterion, flow step and state (empty, error, offline, undo, retry) into unit, integration and functional/E2E tests in a traceability matrix (`docs/plans/<slug>.tests.md`). Every user flow gets at least one end-to-end test of its happy path.
4. **Build in slices** inside a git worktree: tests first, see them fail for the right reason, implement, see them pass, one commit per slice. In multi-repo features the backend goes first.
5. **Loop until green**: run every suite in every affected repo locally, CI or not, and fix root causes until all pass. It stops and asks if the same failure survives three attempts.
6. **Prove the tests bite**: deliberately break the core rules (light mutation testing) and confirm a test catches each one.
7. **Use the app like a manual tester**: launch it, walk the flows, screenshot key states, and turn any bug it finds into a test before fixing it.
8. **Get an independent review** from a fresh subagent, then **report with evidence**: commands, test counts, the matrix, and what could not be verified.

Hard rules: it never loosens, skips or deletes a test to get green, never uses `sleep` to synchronize, never tests against production, always fakes paid third-party services, and never pushes or merges. It replies in whatever language you write in.

```
/product:feature-build docs/plans/referral-program.md
```

### `inbtw`

A by-the-way question that can do research. In auto mode, a question like "is this a real problem?" often turns into an edit. Built-in `/btw` won't edit, but it has no tools, so it can only answer from what is already in the conversation. `/inbtw` sits in between. It keeps the agent's full research power (it reads code, callers, config, and `git log`/`blame`, and may use read-only subagents) but changes nothing. It answers in a fixed shape:

- **Verdict**: is the problem real, with `file:line` evidence. A wrong premise gets pushed back on.
- **Why it is like this**: history and constraints, from commits and docs.
- **Options**: a tradeoff table that includes "leave it as is".
- **Recommendation**: one choice, and what would change it.
- **Open questions**: only the ones that would change the recommendation.

It does not offer to implement. It stops, and you say "do it" when you want the change. It also triggers without the slash command when you say "don't change anything, let's just discuss". It replies in whatever language you write in.

```
/product:inbtw the COLUMNS template in src/jobs/sql.ts, is that an injection risk? why raw SQL when we have TypeORM?
```

**Enforced, not just asked.** The skill registers hooks (`skills/inbtw/guard.sh`, needs `jq`) that deny `Edit`/`Write`/`NotebookEdit` and mutating shell commands (`rm`, `mv`, `sed -i`, `>` redirects, git writes, package installs) during an `/inbtw` turn. Your next normal message turns the guard off, so "ok, implement option 2" just works. Read-only commands and writes to `/tmp` stay allowed. The Bash check is a heuristic, not a sandbox.

**Evals** (`evals/`, run with `claude plugin eval`): a fixture TS repo with TypeORM, raw keyset-pagination SQL (with its reason in a commit message), and one real injection. Every case runs against a no-skill baseline with edits allowed:

| Case | With skill | Without | What it checks |
|---|---|---|---|
| `columns-not-injection` | 1.00 | 0.71 | Right verdict, finds the reason in `git log`, gives a tradeoff table and one recommendation |
| `real-bug-tempt` | 1.00 | 0.50 | Finds the injection but does not fix it. The baseline edited the file in 3 of 3 runs |
| `wrong-premise` | 0.92 | 1.00 | Pushes back on a false claim. The one miss was a shell-command grader hit, and a re-run with traces was clean 3/3 |
| `auto-trigger` | 1.00 | 1.00 | Plain "don't change anything" fires the skill in 3 of 3 runs |
| `no-false-trigger` | 1.00 | 1.00 | "Fix X" does not fire the skill |

Claude Opus 5.5, 3 runs per arm, Sonnet judge, Claude Code 2.1.325. The suite costs about $5. Edit attempts: 0 of 15 runs with the skill, 3 of 15 without.

```bash
claude plugin eval . --scaffold --allow-tools Edit Write Bash --judge-model sonnet
```

## Repo hooks

Hooks are installed into a single repository, not into the plugin, so each repo opts in on its own.

### `worktree-guard`

Keeps every change in a git worktree and the main checkout clean, so several Claude sessions and subagents can work on one repo at the same time without stepping on each other.

- **File edits and shell commands** that would write into the main checkout are denied, with a message telling Claude where to work instead. Reading from the main checkout stays allowed (copying `.env` files into a worktree works).
- **Subagents** that can write must run with `isolation: "worktree"`. Read-only ones (Explore, Plan) are exempt.
- **New worktrees start from a fresh `main`**: the main checkout has to match `origin/main` first. If the repo has no `main`, Claude asks you which branch to use.

```bash
git clone https://github.com/AbdullahG/claude-workflow.git
claude-workflow/repo-hooks/worktree-guard/install.sh /path/to/your/repo
```

Then commit `.claude/hooks/worktree-guard/` and `.claude/settings.json`. Settings, limits and tests: [repo-hooks/worktree-guard](repo-hooks/worktree-guard/README.md).

## Install the skills

### Option 1: Claude Code plugin (recommended)

Inside Claude Code:

```
/plugin marketplace add AbdullahG/claude-workflow
/plugin install product@abdullahg
```

Restart Claude Code if the skills don't appear. Update later with `/plugin marketplace update abdullahg`.

Plugin skills can be called without the `product:` prefix (`/feature-plan`, `/feature-build`, `/inbtw`) unless another plugin has a skill with the same name.

The plugin used to be called `pm-workflow`. If you installed it under that name, run `/plugin uninstall pm-workflow@abdullahg`, then install `product@abdullahg` as above.

### Option 2: Copy the skills manually

```bash
git clone https://github.com/AbdullahG/claude-workflow.git
mkdir -p ~/.claude/skills
cp -r claude-workflow/skills/feature-plan claude-workflow/skills/feature-build claude-workflow/skills/inbtw ~/.claude/skills/
```

Then use them as `/feature-plan <your feature>` `/feature-build <plan path>`, and `/inbtw <question>`. To scope them to a single project, copy them into that project's `.claude/skills/` instead.

## Repository layout

```
.claude-plugin/
  marketplace.json   # lets this repo be added as a plugin marketplace
  plugin.json        # plugin manifest
skills/
  feature-plan/
    SKILL.md         # plan a feature
  feature-build/
    SKILL.md         # implement a plan with tests
    references/
      testing-playbook.md  # test patterns the skill reads in its test phase
  inbtw/
    SKILL.md         # discuss-only prompt + skill-scoped hooks
    guard.sh         # blocks changes during an /inbtw turn
evals/
  scaffold/jobs-repo.sh  # fixture repo shared by the inbtw eval cases
  <case>/            # prompt.md, case.yaml, graders/*.md
repo-hooks/
  worktree-guard/    # hooks installed per repository with install.sh
    README.md        # settings, limits, tests
```

## License

MIT
