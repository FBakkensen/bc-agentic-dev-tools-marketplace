---
name: al-design
description: Idea → feature architecture for AL/Business Central. Reads event-model.html when present (user/API-facing features) for the user-facing journey; settles AL-shape (module map under src/, BC pattern per module, R → P → W boundary, brownfield touchpoints, test layer per scenario family). Runs parallel design-twice for non-trivial calls. Writes architecture.html; creates branch and spec folder when /al-event-model did not. Use after /al-event-model for user/API-facing features, or after /al-grill-adr for pure-backend features. Per feature, not per task.
---

# /al-design, Idea → feature architecture

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on.

Turn a sharpened idea into a feature-level architecture, then write `architecture.html` so the next skill can pick up cold. The HTML's shape is yours to decide per feature. The disciplines below are the substance you bring; the slots and section order are not.

`/al-scope` reads this file next and decomposes it into tasks. That is the only reader that depends on it.

## Preconditions

- `/al-grill-adr` ran for this idea. The grilling outcome sharpens intent and side-effects `CONTEXT.md` / domain ADRs. Without it, you cannot tell domain confusion from genuine architectural choice. **Stop** and run it first.
- For user-facing or API-facing features, `/al-event-model` ran, producing `event-model.html` in the spec folder. Without it, this skill would re-litigate user-side picks inline and the entanglement the pipeline removes returns. If `event-model.html` is missing, run the missing-storm checkpoint: ask the user whether the feature is pure backend (no human, no API consumer, only internal batch work) or whether `/al-event-model` was forgotten. **Stop** unless the user confirms pure backend.
- Branch creation is shared with `/al-event-model`. If on `main` (pure-backend feature, or first per-feature skill to run), this skill creates the branch and spec folder. If on a feature branch (`^\d{3}-`), `/al-event-model` already created it; this skill writes `architecture.html` into the existing spec folder.
- If the spec folder already holds an `architecture.html`, you are reshaping; re-run with the user's awareness, not silently.
- If the spec folder holds a legacy `architecture.md` without `architecture.html`, **Stop**. Legacy markdown specs are frozen historical artifacts; surface the choice (hand-migrate, or delete and reshape via this skill).

## What goes into architecture.html

The artifact's job: tell the next skill (and the next agent, weeks later, fresh session) what this feature is, what changes, and what's testable where. Nothing more. The shape that serves that job per feature is yours.

What the next reader needs from you, expressed as questions you must have answers to:

- **Which user-facing slices does this feature deliver, and where do they come from?** When `event-model.html` is present, the user-facing slots of each slice (Role, Action, Business Event, View, Status) are settled there; this skill reads them, does not re-decide them, and qualifies each slice by its AL pattern (Command / Automation / Translation / View) based on trigger source. When `event-model.html` is absent (pure-backend feature confirmed), name the slice's trigger-source-only slot (Job Queue, install / upgrade, scheduled task); no user-facing slots apply. See `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` *Slice* entry.
- **Which modules are added, extended, or touched?** A module is `src/<module>/`. Use CONTEXT.md vocabulary for the role; "the Settlement intake module," never "the FooBarHandler."
- **Which BC pattern realises each module?** Pick from `${CLAUDE_SKILL_DIR}/../../references/bc-patterns.md`. Verify the pattern against current BaseApp via `/al-research` before committing.
- **Where does the R → P → W boundary sit?** R = reads / inputs / events subscribed. P = pure procedure, no DB, no side effects, the unit-test surface. W = effects (Insert / Modify / Delete, telemetry, errors, events published).
- **Which existing objects, procedures, events, table fields does the feature touch?** Verify every name and signature via `/al-research` before listing; stale memory turns this into fiction.
- **At which layer does each scenario family get tested?** Pure (P-layer, no DB) is the default. E2E earns its place when the behaviour is composition or a side effect that cannot be reproduced at the pure layer (event wiring, table triggers, telemetry shape, install/upgrade transitions).

If a question is unanswerable, the feature is not ready for `/al-scope`. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), or `/al-steer` (replan).

## Disciplines

These are how to think about feature-level architecture for BC. Apply where each one's *why* lands; skip where it does not. The skills downstream trust that you ran these where they applied.

### Deletion test, on every candidate module

Imagine deleting the module. If complexity vanishes, it is a pass-through; do not add the row. If complexity reappears across N callers, it earns its place. **Why**: pass-through modules add navigation cost without hiding anything. Doesn't apply when the seam is a published event with no in-tree callers (no N callers to surface in).

### Two-adapter rule, on every seam

A seam without two adapters is hypothetical. **Why**: one adapter is a tautology; the seam is just one codeunit pretending to be flexible. Production + test counts as two. Two real production variants counts. "Interface for testability" alone with no test fake actually written is not two. Patterns that imply a seam (Event Bridge, Template Method, Command Queue, AL `interface`-based Façade): name both adapters now or pick a different pattern.

### R → P → W as architectural choice

The split *is* the refactor, not annotation. **Why**: pulling pure decision logic out of read/write context is what makes unit testing possible without standing up DB state. P is the most load-bearing line in the design; it names what is testable without a real database.

### AL realisation per slice, no void slots

Each slice in `architecture.html` names its AL realisation across the user-facing slots settled in `event-model.html` (or the trigger-source slot only, for pure-backend slices): the trigger object (page action, subscriber, Job Queue, install hook, API endpoint), the codeunit holding the command, the publication or subscription that moves the chain, the table or field carrying state, the page or factbox or API endpoint that renders the view. **Why**: a void here is a slot in the user-facing chain that has no implementation home, and `/al-implement` either invents one or stalls. Voids in the user-facing chain are caught earlier by `/al-event-model`; this discipline checks AL coverage. If `event-model.html` is absent for a non-pure-backend feature, the missing-storm checkpoint fires before this discipline applies.

### AppSource sanity

Two design-time risks bite at AppSource boundaries:

- **BaseApp modification.** Intercept via published events, table extensions, or AL `interface` implementations. Never edit BaseApp in place. **Why**: AppSource rejects modified-base-app extensions.
- **Shipped-field rename or removal.** `ObsoleteState: Pending → Removed` over the deprecation window. Never rename or remove in place. **Why**: shipped data and shipped callers both break silently.

Both are reshape triggers at design time. The per-task compliance details (IDs, permission sets, `DataClassification`, captions, install / upgrade) bite at `/al-implement`.

### Citation chain in chat, before `architecture.html` writes

Every BC-specific name (object, procedure, event, table, field, pattern) introduced in the artifact rests on a current BaseApp fact. Before `architecture.html` writes, each name not already pointed-at in the workspace or upstream `event-model.html` gets a chat-declared citation: `Researched: <name> → <source path / URL / topic id, verbatim one-liner>`. Route through `/al-research`; do not reach for the underlying tools directly. Names from `event-model.html` are already research-backed by `/al-event-model`; do not re-verify. **Why**: stale training knowledge for BC ships fiction (renamed events, removed procedures, signature drifts). One missed event signature corrupts the brownfield touchpoint list, which corrupts `/al-scope`, which corrupts every task downstream. **Why the chat binding**: a mention of `/al-research` in a Composition list reads as advice and gets skipped under time pressure. A citation chain at write-time binds the gate to the artifact, skipping research means skipping the declaration, which is visible in the transcript. The artifact stays clean of inline citations (names are the citation); the chain lives in chat as the audit trail.

### ADR offer criteria

Offer a design ADR when **all four** are true:

1. **Hard to reverse**: cost of changing later is meaningful.
2. **Surprising without context**: a future reader will wonder why.
3. **Real trade-off**: genuine alternatives, one picked for specific reasons.
4. **Architectural**: mechanism, module shape, pattern, seam placement, test layer. (Domain rules belong to `/al-grill-adr`, not here.)

Three of four does not earn an ADR. **Why**: ADR inflation rots the index; every reader pays the cost of scanning past low-value entries.

Template: `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`. ADRs are markdown; the HTML shift covers only `specs/<NNN>-<slug>/`.

## Parallel design-twice, on non-trivial calls

Non-trivial = multi-module, brownfield refactor, or novel pattern selection. When the host supports subagents, run three parallel delegated design passes with divergent constraints:

| Pass | Constraint |
|---|---|
| 1 | Minimise the interface, 1–3 entry points, maximise leverage per entry. |
| 2 | Maximise flexibility, many use cases, easy extension. |
| 3 | Optimise the most common caller, default case trivial. |

Each pass runs its own `/al-research` for any BC behavioural claim. Each receives a brief that includes BC vocabulary from `CONTEXT.md` and architectural vocabulary from `LANGUAGE.md`, so all three name things consistently.

**Output**: module map + per-module interface, named adapters at every seam, the one trade-off line that distinguishes this design from the others.

**Reconcile**: present all three sequentially. Compare along three axes: **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**. Pick one design (or a hybrid), opinionated. Run `/grill-me` when the choice is the user's call. Never silently skip the reconcile step.

## Branch + folder + write

If already on `^\d{3}-`: `/al-event-model` ran first and created the branch and spec folder. Write `architecture.html` into the existing folder.

If on `main`: this skill is the first per-feature skill to run (pure-backend feature, or `/al-event-model` was skipped after the missing-storm checkpoint resolved to *pure backend*). Resolve `<NNN>` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` (cross-branch scan, not a local-only scan of `specs/`). Derive a 2–4-word kebab-case slug; do not ask the user. Announce the branch name and slug, then create branch `<NNN>-<slug>` and `specs/<NNN>-<slug>/`. If the branch exists locally or remotely: **Stop**, the user resolves.

Then write `architecture.html`. Self-contained HTML, inline `<style>`, Google Fonts via CDN, Mermaid pinned `@11` via jsdelivr; full aesthetic and embedding constraints in `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md`. Voice contract in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. Both are mandatory reads before writing.

## Floor

`architecture.html` carries no surgical-edit contract. Maintaining skills do not edit it; reshape happens by re-running `/al-design`. The only HTML hooks that survive are Mermaid containers when diagrams are present: `<div class="mermaid" data-graph="module-deps">` and / or `<div class="mermaid" data-graph="flow">`. These are for Mermaid to find its graphs, not for the agent to find slots.

Every other piece of structure (section order, slot identities, alert blocks, table column shapes, where the ADRs cited list sits) is your call per feature. Inconsistency across features is fine and expected.

**Names are the citation.** No inline `(see: file.al:120)` annotations anywhere in the artifact. Future readers grep; the IDE gives line numbers for free. Rationale that doesn't fit a slot belongs in an ADR (when load-bearing) or in the conversation transcript that produced the doc, never in a `Notes` dumping ground.

**Map, not memoir.** The artifact is what the next reader needs to understand the feature, not a log of how you arrived at it.

## Lazy reference reads

| Source (read-only) | Target (writable) | Trigger |
|---|---|---|
| `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` | `CONTEXT.md` (repo root) | first need, if missing |
| `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` | `docs/adr/NNNN-<slug>.md` | on ADR accept; resolve `NNNN` per `cross-branch-numbering.md` |
| `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` | (read, not materialised) | before picking ADR `NNNN` and spec folder `NNN` |
| `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` | (read, not materialised) | before writing HTML |
| `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` | (read, not materialised) | before writing HTML |
| `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` | (read, not materialised) | architectural vocabulary, throughout |
| `${CLAUDE_SKILL_DIR}/../../references/bc-patterns.md` | (read, not materialised) | when picking a pattern per module |
| `specs/<NNN>-<slug>/event-model.html` | (read, not materialised) | for user/API-facing features; settles the user-facing slots of each slice |
| most recently modified prior spec under `specs/*/` | (read, not materialised) | before writing HTML, for visual coherence |

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

Full architectural vocabulary in `LANGUAGE.md`. BC pattern catalogue in `bc-patterns.md`.

## Composition

- `/al-grill-adr`, precondition.
- `/al-event-model`, precondition for user-facing or API-facing features; this skill reads `event-model.html` as input. Pure-backend features skip it (missing-storm checkpoint confirms).
- `/al-research`, before any BC-specific claim (pattern, signature, event name).
- `/bc-standard-reference`, when the question is purely BaseApp behaviour.
- `/grill-me`, for ADR offers and design-twice reconciliation.
- `/al-scope`, consumes `architecture.html` next.
- `/al-steer`, replan venue if a precondition or research gate hard-halts.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing `architecture.html` for the first time. The artifact is load-bearing for every downstream skill; drift caught here costs minutes, drift caught at `/al-implement` costs a feature.

</claude-only>

## Out of scope

- No code edits, no interface extraction (`/al-refactor`), no Gherkin (`/al-refine`), no mutations (`/al-mutate`).
- No per-task architecture (`/al-implement` step 2).
- No domain ADRs inline; those belong to `/al-grill-adr`.
- No markdown-mode output. Legacy markdown specs are frozen; this skill refuses to run on a spec folder that holds `architecture.md` without `architecture.html`.
