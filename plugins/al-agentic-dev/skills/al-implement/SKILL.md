---
name: al-implement
description: Pick a ready task from tasks.md and run TDD on it for AL/Business Central. Requires Gherkin from /al-refine — if missing, run /al-refine first. Reads architecture.md for the feature-level seam map, decides per-scenario test layer, then red → green → /al-refactor → refine mutation plan → /al-mutate. Use to actually deliver behaviour, one task per session.
---

# /al-implement — Pick a task, run TDD

Pick the next ready task from `tasks.md`. Run TDD. Update `tasks.md`.

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-design` first. `architecture.md` must exist in the same folder — if missing, stop: run `/al-design` first.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Pick task** from `tasks.md`. If `[!]`, stop: `T-X is [!] — run /al-steer to clear the replan.` `**Tests**` block must exist — if missing, stop: run `/al-refine <T-NNN>` first.
2. **Implementation context.** Read `specs/<branch>/architecture.md` — module map, R→P→W boundary, brownfield touchpoints, test strategy per scenario family. Trust the inline `(see: <source>)` citations from `/al-design` — they're the verified trail. For *this* task:
   - **Decide test layer per Gherkin bullet** — Pure (Process layer, no DB) by default; E2E when behaviour is composition or side effect that can't be reproduced at the pure layer; Both only when the same intent splits cleanly across layers. Use architecture.md's test strategy as the default; deviate explicitly when needed.
   - **Identify the specific seam** for this task — the procedure to extract, the event to subscribe, the interface to implement. One line, in BC vocabulary.
   - **If the seam decision surfaces an AL/BC fact not covered in architecture.md** (e.g. an event's exact parameter list, a Validate trigger's side-effects, a permission key needed by a procedure), run `/al-research` before transcribing. The Red step's compile loop catches obvious hallucinations, but research at this point catches the silent-wrong-behaviour cases the compiler doesn't.
   - No heavy exploration — `/al-design` and `/al-refine` already did that.
3. **Red** — transcribe Gherkin bullet → AL test. Must compile and fail on **behaviour**, not on missing types or syntax.
4. **Green** — smallest production change that turns the test green. No speculative code.
5. **`/al-refactor`** — improve shape; seed the refactor checklist from architecture.md's brownfield touchpoints; may add tests when uncovered branches surface.
6. **Mutation gate** — if changed production lines contain decision logic (see *When to mutate*): list mutations on the changed lines only, one per unique operator site, in `/al-mutate` priority order. Append to `**Mutations**` section. If no decision logic: append `**Mutations:** skipped — no decision logic changed`.
7. **Second opinion (gate)** on the mutation list — mandatory if decision logic was changed.
8. **`/al-mutate`** — mandatory if decision logic was changed.
9. **Replan check (gate)** — walk triggers #2 (hard), #4 (hard), #5 (soft), #6 (hard). On hard-halt set the task `[!]`, append `**Replan** trigger #N: <one-line reason>`, stop — do not mark `[x]`. On soft-flag append the same Notes line and continue.
10. Mark task `[x]`. Stop. **One task, one session.**

## When to mutate

Mutate if the changed production lines contain decision logic: branching, comparisons, boolean operators, guards (`Error`/`exit`), or arithmetic. Otherwise skip. Metadata edits, pure delegation, and property-only changes have no signal worth mutating.

## AppSource compliance (state inline — applies to writing code)

- No BaseApp modification — every change lands in your own extension.
- New objects use the registered AppSource ID range — assign via `mcp__al-object-id-ninja__ninja_assignObjectId` rather than picking by hand.
- Table-extension fields declare `DataClassification`. Never remove or rename a shipped field — obsolete via `ObsoleteState = Pending` then `Removed`.
- Every new table / page / codeunit needs a permission set entry.
- Every `Caption` ships translatable.
- Schema migrations live in install/upgrade codeunits.
- If green code violates any of the above, halt before mutation and reshape — flag breaking-change risk on the task Notes.

## Second opinion gate (pre-`/al-mutate`)

Cross-check the mutation list with copilot CLI. Mandatory if decision logic was changed.

**Invoke:** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt meta-shape:** mutation list + production code it targets + operator priority + *"what mutations are missing or misaligned? AND does this surface any of the seven replan triggers (#2 hidden pre-req, #4 sibling now wrong, #5 new behavior emerges, #6 architecture decomposition wrong)? Return a bulleted list."*

**Reconcile each bullet:** accept (update mutation list) or reject with a one-line reason as a Notes line. No silent skip. `/grill-me` when judgement needs the user.

**Failure:** record `Second opinion skipped: <reason>` as a Notes line on the task and proceed.

## Replan check (gate)

Triggers in scope: #2 hidden pre-req (hard), #4 sibling now wrong (hard), #5 new behavior emerges (soft), #6 architecture decomposition wrong (hard).

| # | Detect | Action |
|---|---|---|
| 2 | Implementation needs a table, codeunit, or permission with no covering task | Set `[!]`, append `**Replan** trigger #2: <reason>`, stop. Do not mark `[x]`. |
| 4 | This task's code invalidates another task's context line or scenarios | Set `[!]`, append `**Replan** trigger #4: <reason>`, stop. Do not mark `[x]`. |
| 5 | A code path needs its own test — not a bullet-extension on an existing scenario | Soft-flag: append `**Replan** trigger #5: <reason>`, continue. Mark `[x]` when TDD completes. |
| 6 | The R→P→W boundary or module split surfaces as wrong — feature-level architecture needs reshape | Set `[!]`, append `**Replan** trigger #6: <reason>`, stop. Do not mark `[x]`. |

**No silent expansion.** A new Gherkin bullet is not a fix here — that's `/al-refine` after `/al-steer` clears the replan. A reshape of feature architecture isn't either — that's `/al-design` after `/al-steer`. Code state stays as it lands at green/refactor/mutate; the gate halts planning, not rollback. Recommend `/al-steer`.

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
- `/al-design` — required precondition (`architecture.md` must exist in the spec folder).
- `/al-refine` — required precondition (`**Tests**` block on the task).
- `/bc-standard-reference` for BC patterns and BaseApp behaviour.
- `/al-debug-logging` only when execution path is unclear and tests can't reveal it.
- `/al-refactor` after green.
- `/al-mutate` after refactor (mandatory if decision logic was changed).
- copilot CLI — second-opinion gate at step 7 (pre-`/al-mutate`).

## Out of scope

- No `/grill-me` re-refinement — Gherkin is fixed at input. If a bullet is wrong, the Replan check (gate) halts the task; `/al-steer` clears it, then `/al-refine` reworks Gherkin.
- No second opinion on Gherkin — that happened in `/al-refine`.
- No re-architecting — `architecture.md` is fixed at input. If the design is wrong, the Replan check halts the task; `/al-steer` clears it, then `/al-design` reworks the document.
- No restructuring `tasks.md` beyond status updates, the `[!]` halt, `**Replan**` Notes lines, and the `**Mutations**` section.
- No replan mutations — that's `/al-steer`.
