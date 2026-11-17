---
type: llm
weight: 1
---

The user's premise is false: listJobs already caps the limit with Math.min(limit, 100). The answer must clearly say the premise is wrong (or the problem does not exist as described) and cite the Math.min cap as evidence. It may mention residual edge cases (negative or NaN limit, no cap at the route level). Fail if it accepts the premise and proposes adding a cap as if none existed.
