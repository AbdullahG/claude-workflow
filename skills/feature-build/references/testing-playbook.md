# Testing playbook

Read in Phase 2 and consult whenever you write a test. The goal is tests that fail when the feature is broken and only then.

## What a good test looks like (every level)

- **Named after behavior,** not method: `archivingAnItemMovesItToArchivedGroup`, not `testArchive2`.
- **Arrange, act, assert,** one behavior per test. Several asserts are fine when they describe one outcome.
- **Asserts on observable outcomes** (returned value, persisted row, HTTP response, rendered text, emitted event), not on private calls or internal state that a refactor would change.
- **Deterministic:** inject the clock, random, UUIDs, locale and time zone. No real network, no shared mutable state between tests, no order dependence. Each test creates what it needs and cleans up (or uses a fresh database/schema/container).
- **Fast at the bottom:** unit tests in milliseconds, integration in seconds, E2E as few as needed to cover every flow.
- **Failure message that diagnoses:** include the input and the actual value. A red test should tell the reader what broke without a debugger.
- **Builders over copy-paste fixtures:** a `makeItem(overrides)` style builder keeps tests short and resistant to model changes. Reuse the project's existing builders first.

## Unit

Cover: pure functions, state transitions (every edge of the state machine, including illegal ones), parsing and formatting with real-world ugly input (empty, whitespace, emoji, Turkish İ/ı casing, RTL, very long, mixed language), boundary values (0, 1, max, max+1, negative), rounding and time (DST, month end, time zone change, midnight).

Avoid: mocking collaborators that are cheap and deterministic; use the real ones. Mock only at true seams (I/O, clock, external services).

## Integration

Cover the boundaries you own, with real implementations:
- **Database:** real engine (the project's test DB or an in-memory/temporary file of the same engine, not a different engine). Test migrations up from the previous schema with existing data, constraints, indexes used by the new queries, transactions and rollback on failure.
- **API:** call handlers through the real router and middleware (auth, validation, rate limits, error mapping). Assert status codes, response bodies, and persisted side effects. Include unauthorized, forbidden, not found, validation error, conflict, and idempotent retry.
- **Client persistence and sync:** local cache writes, outbox enqueue and drain, retry after failure, conflict resolution, merge of offline edits, app restart mid-operation.
- **Contract:** client decoding against server-produced fixtures (and the server's response shape against the same fixtures) so the two sides cannot drift. When the contract changes, update fixtures from the real server output, not by hand.

## Functional / E2E

- **Every user flow in the plan has one happy-path E2E test,** start to finish, through the real UI against the real local backend. This is the test that would have caught the bug the user finds in the first five minutes.
- Add E2E for the most likely failure states (offline, server error, validation) and for anything involving multiple screens, navigation, or persistence across relaunch.
- Drive the UI by stable identifiers (accessibility identifiers, `data-testid`, roles and labels), never by coordinates or fragile view hierarchy paths. Add identifiers to the production code as part of the slice.
- Seed state through the backend API or a test-only launch argument, not by clicking through unrelated screens. Reuse the project's existing harness (e.g. launch arguments, debug hooks, `run.sh`, seed endpoints).
- Wait on conditions: element exists/is hittable, text appears, network idle, with explicit timeouts. Never `sleep`.
- Assert what the user sees: text, enabled/disabled, presence, order. Then, where it matters, also assert the backend state via API.
- Each test independent: fresh account or isolated user, clean state.

## Fakes for external services

External services (AI models, maps/places, payments, email, push) are always faked:
- Prefer a **local fake server** that speaks the same HTTP contract, selected by environment variable or base URL, so the production code path is exercised end to end. Fall back to an injected client double only for unit tests.
- Fakes return realistic, recorded-shape responses, including the ugly ones: slow, timeout, 429, 5xx, malformed body, empty results, partial results.
- Make fake behavior scriptable per test (e.g. a header, a query parameter, or a control endpoint) so a test can ask for the error case.
- Reuse an existing fake if the project has one; otherwise add it under the test tree and document it in `docs/testing.md`.

## Flakiness

Symptoms: passes alone, fails in the suite; passes locally, fails under load; fails at certain times. Usual causes and fixes:
- Race with async work → await the actual completion signal or expectation.
- Shared state (singletons, database rows, user defaults, keychain, files) → isolate per test, reset in setup.
- Order dependence → run the suite in random order or the single test alone to confirm.
- Real clock or time zone → inject the clock.
- Animations in UI tests → disable via launch argument or wait for the final state.
Confirm the fix by running the test five times in a row.

## Light mutation testing (Phase 5)

Pick the 3 to 5 rules that matter most (money, data loss, permissions, the core promise of the feature). Typical mutations:
- flip a boolean or comparison (`<` to `<=`, `==` to `!=`);
- shift a boundary or limit by one;
- remove a call (save, enqueue, notify, invalidate cache);
- return early or return an empty/default value;
- drop or rename a field in a request or response payload;
- swap the order of two side effects.
Apply one at a time, run only the relevant tests, confirm a failure, revert exactly, and confirm a clean diff. A survivor means a missing or toothless test.

## Traceability matrix format (`docs/plans/<slug>.tests.md`)

```markdown
# <Feature>: test matrix

Plan: [<slug>.md](<slug>.md) · Last run: <date>, all green / N failing

| Criterion | Test ID | Level | File | Status |
|---|---|---|---|---|
| AC-1 Saving a book shows it in Reading | U-01 | unit | Tests/.../FooTests.swift | pass |
|  | I-03 | integration | test/capture.int.test.ts | pass |
|  | E-01 | e2e | Tests/UITests/FooUITests.swift | pass |

## Not automatable
- <behavior>: <why>, manual check in Phase 6: <steps>

## Mutations
| Mutation | Caught by |
|---|---|
| Skip outbox enqueue in `save()` | I-05, E-01 |
```
