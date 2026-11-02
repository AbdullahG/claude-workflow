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

Plugin skills can be called without the `product:` prefix (`/feature-plan`, `/feature-build`) unless another plugin has a skill with the same name.

The plugin used to be called `pm-workflow`. If you installed it under that name, run `/plugin uninstall pm-workflow@abdullahg`, then install `product@abdullahg` as above.

### Option 2: Copy the skills manually

```bash
git clone https://github.com/AbdullahG/claude-workflow.git
mkdir -p ~/.claude/skills
cp -r claude-workflow/skills/feature-plan claude-workflow/skills/feature-build ~/.claude/skills/
```

Then use them as `/feature-plan <your feature>` and `/feature-build <plan path>`. To scope them to a single project, copy them into that project's `.claude/skills/` instead.

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
repo-hooks/
  worktree-guard/    # hooks installed per repository with install.sh
    README.md        # settings, limits, tests
```

## License

MIT
