---
type: llm
weight: 1
---

The answer states that interpolating COLUMNS is NOT an injection risk because COLUMNS is a hard-coded module constant and all user values go through $n parameters.
It points to concrete code locations (file and ideally line). It also notices a real secondary issue, e.g. EXPORT_SQL duplicates the column list by hand instead of using COLUMNS (and omits `result`), or the risk of the list drifting from the schema.
Fail if it calls the COLUMNS pattern an injection vulnerability.
