---
name: al-scope
description: Decompose `architecture.md` into a slice-grouped task list in `tasks.md` for AL/Business Central, with one verification task per slice when `event-model.md` is present. Use after `/al-design`, before `/al-refine` on the first task.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-scope, architecture.md → task list

Turn `architecture.md` into context-only per-task entries in `tasks.md` so `/al-refine` can add fresh proof from current app/tests. Tasks group by slice; each user-facing slice closes with a verify task the user signs off. Shape of artifact is yours per feature; floor exists only so maintaining skills can flip status surgically.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, run `/al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/architecture.md` exists. Missing → **Stop**, run `/al-design`.
- User/API-facing features: `event-model.md` present alongside; backend-only features carry `architecture.md` only.

## What goes into tasks.md

- **Goal**: lift the one-line outcome from `event-model.md` journey (user/API-facing) or from `architecture.md` trigger-source (backend-only). Do not re-derive.
- **Context only**: task blocks carry stable non-implementation context: goal, user/API surface, slice intent, dependencies, constraints, risks, source context, acceptance intent. Acceptance intent is context prose, not a `Test Specification` subsection.
- **No proof artifacts**: do not write `Test Specification`, `Verification Plan`, `New and Modified Objects`, AAA cases, `Expected Behaviors`, `Decision Matrix`, `Journey Examples`, `Contract Examples`, or `Exploration Charters`. `/al-refine` owns every proof artifact and writes it fresh.
- **No implementation prescriptions**: do not prescribe new object, procedure, test codeunit, assertion, page-script, or API payload examples. Existing objects, pages, events, APIs, and fields may be named as source context only.
- **Tasks**: one imperative title + short description per task, each task a coherent behaviour slice or refactor step. Compress with existing BC field, codeunit, table names when they are source context.
- **Slice grouping**: every `T-NNN` carries `slice=<slug>` on its comment-anchor line. User/API-facing features: slug = `event-model.md` timeline step (`release-sales-order`, `approve-override`). Backend-only: slug names `architecture.md` slice (`job-queue-cleanup`, `install-upgrade-v2`).
- **Verify tasks**: when `event-model.md` present, every slice closes with one verify task: `kind=verify` on the comment-anchor line, same `slice=` as gated slice, `Depends on:` every technical `T-NNN` in slice. Backend-only skips verify tasks; no user/API surface to verify.
- **Bracketing ops tasks**: always emit, both modes (user-facing and backend-only). `T-001 kind=provision slice=provision` first (refresh the build environment); a `kind=breaking-change slice=breaking-change` task last (validate against the released baseline). Neither carries a proof artifact, neither runs `/al-refine` — they run a script and flip status (`/al-provision`, `/al-validate-breaking-changes`). Provision opens `ready`; the first slice's technical tasks open `blocked` with the slice's first technical task carrying `Depends on: T-001`, and `/al-provision` opens them on its `done`. Breaking-change opens `blocked`, `Depends on:` the final terminal task (last `verify`, or last technical for backend-only) → transitively gates on every feature task, and the skill that lands that terminal task `done` opens it. Every `blocked` → `ready` flip has a named owner — no stranded task. Emit the breaking-change task unconditionally; `/al-validate-breaking-changes` self-skips when detection is off, so `/al-scope` never reads `al-build.json`.
- **Order**: slices follow `event-model.md` timeline order (or `architecture.md` slice declaration order for backend-only). Inside a slice, task order follows dependency and seam readiness: decision/policy primitives before BC wiring, wiring before verify task. `/al-refine` decides proof shape per task.
- **Edges**: `Depends on:` (cannot land without those), `Refactors:` (reshapes shipped code under invariant), `Fixes:` (corrects defect or wrong contract). Omit kinds that do not apply. **Cross-slice gate**: every slice N+1's first technical task carries `Depends on:` slice N's verify task → gate is explicit in dependency row and the `status=` flip from `blocked` to `ready` reads as normal dep-satisfied flip. `Depends on:` lines are the dependency graph; no mermaid fence.
- **Scaffolding context**: permission, caption, translation, and packaging constraints bundle into the task that needs them. Name the constraint, not a code shape.

Unanswerable from `architecture.md` → architecture incomplete. **Stop**, run `/al-steer`.

## TDD-vertical inside slice, user-vertical across slices

Two altitudes, on purpose.

- **TDD-vertical**: every `T-NNN` ships tests + production code together; layer-only tasks (data without callers, logic without tests) leave system half-built and tests-as-afterthought becomes tests-never-written. Kind varies (primitive, extract, wire, fix, pure refactor); verticality at this altitude does not.
- **User-vertical**: a slice is what the user can touch; one slice fans into a *wire* task crossing the slice's trigger plus *primitive / extract / fix* tasks composing into it. Single primitive task is TDD-vertical but invisible to user; closing wire task is what the user verifies. Forcing one slice to one task either bloats past a session or hides the seam under wrapper.

Verify task at end of each slice is where user-vertical becomes a status flip. Carries no AL writes; `/al-refine` fills its `Verification Plan` from current app/tests and `event-model.md` slots; `/al-page-script` generates the slice's bc-replay recording from E2E Journey Examples; `/al-user-verification` pre-flights the recording batch, runs Contract Examples, and guides the user through Journey Examples / Exploration Charters.

## Task order inside slice

Task order inside one slice optimizes for fast proof and stable seams: decision/policy primitives first, BC wiring second, page/API surface last, verify task at the end. The unit/integration boundary is mechanical, not aspirational — see [test-layout.md](../../references/test-layout.md); shape primitives so their proof can live at the unit tier instead of presuming a container. Across slices, order follows `event-model.md` timeline order so the user can verify slice A end-to-end before slice B's primitives interleave with it. Cross-slice interleaving defeats the per-slice verification gate; slice A is half-done when slice B work lands and the gate has nothing coherent to verify.

A primitive used by two slices belongs to first slice that needs it. Later slices reference produced behaviour without re-listing.

## Edges declared at scope

Source `Depends on:` / `Refactors:` / `Fixes:` edges from architecture's slice, module map, brownfield touchpoints now; `/al-refine` or `/al-implement` cannot guess them from titles alone weeks later. Verify tasks always carry `Depends on:` naming every technical `T-NNN` in slice. Dependency closure plus matching `slice=` tells the pipeline when context exists to flip the verify task from `blocked` to `ready` for `/al-refine`. `/al-code-review` validates `ready-for-verification`; it does not open verify tasks. Backend-only slices have no verify task; the cross-slice gate identifies the next slice by its first technical task carrying `Depends on:` this slice's last technical task, then opens that next slice's technical task set.

## Replan check before writing

If decomposition surfaces a gap `architecture.md` does not cover (missing module, pattern conflict, unnamed brownfield touchpoint, slice not in `event-model.md`) → **Stop**, run `/al-steer`; inventing here corrupts every downstream skill and invention is invisible.

## Surgical-edit contract

`tasks.md` carries one contract: maintaining skills find a task by ID and flip its status.

Each task block opens with an H3 heading + one HTML-comment line immediately under it:

```markdown
### T-007 [ ] — Release order, valid item charge
<!-- task=T-007 status=ready slice=release-sales-order kind=technical -->
```

- `task=T-NNN`: monotonic, never reused across kinds, starts at `T-001`. Locator.
- `status=ready | ready-for-implementation | ready-for-verification | blocked | done`: single source of truth for state. `ready` means context exists for `/al-refine` only. `ready-for-implementation` means a technical task has a fresh `Test Specification` and can run `/al-implement`. `ready-for-verification` means a verify task has a fresh `Verification Plan` and can run `/al-page-script` or `/al-user-verification`. `blocked` means dependency/context missing. `done` means downstream evidence exists.
- Scope writes `blocked` for first-slice technical tasks (gated on `T-001`), later-slice technical tasks, and verify tasks whose dependencies/context are missing. The `kind=provision` task (`T-001`) opens `ready` — no dependency, runs first; the first slice's technical tasks carry `Depends on: T-001`, and `/al-provision` flips them `blocked` → `ready` on its `done` (mirrors the cross-slice gate — every `blocked` → `ready` flip has a named owner). The `kind=breaking-change` task opens `blocked`; the skill landing the feature's final terminal task `done` opens it `blocked` → `ready` (`/al-user-verification` on the last verify task, or `/al-code-review` on the last backend slice's clean review). Both ops tasks then flip straight to `done` (or `blocked` on failure) when their owning skill runs the script; they never pass through `ready-for-implementation`/`ready-for-verification`. `/al-refine` flips technical tasks `ready` → `ready-for-implementation` and verify tasks `ready` → `ready-for-verification`. `/al-implement` requires `ready-for-implementation`, never writes `in-progress`, flips technical tasks to `done` on proof, and opens the dependent verify task to `ready` for `/al-refine` at user/API-facing slice technical completion when every in-slice technical dependency is `done`. `/al-code-review` preserves `ready-for-verification` and stamps `review=clean` on the comment line on clean review (sole writer of that transient key), or flips the verify task to `blocked` on findings; any later flip off `ready-for-verification` or new technical task opened in the slice strips the key in the same edit. `/al-page-script` requires `ready-for-verification` and leaves status unchanged. `/al-user-verification` requires `ready-for-verification`, flips verify task to `done` on evidence or `blocked` on functional failure, and on `done` flips next slice's technical tasks `blocked` → `ready`. `/al-steer` flips to `blocked` on replan trigger and may open tasks back to `ready` only after explicit user ack when dependency/context is restored. Skills that materialize a new task write it `ready` because context exists and proof is empty. Multiple technical tasks within a slice can be `ready` or `ready-for-implementation` simultaneously; file order plus in-slice `Depends on:` edges tell the next skill which to pick first.
- `slice=<slug>`: every task carries it. Slug kebab-case, derived from `event-model.md` timeline step or `architecture.md` slice.
- `kind=technical | verify | provision | breaking-change`: every task carries it. Routes downstream (technical → `/al-refine` → `/al-implement`; verify → `/al-refine` → `/al-page-script` to generate the slice's `.yml`, then `/al-user-verification` to host the guided walk; provision → `/al-provision`; breaking-change → `/al-validate-breaking-changes`). The two ops kinds bypass `/al-refine` — no proof artifact, run-and-flip. `slice=provision` / `slice=breaking-change` are reserved slugs, not feature slices.

Heading marker (`[ ]` for `ready`; `[>]` for `ready-for-implementation` and `ready-for-verification`; `[x]` for `done`; `[!]` for `blocked`) is a visible courtesy fallback; the comment line is the byte the Edit anchors on. Writing skill keeps marker in sync on flip. Slice headings (`## Slice: <slug>`), section order, alert blocks, graph styling: your call per feature.

## Description

Lede first: BC site (object, procedure, field) + invariant the task preserves or contract it ships. Cite ADRs inline as `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>`. Shape per [voice-contract.md](../../references/voice-contract.md): tight `<p>` for one or two facts; one fact per landing line for more. `/al-refine` may rewrite description after walking codebase.

Verify-task descriptions name slice's user-facing outcome in `event-model.md` vocabulary (Role, Action, Business Event, View, Status), not AL mechanics. *"Order Processor releases a Sales Order with a valid item charge allocation; the Sales Order Status flips to Released and the Pending Overrides cue does not increment."* AL names live in the technical tasks the verify task depends on.

Shape follows [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). Write telegraphic; drop articles, padding, hedges; fragments fine.

## Document verification

After writing `tasks.md`, run `/al-doc-verify` before the Gate report:

```text
/al-doc-verify --producer al-scope --artifacts specs/<NNN>-<slug>/tasks.md --handoff al-refine
```

`verdict=fail` blocks the Gate report and `/al-refine` handoff; fix the structural/boundary issue or route to `/al-steer`. `verdict=warn` does not block; include the warning in the Gate report. This gate checks document integrity only, not whether the task decomposition is optimal.

## Gate event

Once when task decomposition lands in `tasks.md`. Gate report names slice families decomposed (one per `event-model.md` step for user-facing, one per `architecture.md` slice for backend-only), verify-task count (or *none, backend-only*), dependency shape (linear or branching), states feature Goal in user terms, names user's call to greenlight `/al-refine` on first task of first slice.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-design` (architecture.md), `/al-event-model` for user/API-facing (event-model.md source for slice slugs and Goal) |
| **Hands off to**   | `/al-refine` (one task at a time, technical or verify) |
| **Replan venue**   | `/al-steer` (gap surfaced during decomposition) |
| **Sidebands**      | `/al-research` (non-trivial BC areas), `/bc-standard-reference` (BaseApp grounding) |
