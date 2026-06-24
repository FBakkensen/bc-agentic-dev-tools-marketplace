---
name: al-design
description: Settle the AL/Business Central feature architecture from idea or `event-model.md`. Use after `/al-event-model` for user/API-facing features, after `/al-grill-adr` for backend-only features, or when the user asks to design an AL feature.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-design, Idea → feature architecture

Turn sharpened idea into feature-level architecture, then write `architecture.md`; `/al-scope` reads it next and decomposes it into tasks. Shape per feature is yours; disciplines below are the substance.

## Artifact boundary

Writes only `architecture.md`.

May define production architecture, AL object responsibilities, module boundaries, seams, events, R → P → W flow, testability constraints, and seam expectations.

Never write task-level proof. `/al-scope` owns the `tasks/` folder; `/al-refine` owns task-level proof shape.

## Preconditions

- `/al-grill-adr` ran for this idea; without sharpened intent in `CONTEXT.md` / domain ADRs you cannot tell domain confusion from genuine architectural choice. **Stop**, run it first.
- User/API-facing: `/al-event-model` ran, `event-model.md` in spec folder; without it this skill re-litigates user-side picks inline and entanglement returns. Missing → run missing-storm checkpoint: ask whether feature is backend-only (no human, no API consumer) or whether `/al-event-model` was forgotten. **Stop** unless user confirms backend-only.
- Branch creation shared with `/al-event-model`. On `^\d{3}-`: branch + spec folder exist, write into them. On `main` (backend-only, or first per-feature skill): this skill creates them.
- Existing `architecture.md` → reshaping; re-run with user's awareness.

## What goes into architecture.md

- **Slices**: when `event-model.md` present, its user-facing slots (Role, Action, Business Event, View, Status) are settled; read, do not re-decide, qualify each slice by AL pattern (Command / Automation / Translation / View) based on trigger source. Backend-only slices name trigger-source slot only (Job Queue, install / upgrade, scheduled task); see [LANGUAGE.md](../../references/LANGUAGE.md) *Slice*.
- **Module map**: modules under `src/<module>/`. Use CONTEXT.md vocabulary ("the Settlement intake module", never "the FooBarHandler").
- **BC pattern per module**: pick from [bc-patterns.md](../../references/bc-patterns.md). Verify against current BaseApp via `/al-research` before committing.
- **R → P → W boundary**: R = reads / inputs / events subscribed; P = pure procedure (no DB, no side effects, unit-test surface); W = effects (Insert / Modify / Delete, telemetry, errors, events published). The split *is* the refactor — pulling pure decision logic out of read/write context is what makes unit testing possible without DB state. P is the most load-bearing line in the design.
- **Brownfield touchpoints**: objects, procedures, events, table fields the feature touches. Verify every name + signature against workspace evidence (`al-symbols-mcp` / `grep`); behaviour and contracts the workspace cannot answer route through `/al-research`.
- **Testability constraints**: name where architecture should expose isolated decision logic behind the P layer and where behaviour necessarily crosses BC runtime, database, page/TestPage, event wiring, table triggers, telemetry shape, install / upgrade, permissions, or public surface. Do not write task-level proof, AAA cases, or assertions.
- **Evidence before write**: every BC-specific name in `architecture.md` meets the evidence bar in [voice-contract.md](../../references/voice-contract.md). It is a durable design artifact, so beyond names already in the dependency graph — pattern fitness, BaseApp behaviour, event contracts — routes through `/al-research`, mandatory, not a single-source fetch. Names from `/al-event-model` upstream count only when `grep` against `event-model.md` returns them this session.

Unanswerable → not ready for `/al-scope`. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), or `/al-steer` (replan).

## Deletion test, every candidate module

Imagine deleting the module: complexity vanishes → pass-through, does not earn the row; complexity reappears across N callers → earns place. Doesn't apply when seam is a published event with no in-tree callers.

## Two-adapter rule, every seam

Seam without two adapters is hypothetical; one adapter is a tautology, the seam is one codeunit pretending to be flexible. Production + test counts; two real production variants counts; "interface for testability" with no fake actually written does not. Patterns implying a seam (Event Bridge, Template Method, Command Queue, AL `interface` Façade): name both adapters now or pick a different pattern.

## AL realisation per slice, no void slots

Each slice names its AL realisation across its slots: trigger object (page action, subscriber, Job Queue, install hook, API endpoint), codeunit holding the command, publication or subscription that moves the chain, table or field carrying state, page / factbox / API endpoint that renders the view. Void here = slot with no implementation home → `/al-implement` either invents one or stalls. User-facing voids caught at `/al-event-model`; this discipline checks AL coverage.

Mark each named object `new` or `extends <existing object>` — `extends` marks an extension object on an existing base, still a `New:` object at refine; an object another slice already creates is named with its owning slice, not re-marked. `/al-refine` derives each task's `New and Modified Objects` from these markers without re-deciding brownfield scope. Object level only — fields and signatures are refine's altitude; they shift during TDD and rot in a reshape-only artifact.

## AppSource sanity

Two design-time risks bite at AppSource boundaries: **BaseApp modification** (intercept via published events, table extensions, or AL `interface` implementations; AppSource rejects modified-base-app extensions) and **shipped-field rename or removal** (`ObsoleteState: Pending → Removed` over deprecation window; in-place rename breaks shipped data and shipped callers silently). Both are reshape triggers at design time. Per-task compliance details (IDs, permission sets, `DataClassification`, captions, install / upgrade) bite at `/al-implement`.

## Architecture trade-off criteria

Call out an architecture trade-off inside `architecture.md` when **all four** are true:

1. **Hard to reverse**: cost of changing later is meaningful.
2. **Surprising without context**: a future reader will wonder why.
3. **Real trade-off**: genuine alternatives, one picked for specific reasons.
4. **Architectural**: mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`, not here.

Three of four does not earn the callout. This skill does not write ADR files.

## Parallel design-twice, non-trivial calls

Non-trivial = multi-module, brownfield refactor, or novel pattern selection. When host supports subagents, run three parallel delegated passes with divergent constraints:

| Pass | Constraint |
|---|---|
| 1 | Minimise the interface, 1–3 entry points, maximise leverage per entry. |
| 2 | Maximise flexibility, many use cases, easy extension. |
| 3 | Optimise the most common caller, default case trivial. |

Each pass runs its own `/al-research` and receives BC vocabulary from `CONTEXT.md` plus architectural vocabulary from [LANGUAGE.md](../../references/LANGUAGE.md) → all three name things consistently. Output per pass: module map + per-module interface, named adapters at every seam, the one trade-off line that distinguishes this design. Present all three sequentially, compare along **depth** / **locality** / **seam placement**, pick one (or hybrid) opinionatedly, run `/grill-me` when choice is user's call; `/al-second-opinion` reconciles non-trivial picks.

## Branch + folder + write

On `^\d{3}-`: `/al-event-model` created branch + spec folder; write `architecture.md` into existing folder. On `main`: this is first per-feature skill (backend-only, or `/al-event-model` skipped after missing-storm resolved to backend-only). Resolve `<NNN>` per [cross-branch-numbering.md](../../references/cross-branch-numbering.md) (cross-branch scan, not local-only), derive a 2-4-word kebab-case slug (do not ask), announce both, create branch `<NNN>-<slug>` + `specs/<NNN>-<slug>/`. Branch already exists locally or remotely → **Stop**.

Then write `architecture.md`. Markdown only; constraints in [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). Voice in [voice-contract.md](../../references/voice-contract.md). Both mandatory reads before writing. Write telegraphic; drop articles, padding, hedges; fragments fine. No surgical-edit contract; reshape via re-running. Name relationships (module deps, flow) in prose; no mermaid fences.

## Document verification

After writing `architecture.md`, run the document-integrity check yourself, inline (no subagent), before the Gate report — verify the artifact against [`doc-integrity.md`](../../references/doc-integrity.md): the `architecture.md` profile (module map, boundaries, cross-file consistency, the `new` / `extends` marker on slice-realisation objects) and sibling consistency in the spec folder.

A **fail** (structural or boundary blocker) blocks the Gate report and `/al-scope` handoff; fix it or route to `/al-steer`. A **warn** does not block; include it in the Gate report. This gate checks document integrity only, not whether the architecture is the best design.

## Gate event

Once when `architecture.md` lands. Gate report names chosen BC pattern + R → P → W boundary as 'how this fits', states application problem the architecture solves, names user's call to greenlight `/al-scope`.

## Next step

`architecture.md` landed clean. `Next: /al-scope` — it decomposes the architecture into the slice-grouped `tasks/` folder. A BaseApp behaviour or pattern fitness won't ground → `Next: /al-research`; a domain rule is unsettled → `/al-grill-adr`; the decomposition needs a new decision → `/al-steer`.

## Feed

Three moments narrate to the branch feed; the architecture reshaping itself (deletion test, two-adapter rule, R → P → W split) is interior craft, not a feed beat. At each, hand `/al-feed` a brief — what just happened, why it matters to someone who hasn't read `architecture.md`, the kind — and `/al-feed` composes the card and appends it. The inline document-integrity check returns a verdict, not a card: on a **fail**, fire a card naming the plain-language defect that blocked the docs; a clean pass folds into the `landing` card.

- **decision** · design-twice bake-off reconciled, one blueprint picked (non-trivial calls only): the one-line why-it-won.
- **decision** · an architecture trade-off recorded (all four criteria hold): mechanism picked, alternative rejected, reason.
- **landing** · `architecture.md` lands with the Gate report: chosen BC pattern, R → P → W boundary, problem solved, greenlight to `/al-scope`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-event-model` (user/API-facing features) or `/al-grill-adr` (backend-only) |
| **Hands off to**   | `/al-scope` |
| **Calls directly** | `/al-research` (BC facts), `/al-second-opinion` (parallel design-twice picks) — the only skills it invokes |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `bc-standard-reference` (pure BaseApp questions), `/grill-me` (design-twice reconciliation) |

**Advisor checkpoint.** Before writing `architecture.md` for the first time, do a final shape check (`/al-second-opinion` for non-trivial design picks) — drift caught here costs minutes, drift caught at `/al-implement` costs a feature.
