---
name: al-scope
description: Decompose `architecture.md` into a slice-grouped task list in the `tasks/` folder for AL/Business Central, with one verification task per slice when `event-model.md` is present. Use after `/al-design`, before `/al-refine` on the first task.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-scope, architecture.md → task list

Turn `architecture.md` into context-only per-task files in the `tasks/` folder so `/al-refine` can add fresh proof from current app/tests. One file per task plus a `000-feature.md` header; tasks group by slice; each user-facing slice closes with a verify task the user signs off. Shape of each file is yours per feature; the frontmatter floor exists only so maintaining skills can flip status surgically.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**, run `/al-event-model` (or `/al-design` for backend-only).
- `specs/<branch>/architecture.md` exists. Missing → **Stop**, run `/al-design`.
- User/API-facing features: `event-model.md` present alongside; backend-only features carry `architecture.md` only.

## What goes into the tasks/ folder

- **Folder shape**: write `specs/<NNN>-<slug>/tasks/` — a `000-feature.md` header plus one `NNN-T-MMM-<slug>.md` file per task. `NNN` is a gapped-by-10 execution-order prefix (`010`, `020`, `030`) and the sole owner of run order; leave gaps so later inserts need no renumber. `T-MMM` is the monotonic locator id. See [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md) and [examples/tasks/](../../references/examples/tasks/).

- **Goal**: lift the one-line outcome from `event-model.md` journey (user/API-facing) or `architecture.md` trigger-source (backend-only) into `000-feature.md`, alongside per-slice intent prose. `000-feature.md` carries no task rows and no status.

- **Context only, no proof, no prescription**: task files carry stable non-implementation context — goal, surface, slice intent, dependencies, constraints, risks, source context, acceptance intent as prose. `/al-refine` owns and writes fresh every proof artifact (`Test Specification`, `Verification Plan`, `New and Modified Objects`, AAA cases, `Decision Matrix`, `Journey`/`Contract Examples`, `Exploration Charters`); do not pre-write them, do not prescribe new objects/procedures/assertions/payloads. Existing objects, pages, events, APIs, fields may be named as source context.

- **Tasks**: one imperative title + short description per file, each a coherent behaviour slice or refactor step.

- **Slice grouping**: every task carries `slice: <slug>` — `event-model.md` timeline step (`release-sales-order`) for user/API-facing, `architecture.md` slice (`job-queue-cleanup`) for backend-only.

- **Verify tasks**: when `event-model.md` present, every slice closes with one verify task: `kind: verify`, same `slice:`, `depends_on:` every technical `T-NNN` in the slice. Backend-only has no user/API surface, so skips verify tasks.

- **Bracketing ops tasks**: always emit both. `T-001` `kind: provision` `slice: provision` first, opens `ready`; `kind: breaking-change` `slice: breaking-change` last, opens `blocked`. Neither carries a proof artifact — run-and-flip. First-slice technical tasks open `blocked` `depends_on: [T-001]`. `/al-validate-breaking-changes` self-skips when detection is off.

- **Edges**: frontmatter lists — `depends_on:` (cannot land without those), `refactors:` (reshapes shipped code under invariant), `fixes:` (corrects defect or wrong contract). Omit or leave `[]` when not applicable. Cross-slice gate: slice N+1's first technical task carries `depends_on:` slice N's verify task — backend-only has no verify task, so depend on slice N's last technical task instead. These lists are the dependency graph; no mermaid fence. Source them from architecture's slice / module map / brownfield touchpoints now — titles alone cannot reconstruct them later.

- **Scaffolding context**: permission, caption, translation, packaging constraints bundle into the task that needs them. Name the constraint, not a code shape.

## Order: TDD-vertical inside slice, user-vertical across slices

Two altitudes, on purpose.

- **TDD-vertical**: every `T-NNN` ships tests + production code together. Layer-only tasks (data without callers, logic without tests) leave the system half-built and tests-as-afterthought become tests-never-written. Kind varies (primitive, extract, wire, fix, pure refactor); verticality does not.
- **User-vertical**: a slice is what the user can touch — one *wire* task crossing the slice's trigger plus *primitive / extract / fix* tasks composing into it. The closing wire task is what the verify task signs off.

Inside a slice: decision/policy primitives first, BC wiring second, page/API surface last, verify task at the end. Shape primitives so their proof lives at the unit tier instead of presuming a container — see [test-layout.md](../../references/test-layout.md). A primitive used by two slices belongs to the first that needs it; later slices reference it without re-listing. Across slices, follow `event-model.md` timeline order (or `architecture.md` slice declaration order, backend-only) so the user verifies slice A end-to-end before slice B interleaves — interleaving leaves the per-slice gate nothing coherent to verify.

`/al-refine` decides proof shape per task.

## Replan check before writing

Unanswerable from `architecture.md`, or decomposition surfaces a gap it does not cover (missing module, pattern conflict, unnamed brownfield touchpoint, slice absent from `event-model.md`) → **Stop**, run `/al-steer`. Inventing here corrupts every downstream skill invisibly.

## Surgical-edit contract

Each per-task file carries one contract: maintaining skills find a task by its `T-MMM` filename and flip its status.

Every per-task file opens with YAML frontmatter, then an H1 title:

```markdown
---
task: T-007
status: ready
slice: release-sales-order
kind: technical
depends_on: [T-004]
---
# T-007 — Release order, valid item charge
```

- `task: T-NNN`: monotonic, never reused across kinds, starts at `T-001`. Locator; matches the file's `T-MMM`.
- `status: ready | ready-for-implementation | ready-for-verification | blocked | done`: single source of truth for state. `ready` = context exists, ready for `/al-refine`. `ready-for-implementation` / `ready-for-verification` = fresh proof artifact written. `blocked` = dependency/context missing. `done` = downstream evidence exists. **al-scope writes only `ready` and `blocked`**: `ready` for `T-001` provision (no dependency, runs first); `blocked` for everything gated (first-slice technical on `T-001`, later-slice technical, verify tasks, breaking-change). Downstream skills own every other flip.
- `slice: <slug>`: kebab-case, from `event-model.md` timeline step or `architecture.md` slice. `provision` / `breaking-change` are reserved non-feature slugs.
- `kind: technical | verify | provision | breaking-change`: routes downstream (technical → `/al-refine` → `/al-implement`; verify → `/al-refine` → `/al-page-script` → `/al-user-verification`; the two ops kinds bypass `/al-refine`, run-and-flip).

No `[ ]`/`[x]` heading marker: `status:` in frontmatter is the only state and the byte the Edit anchors on. Per-slice intent in `000-feature.md`, section order, alert blocks: your call per feature.

## Description

Lede first: BC site (object, procedure, field) + invariant the task preserves or contract it ships. Cite ADRs inline as `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>`. Shape per [voice-contract.md](../../references/voice-contract.md): tight `<p>` for one or two facts; one fact per landing line for more. `/al-refine` may rewrite description after walking codebase.

Verify-task descriptions name the slice's user-facing outcome in `event-model.md` vocabulary (Role, Action, Business Event, View, Status), not AL mechanics. *"Order Processor releases a Sales Order with a valid item charge allocation; the Sales Order Status flips to Released and the Pending Overrides cue does not increment."* AL names live in the technical tasks the verify task depends on.

## Document verification

After writing the `tasks/` folder, run the document-integrity check yourself, inline (no subagent), before the Gate report — verify the folder against [`doc-integrity.md`](../../references/doc-integrity.md): the `tasks/` profile (per-task-file frontmatter integrity, duplicate id/prefix, dangling edges, order-vs-edges, verify under-coverage, ops-slug pairing).

A **fail** (structural or boundary blocker) blocks the Gate report and `/al-refine` handoff; fix it or route to `/al-steer`. A **warn** does not block; include it in the Gate report. This gate checks document integrity only, not whether the task decomposition is optimal.

## Gate event

Once when task decomposition lands in the `tasks/` folder. Gate report names slice families decomposed (one per `event-model.md` step for user-facing, one per `architecture.md` slice for backend-only), verify-task count (or *none, backend-only*), dependency shape (linear or branching), states feature Goal in user terms, names user's call to greenlight `/al-refine` on first task of first slice.

## Next step

The `tasks/` folder is decomposed and integrity-checked. `Next: /al-refine T-NNN` on the first task of the first slice — the `kind: provision` task if `/al-scope` bracketed one (`Next: /al-provision`). A gap `architecture.md` could not answer halted the write → `Next: /al-steer`.

## Feed

Two moments narrate to the branch feed; everything else — folder-shape mechanics, per-task frontmatter, edge wiring — stays silent. At each, hand `/al-feed` a brief of what happened and why it matters to a wary dev who has not read `architecture.md`; `/al-feed` composes the punchline and layers and appends the card.

- **landing** — decomposition lands in the `tasks/` folder and a clean document-integrity verdict clears the `/al-refine` handoff. Brief: the design is now a concrete to-do list — NN chunks, each user-facing one ending in a check the user signs off, ready to start. Layers carry the slice families, the user-verification-gate count, linear vs branching shape, and the Goal restated in user terms.
- **surprise** — the replan/stop guard fires: a gap `architecture.md` cannot answer halts the write and routes to `/al-steer`. Brief: hit a hole it could not fill honestly, so it stopped and handed it back instead of guessing. Layers name what was missing.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-design` (architecture.md), `/al-event-model` for user/API-facing (event-model.md source for slice slugs and Goal) |
| **Hands off to**   | `/al-refine` (one task at a time, technical or verify) |
| **Replan venue**   | `/al-steer` (gap surfaced during decomposition) |
| **Sidebands**      | `/al-research` (non-trivial BC areas), `bc-standard-reference` (BaseApp grounding) |
