---
name: al-scope
description: Decompose `architecture.html` into a slice-grouped, ZOMBIES-ordered task list in `tasks.html` for AL/Business Central, with one user verification task per slice when `event-model.html` is present. Use after `/al-design`, before `/al-refine` on the first task.
---

# /al-scope, architecture.html → task list

Turn `architecture.html` into per-task entries in `tasks.html` so `/al-refine` and `/al-implement` pick up cold. Tasks group by slice; each user-facing slice closes with a verify task the user signs off. Shape of the artifact is yours per feature; the floor exists only so maintaining skills can flip status surgically.

## Preconditions

- Branch matches `^\d{3}-`, otherwise **Stop** and run `/al-event-model` (or `/al-design` for pure-backend features).
- `specs/<branch>/architecture.html` exists, otherwise **Stop** and run `/al-design`.
- For user/API-facing features, `event-model.html` is present alongside; pure-backend features carry `architecture.html` only.
- A legacy `architecture.md` without `architecture.html` is frozen, **Stop** and hand-migrate or reshape via `/al-design`.

## What goes into tasks.html

- **Goal**: lift the one-line outcome from `event-model.html`'s journey (user/API-facing) or from `architecture.html`'s trigger-source (pure-backend). Do not re-derive.
- **Tasks**: one imperative title plus a short description per task, each task a coherent slice of behaviour (typically one scenario family). Compress with BC field, codeunit, and table names.
- **Slice grouping**: every `T-NNN` carries `data-slice="<slug>"`. For user/API-facing features the slug is the `event-model.html` timeline step (`release-sales-order`, `approve-override`); for pure-backend features it names the `architecture.html` slice (`job-queue-cleanup`, `install-upgrade-v2`).
- **Verify tasks**: when `event-model.html` is present, every slice closes with one verify task: `data-kind="verify"`, same `data-slice` as the slice it gates, `Depends on:` every technical `T-NNN` in the slice. Pure-backend features skip verify tasks; no user to verify with.
- **Order**: slices follow `event-model.html` timeline order (or `architecture.html` slice declaration order for pure-backend). ZOMBIES (Zero, One, Many, Boundary, Interfaces, Exception, Simple) applies *inside* each slice; the slice's simplest exercise of its seam lands first.
- **Edges**: `Depends on:` (cannot land without those), `Refactors:` (reshapes shipped code under invariant), `Fixes:` (corrects a defect or wrong contract). Omit kinds that do not apply. **Cross-slice gate**: every slice N+1's first technical task carries `Depends on:` slice N's verify task, so the gate is explicit in the dependency row and the data-status flip from `blocked` to `ready` reads as a normal dep-satisfied flip.
- **Dependency graph**: a Mermaid `graph LR` earns its place when ≥3 tasks AND edges are not a single linear chain. Skip for ≤2 tasks or pure linear `Depends on:`. Slice membership is already grep-able on `data-slice`, the graph need not re-encode it.
- **Scaffolding**: permission-set entries, object IDs, captions, translations bundle into the task that introduces the codeunit, table, or page they cover. Name the bundled scaffolding inline.

If a question is unanswerable from `architecture.html`, the architecture is incomplete. **Stop** and run `/al-steer`.

## TDD-vertical inside the slice, user-vertical across slices

Two altitudes, on purpose.

- **TDD-vertical**: every `T-NNN` ships tests plus production code together; layer-only tasks (data without callers, logic without tests) leave the system half-built and tests-as-afterthought becomes tests-never-written. The kind varies (primitive, extract, wire, fix, pure refactor); verticality at this altitude does not.
- **User-vertical**: a slice is what the user can touch; one slice fans into a *wire* task crossing the slice's trigger plus *primitive / extract / fix* tasks composing into it. A single primitive task is TDD-vertical but invisible to the user, the closing wire task is what the user verifies. Forcing one slice to one task either bloats past a session or hides the seam under the wrapper.

The verify task at the end of each slice is where user-vertical becomes a status flip. It carries no Gherkin and no AL writes; `/al-refine` fills its Tests area with a ZOMBIES-ordered user test plan (numbered user-action steps citing `event-model.html` slots), and `/al-user-verification` walks the user through it.

## ZOMBIES inside the slice, slice order from the timeline

ZOMBIES (Zero, One, Many, Boundary, Interfaces, Exception, Simple) orders the technical tasks *within* one slice; the slice's simplest exercise of its seam gives `/al-implement` the cleanest starting test and keeps each TDD cycle inside one session. Across slices the order follows `event-model.html` timeline order so the user can verify slice A end-to-end before slice B's primitives interleave with it. Cross-slice ZOMBIES (current contract pre-0.27) defeats the per-slice verification gate, slice A is half-done when slice B's `Z` task lands and the gate has nothing to verify.

A primitive used by two slices belongs to the first slice that needs it. Later slices reference the produced behaviour without re-listing.

## Edges declared at scope

Source `Depends on:` / `Refactors:` / `Fixes:` edges from the architecture's slice, module map, and brownfield touchpoints now; the `/al-refine` or `/al-implement` agent cannot guess them from titles alone weeks later. Verify tasks always carry `Depends on:` naming every technical `T-NNN` in the slice; the dependency closure plus the matching `data-slice` is what tells `/al-implement` when to flip the verify task from blocked-pending-deps to `ready`.

## Replan check before writing

If decomposition surfaces a gap `architecture.html` does not cover (missing module, pattern conflict, unnamed brownfield touchpoint, slice not in `event-model.html`), **Stop** and run `/al-steer`; inventing here corrupts every downstream skill and the invention is invisible.

## Surgical-edit contract

`tasks.html` carries one contract: maintaining skills find a task by ID and flip its status.

- `<details data-task="T-NNN">` on each per-task block. `T-NNN` is monotonic, never reused across kinds, starts at `T-001`; the anchor `id` mirrors the form (`id="t-001"`).
- `data-status="ready | in-progress | done | blocked"` on the same `<details>`. Scope writes `ready` for every technical task in the **first** slice and `blocked` for every other task (later-slice technical tasks waiting on the cross-slice gate; every slice's verify task waiting on its in-slice cluster). `/al-implement` flips technical tasks `ready` → `in-progress` → `done`, and flips the slice's verify task `blocked` → `ready` when the last technical sibling lands. `/al-user-verification` flips the verify task `ready` → `in-progress` → `done` (pass) or `blocked` (fail), and on `done` flips the next slice's technical tasks `blocked` → `ready`. `/al-steer` flips anything to `blocked` on a replan trigger. Multiple technical tasks within a slice can be `ready` simultaneously; ZOMBIES order in the file plus in-slice `Depends on:` edges tell `/al-implement` which one to pick first.
- `data-slice="<slug>"` on every `<details data-task>`. Slug is kebab-case, derived from the `event-model.html` timeline step or `architecture.html` slice.
- `data-kind="verify"` on verify tasks. Technical tasks omit the attribute (defaults to `technical`). CSS renders the verify badge differently from the status badge.

Rendering (glyph, colour, badge) is yours; maintaining skills flip the attribute, CSS does the rest. Section order, Summary shape, alert blocks, graph styling: your call per feature.

## Description

Lede first: BC site (object, procedure, field) plus the invariant the task preserves or the contract it ships. Cite ADRs inline as `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>`. Shape per [voice-contract.md](../../references/voice-contract.md): tight `<p>` for one or two facts; one fact per landing line for more. `/al-refine` may rewrite the description after walking the codebase.

Verify-task descriptions name the slice's user-facing outcome in `event-model.html` vocabulary (Role, Action, Business Event, View, Status), not AL mechanics. *"Order Processor releases a Sales Order with a valid item charge allocation; the Sales Order Status flips to Released and the Pending Overrides cue does not increment."* AL names live in the technical tasks the verify task depends on.

Visuals follow [html-spec-discipline.md](../../references/html-spec-discipline.md); pull visual coherence from the most recently modified prior `specs/*/` artifact.

## Gate event

Once when the task decomposition lands in `tasks.html`. The Gate report names the slice families decomposed (one per `event-model.html` step for user-facing, one per `architecture.html` slice for pure-backend), the verify-task count (or *none, pure-backend*), the dependency shape (linear or branching), states the feature Goal in user terms, and names the user's call to greenlight `/al-refine` on the first task of the first slice.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-design` (architecture.html), `/al-event-model` for user/API-facing (event-model.html source for slice slugs and Goal) |
| **Hands off to**   | `/al-refine` (one task at a time, technical or verify) |
| **Replan venue**   | `/al-steer` (gap surfaced during decomposition) |
| **Sidebands**      | `/al-research` (non-trivial BC areas), `/bc-standard-reference` (BaseApp grounding) |
