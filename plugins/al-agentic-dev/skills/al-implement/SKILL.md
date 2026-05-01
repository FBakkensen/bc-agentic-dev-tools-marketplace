---
name: al-implement
description: Pick a Gherkin-ready task from tasks.md and run TDD on it for AL/Business Central. Use after /al-refine, one task per session — red → green → /al-refactor → mutation plan → /al-mutate, with /al-build as the gate after every cycle.
---

# /al-implement — Pick a task, run TDD

Pick the next ready task from `tasks.md`. Run TDD per Gherkin bullet, gate every red→green with `/al-build`, refactor while green, then mutation-test. Update `tasks.md`. Stop. **One task, one session.**

All output is telegraphic — BC vocabulary, structured facts, no prose.

**Resolve target paths:**
- **Spec folder:** branch must match `^\d{3}-` → `specs/<branch>/tasks.md` and `specs/<branch>/architecture.md`. Otherwise `Stop.` and run `/al-design` first.
- **Task input:** task entry must carry a `**Tests**` block from `/al-refine`. If missing, `Stop.` and run `/al-refine <T-NNN>` first.

## Flow

Prefer parallel subagents for independent work and output-heavy steps.

1. **Pick task.** Take the next `[ ]` entry from `tasks.md`. If `[!]`: `Stop.` — `T-X is [!] — run /al-steer to clear the replan.` If no `**Tests**` block: `Stop.` — run `/al-refine <T-NNN>`. Mark `[~]`.
2. **Seam map for this task.** Read `specs/<branch>/architecture.md`: module map, R → P → W boundary, brownfield touchpoints, test strategy. Identify the specific seam in BC vocabulary — the procedure to extract, event to subscribe, interface to implement. One line.
3. **Test layer per Gherkin bullet.** Pure (process layer, no DB) by default. E2E when behaviour is composition or side effect that can't reproduce at the pure layer. Both only when intent splits cleanly across layers. Default to `architecture.md`'s strategy; deviate explicitly.
4. **Verify before transcribing.** If the seam surfaces an AL/BC fact `architecture.md` doesn't cover (event signature, Validate trigger side-effects, permission keys), run `/al-research` first. Compile loop catches hallucinated names; research catches silent-wrong-behaviour.
5. **Red.** Transcribe one Gherkin bullet → AL test. Must compile and fail on **behaviour**, not on missing types. Run `/al-build` — confirm red.
6. **Green.** Smallest production change that turns the test green. No speculative code. Run `/al-build` — confirm green.
7. **`/al-refactor`.** Improve shape while green; seed the checklist from `architecture.md`'s brownfield touchpoints. May add tests when uncovered branches surface. Run `/al-build` — must stay green.
8. **Repeat 5–7** for each remaining Gherkin bullet on the task.
9. **Mutation plan.** If decision logic changed (see *When to mutate*), append a `**Mutations**` block per `/al-mutate` *Canonical mutation block* — one row per mutation site in `/al-mutate` priority order, with an expected killer named pre-run. Otherwise: `**Mutations:** skipped — no decision logic changed`. Telegraphic.
10. **Second opinion (gate)** on the mutation list — mandatory when decision logic changed.
11. **Commit WIP.** Mandatory before `/al-mutate` runs — its preflight requires `git status` empty so revert is `git checkout --` against a known-good baseline. Stage all task work (tests, production, scaffolding, `**Mutations**` block, `[~]`) and commit. Skip if `/al-mutate` is skipped.
12. **`/al-mutate`.** Mandatory when decision logic changed. Dispatch `Agent(subagent_type: 'al-agentic-dev:al-mutate')` with the calling task ID + `**Mutations**` block.
13. **Replan check (gate)** — see below.
14. **Close.** `/al-build` green is the precondition. Mark task `[x]`, commit. `Stop.`

## When to mutate

Mutate if changed production lines contain branching, comparisons, boolean operators, guards (`Error`/`exit`), or arithmetic. Skip metadata edits, pure delegation, and property-only changes — no signal worth mutating.

## Second opinion (gate)

Cross-check the mutation list via the `al-agentic-dev:al-second-opinion` agent. Mandatory when decision logic changed.

**Invoke:** `Agent(subagent_type: 'al-agentic-dev:al-second-opinion', prompt: <body>)`.

**Prompt body shape:** mutation list + production code it targets + operator priority + *"what mutations are missing or misaligned? AND does this surface any of the seven replan triggers? Return a bulleted list."* The agent prepends the role frame and applies the canonical safety envelope.

Reconcile each returned bullet — accept (update list) or reject with a reason. No silent skip. `/grill-me` when judgement needs the user. If the agent returns `Second opinion skipped: <reason>`, note it in session and proceed.

## Replan check (gate)

Walk all seven triggers. Hard-halt sets `[!]`, appends `**Replan** trigger #N: <reason>`, stops. Do not mark `[x]`. Soft-flag appends the same Notes line and continues.

| # | Trigger | Mode | Detect |
|---|---|---|---|
| 1 | Task too big | soft | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | hard | Implementation needs a table, codeunit, or permission with no covering task |
| 3 | Wrong order | hard | Task can't land without a later task's seam in place |
| 4 | Sibling now wrong | hard | This task's code invalidates another task's context or scenarios |
| 5 | New behavior emerges | soft | A code path needs its own test, not a bullet-extension |
| 6 | Architecture decomposition wrong | hard | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | soft | What's landing no longer matches the feature `Goal` |

**Trivia exception** (precedes hard-halt). Missing scaffolding — permission set entry, object ID assignment, caption for a new object, BC-vocabulary rename — is not a replan trigger. Apply inline (≤3 lines), append `**Absorbed**: <one line>` to Notes, re-run `/al-build`, continue. Cap: one absorption per task. Never absorbs schema changes, new event publishers, new codeunits, or test-outcome changes.

**No silent expansion.** A new Gherkin bullet is not a fix here — that's `/al-refine` after `/al-steer` clears the replan. A reshape of feature architecture isn't either — that's `/al-design` after `/al-steer`. Code stays as it lands; the gate halts planning, not rollback. Recommend `/al-steer`.

## Tests (when transcribing Gherkin → AL)

- **Test naming:** short PascalCase, BC BaseApp style (`PostSalesOrderWithBlockedCustomer`). **Not** `GivenX_WhenY_ThenZ`.
- **Body comments:** `// [FEATURE]` in `OnRun()`; `// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]` inside each `[Test]`.
- Every `[Test]` calls a local `Initialize()` as its first statement.
- Positive AND negative cases. Boundaries when relevant.
- **AL `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` must restate the originating Gherkin bullet faithfully.** If they drift, fix the test or update the bullet — never let them diverge silently.

## AppSource compliance (state inline)

- No BaseApp modification — every change lands in your own extension.
- New objects use the registered AppSource ID range — assign via `mcp__al-object-id-ninja__ninja_assignObjectId`.
- Table-extension fields declare `DataClassification`. Never remove or rename a shipped field — obsolete via `Pending` → `Removed`.
- Every new table / page / codeunit needs a permission set entry. Every `Caption` ships translatable. Schema migrations live in install/upgrade codeunits.
- If green code violates any of the above, halt before mutation and reshape — flag breaking-change risk on the task Notes.

## Naming and vocabulary (state inline)

- **BC verbs:** Insert / Modify / Delete (records — not Create/Update/Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

- `/al-build` — build gate after every red→green→refactor cycle and before declaring `[x]`.
- `/al-design` precondition (`architecture.md` exists). `/al-refine` precondition (`**Tests**` block on the task).
- `/al-research` for AL/BC facts not covered by `architecture.md`. `/bc-standard-reference` for pure BaseApp questions.
- `/al-refactor` after green. `/al-mutate` after refactor (mandatory when decision logic changed). `/al-debug-logging` only when execution path is unclear and tests can't reveal it.
- `al-agentic-dev:al-second-opinion` — advisory gate before `/al-mutate` (read-only sandbox; copilot CLI under the hood). `/grill-me` when judgement needs the user. `/al-steer` is the replan venue.

## Out of scope

- No re-refinement (Gherkin fixed) or re-architecting (`architecture.md` fixed) — when wrong, the Replan check halts; `/al-steer` clears, then `/al-refine` or `/al-design` reworks.
- No restructuring `tasks.md` beyond status updates, the `[!]` halt, `**Replan**` Notes lines, and the `**Mutations**` section.
- `tasks.md` Notes entries are telegraphic forward-facing facts — each independently actionable by a future agent, no prose.
- No replan mutations — that's `/al-steer`.
