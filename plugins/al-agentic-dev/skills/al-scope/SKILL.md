---
name: al-scope
description: Decompose `architecture.html` into a ZOMBIES-ordered task list in `tasks.html` for AL/Business Central. Use after `/al-design`, before `/al-refine` on the first task.
---

# /al-scope, architecture.html → task list

Turn `architecture.html` into per-task entries in `tasks.html` so `/al-refine` and `/al-implement` pick up cold. Shape of the artifact is yours per feature; the floor exists only so maintaining skills can flip status surgically.

## Preconditions

- Branch matches `^\d{3}-`, otherwise **Stop** and run `/al-event-model` (or `/al-design` for pure-backend features).
- `specs/<branch>/architecture.html` exists, otherwise **Stop** and run `/al-design`.
- For user/API-facing features, `event-model.html` is present alongside; pure-backend features carry `architecture.html` only.
- A legacy `architecture.md` without `architecture.html` is frozen, **Stop** and hand-migrate or reshape via `/al-design`.

## What goes into tasks.html

- **Goal**: lift the one-line outcome from `event-model.html`'s journey (user/API-facing) or from `architecture.html`'s trigger-source (pure-backend). Do not re-derive.
- **Tasks**: one imperative title plus a short description per task, each task a coherent slice of behaviour (typically one scenario family). Compress with BC field, codeunit, and table names.
- **Order**: ZOMBIES (Zero, One, Many, Boundary, Interfaces, Exception, Simple). Simplest exercise of the seam first.
- **Edges**: `Depends on:` (cannot land without those), `Refactors:` (reshapes shipped code under invariant), `Fixes:` (corrects a defect or wrong contract). Omit kinds that do not apply.
- **Dependency graph**: a Mermaid `graph LR` earns its place when ≥3 tasks AND edges are not a single linear chain. Skip for ≤2 tasks or pure linear `Depends on:`; the Summary already covers it.
- **Scaffolding**: permission-set entries, object IDs, captions, translations bundle into the task that introduces the codeunit, table, or page they cover. Name the bundled scaffolding inline.

If a question is unanswerable from `architecture.html`, the architecture is incomplete. **Stop** and run `/al-steer`.

## Vertical slicing

Every `T-NNN` ships tests plus production code together; layer-only tasks (data without callers, logic without tests) leave the system half-built and tests-as-afterthought becomes tests-never-written. Slice kind varies (primitive, extract, wire, fix, pure refactor); verticality does not.

## One slice fans into many tasks

A complex slice in `architecture.html` typically fans into a *wire* task crossing the slice's trigger plus *primitive / extract / fix* tasks composing into it; the slice is the architectural unit, the task is the TDD-cycle unit. Forcing one slice to one task either bloats past a session or hides the seam under the wrapper.

## ZOMBIES order, not arrival order

Order is Zero, One, Many, Boundary, Interfaces, Exception, Simple, not the order tasks occurred to you; simplest exercise of the seam first gives `/al-implement` the cleanest starting test and keeps each TDD cycle inside one session.

## Edges declared at scope

Source `Depends on:` / `Refactors:` / `Fixes:` edges from the architecture's slice, module map, and brownfield touchpoints now; the `/al-refine` or `/al-implement` agent cannot guess them from titles alone weeks later.

## Replan check before writing

If decomposition surfaces a gap `architecture.html` does not cover (missing module, pattern conflict, unnamed brownfield touchpoint), **Stop** and run `/al-steer`; inventing here corrupts every downstream skill and the invention is invisible.

## Surgical-edit contract

`tasks.html` carries one contract: maintaining skills find a task by ID and flip its status.

- `<details data-task="T-NNN">` on each per-task block. `T-NNN` is monotonic, never reused, starts at `T-001`; the anchor `id` mirrors the form (`id="t-001"`).
- `data-status="ready | in-progress | done | blocked"` on the same `<details>`. Scope writes only `ready`; `/al-implement` and `/al-steer` flip later.

Rendering (glyph, colour, badge) is yours; maintaining skills flip the attribute, CSS does the rest. Section order, Summary shape, alert blocks, graph styling: your call per feature.

## Description

Lede first: BC site (object, procedure, field) plus the invariant the task preserves or the contract it ships. Cite ADRs inline as `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>`. Shape per [voice-contract.md](../../references/voice-contract.md): tight `<p>` for one or two facts; one fact per landing line for more. `/al-refine` may rewrite the description after walking the codebase.

Visuals follow [html-spec-discipline.md](../../references/html-spec-discipline.md); pull visual coherence from the most recently modified prior `specs/*/` artifact.

## Gate event

Once when the task decomposition lands in `tasks.html`. The Gate report names the slice families decomposed and the dependency shape (linear chain or branching), states the feature Goal in user terms, and names the user's call to greenlight `/al-refine` on the first task.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-design` (architecture.html), `/al-event-model` for user/API-facing (event-model.html source for Goal) |
| **Hands off to**   | `/al-refine` (one task at a time) |
| **Replan venue**   | `/al-steer` (gap surfaced during decomposition) |
| **Sidebands**      | `/al-research` (non-trivial BC areas), `/bc-standard-reference` (BaseApp grounding) |
