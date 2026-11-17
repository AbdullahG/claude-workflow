---
name: auto-trigger
tags: [trigger]
runs: 3
max_turns: 25
timeout_seconds: 400
allowed_tools: [Read, Glob, Grep, Bash, Edit, Write, Skill, Agent]
---

Hicbir sey degistirmeden tartisalim: src/jobs/sql.ts'deki ${COLUMNS} interpolation'i SQL injection riski mi?
