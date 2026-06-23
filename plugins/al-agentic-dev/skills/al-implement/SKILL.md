---
name: al-implement
description: Pick a `ready-for-implementation` technical task from the `tasks/` folder and drive it through TDD for AL/Business Central. Use after `/al-refine`, one task per session, Unit AAA cases first, then Integration AAA cases, then refactor and task-end mutation.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-implement, Pick a task, run TDD

Pick next `ready-for-implementation` technical task from the `tasks/` folder. Consume its fresh `Test Specification`. Drive AAA cases red → green: `Unit` first, `Integration` second. Reconcile final procedure names and scopes in the task file. Refactor full task diff once. Mutate at task end. Flip status to `done` when downstream evidence exists. One task per session.

Two entry modes: the normal **task-pick** above, and **fix-mode**, driven by `/al-code-review`'s autonomous loop with a single finding rather than a task pick (see Fix-mode). The body below describes task-pick; fix-mode reuses the same discipline with the deltas that section names.

**Layer.** Red-first at the Unit + Integration layers (see [`test-strategy.md`](../../references/test-strategy.md)). A production bug a higher layer surfaces is pushed down to this layer so the proof lives where an oracle sees it.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/` holds the `tasks/` folder + `architecture.md`. Missing → `/al-design`.
- Target task `kind: technical`. `kind: verify` → **Stop**; route via `/al-steer` or `/al-code-review` based on verification state. `kind: provision` → `/al-provision`; `kind: breaking-change` → `/al-validate-breaking-changes` (ops tasks, run-and-flip, never reach `ready-for-implementation`).
- Target task `status: ready-for-implementation` with populated `Test Specification`. Plain `ready` → **Stop**, `/al-refine T-NNN`. `ready-for-implementation` with empty or missing `Test Specification` → **Stop**, `/al-steer`; status and proof disagree. `blocked` → `/al-steer`. `done` → downstream evidence exists; do not reopen here — **except in fix-mode**, where `/al-code-review` reopens the finding's originating `done` task on purpose.
- Before code (not at refactor), read [`test-specification.md`](../../references/test-specification.md) and [`voice-contract.md`](../../references/voice-contract.md). Production names and signatures arrive minted in the task's `New and Modified Objects`; the `al-red-green` agent reads implementation references (`tdd.md`, `test-layout.md`, `testability.md`, `thrift-rules.md`, `bc-code-intelligence-dispatch.md`) on each spawn.

## What this session answers

- **Seam.** Read `architecture.md` R → P → W boundary, module map, brownfield touchpoints. Name seam in BC vocab: procedure to extract, event to subscribe, interface to implement, or page/action to wire.
- **AL surface.** Build against the task's `New and Modified Objects` signatures — production surface only; test codeunits and procedures are minted by the `al-red-green` agent per case. In-object drift (procedure rename, parameter change, visibility flip, helper procedure, field addition on a named object): absorb, reconcile the section to actuals before `done`, note in `Contract notes`.
- **AAA order.** `Unit` cases first, then `Integration`, in coverage-ID order. One case red → green before the next.
- **End.** `status:` `ready-for-implementation` → `done`; final full `/al-build` green. User/API-facing slice-done opens the slice verify task to `ready` for `/al-refine`. Backend-only slice-done announces `/al-code-review` per-slice. Feature-done announces `/al-code-review` per-feature.

Unanswerable → task not ready. Resolve via `al-research` agent, `/al-refine`, or `/al-steer`.

## Workflow

### One AAA case at a time

RED → GREEN → gate, one case, then next. Bulk-RED locks test surface before the seam is understood and verifies imagined behaviour. No `in-progress` status; the task stays `ready-for-implementation` until `done` or `blocked`.

Default order:

1. `Unit` cases red/green, one per spawn of `al-agentic-dev:al-red-green`.
2. `Integration` cases red/green, one per spawn.
3. Full task refactor.
4. Full gate.
5. Task-end mutation for non-trivial work.

For each case, spawn `al-agentic-dev:al-red-green` with: the single AAA case (Arrange/Act/Assert text from the `Test Specification`), the task's `New and Modified Objects` block, and the task file path. Read the outcome note before proceeding:

- Green → run the full suite gate (a red anywhere, including a sibling task's test, blocks the `done` flip), then proceed to the next case.
- Push-up signal → handle the push-up commitment gate (see Gate every push-up section below).
- New decision flagged → route to `/al-steer`.

Exception: when a Unit seam should exist but current code is tangled, instruct the `al-red-green` spawn to write an Integration characterization test first, then spawn again to extract the Unit seam and add the Unit case. Reconcile scope changes in the task file.

### Gate every push-up above the blessed scope

Writing a test above the scope `/al-refine` blessed is a **push-up** that needs commitment, not a silent reclassify (see [`test-strategy.md`](../../references/test-strategy.md)). The push-up signal arrives in the `al-red-green` outcome note: either a planned `Unit` case hit an AL-Runner wall (the agent stopped and signaled) or a *new* `Integration` case emerged mid-TDD (trigger #5). Before the non-`Unit` test is written, **stop** — emit the commitment as a Stop ([`voice-contract.md`](../../references/voice-contract.md)): the case, why `Unit` cannot hold it, and the seam from [`testability.md`](../../references/testability.md) that would versus accepting `Integration`. Commitment is build-the-seam (push down via `/al-refactor`) or accept-the-slower-test; on accept, record the justification in `Contract notes` and spawn `al-red-green` with the accepted `Integration` case.

This is the pipeline's one hard gate, elevated above the act-inline floor (`/al-steer`'s provable-mutation rule) because a silent slow test is a durable cost, not reversible. **Unattended**, where no human answers, the stop degrades by context so the push-up never lands silently — an unblessed push-up is replan-class when no one can commit. **Autopilot** (autonomous task-pick): flip `status: blocked` and route to `/al-steer`. **Fix-mode**: do *not* route to `/al-steer` — fix-mode is mute (see Fix-mode), so report the uncommittable push-up back to the calling loop as `cannot fix — escalate`; it lands in `/al-code-review`'s **needs-a-decision** set-aside class, and the loop routes it at run end. A push-up already blessed by `/al-refine`'s report flows without a stop; the gate fires only on deviation above plan.

### Reconcile task spec before done

Before `done`, update the task file so it reflects actual proof:

- `Procedure:` and AAA headers match actual AL test procedure names; `Covered By` names them only.
- `Covers:` references real `B#` / `R#`.
- `Scope:` is final; any scope change is edited back in.
- `New and Modified Objects` matches the actual diff: objects, fields, signatures, visibility, R → P → W letters.
- Implementation discoveries land in `Contract notes` as new bullets, one fact per landing line.
- `Researched:` citations and in-object drift from each `al-red-green` outcome note land as `Contract notes` bullets (the evidence-bar trace, [voice-contract.md](../../references/voice-contract.md)) — skipped research stays visible to `/al-code-review`.
- Closeout follows the [test-specification.md](../../references/test-specification.md) shape: pyramid bullets plus the mutation verdict table with labeled `Survivor:` / `Why kept:` lines.

### One `/al-refactor` pass on full task diff

Mandatory before mutation. Inline renames + obvious dedupe land inside GREEN; substantive reshape (cross-case naming drift, duplication, AppSource concerns, seam shape) waits for the full-diff pass, since it only shows after the cases land. Reshape after mutation invalidates mutation evidence.

### `/al-mutate` after refactor

Trigger fires when prod or tests moved this cycle — prod moved to prove tests catch new decision logic, tests moved to prove new assertions pin prod behaviour. Task-end. `/al-implement` supplies scope (task context, changed prod/test files, green refactor diff, business decision points); `/al-mutate` owns site selection, operator choice, second-opinion challenge, execution, verdict.

Commit WIP before `/al-mutate`. The mutate-build-revert cycle assumes `git status` empty; uncommitted work bleeds into revert and corrupts every classification.

Prefer the lowest sensitive layer: Unit mutants for pure decisions, Integration mutants for BC wiring/runtime faults. Survivor → resume TDD here: write killer test, prove RED/GREEN, run `/al-build`, rerun the survivor site. Full mutation rerun only when the new test or fix changes shared decision logic.

### AppSource compliance bites at implementation time

New objects get IDs via available allocator. Shipped fields never rename in place (`ObsoleteState: Pending` → `Removed` over a deprecation window).

### Replan halts planning, not code

Eight triggers run as gate after mutation, before `done`. Trigger invalidates plan → flip `status: blocked`, route to `/al-steer`. Trigger is new info the plan absorbs → note in task body and continue. Record trigger ID + one-line reason; the check is silent unless a trigger fires. A trigger read off a tool diagnosis (compile-error class, runner gap) is re-confirmed once before the `blocked` flip; one read off a recorded fact (`depends_on:`, Goal text) is acted on as-is.

| # | Trigger | Detect |
|---|---|---|
| 1 | Task too big | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | Implementation needs table, codeunit, or permission with no covering task, or a production object absent from the task's `New and Modified Objects` |
| 3 | Wrong order | Task can't land without later task's seam in place |
| 4 | Sibling now wrong | This task's code invalidates another task's context, `Test Specification`, or `Verification Plan` |
| 5 | New behaviour emerges | Code path needs its own test, not an appended assertion |
| 6 | Architecture decomposition wrong | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | What's landing no longer matches feature Goal |
| 8 | Verification failed | User-facing verify example does not match observed behaviour; surfaced from verify task |

A mutation that only applies a decision already made absorbs inline: missing scaffolding, permission set entry, object ID, caption, local BC-vocab rename, or reusing a seam pattern a sibling task established — apply, note, rerun `/al-build`, continue. A new decision routes through `/al-steer`: schema changes, new event publishers, new codeunits, a genuinely new seam, test-outcome changes, or a production object the assertions require (trigger #2). A public-surface rename is not trivia — it is an AppSource decision, route it.

Before flipping task to `done`, call `advisor()` — final correctness check on implementation, reconciled task spec, refactor outcome, and mutation result before durable status change.

Flip surface: locate the task file by its `T-MMM` filename (e.g. `tasks/070-T-007-derive-audit-reason.md`) and edit anchored on its `status:` frontmatter line, swapping the value byte-exact:

```markdown
old_string: status: ready-for-implementation
new_string: status: done
```

Everything else inside the task body follows the task shape. See [notes-discipline.md](../../references/notes-discipline.md), [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md), [voice-contract.md](../../references/voice-contract.md).

### Gate report at done

The `done` flip is a gate event: emit the four-line Gate report (Did / Was / Fits / Next) per [voice-contract.md](../../references/voice-contract.md). Mechanics — procedure names, RED/GREEN beats, mutant IDs, build counts, commit hashes — live in commits and the task file; the user pulls detail by asking.

At the `done` flip, open any **same-slice** task whose `depends_on:` is now fully `done` and carries no replan flag, `blocked` → `ready`; name each opened `T-NNN` in the Gate report's **Next**. A task `blocked` on an unsatisfied edge or a replan flag stays `blocked` — that needs a decision, `/al-steer`'s. Opening the **next** slice is not this flip's call: it waits on the per-slice gate chain (`/al-code-review`, then `/al-user-verification` for a user-facing slice), never on a bare `done` flip.

The slice verify task is one such same-slice dependent: at user/API-facing slice-done it opens `blocked` → `ready` once every in-slice technical dependency is `done`, which opens `/al-refine` to write the fresh `Verification Plan`. Do not run `/al-code-review` until the verify task is `ready-for-verification`.

## Fix-mode (driven by /al-code-review)

`/al-code-review`'s loop hands a single judged, must-fix finding (Finding / Where / Source / Recommended next) plus its **originating task** — the task whose code the finding flags, traced by the `T-NNN` commit prefix. Fix-mode is the same discipline aimed at one finding instead of a task's `Test Specification`:

- **Reopen the originating task** (`done` → `ready-for-implementation` in working memory; the durable flip is the reconcile + re-close at the end). The task's existing `Test Specification`, `New and Modified Objects`, and `Contract notes` are the context.
- **Land the fix red-first.** A coverage-gap finding adds the missing AAA case to the existing spec; a finding on existing covered behaviour adjusts the case that should have caught it. Spawn `al-agentic-dev:al-red-green` with the case and the originating task file path — same as task-pick. The agent handles evidence bar, RED/GREEN, and push-up detection.
- **Refactor inline only — no full-diff pass.** Inline renames and obvious dedupe land inside GREEN as usual, but a single-finding fix does not earn the mandatory full-task-diff `/al-refactor` (the four-lens pass exists to catch cross-case naming drift and duplication that surface only after a *task's worth* of cases land — a one-finding fix has neither). Skipping it keeps fix-mode cheap inside a loop that may run it many times.
- **Mutate** the changed sites at fix end, same trigger and cycle. `/al-mutate` sources its task context, changed files, and business decision points from the reopened originating task and the fix diff — the finding is the decision point under test. Mutation stays mandatory; it is the proof the fix's test actually catches the bug.
- **Reconcile** the originating task before re-closing: `New and Modified Objects` and `Researched:` bullets must match the post-fix diff, so `/al-code-review`'s lens 1 reads truth on the next round. Commit under the originating `T-NNN` prefix.

Fix-mode is **mute**: it returns to the calling loop and does **not** announce a slice-gate handoff, trigger `/al-code-review`, or open same-slice / next-slice dependents — the loop owns re-review, and re-opening the gate here would recurse. A replan trigger that fires mid-fix (the finding turns out to need a new decision, or the fix won't go green) is **not** routed to `/al-steer` from here; fix-mode reports "cannot fix — escalate" back to the loop, which owns the escalation. Hygiene (non-semantic) findings never reach fix-mode — `/al-code-review` applies those directly without a test.

## Feed

Highest-traffic skill, so the red/green grind stays out of the feed — only durable-state and settled-question moments earn a card. Hand `/al-feed` a brief by name (never inline the append); it composes punchline + layers and appends.

- **verdict** — first AAA case completes red→green this session. Captures the behaviour/coverage-ID, Unit-before-Integration, failed-first as regression proof.
- **surprise** — an AL Runner ERROR / exit-2 off the planned path, a push-up gate stopping for commitment (or degrading to `blocked` unattended), or a replan trigger fires post-mutation. Captures which wall, absorbed vs handed to `/al-steer`. Only on a real trigger — a clean walk fires nothing.
- **verdict** — `/al-mutate` task-end verdict. Captures survivors and why kept (equivalent vs real gap).
- **landing** — the `ready-for-implementation → done` flip after final green and Gate report. Captures the Gate report (Did/Was/Fits/Next), next task(s) opened, slice-done handoff.

## Composition

| | |
|---|---|
| **Runs after**     | task-pick: `/al-refine` (filled `Test Specification` in the task file and flipped task to `ready-for-implementation`). fix-mode: `/al-code-review`'s loop, with one must-fix finding + its originating task |
| **Hands off to**   | task-pick: next `ready-for-implementation` technical task; `/al-refine` on the slice verify task at user/API-facing slice-done; `/al-code-review` per-slice for backend-only slice-done; `/al-code-review` per-feature at feature-done. fix-mode: returns to the calling loop, mute (no gate announcement, no dependents opened) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `al-red-green` agent (RED→GREEN per case; spawns `al-research` for evidence-bar escalation), `/al-debug-logging` (execution path unclear), `/grill-me` (judgement needs user), `bc-standard-reference` agent (BaseApp questions) |
