---
name: al-implement
description: Pick a ready task from tasks.md and run TDD on it for AL/Business Central. Codebase explore → /al-research (if non-trivial) → /grill-me to re-refine → red → green → /al-refactor → mutation discovery → /al-mutate (mandatory if non-trivial). Use to actually deliver behaviour, one task per session.
---

# /al-implement — Pick a task, run TDD

Pick the next ready task from `tasks.md`. Run TDD. Update `tasks.md`.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Pick task** from `tasks.md`.
2. **Codebase exploration**; `/al-research` if non-trivial.
3. **`/grill-me`** to re-refine — may add tests, split the task, or kick to `/al-refine`.
4. **Second opinion (gate)** on the task's Gherkin bullets — see *Second opinion gates* below. Mandatory for non-trivial.
5. **Red** — failing test that compiles. Add only the scaffold needed to compile; the test must fail on **behaviour**, not on missing types or syntax.
6. **Green** — smallest production change that turns the test green. No speculative code.
7. **`/al-refactor`** — improve shape; may add tests when uncovered branches surface.
8. **Mutation discovery** — list the mutations to verify; append to the task's `**Mutations**` section.
9. **Second opinion (gate)** on the mutation list — see *Second opinion gates* below. Mandatory for non-trivial.
10. **`/al-mutate`** — mandatory if non-trivial.
11. Mark task `[x]`. Stop. **One task, one session.**

## Trivial vs non-trivial

- **Trivial:** renaming, comments, formatting, obvious one-liners. Mutation testing optional.
- **Non-trivial:** anything touching BC standard surfaces, posting, events, dimensions, ledger entries, posting setup, transaction isolation, permissions, or AppSource compliance. **Research mandatory. Mutation testing mandatory.**

## Second opinion gates

Two gates cross-check the plan with copilot CLI for completeness and correctness. Independent perspective from a different training distribution — not authority. **Mandatory for non-trivial; skipped for trivial.**

**Invoke (both gates):** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt meta-shape (same for both):** artefact + goal + the gate question + *"return a bulleted list of gaps"*. No predefined out-of-scope rules — trust copilot to identify what matters in context.

- **Step 4 (pre-Red).** Artefact: the task's Gherkin bullets. Question: *what scenarios, negatives, or boundaries are missing or wrong?*
- **Step 9 (pre-`/al-mutate`).** Artefact: the proposed mutation list + the production code it targets + the operator priority. Question: *what mutations are missing or misaligned?*

**Reconcile each bullet:** accept (update artefact) or reject with a one-line reason as a Notes line. **No silent skip.** `/grill-me` when judgement needs the user.

**Trust:** copilot's AL/BC training is also thin — weigh against this skill's discipline and the task goal.

**Failure:** if copilot is unavailable / errors / times out, record `Second opinion skipped: <reason>` as a Notes line on the task and proceed.

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
- copilot CLI — second-opinion gates at steps 4 (pre-Red) and 9 (pre-`/al-mutate`).

## Out of scope

- No restructuring `tasks.md` beyond status updates and appended sub-tasks. Restructuring is `/al-refine`'s job.
