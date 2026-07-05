---
name: al-implement
description: Pick a `ready-for-implementation` technical task from the `tasks/` folder and drive it red→green through TDD for AL/Business Central. Use after `/al-refine`, one task per session, Unit AAA cases first, then Integration AAA cases. Stops at green and hands off to `/al-refactor` then `/al-mutate`.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-implement, Pick a task, drive it red→green

Pick the next `ready-for-implementation` technical task from the `tasks/` folder. Consume its fresh `Test Specification`. Drive AAA cases red → green: `Unit` first, `Integration` second. Reconcile final procedure names and scopes in the task file. Flip status to `done` when the full suite is green and the spec reconciled. **Stop at green** — reshape (`/al-refactor`) and rigor (`/al-mutate`) are the next steps the user invokes, not work this skill runs. One task per session.

This skill calls only `/al-research` (evidence-bar escalation), `/al-build` (compile/test), and `/al-second-opinion` (cross-family read on non-trivial work). It spawns a subagent per AAA case but invokes no other skill — it hands off by naming the next step, never by chaining.

**Layer.** Red-first at the Unit + Integration layers (see [`test-strategy.md`](../../references/test-strategy.md)). A production bug a higher layer surfaces is pushed down to this layer so the proof lives where an oracle sees it.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, `Next: /al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/` holds the `tasks/` folder + `architecture.md`. Missing → **Stop**, `Next: /al-design`.
- Target task `kind: technical`. `kind: verify` → **Stop**; `Next: /al-steer` or `/al-code-review` based on verification state. `kind: provision` → `Next: /al-provision`; `kind: breaking-change` → `Next: /al-validate-breaking-changes` (ops tasks, run-and-flip, never reach `ready-for-implementation`).
- Target task `status: ready-for-implementation` with populated `Test Specification`. Plain `ready` → **Stop**, `Next: /al-refine T-NNN`. `ready-for-implementation` with empty or missing `Test Specification` → **Stop**, `Next: /al-steer`; status and proof disagree. `blocked` → **Stop**, `Next: /al-steer`. `done` → already green and reconciled; do not reopen here **unless** re-entered for a named follow-up on that same task: an `/al-mutate` reached-real-gap survivor (write the killer test) or an `/al-code-review` finding routed here as `T-NNN`. Work either red-first under the originating task, no status flip, reconciling `Contract notes` on green. Any other reason to touch a `done` task → **Stop**, `Next: /al-steer`.
- Before code, read [`test-specification.md`](../../references/test-specification.md) and [`voice-contract.md`](../../references/voice-contract.md). Production names and signatures arrive minted in the task's `New and Modified Objects`; the per-case subagent reads its own implementation references on each spawn.

## What this session answers

- **Seam.** Read `architecture.md` R → P → W boundary, module map, brownfield touchpoints. Name seam in BC vocab: procedure to extract, event to subscribe, interface to implement, or page/action to wire.
- **AL surface.** Build against the task's `New and Modified Objects` signatures — production surface only; test codeunits and procedures are minted by the per-case subagent. In-object drift (procedure rename, parameter change, visibility flip, helper procedure, field addition on a named object): absorb, reconcile the section to actuals before `done`, note in `Contract notes`.
- **AAA order.** `Unit` cases first, then `Integration`, in coverage-ID order. One case red → green before the next.
- **End.** `status:` `ready-for-implementation` → `done` at full green + reconcile. Then hand off: `/al-refactor` (reshape) and `/al-mutate` (rigor) for non-trivial work; then the slice gate.

Unanswerable → task not ready. Resolve via `/al-research`, `/al-refine`, or `/al-steer`.

## Workflow

### One AAA case at a time

RED → GREEN → gate, one case, then next. Bulk-RED locks test surface before the seam is understood and verifies imagined behaviour. No `in-progress` status; the task stays `ready-for-implementation` until `done` or `blocked`.

Default order:

1. `Unit` cases red/green, one per spawned subagent.
2. `Integration` cases red/green, one per spawned subagent.
3. Full gate.

For each case, **spawn a subagent with the prompt in [`subagents/al-red-green.md`](../../references/subagents/al-red-green.md)** (a capable coding model fits — see that file's tier note), passing: the single AAA case (Arrange/Act/Assert text from the `Test Specification`), the task's `New and Modified Objects` block, and the task file path. Read the subagent's outcome note before proceeding — and before relaying anything from it, run pre-send check 3 ([voice-contract.md](../../references/voice-contract.md) Relaying subagent findings): a note naming no object or observation goes back to the spawn; relay through the Gate/Stop shape, never raw. Then route on the verdict:

- `GREEN` → run the full suite gate (a red anywhere, including a sibling task's test, blocks the `done` flip), then proceed to the next case.
- `PUSH-UP` → handle the push-up commitment gate (see below).
- New decision flagged / `BLOCKED` → `Next: /al-steer`.

Exception: when a Unit seam should exist but current code is tangled, instruct the spawn to write an Integration characterization test first, then spawn again to extract the Unit seam and add the Unit case. Reconcile scope changes in the task file.

### Gate every push-up above the blessed scope

Writing a test above the scope `/al-refine` blessed is a **push-up** that needs commitment, not a silent reclassify (see [`test-strategy.md`](../../references/test-strategy.md)). The push-up signal arrives in the subagent's outcome note: either a planned `Unit` case hit an AL-Runner wall or a *new* `Integration` case emerged mid-TDD (trigger #5). Before the non-`Unit` test is written, **stop** — emit the commitment as a Stop ([`voice-contract.md`](../../references/voice-contract.md)): the case, why `Unit` cannot hold it, and the seam from [`testability.md`](../../references/testability.md) that would push it down versus accepting `Integration`. Commitment is build-the-seam (push down) or accept-the-slower-test; on accept, record the justification in `Contract notes` and spawn the case again as `Integration`.

This is the pipeline's one hard gate, elevated above the act-inline floor because a silent slow test is a durable cost, not reversible. **Unattended**, where no human answers, the stop degrades by context so the push-up never lands silently — an unblessed push-up is replan-class when no one can commit: flip `status: blocked` and `Next: /al-steer`. A push-up already blessed by `/al-refine`'s report flows without a stop; the gate fires only on deviation above plan.

### Reconcile task spec before done

Before `done`, update the task file so it reflects actual proof:

- `Procedure:` and AAA headers match actual AL test procedure names; `Covered By` names them only.
- `Covers:` references real `B#` / `R#`.
- `Scope:` is final; any scope change is edited back in.
- `New and Modified Objects` matches the actual diff: objects, fields, signatures, visibility, R → P → W letters.
- Implementation discoveries land in `Contract notes` as new bullets, one fact per landing line.
- `Researched:` citations and in-object drift from each subagent outcome note land as `Contract notes` bullets (the evidence-bar trace, [voice-contract.md](../../references/voice-contract.md)) — skipped research stays visible to `/al-code-review`.
- Closeout follows the [test-specification.md](../../references/test-specification.md) shape: pyramid bullets. The mutation verdict table lands later, when `/al-mutate` runs.

### AppSource compliance bites at implementation time

New objects get IDs via available allocator. Shipped fields never rename in place (`ObsoleteState: Pending` → `Removed` over a deprecation window).

### Replan halts planning, not code

Eight triggers run as a gate before `done`. The tier test is what the unknown touches: local and reversible (naming, internal structure, test shape) → absorb; it contradicts a settled artifact (`architecture.md`, `event-model.md`, this task's `Test Specification` contract, an ADR) → the map itself is wrong, stop. Trigger invalidates plan → flip `status: blocked` and write the one-line `blocked-on:` headline in the same Edit, `Next: /al-steer`. Trigger is new info the plan absorbs → append a one-line entry to the task's `deviations:` frontmatter (what was assumed, what it touches) and continue; agent-depth goes to the body, but the assumption itself is never buried there — the dashboard renders `deviations:`, so absorbed unknowns stay visible to the developer instead of surfacing only at the gate. Record trigger ID + one-line reason; the check is silent unless a trigger fires. Either path changed frontmatter — rebuild the dashboard before yielding ([dashboard.md](../../references/dashboard.md)); on a block especially, the developer's standing view must show the block, not lag it. A trigger read off a tool diagnosis (compile-error class, runner gap) is re-confirmed once before the `blocked` flip; one read off a recorded fact (`depends_on:`, Goal text) is acted on as-is.

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

A change that only applies a decision already made absorbs inline: missing scaffolding, permission set entry, object ID, caption, local BC-vocab rename, or reusing a seam pattern a sibling task established — apply, log it as a `deviations:` line when it rests on an assumption the user never blessed, rerun `/al-build`, continue. A new decision routes through `/al-steer`: schema changes, new event publishers, new codeunits, a genuinely new seam, test-outcome changes, or a production object the assertions require (trigger #2). A public-surface rename is not trivia — it is an AppSource decision, route it.

Before flipping to `done`, do a final correctness read of the implementation against the reconciled task spec — production logic, AAA coverage, the `New and Modified Objects` surface. For non-trivial work, `/al-second-opinion` is available for an independent cross-family read before the durable status change.

Flip surface: locate the task file by its `T-MMM` filename (e.g. `tasks/070-T-007-derive-audit-reason.md`) and edit anchored on its `status:` frontmatter line, swapping the value byte-exact:

```markdown
old_string: status: ready-for-implementation
new_string: status: done
```

Everything else inside the task body follows the task shape. See [notes-discipline.md](../../references/notes-discipline.md), [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md), [voice-contract.md](../../references/voice-contract.md).

### Done flip opens same-slice dependents

`done` means: the full suite is green and the task spec is reconciled to the diff. (Reshape and mutation are the user's next steps; `/al-code-review` notes a missing mutation verdict if the user skipped `/al-mutate`.) Commit the work before handing off so the tree is clean for the user's `/al-refactor` / `/al-mutate`.

The `done` flip is a state write this skill owns inline (a filesystem handoff, not a cross-skill call). At the flip, open any **same-slice technical** task whose `depends_on:` is now fully `done` and carries no replan flag, `blocked` → `ready`; name each opened `T-NNN` in the gate report. A task `blocked` on an unsatisfied edge or a replan flag stays `blocked` — that needs a decision, `/al-steer`'s. Opening the **next** slice is not this flip's call: it waits on the per-slice gate chain (`/al-code-review` at slice-done, then for a user-facing slice the verify track through `/al-user-verification`).

The slice verify task is the exception — `/al-implement` does **not** open it. At user/API-facing slice-done the review gate runs first: announce `Next: /al-code-review` per-slice. A clean review is what opens the verify task `blocked` → `ready` and routes to `/al-refine` (the verify track sits behind the review gate). So slice-done here only announces `/al-code-review`; do not open the verify task and do not run `/al-refine` on it.

### Gate report at done

The `done` flip is a gate event: emit the four-row Gate report (Did / Was / Fits / Next) rendered box-first per [voice-contract.md](../../references/voice-contract.md), and run its pre-send checks on the draft. Mechanics — procedure names, RED/GREEN beats, build counts, commit hashes — live in commits and the task file; the user pulls detail by asking.

## Next step

End by naming the concrete next move, read off current state:

- **Mid-task non-`done` exits** carry their own `Next:` above (push-up unattended → `/al-steer`, missing spec → `/al-refine`, replan → `/al-steer`).
- **Task `done`, work was non-trivial:** `Next: /al-refactor` (reshape the full task diff while green), then `/al-mutate` (validate test rigor at task end). These are strongly directed — `/al-code-review` notes a missing mutation verdict — but the user owns whether and when to run them.
- **Task `done`, trivial work:** name the slice gate directly. More `ready-for-implementation` tasks in the slice → `Next: /al-implement` (next task). Slice-done (the slice's last technical task) → `Next: /al-code-review` per-slice, both slice types — the review gate runs before the verify task is opened. Feature-done → `Next: /al-code-review` per-feature.

If state can't be read, fall back to the typical next step: `/al-refactor` then `/al-mutate`, then `/al-code-review`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refine` (filled `Test Specification` in the task file and flipped task to `ready-for-implementation`) |
| **Hands off to**   | `/al-refactor` then `/al-mutate` on non-trivial task-done; next `ready-for-implementation` technical task; `/al-code-review` per-slice at slice-done (both slice types); `/al-code-review` per-feature at feature-done |
| **Calls directly** | `/al-research` (evidence-bar escalation), `/al-build` (compile/test), `/al-second-opinion` (cross-family read, non-trivial work) — the only three skills it invokes |
| **Spawns**         | per-case subagent from [`subagents/al-red-green.md`](../../references/subagents/al-red-green.md) (RED→GREEN per AAA case) |
| **Replan venue**   | `/al-steer` |
