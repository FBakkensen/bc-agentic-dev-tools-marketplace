---
name: al-design
description: Settle the AL/Business Central feature architecture from idea or `event-model.md`. Use after `/al-event-model` for user/API-facing features, after `/al-grill-adr` for backend-only features, or when the user asks to design an AL feature.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-design, Idea → feature architecture

Turn sharpened idea into feature-level architecture, then write `architecture.md` so `/al-scope` picks it up cold. Shape per feature is yours; disciplines below are the substance.

`/al-scope` reads this file next and decomposes it into tasks.

## Artifact boundary

Writes only `architecture.md`.

May define production architecture, AL object responsibilities, module boundaries, seams, events, R → P → W flow, testability constraints, and seam expectations.

Never write `tasks.md`. Never write task-level AAA cases, `Test Specification`, `Verification Plan`, Journey Examples, Contract Examples, Exploration Charters, verification journeys, or task proof. `/al-scope` owns `tasks.md`; `/al-refine` owns task-level proof shape.

## Preconditions

- `/al-grill-adr` ran for this idea; without sharpened intent in `CONTEXT.md` / domain ADRs you cannot tell domain confusion from genuine architectural choice. **Stop**, run it first.
- User/API-facing: `/al-event-model` ran, `event-model.md` in spec folder; without it this skill re-litigates user-side picks inline and entanglement returns. Missing → run missing-storm checkpoint: ask whether feature is backend-only (no human, no API consumer) or whether `/al-event-model` was forgotten. **Stop** unless user confirms backend-only.
- Branch creation shared with `/al-event-model`. On `^\d{3}-`: branch + spec folder exist, write into them. On `main` (backend-only, or first per-feature skill): this skill creates them.
- Existing `architecture.md` → reshaping; re-run with user's awareness.

## What goes into architecture.md

- **Slices**: when `event-model.md` present, its user-facing slots (Role, Action, Business Event, View, Status) are settled; read, do not re-decide, qualify each slice by AL pattern (Command / Automation / Translation / View) based on trigger source. Backend-only slices name trigger-source slot only (Job Queue, install / upgrade, scheduled task); see [LANGUAGE.md](../../references/LANGUAGE.md) *Slice*.
- **Module map**: modules under `src/<module>/`. Use CONTEXT.md vocabulary ("the Settlement intake module", never "the FooBarHandler").
- **BC pattern per module**: pick from [bc-patterns.md](../../references/bc-patterns.md). Verify against current BaseApp via `/al-research` before committing.
- **R → P → W boundary**: R = reads / inputs / events subscribed; P = pure procedure (no DB, no side effects, unit-test surface); W = effects (Insert / Modify / Delete, telemetry, errors, events published).
- **Brownfield touchpoints**: objects, procedures, events, table fields the feature touches. Verify every name + signature via `/al-research`; stale memory ships fiction.
- **Testability constraints**: name where architecture should expose isolated decision logic behind the P layer and where behaviour necessarily crosses BC runtime, database, page/TestPage, event wiring, table triggers, telemetry shape, install / upgrade, permissions, or public surface. Do not write task-level proof, AAA cases, or assertions.
- **Which BC names verified this session?** Every BC-specific name landing in `architecture.md` (pattern, event, codeunit, table, field, procedure): backed this session by `al-symbols-mcp` / `grep` hit, including `grep` against `event-model.md` for upstream-cited names, or `/al-research` citation. Recall does not satisfy. See *Citation chain in chat, before write* below.

Unanswerable → not ready for `/al-scope`. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), or `/al-steer` (replan).

## Deletion test, every candidate module

Imagine deleting the module: complexity vanishes → pass-through, does not earn the row; complexity reappears across N callers → earns place. Doesn't apply when seam is a published event with no in-tree callers.

## Two-adapter rule, every seam

Seam without two adapters is hypothetical; one adapter is a tautology, the seam is one codeunit pretending to be flexible. Production + test counts; two real production variants counts; "interface for testability" with no fake actually written does not. Patterns implying a seam (Event Bridge, Template Method, Command Queue, AL `interface` Façade): name both adapters now or pick a different pattern.

## R → P → W as architectural choice

The split *is* the refactor, not annotation; pulling pure decision logic out of read/write context is what makes unit testing possible without standing up DB state. P is the most load-bearing line in the design.

## AL realisation per slice, no void slots

Each slice names its AL realisation across its slots: trigger object (page action, subscriber, Job Queue, install hook, API endpoint), codeunit holding the command, publication or subscription that moves the chain, table or field carrying state, page / factbox / API endpoint that renders the view. Void here = slot with no implementation home → `/al-implement` either invents one or stalls. User-facing voids caught at `/al-event-model`; this discipline checks AL coverage.

## AppSource sanity

Two design-time risks bite at AppSource boundaries: **BaseApp modification** (intercept via published events, table extensions, or AL `interface` implementations; AppSource rejects modified-base-app extensions) and **shipped-field rename or removal** (`ObsoleteState: Pending → Removed` over deprecation window; in-place rename breaks shipped data and shipped callers silently). Both are reshape triggers at design time. Per-task compliance details (IDs, permission sets, `DataClassification`, captions, install / upgrade) bite at `/al-implement`.

## Citation chain in chat, before write

Before writing any BC-specific name into `architecture.md` (pattern, event, codeunit, table, field, procedure), the name either appears in `al-symbols-mcp` / `grep` result you ran this session, or cited via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Workspace lookup is empirical anchor; memory of training data or past sessions is not. Training data for BC is stale fiction; workspace + `/al-research` are the empirical anchor. Names already research-backed by `/al-event-model` upstream count when `grep` against `event-model.md` returns the name this session, not when you recall they're there. Your confidence about a name, signature, or pattern label is not evidence any are right.

## Architecture trade-off criteria

Call out an architecture trade-off inside `architecture.md` when **all four** are true:

1. **Hard to reverse**: cost of changing later is meaningful.
2. **Surprising without context**: a future reader will wonder why.
3. **Real trade-off**: genuine alternatives, one picked for specific reasons.
4. **Architectural**: mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`, not here.

Three of four does not earn the callout; inflation rots the artifact. This skill does not write ADR files.

## Parallel design-twice, non-trivial calls

Non-trivial = multi-module, brownfield refactor, or novel pattern selection. When host supports subagents, run three parallel delegated passes with divergent constraints:

| Pass | Constraint |
|---|---|
| 1 | Minimise the interface, 1–3 entry points, maximise leverage per entry. |
| 2 | Maximise flexibility, many use cases, easy extension. |
| 3 | Optimise the most common caller, default case trivial. |

After the delegated pass outputs are collected and reconciled, close the completed subagent threads. Do not leave design-pass agents open as passive state.

Each pass runs its own `/al-research` and receives BC vocabulary from `CONTEXT.md` plus architectural vocabulary from [LANGUAGE.md](../../references/LANGUAGE.md) → all three name things consistently. Output per pass: module map + per-module interface, named adapters at every seam, the one trade-off line that distinguishes this design. Present all three sequentially, compare along **depth** / **locality** / **seam placement**, pick one (or hybrid) opinionatedly, run `/grill-me` when choice is user's call; `/al-second-opinion` reconciles non-trivial picks. Never silently skip the reconcile.

## Branch + folder + write

On `^\d{3}-`: `/al-event-model` created branch + spec folder; write `architecture.md` into existing folder. On `main`: this is first per-feature skill (backend-only, or `/al-event-model` skipped after missing-storm resolved to backend-only). Resolve `<NNN>` per [cross-branch-numbering.md](../../references/cross-branch-numbering.md) (cross-branch scan, not local-only), derive a 2-4-word kebab-case slug (do not ask), announce both, create branch `<NNN>-<slug>` + `specs/<NNN>-<slug>/`. Branch already exists locally or remotely → **Stop**.

Then write `architecture.md`. Markdown only; constraints in [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). Voice in [voice-contract.md](../../references/voice-contract.md). Both mandatory reads before writing. Write telegraphic; drop articles, padding, hedges; fragments fine. No surgical-edit contract; reshape via re-running. Name relationships (module deps, flow) in prose; no mermaid fences.

## Gate event

Once when `architecture.md` lands. Gate report names chosen BC pattern + R → P → W boundary as 'how this fits', states application problem the architecture solves, names user's call to greenlight `/al-scope`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-event-model` (user/API-facing features) or `/al-grill-adr` (backend-only) |
| **Hands off to**   | `/al-scope` |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/bc-standard-reference` (pure BaseApp questions), `/grill-me` (design-twice reconciliation), `/al-second-opinion` (parallel design-twice picks) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing `architecture.md` for first time. Artifact is load-bearing for every downstream skill; drift caught here costs minutes, drift caught at `/al-implement` costs a feature.

</claude-only>
