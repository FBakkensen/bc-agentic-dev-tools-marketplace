---
name: al-implement
description: Pick a ready task from tasks.md and run TDD on it for AL/Business Central. Codebase explore → /al-research (if non-trivial) → /grill-me to re-refine → red → green → /al-refactor → mutation discovery → /al-mutate (mandatory if non-trivial). Use to actually deliver behaviour, one task per session.
---

# /al-implement — Pick a task, run TDD

Pick the next ready task from `tasks.md`. Run TDD. Update `tasks.md`.

## Flow

1. **Pick task** from `tasks.md`.
2. **Codebase exploration**; `/al-research` if non-trivial.
3. **`/grill-me`** to re-refine — may add tests, split the task, or kick to `/al-refine`.
4. **Red** — failing test that compiles. Add only the scaffold needed to compile; the test must fail on **behaviour**, not on missing types or syntax.
5. **Green** — smallest production change that turns the test green. No speculative code.
6. **`/al-refactor`** — improve shape; may add tests when uncovered branches surface.
7. **Mutation discovery** — list the mutations to verify; append to the task's `**Mutations**` section.
8. **`/al-mutate`** — mandatory if non-trivial.
9. Mark task `[x]`. Stop. **One task, one session.**

## Trivial vs non-trivial

- **Trivial:** renaming, comments, formatting, obvious one-liners. Mutation testing optional.
- **Non-trivial:** anything touching BC standard surfaces, posting, events, dimensions, ledger entries, posting setup, transaction isolation, permissions, or AppSource compliance. **Research mandatory. Mutation testing mandatory.**

## Tests (when transcribing Gherkin bullets to AL)

- **Test naming:** short PascalCase, BC BaseApp style (e.g. `PostSalesOrderWithBlockedCustomer`). **Not** `GivenX_WhenY_ThenZ`.
- **Body comments:** `// [FEATURE]` in `OnRun()`; `// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]` inside each test.
- Each test calls a local `Initialize()` as its first statement.
- Both positive AND negative cases. Boundaries when relevant.
- **Verify the AL `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` restates the originating Gherkin bullet faithfully.** If they drift, either fix the test or update the bullet — never let them diverge silently.

## Naming and vocabulary (state explicitly — do not rely on CLAUDE.md)

- **BC vocabulary:** Insert / Modify / Delete (records — not Create/Update/Remove), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Record variables** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures:** PascalCase, verb-first (`CreateCustomer`, `ValidateEmail`). **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## When to stop early

- Task is wrong or too large → leave a Notes line in `tasks.md`, recommend `/al-refine`. **Do not silently expand.**
- Discovered sub-task → append to `tasks.md` (new T-NNN), continue the original.

## Composition

- `/grill-me` whenever intent is ambiguous.
- `/al-research` for non-trivial BC areas.
- `/al-build` to compile and run tests.
- `/bc-standard-reference` for BC patterns and BaseApp behaviour.
- `/al-debug-logging` only when execution path is unclear and tests can't reveal it.
- `/al-refactor` after green.
- `/al-mutate` after refactor (mandatory if non-trivial).

## Out of scope

- No restructuring `tasks.md` beyond status updates and appended sub-tasks. Restructuring is `/al-refine`'s job.
