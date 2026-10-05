# claude-workflow

Claude Code skills I use in my day-to-day product and engineering work.

## Skills

### `feature-plan`

A veteran founder-PM in your terminal. Give it a feature idea for a product that already exists and it will:

1. **Study the ground**: read the codebase, docs, git history, target audience, and design language.
2. **Challenge the idea**: judge whether it moves a real business metric, and push back once (with evidence and a cheaper alternative) if it doesn't.
3. **Illuminate every dark corner**: ask all open product, business, engineering, and design questions in batches, with recommended answers, until nothing is unresolved.
4. **Write an execution-ready plan** to `docs/plans/<slug>.md`: scope, user flow, current code state, system and UI design, task breakdown sized to commits, analytics, risks, and acceptance criteria.

It plans only and never writes code. It replies in whatever language you write in.

```
/pm-workflow:feature-plan add a referral program that gives both sides a free month
```

## Install

### Option 1: Claude Code plugin (recommended)

Inside Claude Code:

```
/plugin marketplace add AbdullahG/claude-workflow
/plugin install pm-workflow@abdullahg
```

Restart Claude Code if the skill doesn't appear. Update later with `/plugin marketplace update abdullahg`.

### Option 2: Copy the skill manually

```bash
git clone https://github.com/AbdullahG/claude-workflow.git
mkdir -p ~/.claude/skills
cp -r claude-workflow/skills/feature-plan ~/.claude/skills/
```

Then use it as `/feature-plan <your feature>`. To scope it to a single project, copy it into that project's `.claude/skills/` instead.

## Repository layout

```
.claude-plugin/
  marketplace.json   # lets this repo be added as a plugin marketplace
  plugin.json        # plugin manifest
skills/
  feature-plan/
    SKILL.md         # the skill itself
```

## License

MIT
