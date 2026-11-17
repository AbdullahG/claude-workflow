---
name: no-false-trigger
tags: [trigger,negative]
runs: 3
max_turns: 25
timeout_seconds: 400
allowed_tools: [Read, Glob, Grep, Bash, Edit, Write, Skill, Agent]
---

src/jobs/filter.ts'deki SQL injection'i duzelt.
