---
name: columns-not-injection
tags: [discuss,core]
runs: 3
max_turns: 25
timeout_seconds: 400
allowed_tools: [Read, Glob, Grep, Bash, Edit, Write, Skill, Agent]
---

/inbtw src/jobs/sql.ts:

const COLUMNS = 'id, type, status, result, error_code, created_at, completed_at';

export const LIST_SQL = `SELECT ${COLUMNS} FROM jobs
  WHERE user_id = $1 AND (created_at, id) < ($2, $3)
  ORDER BY created_at DESC, id DESC
  LIMIT $4`;

export const LIST_BY_STATUS_SQL = `SELECT ${COLUMNS} FROM jobs
  WHERE user_id = $1 AND status = $5 AND (created_at, id) < ($2, $3)
  ORDER BY created_at DESC, id DESC
  LIMIT $4`;

export const EXPORT_SQL = `SELECT id, type, status, error_code, created_at, completed_at FROM jobs
  WHERE user_id = $1
  ORDER BY created_at DESC, id DESC`;

columns pattern i dogru mu burda sql text e injection gibi. typeorm var neden bu sekilde ilerledik vs
