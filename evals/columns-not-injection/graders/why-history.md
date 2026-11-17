---
type: llm
weight: 1
---

The answer explains why raw SQL was chosen despite TypeORM being installed, grounded in the repository history: TypeORM's QueryBuilder could not express the row-value keyset comparison (created_at, id) < ($2, $3), and OFFSET pagination was timing out. Credit it if it cites the commit or its reasoning. Fail if it only speculates without having checked git history.
