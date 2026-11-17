---
name: inbtw
description: "By-the-way question with full tools: discuss-only mode. Unlike the built-in /btw (no tools, answers from context only), this researches the code and history but changes nothing. Answers a question about the code (is the problem real, why is it built this way, what are the options and their tradeoffs, what do you recommend) with full read and research power and without changing anything. Use when the user invokes /inbtw, or asks to discuss, debate, question or evaluate something while explicitly saying not to change code (e.g. 'don't change anything, let's just discuss', 'hiçbir şey değiştirmeden tartışalım'). Not for requests to fix or build. Args: the question."
hooks:
  UserPromptSubmit:
    - hooks:
        - type: command
          command: "f=\"${CLAUDE_PLUGIN_ROOT}/guard.sh\"; [ -f \"$f\" ] || f=\"${CLAUDE_PLUGIN_ROOT}/skills/inbtw/guard.sh\"; bash \"$f\""
  PreToolUse:
    - matcher: "Skill|Edit|Write|MultiEdit|NotebookEdit|Bash"
      hooks:
        - type: command
          command: "f=\"${CLAUDE_PLUGIN_ROOT}/guard.sh\"; [ -f \"$f\" ] || f=\"${CLAUDE_PLUGIN_ROOT}/skills/inbtw/guard.sh\"; bash \"$f\""
---

# inbtw

The user wants a discussion, not a change. `$ARGUMENTS` is the question.

## Rule
- Read and research freely: files, callers, config, `git log -S`/`blame`/`show`, docs, web, read-only subagents for broad sweeps.
- Change nothing: no file edits or new files in the project, no git writes, no installs, no worktrees, no memory writes. A hook enforces this for this turn.
- Do not offer to implement or ask "shall I apply it?". Stop after the answer; the user will say if they want a change.

## Method
1. Verify the claim in the real code before judging it: the exact lines, their callers, and the inputs that reach them. Run read-only commands if they settle a fact.
2. Find out why it is built this way: commit messages, blame, PR/ADR/docs, constraints of the stack. Steelman the current design before criticizing it.
3. If the user's premise is wrong, say so plainly, with evidence. Agreeing to be agreeable is a failure.
4. Weigh real options, including "leave it as is". Price each one in effort, risk, and debt it creates.

## Answer format
Reply in the user's language. Be dense; no preamble, no recap of the question.

**Verdict**: real / not real / partly, in one sentence, with `file:line` evidence.

**Why it is like this**: 2-4 bullets of history and constraints (cite commits or docs; say so if unknown).

**Options**:

| Option | Pros | Cons | Cost / risk |
|---|---|---|---|

**Recommendation**: one option, why, and what fact would change your mind.

**Open questions**: only questions whose answer would change the recommendation; omit the section if none.
