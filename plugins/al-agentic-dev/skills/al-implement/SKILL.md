---
name: al-implement
description: Pick a Gherkin-ready task from tasks.md and run TDD on it for AL/Business Central. Use after /al-refine, one task per session, red → green → /al-refactor → mutation plan → /al-mutate, with /al-build as the gate after every cycle.
---

# /al-implement, Pick a task, run TDD

Pick the next ready task from `tasks.md`. Run TDD per Gherkin bullet, gate every red → green → refactor with `/al-build`, then mutation-test. Update `tasks.md`. Stop. **One task, one session.**

**Resolve target paths:**
- **Spec folder:** branch must match `^\d{3}-` → `specs/<branch>/tasks.md` and `specs/<branch>/architecture.md`. Otherwise `Stop.`, run `/al-design` first.
- **Task input:** task entry must carry a `**Tests**` block from `/al-refine`. If missing, `Stop.`, run `/al-refine <T-NNN>` first.

Read before writing to `tasks.md`:
- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`, voice rules for the prose itself.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md`, what goes in a Notes line vs an ADR; trigger test; valid shapes.

## Philosophy

**Tests target the Process layer's seam interface** (`Access = Internal` for Pure bullets, public for E2E). Production code outside the seam, Read collaborators, Write collaborators, public façade, can change entirely; the seam is the contract under test. This is the R → P → W layering of `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`. Two test surfaces follow: E2E crosses the external interface; unit tests target P directly with stubbed R/W collaborators. See `tdd-cycle.md`.

**Deep internals rename freely.** A test that breaks on rename of a private procedure inside the Process implementation was testing implementation, not behaviour, the rename-survival invariant is canon. See `test-invariants.md`.

**AL Runner is the empirical classifier.** A bullet tagged Pure that returns ERROR / exit 2 under `/al-build -UnitTestOnly` is not unit-runnable yet, apply the three-step resolution (review test → refactor production → reclassify). See `al-runner.md`.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all production.** Treating RED as "transcribe every Gherkin bullet" and GREEN as "implement the whole task" produces **crap tests**:

- Tests written in bulk verify _imagined_ behaviour, not _actual_ behaviour.
- They test the _shape_ of records and procedure signatures rather than posting outcomes, ledger entries, document flow.
- They go insensitive to real changes, pass when behaviour breaks, fail when behaviour is fine.
- You outrun your headlights, locking in a test surface before you understand the seam.

**Correct approach: vertical slices via tracer bullets.** One Gherkin bullet → one test → just enough production to pass → repeat. Each cycle responds to what the last one taught you.

```
WRONG (horizontal):
  RED:   bullet1, bullet2, bullet3, bullet4
  GREEN: impl1,   impl2,   impl3,   impl4

RIGHT (vertical):
  RED → GREEN → /al-refactor → /al-build:  bullet1 → impl1
  RED → GREEN → /al-refactor → /al-build:  bullet2 → impl2
  RED → GREEN → /al-refactor → /al-build:  bullet3 → impl3
  ...
```

## Flow

Prefer parallel subagents for independent work and output-heavy steps.

1. **Pick task.** Take the next `[ ]` entry from `tasks.md`. If `[!]`: `Stop.` `T-X is [!], run /al-steer to clear the replan.` If no `**Tests**` block inside the task's `<details>`: `Stop.` Run `/al-refine <T-NNN>`. Flip the `<summary>` line status marker from `[ ]` to `[~]` and regenerate the `## Summary` table so its row reflects the new status.
2. **Seam map.** Read `specs/<branch>/architecture.md`: module map, R → P → W boundary, brownfield touchpoints, test strategy. Name the seam in BC vocabulary, the procedure to extract, event to subscribe, interface to implement. One line.
3. **Test layer per Gherkin bullet.** Pure (process layer, no DB) by default. E2E when behaviour is composition or a side effect that can't reproduce at the pure layer. Both only when intent splits cleanly across layers. Default to `architecture.md`'s strategy; deviate explicitly.
4. **Verify before transcribing.** If the seam surfaces an AL/BC fact `architecture.md` doesn't cover (event signature, Validate-trigger side effects, permission keys), run `/al-research` first. Compile loop catches hallucinated names; research catches silent-wrong-behaviour.
5. **Tracer bullet.** Pick the first Gherkin bullet that proves the seam end-to-end. Run cycle (steps 7–10). This bullet is the proof the path works.
6. **Scaffold.** One-time per task. Create compilable stubs for the seam, interface declaration, procedure signatures, empty implementations, new test codeunit shell. Run `/al-build` to confirm green. Subsequent bullets reuse the scaffold. See `tdd-cycle.md`.
7. **RED.** Transcribe one Gherkin bullet → AL test. Must compile and fail on **behaviour**, not on missing types. Run the gate (see *`/al-build`, the test gate*), confirm red.
8. **GREEN.** Smallest production change that turns the test green. No speculative code, no anticipation of the next bullet. Run the gate, confirm green.
9. **`/al-refactor`.** Improve shape while green; seed the checklist from `architecture.md`'s brownfield touchpoints. May add tests when uncovered branches surface. Run the gate, must stay green.
10. **Cycle checklist** (every red → green → refactor):
    - [ ] Test exercises the seam interface, `Access = Internal` for Pure bullets, public (page action, codeunit `Run`, event publisher) for E2E.
    - [ ] Test would survive a rename of any private procedure inside the unit.
    - [ ] Assertions read posting outcomes / ledger entries / document flow, not table shape or call order.
    - [ ] `[SCENARIO]` / `[GIVEN]` / `[WHEN]` / `[THEN]` restate the originating Gherkin bullet faithfully.
11. **Repeat 7–10** for each remaining Gherkin bullet on the task.
12. **Mutation plan.** If decision logic changed (see *When to mutate*), write a `**Mutations plan**` block inside the task's `<details>` after `**Tests**` per the *Canonical `**Mutations plan**` block* in `/al-mutate`: one row per mutation site in `/al-mutate` priority order, with an expected killer named pre-run. Otherwise write the `**Mutations**` chip directly to the task's NOTE alert with value `skipped, no decision logic changed.` and regenerate the Summary row.
13. **Second opinion (gate)** on the mutation list, mandatory when decision logic changed.
14. **Commit WIP.** Mandatory before `/al-mutate`. Its preflight requires `git status` empty so revert is `git checkout --` against a known-good baseline. Stage all task work (tests, production, scaffolding, `**Mutations plan**` block, `[~]` status) and commit. Skip if `/al-mutate` is skipped.
15. **`/al-mutate`.** Mandatory when decision logic changed. Invoke `/al-mutate` with the calling task ID. `/al-mutate` reads the `**Mutations plan**` block, runs the mutations, writes the `**Mutations**` chip to the NOTE alert, regenerates the Summary cell, and deletes the plan block.
16. **Replan check (gate)**: see below.
17. **Close.** Final full `/al-build` green is the precondition (container, regardless of how many bullets ran on `-UnitTestOnly`). Flip the `<summary>` line status marker from `[~]` to `[x]`, regenerate the Summary row, commit. `Stop.`

## `/al-build`, the test gate

**Invocation:** `/al-build` (full gate, container) or `/al-build -UnitTestOnly` (AL Runner only, Pure layer, when `unitTestApp` is configured). **Returns:** compile status + test summary (passed / failed / errors). See `al-runner.md`.

**Layer routing:**

- **Pure-tagged bullets**, `/al-build -UnitTestOnly` after every RED, GREEN, refactor. AL Runner is the inner-loop gate (seconds); container precedes `[x]`.
- **E2E-tagged bullets**: full `/al-build` after every RED, GREEN, refactor. Container is the gate.
- **Both-tagged bullets** (sit in Pure sub-block), two consecutive cycles per bullet. **First**: full Pure cycle (`/al-build -UnitTestOnly` for RED → GREEN → refactor), drives the implementation. **Second**: write an E2E test exercising the same scenario through the public surface; gate with full `/al-build`. The E2E test should pass against the production code the Pure cycle just wrote, failure surfaces integration-level behaviour the Pure layer missed (fix, re-gate). Both cycles complete before moving to the next bullet.
- **Order**: traverse bullets in numeric order. `/al-refine` writes the Pure sub-block before the E2E sub-block (contiguous numbering, ZOMBIES preserved within each), so Pure-first is enforced by construction, no reordering at execution time.
- **Final precondition before `[x]`**: full `/al-build` regardless. AL Runner does not replace the container; it precedes it.

**ERROR / exit 2 resolution** (Pure bullets only, three steps in order, cheapest first):

1. **Review the test.** Was it reaching for an unsupported runner feature unnecessarily (`HttpClient.Send` direct, multi-dataitem query, `Commit()`-dependent assertion)? Adjust to exercise the same behaviour without the unsupported feature.
2. **Refactor production.** Extract a seam via `decoupling.md` (three-phase) so the test can inject a stub. The unsupported call moves behind the seam. Retry RED.
3. **Reclassify the bullet as E2E.** The bullet fundamentally needs a container. Move test to a container test app, append a `T-NNN#K: layer = E2E (override; AL Runner ERROR)` Notes line. Last resort.

A red turn from any non-RED build halts the cycle. Fix forward; do not leave the task with a failing build.

## When to mutate

Mutate if changed production lines contain branching, comparisons, boolean operators, guards (`Error` / `exit`), or arithmetic. Skip metadata edits, pure delegation, and property-only changes, no signal worth mutating.

## Second opinion (gate)

Cross-check the mutation list via `/al-second-opinion`. Mandatory when decision logic changed.

**Invoke:** `/al-second-opinion` with the prompt body below.

**Prompt body shape:** mutation list + production code it targets + operator priority + *"what mutations are missing or misaligned? AND does this surface any of the seven replan triggers? Return a bulleted list."* `/al-second-opinion` prepends the role frame and applies the canonical safety envelope.

Reconcile each returned bullet, accept (update list) or reject. Rejection rationale stays in the session, DO NOT write it to Notes. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`. `/grill-me` when judgement needs the user. If `/al-second-opinion` returns `Second opinion skipped: <reason>`, note it in session and proceed.

## Replan check (gate)

Walk all seven triggers. Hard-halt flips the `<summary>` marker to `[!]`, adds an IMPORTANT alert to the task's `<details>` block, stops, regenerates the Summary row. Do not flip to `[x]`. Soft-flag adds the IMPORTANT alert and continues.

IMPORTANT alert shape: `> [!IMPORTANT]\n> **Replan flag**: trigger #N, <one-line reason>.` DO NOT write replan flags to `**Notes**` lines; the alert is the single source of truth (see `notes-discipline.md`).

| # | Trigger | Mode | Detect |
|---|---|---|---|
| 1 | Task too big | soft | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | hard | Implementation needs a table, codeunit, or permission with no covering task |
| 3 | Wrong order | hard | Task can't land without a later task's seam in place |
| 4 | Sibling now wrong | hard | This task's code invalidates another task's context or scenarios |
| 5 | New behaviour emerges | soft | A code path needs its own test, not a bullet-extension |
| 6 | Architecture decomposition wrong | hard | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | soft | What's landing no longer matches the feature `Goal` |

**Trivia exception** (precedes hard-halt). Missing scaffolding (permission set entry, object ID assignment, caption for a new object, BC-vocabulary rename) is not a replan trigger. Apply inline (≤3 lines), write the `**Absorbed**: <one line>` chip into the task's NOTE alert (joining with ` · ` if other chips exist; adding the alert if absent), re-run `/al-build`, continue. Cap: one absorption per task. Never absorbs schema changes, new event publishers, new codeunits, or test-outcome changes. DO NOT write Absorbed to a `**Notes**` line.

**No silent expansion.** A new Gherkin bullet is not a fix here, that's `/al-refine` after `/al-steer` clears the replan. A reshape of feature architecture isn't either, that's `/al-design` after `/al-steer`. Code stays as it lands; the gate halts planning, not rollback. Run `/al-steer`.

## AL test conventions

- **Test naming:** short PascalCase, BC BaseApp style, `PostSalesOrderWithBlockedCustomer`, `RuleSetCopyPreservesIntervals`. _Avoid_: `GivenX_WhenY_ThenZ`, that pattern doesn't match BaseApp and reads as ceremony.
- **Body comments:** `// [FEATURE]` in `OnRun()`; `// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]` inside each `[Test]`.
- Every `[Test]` calls a local `Initialize()` as its first statement.
- Positive AND negative cases. Boundaries when relevant.
- **`[SCENARIO]` / `[GIVEN]` / `[WHEN]` / `[THEN]` must restate the originating Gherkin bullet faithfully.** If they drift, fix the test or update the bullet, never let them diverge silently.

## AppSource compliance

`/al-design` owns the canonical rules. Two bite at implementation time:

- **New object** → assign ID via `/al-object-id-allocator` or the available object ID allocator at the moment you add the object. Never hand-pick.
- **Renaming a shipped field** → don't. Set `ObsoleteState = Pending` → `Removed` over the deprecation window.

If green code violates either, halt before mutation, reshape, and flag breaking-change risk on the task Notes.

## Naming and vocabulary

- **BC verbs:** Insert / Modify / Delete (records, not Create / Update / Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

- `/al-build`, test gate after every RED, GREEN, `/al-refactor`, and before `[x]`. `-UnitTestOnly` for Pure-layer inner loop.
- `/al-design` precondition (`architecture.md` exists). `/al-refine` precondition (`**Tests**` block on the task).
- `/al-research` for AL/BC facts not covered by `architecture.md`. `/bc-standard-reference` for pure BaseApp questions.
- `/al-refactor` after green. `/al-mutate` after refactor (mandatory when decision logic changed). `/al-debug-logging` only when execution path is unclear and tests can't reveal it.
- `/al-second-opinion`, advisory gate before `/al-mutate` (read-only sandbox; copilot CLI under the hood). `/grill-me` when judgement needs the user. `/al-steer` is the replan venue.

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `tdd-cycle.md`, three-layer trust, three laws, five phases (Scaffold/Red/Green/Refactor/Mutate).
- `test-doubles.md`, Meszaros 5-kind taxonomy (Dummy/Stub/Spy/Mock/Fake) with AL code shapes.
- `test-invariants.md`, no-touch list (`[Test]`, `Subtype = Test`, `[HandlerFunctions(...)]`, etc.) and rename-safety protocol.
- `al-runner.md`, fast pre-check, three outcomes (PASS/FAIL/ERROR), ERROR / exit 2 resolution.

## Out of scope

- No re-refinement (Gherkin fixed) or re-architecting (`architecture.md` fixed); when wrong, the Replan check halts, `/al-steer` clears, then `/al-refine` or `/al-design` reworks.
- No restructuring `tasks.md` beyond: `<summary>` status flips, Summary regeneration on every flip, IMPORTANT alert for replan flags, NOTE chip writes (`**Absorbed**`, `**Mutations**`), and the transient `**Mutations plan**` block under `**Tests**`.
- `tasks.md` Notes entries are now strictly: non-obvious BC constraint specific to this task, or explicit deferred decision. One line, BC vocabulary, independently actionable. See `notes-discipline.md`.

  | | Where it lives |
  |---|---|
  | Absorbed scaffolding | NOTE alert chip: `**Absorbed**: assigned object ID 50101 to NALICF Sales Post Ext via ninja_assignObjectId` |
  | Replan flag | IMPORTANT alert: `**Replan flag**: trigger #2, install codeunit needs permission set entry.` |
  | Mutations result | NOTE alert chip plus Summary cell, written by `/al-mutate` |
  | Layer override (per scenario) | NOTE alert chip: `**Layer**: E2E (override; posting side effect)` |
- No replan mutations; that is `/al-steer`.
