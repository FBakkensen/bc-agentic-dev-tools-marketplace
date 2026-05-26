---
name: al-scope
description: Decompose `architecture.html` into a slice-grouped, ZOMBIES-ordered task list in `tasks.html` for AL/Business Central, with one user verification task per slice when `event-model.html` is present. Use after `/al-design`, before `/al-refine` on the first task.
---

**Voice:** caveman. Drop articles, filler, hedging. Fragments OK. Arrows for causality. Technical terms exact, code unchanged, errors quoted exact.

**Carve-outs:** drop caveman for confirm-before-destroy, user dialog turns (questions / grill rounds), numbered user-action steps, Stop block reason line.

# /al-scope, architecture.html → task list

Turn `architecture.html` into per-task entries in `tasks.html` so `/al-refine` and `/al-implement` pick up cold. Tasks group by slice; each user-facing slice closes with a verify task the user signs off. Shape of artifact is yours per feature; floor exists only so maintaining skills can flip status surgically.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, run `/al-event-model` (or `/al-design` for pure-backend).
- `specs/<branch>/architecture.html` exists. Missing → **Stop**, run `/al-design`.
- User/API-facing features: `event-model.html` present alongside; pure-backend features carry `architecture.html` only.
- Legacy `architecture.md` without `architecture.html` → frozen, **Stop**, hand-migrate or reshape via `/al-design`.

## What goes into tasks.html

- **Goal**: lift the one-line outcome from `event-model.html` journey (user/API-facing) or from `architecture.html` trigger-source (pure-backend). Do not re-derive.
- **Tasks**: one imperative title + short description per task, each task a coherent slice of behaviour (typically one scenario family). Compress with BC field, codeunit, table names.
- **Slice grouping**: every `T-NNN` carries `data-slice="<slug>"`. User/API-facing features: slug = `event-model.html` timeline step (`release-sales-order`, `approve-override`). Pure-backend: slug names `architecture.html` slice (`job-queue-cleanup`, `install-upgrade-v2`).
- **Verify tasks**: when `event-model.html` present, every slice closes with one verify task: `data-kind="verify"`, same `data-slice` as gated slice, `Depends on:` every technical `T-NNN` in slice. Pure-backend skips verify tasks; no user to verify with.
- **Order**: slices follow `event-model.html` timeline order (or `architecture.html` slice declaration order for pure-backend). ZOMBIES (Zero, One, Many, Boundary, Interfaces, Exception, Simple) applies *inside* each slice; slice's simplest exercise of seam lands first.
- **Edges**: `Depends on:` (cannot land without those), `Refactors:` (reshapes shipped code under invariant), `Fixes:` (corrects defect or wrong contract). Omit kinds that do not apply. **Cross-slice gate**: every slice N+1's first technical task carries `Depends on:` slice N's verify task → gate is explicit in dependency row and data-status flip from `blocked` to `ready` reads as normal dep-satisfied flip.
- **Dependency graph**: Mermaid `graph LR` earns place when ≥3 tasks AND edges not a single linear chain. Skip for ≤2 tasks or pure linear `Depends on:`. Slice membership already grep-able on `data-slice`; graph need not re-encode it.
- **Scaffolding**: permission-set entries, object IDs, captions, translations bundle into task that introduces the codeunit, table, or page they cover. Name bundled scaffolding inline.

Unanswerable from `architecture.html` → architecture incomplete. **Stop**, run `/al-steer`.

## TDD-vertical inside slice, user-vertical across slices

Two altitudes, on purpose.

- **TDD-vertical**: every `T-NNN` ships tests + production code together; layer-only tasks (data without callers, logic without tests) leave system half-built and tests-as-afterthought becomes tests-never-written. Kind varies (primitive, extract, wire, fix, pure refactor); verticality at this altitude does not.
- **User-vertical**: a slice is what the user can touch; one slice fans into a *wire* task crossing the slice's trigger plus *primitive / extract / fix* tasks composing into it. Single primitive task is TDD-vertical but invisible to user; closing wire task is what the user verifies. Forcing one slice to one task either bloats past a session or hides the seam under wrapper.

Verify task at end of each slice is where user-vertical becomes a status flip. Carries no Gherkin and no AL writes; `/al-refine` fills its Tests area with a ZOMBIES-ordered user test plan (numbered user-action steps citing `event-model.html` slots), `/al-user-verification` walks the user through it.

## ZOMBIES inside slice, slice order from timeline

ZOMBIES (Zero, One, Many, Boundary, Interfaces, Exception, Simple) orders technical tasks *within* one slice; slice's simplest exercise of seam gives `/al-implement` cleanest starting test and keeps each TDD cycle inside one session. Across slices order follows `event-model.html` timeline order so user can verify slice A end-to-end before slice B's primitives interleave with it. Cross-slice ZOMBIES (pre-0.27 contract) defeats per-slice verification gate; slice A half-done when slice B's `Z` task lands and gate has nothing to verify.

A primitive used by two slices belongs to first slice that needs it. Later slices reference produced behaviour without re-listing.

## Edges declared at scope

Source `Depends on:` / `Refactors:` / `Fixes:` edges from architecture's slice, module map, brownfield touchpoints now; `/al-refine` or `/al-implement` cannot guess them from titles alone weeks later. Verify tasks always carry `Depends on:` naming every technical `T-NNN` in slice; dependency closure plus matching `data-slice` tells `/al-implement` when to flip verify task from blocked-pending-deps to `ready`.

## Replan check before writing

If decomposition surfaces a gap `architecture.html` does not cover (missing module, pattern conflict, unnamed brownfield touchpoint, slice not in `event-model.html`) → **Stop**, run `/al-steer`; inventing here corrupts every downstream skill and invention is invisible.

## Surgical-edit contract

`tasks.html` carries one contract: maintaining skills find a task by ID and flip its status.

- `<details data-task="T-NNN">` on each per-task block. `T-NNN` monotonic, never reused across kinds, starts at `T-001`; anchor `id` mirrors form (`id="t-001"`).
- `data-status="ready | in-progress | done | blocked"` on the same `<details>`. Scope writes `ready` for every technical task in **first** slice and `blocked` for every other task (later-slice technical tasks waiting on cross-slice gate; every slice's verify task waiting on in-slice cluster). `/al-implement` flips technical tasks `ready` → `in-progress` → `done`, flips slice's verify task `blocked` → `ready` when last technical sibling lands. `/al-user-verification` flips verify task `ready` → `in-progress` → `done` (pass) or `blocked` (fail), and on `done` flips next slice's technical tasks `blocked` → `ready`. `/al-steer` flips anything to `blocked` on replan trigger. Multiple technical tasks within a slice can be `ready` simultaneously; ZOMBIES order in file plus in-slice `Depends on:` edges tell `/al-implement` which to pick first.
- `data-slice="<slug>"` on every `<details data-task>`. Slug kebab-case, derived from `event-model.html` timeline step or `architecture.html` slice.
- `data-kind="verify"` on verify tasks. Technical tasks omit attribute (defaults to `technical`). CSS renders verify badge differently from status badge.

Rendering (glyph, colour, badge) is yours; maintaining skills flip attribute, CSS does the rest. Section order, Summary shape, alert blocks, graph styling: your call per feature.

## Description

Lede first: BC site (object, procedure, field) + invariant the task preserves or contract it ships. Cite ADRs inline as `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>`. Shape per [voice-contract.md](../../references/voice-contract.md): tight `<p>` for one or two facts; one fact per landing line for more. `/al-refine` may rewrite description after walking codebase.

Verify-task descriptions name slice's user-facing outcome in `event-model.html` vocabulary (Role, Action, Business Event, View, Status), not AL mechanics. *"Order Processor releases a Sales Order with a valid item charge allocation; the Sales Order Status flips to Released and the Pending Overrides cue does not increment."* AL names live in the technical tasks the verify task depends on.

Visuals follow [html-spec-discipline.md](../../references/html-spec-discipline.md); pull visual coherence from most recently modified prior `specs/*/` artifact.

## Gate event

Once when task decomposition lands in `tasks.html`. Gate report names slice families decomposed (one per `event-model.html` step for user-facing, one per `architecture.html` slice for pure-backend), verify-task count (or *none, pure-backend*), dependency shape (linear or branching), states feature Goal in user terms, names user's call to greenlight `/al-refine` on first task of first slice.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-design` (architecture.html), `/al-event-model` for user/API-facing (event-model.html source for slice slugs and Goal) |
| **Hands off to**   | `/al-refine` (one task at a time, technical or verify) |
| **Replan venue**   | `/al-steer` (gap surfaced during decomposition) |
| **Sidebands**      | `/al-research` (non-trivial BC areas), `/bc-standard-reference` (BaseApp grounding) |
