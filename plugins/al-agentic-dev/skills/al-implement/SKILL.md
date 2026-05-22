---
name: al-implement
description: Pick a Gherkin-ready task from tasks.html and run TDD on it for AL/Business Central. Use after /al-refine, one task per session, red → green per Gherkin bullet, then /al-refactor (mandatory full pass) → mutation plan → /al-mutate, with /al-build as the gate after every cycle.
---

# /al-implement, Pick a task, run TDD

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on. No need to comment on what was skipped.

Pick the next ready task from `tasks.html`. Run TDD per Gherkin bullet, gate every red → green with `/al-build`, then run `/al-refactor` once on the full task diff and mutation-test. Update `tasks.html`. Stop. **One task, one session.**

**Resolve target paths:**
- **Spec folder:** branch must match `^\d{3}-` → `specs/<branch>/tasks.html` and `specs/<branch>/architecture.html`. Otherwise `Stop.`, run `/al-design` first.
- **Legacy markdown spec** (`tasks.md` without `tasks.html`): `Stop.` Legacy specs are frozen; hand-migrate before continuing.
- **Task input:** task entry must carry a non-empty `data-section="tests"` slot from `/al-refine`. If empty, `Stop.`, run `/al-refine <T-NNN>` first.

Read before writing to `tasks.html`:
- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`, voice rules for the prose itself.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md`, what goes in a Notes line vs an ADR; trigger test; valid shapes.
- `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md`, data-attribute contract and surgical-edit discipline.
- `${CLAUDE_SKILL_DIR}/../../references/user-communication.md`, chat output shapes (Opener, Phase, Per-bullet, AL Runner ERROR, Second opinion, Replan, Close, Stop) and voice carve-outs from `voice-contract.md`.

## User-facing chat

The user invokes `/al-implement` without `tasks.html` open. The TDD loop is long; the user needs the task identity, each Gherkin bullet's body, named test and production output per RED / GREEN, and final state so they can track progress and re-enter without reading the file. Shapes defined in `user-communication.md`; this table maps them to flow steps.

| Step | Shape |
|---|---|
| Pre-flight (resolve target paths and task input) | **Stop (pre-flight)** on any halt: branch mismatch, legacy markdown spec, blocked task, empty Tests slot. |
| Step 1 (pick task + status flip) | **Opener** (chip line with title + status flip; two-column table with `Pure` / `E2E` counts from the Tests slot and `First` pointer to bullet 1). |
| Step 2 (seam map) | **Phase boundary** with one-line seam in BC vocab. |
| Step 3 (test layer per bullet) | Inline with per-bullet output; no separate shape. |
| Step 4 (verify before transcribing) | **Phase boundary** if `/al-research` fires; no chat from this skill while research runs. |
| Step 5 (tracer bullet) and Step 6 (scaffold) | **Phase boundary** for scaffold; first per-bullet output follows. |
| Steps 7-9 (RED → GREEN per Gherkin bullet, cycle checklist) | **Per-bullet**: bullet header + Given/When/Then echoed + **RED** line (named test proc + codeunit + `/al-build` summary) + **GREEN** line (named production changes + `/al-build` summary). |
| ERROR / exit 2 resolution inside the cycle | **AL Runner ERROR resolution** beat (not a Stop); one labelled line per resolution step taken. |
| Step 10 (repeat 7-9) | One **Per-bullet** block per remaining bullet. |
| Step 11 (`/al-refactor` mandatory full pass) | **Phase boundary** with one-line refactor outcome (renames, extracts, reshape). |
| Step 12 (mutation plan) | **Phase boundary** when plan written, omit when skipped (logic unchanged). |
| Step 13 (second opinion on mutations) | **Second opinion** (aggregate outcome), only when decision logic changed. |
| Step 14 (commit WIP) | One short line naming the commit SHA. |
| Step 15 (`/al-mutate`) | **Phase boundary** with one-line mutation outcome. |
| Step 16 (replan check) | **Replan check** (pass or trigger fired). If hard-halt, **Stop (mid-flow)** with State / Next. |
| Step 17 (close) | **Close**. |

## Philosophy

**Tests target the Process layer's seam interface** (`Access = Internal` for Pure bullets, public for E2E). Production code outside the seam, Read collaborators, Write collaborators, public façade, can change entirely; the seam is the contract under test. This is the R → P → W layering of `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`. Two test surfaces follow: E2E crosses the external interface; unit tests target P directly with stubbed R/W collaborators. See `tdd-cycle.md`.

**Deep internals rename freely.** A test that breaks on rename of a private procedure inside the Process implementation was testing implementation, not behaviour; the rename-survival invariant is canon. See `test-invariants.md`.

**AL Runner is the empirical classifier.** A bullet tagged Pure that returns ERROR / exit 2 under `/al-build -UnitTestOnly` is not unit-runnable yet; apply the three-step resolution (review test → refactor production → reclassify). See `al-runner.md`.

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
  RED → GREEN → /al-build:  bullet1 → impl1
  RED → GREEN → /al-build:  bullet2 → impl2
  RED → GREEN → /al-build:  bullet3 → impl3
  ...
  → /al-refactor (mandatory, full task diff) → /al-mutate
```

Inline renames and obvious dedupe land inside GREEN as you write; substantive refactor (naming drift across bullets, project-vocab slip, reshape opportunities) lands at the per-task `/al-refactor` pass.

## Flow

Prefer parallel subagents for independent work and output-heavy steps.

1. **Pick task.** Take the next task with `data-status="ready"` in `tasks.html`. If `data-status="blocked"`: `Stop.` `T-X is blocked, run /al-steer to clear the replan.` If `data-section="tests"` slot is empty: `Stop.` Run `/al-refine <T-NNN>`. Flip the task's `data-status` from `ready` to `in-progress` (Edit anchored on `<details data-task="T-NNN" data-status="ready">`) and regenerate the Summary table.
2. **Seam map.** Read `specs/<branch>/architecture.html`: module map, R → P → W boundary, brownfield touchpoints, test strategy. Name the seam in BC vocabulary, the procedure to extract, event to subscribe, interface to implement. One line.
3. **Test layer per Gherkin bullet.** Pure (process layer, no DB) by default. E2E when behaviour is composition or a side effect that can't reproduce at the pure layer. Both only when intent splits cleanly across layers. Default to `architecture.html`'s strategy; deviate explicitly.
4. **Verify before transcribing.** If the seam surfaces an AL/BC fact `architecture.html` doesn't cover (event signature, Validate-trigger side effects, permission keys), run `/al-research` first. Compile loop catches hallucinated names; research catches silent-wrong-behaviour.
5. **Tracer bullet.** Pick the first Gherkin bullet that proves the seam end-to-end. Run cycle (steps 7–9). This bullet is the proof the path works.
6. **Scaffold.** One-time per task. Create compilable stubs for the seam, interface declaration, procedure signatures, empty implementations, new test codeunit shell. Run `/al-build` to confirm green. Subsequent bullets reuse the scaffold. See `tdd-cycle.md`.
7. **RED.** Transcribe one Gherkin bullet → AL test. Must compile and fail on **behaviour**, not on missing types. Run the gate (see *`/al-build`, the test gate*), confirm red.
8. **GREEN.** Smallest production change that turns the test green. No speculative code, no anticipation of the next bullet. Rename obvious lies and dedupe inline as you write; substantive refactor lands at the per-task `/al-refactor` pass (step 11). Run the gate, confirm green.
9. **Cycle checklist** (every red → green):
    - [ ] Test exercises the seam interface, `Access = Internal` for Pure bullets, public (page action, codeunit `Run`, event publisher) for E2E.
    - [ ] Test would survive a rename of any private procedure inside the unit.
    - [ ] Assertions read posting outcomes / ledger entries / document flow, not table shape or call order.
    - [ ] `[SCENARIO]` / `[GIVEN]` / `[WHEN]` / `[THEN]` restate the originating Gherkin bullet faithfully.
10. **Repeat 7–9** for each remaining Gherkin bullet on the task.
11. **`/al-refactor` (mandatory full pass).** All bullets green. Invoke `/al-refactor` against the whole task diff; every file touched by this task is in scope. Naming drift across bullets, project-vocabulary slip (per `CONTEXT.md`), duplication that only became visible after the second or third bullet, reshape opportunities: all surface here, not per-bullet. Mandatory before `/al-mutate`. Run the gate, must stay green.
12. **Mutation plan.** If decision logic changed (see *When to mutate*), write a `**Mutations plan**` table inside the task block after the Tests slot per the *Canonical `**Mutations plan**` block* in `/al-mutate`: one row per mutation site in `/al-mutate` priority order, with an expected killer named pre-run. Otherwise write the `**Mutations**` chip directly to the task's NOTE alert with value `skipped, no decision logic changed.` and regenerate the Summary row.
13. **Second opinion (gate)** on the mutation list, mandatory when decision logic changed.
14. **Commit WIP.** Mandatory before `/al-mutate`. Its preflight requires `git status` empty so revert is `git checkout --` against a known-good baseline. Stage all task work (tests, production, scaffolding, `**Mutations plan**` block, `data-status="in-progress"`) and commit. Skip if `/al-mutate` is skipped.
15. **`/al-mutate`.** Mandatory when decision logic changed. Invoke `/al-mutate` with the calling task ID. `/al-mutate` reads the `**Mutations plan**` block, runs the mutations, writes the `**Mutations**` chip to the NOTE alert, regenerates the Summary cell, and deletes the plan block.
16. **Replan check (gate)**: see below.
17. **Close.** Final full `/al-build` green is the precondition (container, regardless of how many bullets ran on `-UnitTestOnly`). Flip the task's `data-status` from `in-progress` to `done` (Edit anchored on the `<details>` opening tag), regenerate the Summary row, commit. `Stop.`

## `/al-build`, the test gate

**Invocation:** `/al-build` (full gate, container) or `/al-build -UnitTestOnly` (AL Runner only, Pure layer, when `unitTestApp` is configured). **Returns:** compile status + test summary (passed / failed / errors). See `al-runner.md`.

**Layer routing:**

- **Pure-tagged bullets**, `/al-build -UnitTestOnly` after every RED, GREEN. AL Runner is the inner-loop gate (seconds); container precedes `done`.
- **E2E-tagged bullets**: full `/al-build` after every RED, GREEN. Container is the gate.
- **Both-tagged bullets** (sit in Pure sub-block), two consecutive cycles per bullet. **First**: full Pure cycle (`/al-build -UnitTestOnly` for RED → GREEN), drives the implementation. **Second**: write an E2E test exercising the same scenario through the public surface; gate with full `/al-build`. The E2E test should pass against the production code the Pure cycle just wrote; failure surfaces integration-level behaviour the Pure layer missed (fix, re-gate). Both cycles complete before moving to the next bullet.
- **Per-task `/al-refactor` pass** (step 11): gated by full `/al-build`, regardless of which layer mix the task used. The pass sees the whole task diff.
- **Order**: traverse bullets in numeric order. `/al-refine` writes the Pure sub-block before the E2E sub-block (contiguous numbering, ZOMBIES preserved within each), so Pure-first is enforced by construction; no reordering at execution time.
- **Final precondition before `done`**: full `/al-build` regardless. AL Runner does not replace the container; it precedes it.

**ERROR / exit 2 resolution** (Pure bullets only, three steps in order, cheapest first):

1. **Review the test.** Was it reaching for an unsupported runner feature unnecessarily (`HttpClient.Send` direct, multi-dataitem query, `Commit()`-dependent assertion)? Adjust to exercise the same behaviour without the unsupported feature.
2. **Refactor production.** Extract a seam via `decoupling.md` (three-phase) so the test can inject a stub. The unsupported call moves behind the seam. Retry RED.
3. **Reclassify the bullet as E2E.** The bullet fundamentally needs a container. Move test to a container test app, append a `T-NNN#K: layer = E2E (override; AL Runner ERROR)` Notes line. Last resort.

A red turn from any non-RED build halts the cycle. Fix forward; do not leave the task with a failing build.

## When to mutate

Mutate if changed production lines contain branching, comparisons, boolean operators, guards (`Error` / `exit`), or arithmetic. Skip metadata edits, pure delegation, and property-only changes; no signal worth mutating.

## Second opinion (gate)

Cross-check the mutation list via `/al-second-opinion`. Mandatory when decision logic changed.

**Invoke:** `/al-second-opinion` with the prompt body below.

**Prompt body shape:** mutation list + production code it targets + operator priority + *"what mutations are missing or misaligned? AND does this surface any of the seven replan triggers? Return a bulleted list."* `/al-second-opinion` prepends the role frame and applies the canonical safety envelope.

Reconcile each returned bullet, accept (update list) or reject. Rejection rationale stays in the session; DO NOT write it to Notes. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`. `/grill-me` when judgement needs the user. If `/al-second-opinion` returns `Second opinion skipped: <reason>`, note it in session and proceed.

## Replan check (gate)

Walk all seven triggers. Hard-halt flips the task's `data-status` to `blocked` (Edit on the `<details>` opening tag), adds an IMPORTANT alert to the task block, stops, regenerates the Summary row. Do not flip to `done`. Soft-flag adds the IMPORTANT alert and continues.

IMPORTANT alert shape: an `<aside data-alert="important">` whose body reads `**Replan flag**: trigger #N, <one-line reason>.` DO NOT write replan flags to Notes lines; the alert is the single source of truth (see `notes-discipline.md`).

Canonical trigger names and modes: see `notes-discipline.md` *Replan triggers*. Per-skill detection cues (implementation perspective):

| # | Trigger | Detect |
|---|---|---|
| 1 | Task too big | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | Implementation needs a table, codeunit, or permission with no covering task |
| 3 | Wrong order | Task can't land without a later task's seam in place |
| 4 | Sibling now wrong | This task's code invalidates another task's context or scenarios |
| 5 | New behaviour emerges | A code path needs its own test, not a bullet-extension |
| 6 | Architecture decomposition wrong | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | What's landing no longer matches the feature Goal |

**Trivia exception** (precedes hard-halt). Missing scaffolding (permission set entry, object ID assignment, caption for a new object, BC-vocabulary rename) is not a replan trigger. Apply inline (≤3 lines), write the `**Absorbed**: <one line>` chip into the task's NOTE alert (joining with ` · ` if other chips exist; adding the alert if absent), re-run `/al-build`, continue. Cap: one absorption per task. Never absorbs schema changes, new event publishers, new codeunits, or test-outcome changes. DO NOT write Absorbed to a Notes line.

**No silent expansion.** A new Gherkin bullet is not a fix here; that's `/al-refine` after `/al-steer` clears the replan. A reshape of feature architecture isn't either; that's `/al-design` after `/al-steer`. Code stays as it lands; the gate halts planning, not rollback. Run `/al-steer`.

## AL test conventions

- **Test naming:** short PascalCase, BC BaseApp style, `PostSalesOrderWithBlockedCustomer`, `RuleSetCopyPreservesIntervals`. _Avoid_: `GivenX_WhenY_ThenZ`; that pattern doesn't match BaseApp and reads as ceremony.
- **Body comments:** `// [FEATURE]` in `OnRun()`; `// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]` inside each `[Test]`.
- Every `[Test]` calls a local `Initialize()` as its first statement.
- Positive AND negative cases. Boundaries when relevant.
- **`[SCENARIO]` / `[GIVEN]` / `[WHEN]` / `[THEN]` must restate the originating Gherkin bullet faithfully.** If they drift, fix the test or update the bullet; never let them diverge silently.

## AppSource compliance

`/al-design` owns the canonical rules. Two bite at implementation time:

- **New object** → assign ID via `/al-object-id-allocator` or the available object ID allocator at the moment you add the object. Never hand-pick.
- **Renaming a shipped field** → don't. Set `ObsoleteState = Pending` → `Removed` over the deprecation window.

If green code violates either, halt before mutation, reshape, and flag breaking-change risk on the task Notes.

## Composition

- `/al-build`, test gate after every RED, GREEN, after the per-task `/al-refactor` pass (step 11), and before `done`. `-UnitTestOnly` for Pure-layer inner loop.
- `/al-design` precondition (`architecture.html` exists). `/al-refine` precondition (non-empty `data-section="tests"` slot on the task).
- `/al-research` for AL/BC facts not covered by `architecture.html`. `/bc-standard-reference` for pure BaseApp questions.
- `/al-refactor` once per task on the full task diff after all bullets green, mandatory before `/al-mutate`. Owns naming, project-vocabulary (per `CONTEXT.md`), reshape, AppSource compliance. `/al-mutate` after refactor (mandatory when decision logic changed). `/al-debug-logging` only when execution path is unclear and tests can't reveal it.
- `/al-second-opinion`, advisory gate before `/al-mutate`. Cross-runtime: from Claude Code it shells out to `codex exec`; from Codex it shells out to `claude -p`. `/grill-me` when judgement needs the user. `/al-steer` is the replan venue.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping the task to `done`. Final correctness check on the implementation, the refactor outcome, and the mutation result, before the durable status change.

</claude-only>

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `tdd-cycle.md`, three-layer trust, three laws, five phases (Scaffold/Red/Green/Refactor/Mutate).
- `test-doubles.md`, Meszaros 5-kind taxonomy (Dummy/Stub/Spy/Mock/Fake) with AL code shapes.
- `test-invariants.md`, no-touch list (`[Test]`, `Subtype = Test`, `[HandlerFunctions(...)]`, etc.) and rename-safety protocol.
- `al-runner.md`, fast pre-check, three outcomes (PASS/FAIL/ERROR), ERROR / exit 2 resolution.
- `html-spec-discipline.md`, data-attribute contract and surgical-edit discipline.

## Out of scope

- No re-refinement (Gherkin fixed) or re-architecting (`architecture.html` fixed); when wrong, the Replan check halts, `/al-steer` clears, then `/al-refine` or `/al-design` reworks.
- No restructuring `tasks.html` beyond: `data-status` flips, Summary regeneration on every flip, IMPORTANT alert for replan flags, NOTE chip writes (`**Absorbed**`, `**Mutations**`), and the transient `**Mutations plan**` block under the Tests slot.
- `tasks.html` Notes entries are now strictly: non-obvious BC constraint specific to this task, or explicit deferred decision. One line, BC vocabulary, independently actionable. See `notes-discipline.md`.

  | | Where it lives |
  |---|---|
  | Absorbed scaffolding | NOTE alert chip: `**Absorbed**: assigned object ID 50101 to NALICF Sales Post Ext via ninja_assignObjectId` |
  | Replan flag | IMPORTANT alert: `**Replan flag**: trigger #2, install codeunit needs permission set entry.` |
  | Mutations result | NOTE alert chip plus Summary cell, written by `/al-mutate` |
  | Layer override (per scenario) | NOTE alert chip: `**Layer**: E2E (override; posting side effect)` |
- No replan mutations; that is `/al-steer`.
