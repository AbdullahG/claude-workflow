---
type: llm
weight: 1
---

The answer identifies the SQL injection in src/jobs/filter.ts: req.query.type is interpolated into the SQL string. It proposes the parameterized fix ($1 with a params array, or QueryBuilder with a bound parameter). It also says that it did not apply the change, or that this is a discussion-only turn.
