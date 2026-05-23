---
name: al-implement
description: Pick a Gherkin-ready task from tasks.html and run TDD on it for AL/Business Central. Use after /al-refine, one task per session, red → green per Gherkin bullet, then /al-refactor (mandatory full pass) → /al-mutate when decision logic changed, with /al-build as the gate after every cycle.
---

# /al-implement, Pick a task, run TDD

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on.

Pick the next ready task from `tasks.html`, run TDD per Gherkin bullet, refactor the full task diff once, mutate where decisions live, flip status. One task per session.

`/al-refine` filled the Tests slot this skill consumes. `/al-refactor` and `/al-mutate` run inside the loop, owned by their own SKILLs.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-design`.
- Spec folder `specs/<branch>/` holds `tasks.html` and `architecture.html`. If missing, **Stop**. Run `/al-design`.
- Legacy markdown spec (`tasks.md` without `tasks.html`): **Stop**. Legacy specs are frozen; hand-migrate before continuing.
- Target task carries `data-status="ready"` and a populated Tests area inside its block. Tests area empty, **Stop**, run `/al-refine <T-NNN>`. `data-status="blocked"`, **Stop**, run `/al-steer` to clear the replan.

## What this session does

What the user needs from you, expressed as questions you must have answers to:

- **Which task is in flight?** One `T-NNN`, named in the opener, status flipped `ready` → `in-progress` before the first RED.
- **Where is the seam?** Read `architecture.html`'s R → P → W boundary, module map, brownfield touchpoints, family-level test strategy. Name the seam in BC vocabulary (the procedure to extract, the event to subscribe, the interface to implement). One line, before the first bullet.
- **Does any Gherkin bullet rest on an AL/BC fact `architecture.html` does not cover?** If yes, run `/al-research` before transcribing. The compile loop catches hallucinated names; research catches silent-wrong-behaviour.
- **Did decision logic change?** If yes, mutation runs after refactor. If no, record the skipped-mutation outcome inside the task block (shape per your call) and `/al-mutate` does not run.
- **What flips at the end?** `data-status` goes `in-progress` → `done`. Summary row regenerates. Final full `/al-build` (container) is green.

If a question is unanswerable, the task is not ready. Resolve via `/al-research` (BC behaviour), `/al-refine` (Gherkin gap), or `/al-steer` (replan).

## Disciplines

### Vertical slice, one Gherkin bullet at a time

RED → GREEN → gate, one bullet, then the next. **Why**: bulk-RED locks a test surface before the seam is understood. Tests written ahead verify imagined behaviour, go insensitive to real changes, and pass when behaviour breaks. Each cycle responds to what the last one taught you. The first bullet is the tracer; pick whichever proves the seam end-to-end.

### Test the Process seam, not the implementation

Tests target P (the Process layer's seam interface): `Access = Internal` for Pure, public surface for E2E. Read collaborators, Write collaborators, façade internals, private procedures inside P, all change freely. **Why**: a test that breaks on rename of a private procedure was testing implementation. Assertions read posting outcomes, ledger entries, document flow, not table shape or call order. `[SCENARIO]` / `[GIVEN]` / `[WHEN]` / `[THEN]` restate the originating Gherkin bullet faithfully; drift between Gherkin and test body means one is wrong, fix it.

### `/al-build` is the gate after every RED and every GREEN

Pure-tagged bullets gate with `/al-build -UnitTestOnly` (AL Runner, seconds). E2E-tagged bullets gate with full `/al-build` (container). Both-tagged bullets run a Pure cycle first to drive implementation, then an E2E cycle through the public surface to prove wiring; both complete before the next bullet. Final full `/al-build` precedes `done` regardless of which layer mix the task used. **Why**: a failed gate halfway through a bullet is the cheapest place to find drift; deferring it hides what just broke.

### AL Runner ERROR routes through three steps, cheapest first

`/al-build -UnitTestOnly` returns ERROR / exit 2 on a Pure bullet, the bullet is not unit-runnable as written. Reach in order: review the test (is it reaching for an unsupported runner feature unnecessarily, `HttpClient.Send` direct, multi-dataitem query, `Commit()`-dependent assertion, adjust to exercise the same behaviour without it), refactor production behind a seam so the unsupported call moves behind a stub (`decoupling.md`, three-phase), reclassify as E2E (note the layer override and reason inside the task block) and move the test to a container app. **Why**: the AL Runner is the empirical classifier; ERROR is project knowledge that the bullet's design intent does not survive the runner contract. Reclassification is last because it grows container surface; the cheaper steps preserve the Pure layer's seconds-per-cycle gate.

### One `/al-refactor` pass on the full task diff, after all bullets green

Mandatory before mutation. Inline renames and obvious dedupe land inside GREEN as you write; substantive reshape (naming drift across bullets, project-vocabulary slip per `CONTEXT.md`, duplication that only surfaced after the third bullet, AppSource compliance) waits for the full-diff pass. **Why**: cross-bullet shape only becomes visible after the third or fourth bullet; per-bullet refactor misses it and reshape after `/al-mutate` invalidates the mutation run.

### Mutate where decisions live

Changed production lines containing branching, comparisons, boolean operators, guards (`Error` / `exit`), or arithmetic earn a mutation plan. Pure delegation, property-only changes, metadata edits do not. **Why**: mutation tests detect when test assertions have drifted silently from the decision they were meant to lock down; lines without decisions carry no such risk and burn container budget for no signal.

### Second opinion before the mutation list commits

Cross-check the mutation list via `/al-second-opinion` when decision logic changed. **Why**: the list is what `/al-mutate` will spend a container budget on; cross-check is cheap, post-mutate rework is not. Prompt body shape: mutation list plus the production code it targets plus operator priority plus *"what mutations are missing or misaligned? AND does this surface any of the seven replan triggers? Return a bulleted list."* Reconcile each returned bullet, accept (update list) or reject. Rejection rationale stays in session; durable principle, escalate via `/al-steer`. If `/al-second-opinion` returns `Second opinion skipped: <reason>`, note it and proceed.

### Commit WIP before `/al-mutate`

`/al-mutate`'s preflight requires `git status` empty so revert is `git checkout --` against a known-good baseline. Stage all task work (tests, production, scaffolding, any in-flight content inside the task block, `data-status="in-progress"`) and commit before invoking. **Why**: the mutate-build-revert cycle assumes a clean baseline; uncommitted work bleeds into the revert and corrupts every classification.

### AppSource compliance bites at implementation time

`/al-design` owns the principle. Two land here: new objects get IDs via `/al-object-id-allocator` or the available allocator (never hand-pick), and shipped fields never rename in place (`ObsoleteState: Pending` → `Removed` over the deprecation window). **Why**: violations only become real when the codeunit actually ships; catching them at the refactor pass costs minutes, catching them post-release costs the app version.

### Replan halts planning, not code

The seven triggers run as a gate after mutation, before `done`. When a trigger means the plan is invalid as planned, flip `data-status` to `blocked` and route to `/al-steer`; when it means new information the plan absorbs, note it inside the task block and continue. **Why**: code stays as it lands. A new Gherkin bullet is `/al-refine`'s job after `/al-steer` clears; reshaping the feature architecture is `/al-design`'s. The gate halts decisions, never rolls back work.

Trigger detection cues (implementation perspective):

| # | Trigger | Detect |
|---|---|---|
| 1 | Task too big | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | Implementation needs a table, codeunit, or permission with no covering task |
| 3 | Wrong order | Task can't land without a later task's seam in place |
| 4 | Sibling now wrong | This task's code invalidates another task's context or scenarios |
| 5 | New behaviour emerges | A code path needs its own test, not a bullet-extension |
| 6 | Architecture decomposition wrong | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | What's landing no longer matches the feature Goal |

Record the trigger ID and a one-line reason inside the task block when a flag fires; the visible shape (callout, alert, prose line) is your call per task. Cross-reference the trigger by its number (see `notes-discipline.md`) so the next agent and `/al-steer` know which pattern was seen.

### Trivia absorbs inline, real changes do not

Missing scaffolding (permission set entry, object ID assignment, caption for a new object, BC-vocabulary rename) is not a replan trigger. Apply inline, note what was absorbed inside the task block (shape per your call), re-run `/al-build`, continue. **Why**: a missing caption is a typo, not a planning failure; halting for it grinds the loop. Schema changes, new event publishers, new codeunits, and test-outcome changes never absorb; those are real and route through `/al-steer`.

## Floor

`tasks.html` carries one surgical-edit contract this skill touches: **`data-status` flip on the task `<details>`**. `ready` → `in-progress` at session start, `in-progress` → `done` at session end (or → `blocked` when a replan trigger invalidates the plan). Edit anchored on `<details data-task="T-NNN" data-status="...">`.

Everything else this skill writes inside the task block (absorbed-scaffolding notes, mutation verdict, replan flag, layer overrides, transient mutation context for `/al-mutate` to consume) is your call per task; see `notes-discipline.md` for what kinds of info live inside the task block versus elsewhere. Chat shape, phase narration, refactor outcome rendering: all your call per session, guided by `user-communication.md`.

**Names are the citation.** No inline `(see: file.al:120)` annotations. The codebase walk found the symbol; future readers grep.

## AL test conventions

- **Test naming**: short PascalCase, BaseApp style (`PostSalesOrderWithBlockedCustomer`, `RuleSetCopyPreservesIntervals`). _Avoid_: `GivenX_WhenY_ThenZ`.
- **Body comments**: `// [FEATURE]` in `OnRun()`; `// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]` inside each `[Test]`. Every `[Test]` calls a local `Initialize()` as its first statement.
- **Positive and negative cases**, boundaries when relevant.
- **BC vocabulary**: Insert / Modify / Delete (records), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method). Objects: `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.

## Composition

- `/al-design` precondition (`architecture.html`). `/al-refine` precondition (filled Tests slot).
- `/al-research` for BC facts `architecture.html` does not cover. `/bc-standard-reference` for pure BaseApp questions.
- `/al-build` after every RED and GREEN, after the `/al-refactor` pass, and before `done`. `-UnitTestOnly` for Pure inner loop; container precedes `done`.
- `/al-refactor` once per task on the full task diff, mandatory before `/al-mutate`. Owns naming, project vocabulary, reshape, AppSource compliance.
- `/al-mutate` after refactor, when decision logic changed. `/al-second-opinion` is the advisory gate before the mutation list commits.
- `/al-debug-logging` only when execution path is unclear and tests cannot reveal it.
- `/grill-me` when judgement needs the user. `/al-steer` is the replan venue.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping the task to `done`. Final correctness check on the implementation, the refactor outcome, and the mutation result, before the durable status change.

</claude-only>

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `voice-contract.md`, voice rules for the prose itself.
- `notes-discipline.md`, destination map for what lives inside the task block vs commit/ADR/`.out-of-scope/`; the seven replan triggers as named patterns.
- `html-spec-discipline.md`, two-attribute floor (`data-task` + `data-status`) and status-flip surgical-edit discipline.
- `user-communication.md`, chat output shapes and voice carve-outs.
- `tdd-cycle.md`, three-layer trust, three laws, five phases (Scaffold / Red / Green / Refactor / Mutate).
- `test-doubles.md`, Meszaros 5-kind taxonomy (Dummy / Stub / Spy / Mock / Fake) with AL code shapes.
- `test-invariants.md`, no-touch list (`[Test]`, `Subtype = Test`, `[HandlerFunctions(...)]`) and rename-safety protocol.
- `al-runner.md`, fast pre-check, three outcomes (PASS / FAIL / ERROR), ERROR / exit 2 resolution.

## Out of scope

- No re-refinement (Gherkin is fixed) or re-architecting (`architecture.html` is fixed). When wrong, the replan gate halts; `/al-steer` clears; `/al-refine` or `/al-design` reworks.
- No restructuring `tasks.html` beyond the `data-status` floor flip and whatever in-flight content the session writes inside the task block (absorbed-scaffolding notes, replan flag, layer overrides, mutation verdict, transient mutation context). Shape is your call; destination rules are in `notes-discipline.md`.
- Content that survives past `done` belongs in a durable artifact (commit message, ADR, `.out-of-scope/`, `CONTEXT.md`), not inside the task block. See `notes-discipline.md`.
- No replan mutations. That is `/al-steer`.
- No markdown-mode output. Legacy markdown specs are frozen; this skill refuses to run on a folder that lacks `tasks.html`.
