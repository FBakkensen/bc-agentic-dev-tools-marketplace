---
name: al-implement
description: Pick a ready task from tasks.md and run TDD on it for AL/Business Central. Requires Gherkin from /al-refine — if missing, run /al-refine first. Implementation context → red → green → /al-refactor → refine mutation plan → /al-mutate. Use to actually deliver behaviour, one task per session.
---

# /al-implement — Pick a task, run TDD

Pick the next ready task from `tasks.md`. Run TDD. Update `tasks.md`.

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-scope` first.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Pick task** from `tasks.md`. `**Tests**` block must exist — if missing, stop: run `/al-refine <T-NNN>` first. `**Architecture**` block must exist — if missing, stop: run `/al-architect <T-NNN>` first.
2. **Implementation context** — locate the test codeunit and production code (read the `**Architecture**` block; check Notes for file paths left by `/al-refine`; otherwise a quick Glob/Grep). No heavy exploration — `/al-refine` and `/al-architect` already did that.
3. **Red** — transcribe Gherkin bullet → AL test. Must compile and fail on **behaviour**, not on missing types or syntax.
4. **Green** — smallest production change that turns the test green. No speculative code.
5. **`/al-refactor`** — improve shape; seed the refactor checklist from the task's `**Architecture**` brownfield touchpoints; may add tests when uncovered branches surface.
6. **Mutation gate** — if changed production lines contain decision logic (see **When to mutate**): list mutations on the changed lines only, one per unique operator site, in `/al-mutate` priority order. Append to `**Mutations**` section. If no decision logic: append `**Mutations:** skipped — no decision logic changed`.
7. **Second opinion (gate)** on the mutation list — mandatory if decision logic was changed.
8. **`/al-mutate`** — mandatory if decision logic was changed.
9. Mark task `[x]`. Stop. **One task, one session.**

## Escape hatch

If a Gherkin bullet is wrong or a sub-task emerges mid-TDD: stop. Append a Notes line to the task in `tasks.md`. User re-runs `/al-refine <T-NNN>` to fix or split. Do not silently expand.

## When to mutate

Mutate if the changed production lines contain decision logic: branching, comparisons, boolean operators, guards (`Error`/`exit`), or arithmetic. Otherwise skip. Metadata edits, pure delegation, and property-only changes have no signal worth mutating.

## Second opinion gate (pre-`/al-mutate`)

Cross-check the mutation list with copilot CLI. Mandatory if decision logic was changed.

**Invoke:** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt meta-shape:** mutation list + production code it targets + operator priority + *"what mutations are missing or misaligned? Return a bulleted list."*

**Reconcile each bullet:** accept (update mutation list) or reject with a one-line reason as a Notes line. No silent skip. `/grill-me` when judgement needs the user.

**Failure:** record `Second opinion skipped: <reason>` as a Notes line on the task and proceed.

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

## Composition

- `/al-build` to compile and run tests.
- `/al-architect` — required precondition (`**Architecture**` block on the task).
- `/bc-standard-reference` for BC patterns and BaseApp behaviour.
- `/al-debug-logging` only when execution path is unclear and tests can't reveal it.
- `/al-refactor` after green.
- `/al-mutate` after refactor (mandatory if decision logic was changed).
- copilot CLI — second-opinion gate at step 7 (pre-`/al-mutate`).

## Out of scope

- No `/grill-me` re-refinement — Gherkin is fixed at input. Use the escape hatch if wrong.
- No second opinion on Gherkin — that happened in `/al-refine`.
- No re-architecting — Architecture block is fixed at input. If the design is wrong, stop and re-run `/al-architect`.
- No restructuring `tasks.md` beyond status updates, appended sub-tasks, and the `**Mutations**` section.
