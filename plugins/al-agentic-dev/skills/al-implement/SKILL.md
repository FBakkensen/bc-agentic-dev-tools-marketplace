---
name: al-implement
description: Pick a Gherkin-ready task from `tasks.html` and drive it through TDD for AL/Business Central. Use after `/al-refine`, one task per session, red to green per Gherkin bullet, then refactor and mutate with `/al-build` between.
---

# /al-implement, Pick a task, run TDD

Pick the next ready task from `tasks.html`. Run TDD per Gherkin bullet. Refactor the full task diff once. Mutate where decisions live. Flip status. One task per session.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend features).
- `specs/<branch>/` holds `tasks.html` and `architecture.html`. If missing, run `/al-design`.
- User/API-facing features: `event-model.html` is present, and the canonical Role / Business Event / View names from there already live in the Gherkin via `/al-refine`; transcribe verbatim into test names and `[SCENARIO]` / `[GIVEN]` / `[WHEN]` / `[THEN]` comments.
- Legacy markdown spec (`tasks.md` without `tasks.html`): frozen. Hand-migrate first.
- Target task carries `data-status="ready"` and a populated Tests area. Empty Tests, run `/al-refine <T-NNN>`. `blocked`, run `/al-steer`.
- Target task carries `data-kind="verify"`: **Stop** and route to `/al-user-verification`. Verify tasks are not TDD; this skill writes AL.

## What this session answers

- **Which task is in flight?** One `T-NNN`, named in the opener, status flipped `ready` → `in-progress` before the first RED.
- **Where is the seam?** Read `architecture.html`'s R → P → W boundary, module map, brownfield touchpoints. Name the seam in BC vocabulary (the procedure to extract, the event to subscribe, the interface to implement). One line.
- **Did decision logic change?** If yes, mutation runs after refactor. If no, record skipped-mutation outcome inside the task block; `/al-mutate` does not run.
- **What flips at the end?** `data-status` goes `in-progress` → `done`; final full `/al-build` (container) is green. When this is the slice's last technical task (all sibling `T-NNN` with the same `data-slice` are also `done`), also flip the slice's verify task from `blocked` → `ready` and announce `/al-user-verification` as the next handoff.
- **Which BC names did you verify this session?** Every BC-specific name a Gherkin bullet rests on (procedure, event, table, field, codeunit, attribute): backed this session by an `al-symbols-mcp` or `grep` hit, or a `/al-research` citation. Recall does not satisfy. See *Citation chain in chat* below.

Unanswerable question, task is not ready. Resolve via `/al-research`, `/al-refine`, or `/al-steer`.

## Workflow

### One Gherkin bullet at a time

RED → GREEN → gate, one bullet, then the next. Bulk-RED locks a test surface before the seam is understood, and tests written ahead verify imagined behaviour. The first bullet is the tracer; pick whichever proves the seam end-to-end.

### Citation chain in chat, per Gherkin bullet before RED

Before the first RED of any Gherkin bullet, every BC-specific name in the bullet either appears in an `al-symbols-mcp` or `grep` result you ran this session, or is cited via `/al-research`: `Researched: <fact> → <source path / URL / topic id>`. The workspace lookup is the empirical anchor; memory of past sessions or training data is not. Test mechanics, Copilot APIs, and platform behaviour around triggers / subscribers / `Insert(false)` semantics are the highest-failure surfaces; training data ships confidently-wrong claims the compile loop only catches when the name is also wrong. Your confidence about a BC name is not evidence the name exists, signs the right way, or behaves as recalled.

### Test the Process seam, not the implementation

Tests target P (`Access = Internal` for Pure, public surface for E2E). Read and Write collaborators, façade internals, and private procedures inside P change freely. Assertions read posting outcomes, ledger entries, document flow; not table shape or call order. See [testability.md](../../references/testability.md) for three-phase decoupling and seam catalogue, [tdd.md](../../references/tdd.md) for the five phases and no-touch invariants.

### `/al-build` gates every RED and every GREEN

Pure-tagged bullets gate with `/al-build -UnitTestOnly` (AL Runner, seconds). E2E-tagged bullets gate with full `/al-build` (container). Both-tagged bullets run a Pure cycle first to drive implementation, then an E2E cycle through the public surface to prove wiring. Final full `/al-build` precedes `done`.

AL Runner ERROR / exit 2 routes cheapest-first: review the test (adjust to avoid the unsupported call), refactor production behind a seam so the unsupported call moves behind a stub, reclassify as E2E (note the override inside the task block). Reclassification is last because it grows container surface. Run `al-runner --guide` when the unsupported feature is unclear.

### One `/al-refactor` pass on the full task diff, after all bullets green

Mandatory before mutation. Inline renames and obvious dedupe land inside GREEN as you write; substantive reshape (cross-bullet naming drift, project-vocabulary slip, duplication that surfaced after the third bullet, AppSource compliance) waits for the full-diff pass. Cross-bullet shape only becomes visible after the third or fourth bullet; per-bullet refactor misses it, and reshape after `/al-mutate` invalidates the mutation run.

### `/al-mutate` after refactor, when decisions changed

Mutate lines containing branching, comparisons, boolean operators, guards (`Error` / `exit`), or arithmetic. Pure delegation, property-only changes, and metadata edits skip mutation. Cross-check the mutation list via `/al-second-opinion` before it commits; prompt body asks *"what mutations are missing or misaligned? AND does this surface any of the eight replan triggers? Return a bulleted list."* Reconcile each returned bullet. If skipped, note the reason and proceed. See [tdd.md](../../references/tdd.md) for operators and selection heuristics.

Commit WIP before `/al-mutate`. The mutate-build-revert cycle assumes `git status` empty; uncommitted work bleeds into the revert and corrupts every classification.

### AppSource compliance bites at implementation time

New objects get IDs via the available allocator (never hand-pick). Shipped fields never rename in place (`ObsoleteState: Pending` → `Removed` over the deprecation window). Catching at refactor costs minutes; catching post-release costs the app version.

### Replan halts planning, not code

The eight triggers run as a gate after mutation, before `done`. Trigger invalidates the plan: flip `data-status="blocked"`, route to `/al-steer`. Trigger is new information the plan absorbs: note inside the task block and continue. Record the trigger ID and one-line reason. Trigger catalogue:

| # | Trigger | Detect |
|---|---|---|
| 1 | Task too big | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | Implementation needs a table, codeunit, or permission with no covering task |
| 3 | Wrong order | Task can't land without a later task's seam in place |
| 4 | Sibling now wrong | This task's code invalidates another task's context or scenarios |
| 5 | New behaviour emerges | A code path needs its own test, not a bullet-extension |
| 6 | Architecture decomposition wrong | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | What's landing no longer matches the feature Goal |
| 8 | Verification failed | User-facing scenario in `/al-user-verification` does not match observed behaviour; surfaced from the verify task, not from a technical cycle here |

Trivia absorbs inline: missing scaffolding (permission set entry, object ID, caption, BC-vocabulary rename) is not a trigger. Apply, note, re-run `/al-build`, continue. Schema changes, new event publishers, new codeunits, and test-outcome changes never absorb; route through `/al-steer`.

<claude-only>

Before flipping the task to `done`, call `advisor()`. Final correctness check on implementation, refactor outcome, and mutation result before the durable status change.

</claude-only>

Flip surface: edit anchored on `<details data-task="T-NNN" data-status="...">`. Everything else inside the task block (absorbed notes, mutation verdict, replan flag, layer overrides) is shape-per-task. See [notes-discipline.md](../../references/notes-discipline.md), [html-spec-discipline.md](../../references/html-spec-discipline.md), [voice-contract.md](../../references/voice-contract.md).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refine` (filled Tests slot in `tasks.html`) |
| **Hands off to**   | `/al-user-verification` when the slice's verify task flips ready; otherwise the next ready technical task. `/al-code-review` fires at slice-done (after user verification) and feature-done. |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/al-debug-logging` (execution path unclear), `/grill-me` (judgement needs the user), `/bc-standard-reference` (pure BaseApp questions) |
