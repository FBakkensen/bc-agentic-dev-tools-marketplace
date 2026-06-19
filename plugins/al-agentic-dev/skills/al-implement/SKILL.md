---
name: al-implement
description: Pick a `ready-for-implementation` technical task from the `tasks/` folder and drive it through TDD for AL/Business Central. Use after `/al-refine`, one task per session, Unit AAA cases first, then Integration AAA cases, then refactor and task-end mutation.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-implement, Pick a task, run TDD

Pick next `ready-for-implementation` technical task from the `tasks/` folder. Consume its fresh `Test Specification`. Drive AAA cases red → green: `Unit` first, `Integration` second. Reconcile final procedure names and scopes in the task file. Refactor full task diff once. Mutate at task end. Flip status to `done` when downstream evidence exists. One task per session.

**Layer.** The red-first driver at the Unit + Integration layers (see [`test-strategy.md`](../../references/test-strategy.md)): the cheapest sensitive layer where bugs get pinned. A production bug a higher layer surfaces is pushed down to this layer so the proof lives where an oracle can see it.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/` holds the `tasks/` folder + `architecture.md`. Missing → `/al-design`.
- Target task `kind: technical`. `kind: verify` → **Stop**; route via `/al-steer` or `/al-code-review` based on verification state. `kind: provision` → `/al-provision`; `kind: breaking-change` → `/al-validate-breaking-changes` (ops tasks, run-and-flip, never reach `ready-for-implementation`).
- Target task `status: ready-for-implementation` with populated `Test Specification`. Plain `ready` → **Stop**, `/al-refine T-NNN`. `ready-for-implementation` with empty or missing `Test Specification` → **Stop**, `/al-steer`; status and proof disagree. `blocked` → `/al-steer`. `done` → downstream evidence exists; do not reopen here.
- Read [`test-specification.md`](../../references/test-specification.md), [`test-strategy.md`](../../references/test-strategy.md), [`tdd.md`](../../references/tdd.md), [`test-layout.md`](../../references/test-layout.md) (which test app a case lands in, plus the authoring contract: attributes, `Initialize()`, doubles location, library discipline), and [`testability.md`](../../references/testability.md).
- Read [`voice-contract.md`](../../references/voice-contract.md) (BC vocabulary + evidence bar + Gate report shape) and [`bc-code-intelligence-dispatch.md`](../../references/bc-code-intelligence-dispatch.md) (write-time construct lookup). Production names and signatures arrive minted in the task's `New and Modified Objects`; construct lookups stay this skill's own. Both reads arrive before code, not at refactor.

## What this session answers

- **Which task in flight?** One `T-NNN`, named in opener. Status stays `ready-for-implementation` during the run; session-local work is not durable status.
- **Where is the seam?** Read `architecture.md` R → P → W boundary, module map, brownfield touchpoints. Name seam in BC vocab: procedure to extract, event to subscribe, interface to implement, or page/action to wire.
- **Which AL surface lands?** Read the task's `New and Modified Objects`; build against its signatures. The section names production surface only — test codeunits and test procedures are this skill's to mint. In-object drift — procedure rename, parameter change, visibility flip, helper procedure, field addition on a named object — absorb, reconcile the section to actuals before `done`, note drift in `Contract notes`; no drift → no edit.
- **Which AAA cases land?** Traverse `Unit` cases first, then `Integration`, in coverage-ID order. One case red → green before the next.
- **Which BC names and constructs verified this session?** Every exact BC-specific name in the AAA case or implementation path, and every BC construct class it touches, meets the evidence bar in [voice-contract.md](../../references/voice-contract.md): names via workspace hit or quoted fetch, constructs via fetched topic or quoted Learn passage.
- **What flips at end?** `status:` goes `ready-for-implementation` → `done` on the task file's frontmatter line; final full `/al-build` green. User/API-facing slice-done opens the slice verify task to `ready` for `/al-refine`. Backend-only slice-done announces `/al-code-review` per-slice. Feature-done announces `/al-code-review` per-feature.

Unanswerable question → task not ready. Resolve via `/al-research`, `/al-refine`, or `/al-steer`.

## Workflow

### One AAA case at a time

RED → GREEN → gate, one case, then next. Bulk-RED locks test surface before seam understood. Tests written ahead verify imagined behaviour. No `in-progress` status; the task remains `ready-for-implementation` until it becomes `done` or `blocked`.

Default order:

1. `Unit` cases red/green via `/al-build -UnitTestOnly` when `unitTestApp` is configured.
2. `Integration` cases red/green via full `/al-build`.
3. Full task refactor.
4. Full gate.
5. Task-end mutation for non-trivial work.

Exception: when a Unit seam should exist but current code is tangled, write an Integration characterization test first to anchor behaviour, then extract the Unit seam and add the Unit case. Reconcile scope changes in the task file.

### Evidence before RED, names and constructs

Before first RED of any AAA case, the evidence bar in [voice-contract.md](../../references/voice-contract.md) is met for every exact BC-specific name in its Arrange / Act / Assert **and** for every BC construct class on the implementation path (the classes the bar's Constructs bullet names). Names → workspace evidence this session or quoted fetch. Constructs → fetched topic per [bc-code-intelligence-dispatch.md](../../references/bc-code-intelligence-dispatch.md) or quoted Learn passage, declared as `Researched:`; legacy code is precedent, not authority — a construct copied from the workspace still earns its fetch, because that is exactly how a repo's `SetLoadFields`-after-filters debt replicates. Sources disagree, or the fact belongs in a design artifact → `/al-research`.

### Test the Process seam, not incidental implementation

Tests target the behaviour boundary named by the task. `Unit` cases target the P layer directly with stubbed R/W collaborators. `Integration` cases cross BC runtime/database/page/event seams. Assertions read business outcomes: status, errors, posting outcomes, ledger entries, document flow, emitted event, visible page state. Avoid asserting table shape or call order unless a Unit spy is the behaviour boundary.

See [testability.md](../../references/testability.md) for three-phase decoupling + seam catalogue and [tdd.md](../../references/tdd.md) for five phases + no-touch invariants.

### Gates every RED and every GREEN

`Scope: Unit` → `/al-build -UnitTestOnly` when supported. `Scope: Integration` → full `/al-build`. Final closeout always uses full `/al-build`. The closeout gate is the whole suite, not this task's cases — a red anywhere, including a sibling task's test, blocks the `done` flip (that is trigger #4, sibling now wrong), never a clean close.

AL Runner ERROR / exit 2 routes cheapest-first: review test (adjust unsupported call) → refactor production behind seam so unsupported call moves behind stub → reclassify as `Integration` and update the task file. Reclassification last because it grows container surface. Before treating an ERROR as a runner-capability gap, re-confirm the compile-error class — an AL0305 missing-dependency cascade reads as an AL0327 runner gap, and reclassifying on the misread grows container surface for a phantom. Run `al-runner --guide` when unsupported feature is unclear.

### Reconcile task spec before done

Before `done`, update the task file so it reflects actual proof:

- AAA header matches actual `Procedure`.
- `Procedure:` matches actual AL test procedure name.
- `Covered By` names actual AL test procedures only.
- `Covers:` references real `B#` / `R#`.
- `Scope:` is final. Any scope change is edited back into the task file.
- `New and Modified Objects` matches the actual diff: objects, fields, signatures, visibility, R → P → W letters.
- Completed task keeps final `Test Specification`.
- Implementation discoveries land in `Contract notes` as new bullets, one fact per landing line — never spliced onto an existing bullet, never a `;`-chained paragraph. How a decision was reached goes to the commit message, not the task file.
- `Researched:` citations from this task land as `Contract notes` bullets (the evidence-bar trace, [voice-contract.md](../../references/voice-contract.md)) — skipped research stays visible to `/al-code-review` and the next session.
- Closeout follows the [test-specification.md](../../references/test-specification.md) shape: pyramid bullets plus the mutation verdict table with labeled `Survivor:` / `Why kept:` lines.

### One `/al-refactor` pass on full task diff

Mandatory before mutation. Inline renames + obvious dedupe land inside GREEN as you write; substantive reshape waits for full-diff pass. Cross-case naming drift, project-vocabulary slip, duplication, AppSource concerns, and seam shape only show after the cases land. Reshape after mutation invalidates mutation evidence.

### `/al-mutate` after refactor

Trigger fires when prod or tests moved this cycle. Prod moved → mutate to prove tests catch new decision logic. Tests moved → mutate to prove new assertions pin prod behaviour. Mutation stays task-end. `/al-implement` supplies scope: task context, changed prod/test files, green refactor diff, and business decision points. `/al-mutate` owns site selection, skipped-site rationale, operator choice, second-opinion challenge, delegated execution, and compact verdict.

Commit WIP before `/al-mutate`. Mutate-build-revert cycle assumes `git status` empty; uncommitted work bleeds into revert and corrupts every classification.

Prefer the lowest sensitive layer: Unit mutants for pure decisions, Integration mutants for BC wiring/runtime faults. Survivor → same host session resumes TDD here. Write killer test, prove RED/GREEN, run `/al-build`, then rerun the survivor site by default. Full mutation rerun only when the new test or fix changes shared decision logic.

### AppSource compliance bites at implementation time

New objects get IDs via available allocator. Shipped fields never rename in place (`ObsoleteState: Pending` → `Removed` over deprecation window). Catching at refactor → minutes; catching post-release → app version.

### Replan halts planning, not code

Eight triggers run as gate after mutation, before `done`. Trigger invalidates plan → flip `status: blocked` on the task file's frontmatter line, route to `/al-steer`. Trigger is new info plan absorbs → note inside task body and continue. Record trigger ID + one-line reason. The check is silent unless a trigger fires; do not narrate clearing the triggers one by one — a walk that ends in "no trigger" is bookkeeping the user did not ask to read. A trigger read off a tool diagnosis (compile-error class, runner gap) is re-confirmed once before the `blocked` flip; one read off a recorded fact (`depends_on:`, Goal text) is acted on as-is.

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

Trivia absorbs inline: missing scaffolding, permission set entry, object ID, caption, or BC-vocab rename — build-gate forcings the spec's assertions never observe. Reusing a seam pattern a sibling task already established (the same interface, the same test-double shape) is applying a decision already made, not trigger #6 — absorb it inline, do not route a settled architecture through `/al-steer` a second time. A non-semantic edit the user asks for in-flow — a comment, a local rename, formatting that moves no decision logic and keeps the gate green — absorbs the same way; minting a task for a two-line comment scrub is the ceremony the pushback targets. A public-surface rename is not trivia: it is an AppSource decision, route it. Apply, note, rerun `/al-build`, continue. A production object the assertions require stays trigger #2; schema changes, new event publishers, new codeunits, a genuinely new seam, or test-outcome changes route through `/al-steer`.

Before flipping task to `done`, call `advisor()`. Final correctness check on implementation, reconciled task spec, refactor outcome, and mutation result before durable status change.

Flip surface: locate the task file by its `T-MMM` filename (e.g. `tasks/070-T-007-derive-audit-reason.md`) and edit anchored on its `status:` frontmatter line. Status flip swaps the `status:` value byte-exact:

```markdown
old_string: status: ready-for-implementation
new_string: status: done
```

Everything else inside the task body follows the task shape. See [notes-discipline.md](../../references/notes-discipline.md), [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md), [voice-contract.md](../../references/voice-contract.md).

### Gate report at done

The `done` flip is a gate event: emit the four-line Gate report (Did / Was / Fits / Next) per [voice-contract.md](../../references/voice-contract.md). Mechanics — procedure names, RED/GREEN beats, mutant IDs, build counts, commit hashes — live in commits and the task file; the user pulls detail by asking. No "What landed" / "Things you should know" dumps; invented closeout shapes are how the highest-traffic gate drifts into ceremony.

At the `done` flip, open any **same-slice** task whose `depends_on:` is now fully `done` and that carries no replan flag, `blocked` → `ready` — the close just satisfied its last edge, so the open is provable from frontmatter and reversible, owned here, not routed to `/al-steer`. Name each opened `T-NNN` in the Gate report's **Next**. A task `blocked` on an unsatisfied edge or a replan flag stays `blocked` — that block needs a decision and is `/al-steer`'s. Opening the **next** slice is not this flip's call: it waits on the per-slice gate chain (`/al-code-review`, then `/al-user-verification` for a user-facing slice), never on a bare `done` flip.

The slice verify task is one such same-slice dependent: at user/API-facing slice-done it opens `blocked` → `ready` once every in-slice technical dependency is `done`, which opens `/al-refine` to write the fresh `Verification Plan`. Do not run `/al-code-review` until the verify task is `ready-for-verification`.

## Feed

Highest-traffic skill, so the red/green grind stays out of the feed — only durable-state and settled-question moments earn a card. At each, hand `/al-feed` a brief (what just happened, why it matters to someone who has not read the diff, the kind) and `/al-feed` composes the punchline + layers and appends the card. Compose by name; never inline the append.

- **verdict** — first AAA case completes red→green this session. The agent wrote a test that failed on purpose, then made code pass it: the test really checks behaviour, not decoration. Captures the behaviour/coverage-ID, Unit-before-Integration, failed-first as regression proof.
- **surprise** — an AL Runner ERROR / exit-2 off the planned path, or a replan trigger fires post-mutation. Hit a wall the planned approach didn't hold; worked around it or stopped for replan. Captures which wall, absorbed vs handed to `/al-steer`. Only on a real trigger — a clean walk fires nothing.
- **verdict** — `/al-mutate` task-end verdict. The agent broke its own code in small ways to check the tests catch each break, and reports whether they did. Captures survivors and why kept (equivalent vs real gap).
- **landing** — the `ready-for-implementation → done` flip after final green and Gate report. Task done, suite green, work proven, downstream unlocked. Captures the Gate report (Did/Was/Fits/Next), next task(s) opened, slice-done handoff.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refine` (filled `Test Specification` in the task file and flipped task to `ready-for-implementation`) |
| **Hands off to**   | next `ready-for-implementation` technical task; `/al-refine` on the slice verify task at user/API-facing slice-done; `/al-code-review` per-slice for backend-only slice-done; `/al-code-review` per-feature at feature-done |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (evidence-bar escalation: source conflict, design-artifact fact), `/al-debug-logging` (execution path unclear), `/grill-me` (judgement needs user), `/bc-standard-reference` (BaseApp questions) |
