---
name: al-scope
description: Decompose a feature-level architecture.html into a ZOMBIES-ordered task list in tasks.html for AL/Business Central work. Use after /al-design and before /al-refine. Reads the architecture, writes the Goal, the per-task entries, and a dependency graph when it earns its place. Per-task structure carries the floor (T-NNN ID + status) so downstream skills can find and flip status; everything else is your call per feature.
---

# /al-scope, architecture.html → task list

Decompose `architecture.html` into per-task entries in `tasks.html`. The artifact's job: tell `/al-refine` (and the next agent, weeks later, fresh session) what tasks exist, in what order, with what dependencies, so refinement and TDD can pick up cold.

The shape that serves that job per feature is yours. The disciplines below are the substance you bring. The floor on `tasks.html` exists so maintaining skills can flip task status surgically without re-parsing the whole file; nothing more.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend features).
- Spec folder `specs/<branch>/` already holds `architecture.html`. If missing, **Stop**. Run `/al-design`.
- For user/API-facing features, `event-model.html` is also present (settled by `/al-event-model`). Pure-backend features carry `architecture.html` only.
- Spec folder holds a legacy `architecture.md` without `architecture.html`: **Stop**. Legacy markdown specs are frozen; hand-migrate or reshape via `/al-design`.

## What goes into tasks.html

What the next reader needs from you, expressed as questions you must have answers to:

- **What is the feature's Goal?** Take it from `event-model.html`'s user-facing journey for user/API-facing features (one-line summary of the outcome the journey delivers); from `architecture.html`'s trigger-source description for pure-backend features. Do not re-derive.
- **What tasks decompose the feature?** One imperative title plus a short description paragraph per task. Each task maps to a coherent slice of behaviour, typically a single scenario family from the test strategy. Use BC field, codeunit, and table names as compression.
- **In what order?** ZOMBIES (Zero, One, Many, Boundary, Interfaces, Exception, Simple). Start with the simplest case that exercises the seam, layer complexity outward.
- **What depends on what?** Per task, identify cross-task relationships in terms the agent and reader both understand. Three kinds: `Depends on:` (cannot land without those tasks already in place), `Refactors:` (reshapes code shipped by that task under an invariant), `Fixes:` (corrects a defect or wrong contract from that task). Omit any kind that does not apply.
- **Does a dependency graph earn its place?** A Mermaid `graph LR` makes non-linear shape visible (fan-out, fan-in, refactor / fix edges). Include when ≥3 tasks AND the edges are not a single linear chain. Skip when ≤2 tasks or all edges are linear `Depends on:` only. The Summary already conveys linear order.
- **What scaffolding rides with each task?** Permission-set entries, object IDs, captions, translations bundle into the task that introduces the new codeunit, table, or page they cover. Never their own task. Name the bundled scaffolding so `/al-refine` and `/al-implement` know it is in scope.

If a question is unanswerable from `architecture.html`, the architecture is incomplete. **Stop**. Run `/al-steer`, which routes to `/al-grill-adr` or `/al-design` re-run.

## Disciplines

### Vertical slicing, every task

Every `T-NNN` ships tests plus production code together. **Why**: layer-only tasks (data without callers, logic without tests, wire-up without target) leave the system half-built, and tests-as-afterthought becomes tests-never-written. Horizontal phasing (data first, then logic, then UI, then tests later) is rejected by name; see `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` *Vertical slicing*. If a task cannot satisfy this, split or merge until it does. The *kind* of slice varies (primitive: pure logic + tests; extract: refactor moving an existing capability; wire: the slice's trigger surface; fix: contract correction; pure refactor: shape change under invariant); verticality does not.

### One slice fans into many tasks

A complex slice in `architecture.html` typically fans into a *wire* task crossing the slice's trigger, plus *primitive / extract / fix* tasks composing into it. **Why**: the slice is the architectural unit; the task is the TDD-cycle unit. Forcing one slice to one task either bloats the task past a session or hides the seam under the wrapper.

### ZOMBIES order, not arrival order

Zero, One, Many, Boundary, Interfaces, Exception, Simple. **Why**: simplest exercise of the seam first gives `/al-implement` the cleanest starting test. Complexity layered outward keeps each task's TDD cycle inside one session. Arrival order (the order tasks occurred to you) buries the seam under setup.

### Edges declared at scope, not derived later

Source edges from the architecture's slice, module map, and brownfield touchpoints. **Why**: a task that wires a slice trigger depends on the primitive tasks it composes; a refactor task points at the task whose object it reshapes. These are not guessable later from titles alone; the agent doing `/al-refine` or `/al-implement` needs them declared.

### Replan check before writing

If decomposition surfaces a gap `architecture.html` does not cover (missing module, pattern conflict, unnamed brownfield touchpoint), do not invent. **Why**: inventing here corrupts every downstream skill, and the invention is invisible (no one knows to look for it). **Stop** and run `/al-steer`.

## Floor

`tasks.html` carries one surgical-edit contract: maintaining skills find a task by its ID and flip its status. Everything else is yours per feature.

The two hooks:

- `<details data-task="T-NNN">` on each per-task block. `T-NNN` is monotonic, never reused, starts at `T-001`. The `data-task` attribute and the anchor `id` use the same form (`data-task="T-001"` and `id="t-001"` for cross-doc links).
- `data-status="ready | in-progress | done | blocked"` on the same `<details>`. Scope writes only `ready`. `/al-implement` and `/al-steer` flip later.

How the status renders visually (glyph, colour, badge) is your call. Maintaining skills flip the attribute; the rendering follows from CSS or whatever you wired up.

**Nothing else is a contract.** Section order, Summary table shape, alert blocks, edge rendering, dependency graph styling, where description sits relative to edges, whether NOTE/IMPORTANT/WARNING alerts appear at all: your call. Inconsistency across features is fine and expected.

**Names are the citation.** No inline `(see: file.al:120)` annotations. Future readers grep; the IDE gives line numbers for free.

## Description

What the task delivers. Lede first: BC site (object, procedure, field) plus the invariant the task preserves or the contract it ships. Cite ADRs inline as `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>`. Shape per `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`: tight `<p>` for one or two facts; one fact per landing line when content carries more (bullets, sub-callouts, table rows, separate paragraphs, your call).

`/al-refine` may rewrite the description after walking the codebase, swapping in concrete `file:line` citations, object IDs from `/al-research`, or sharpened invariants the codebase walk surfaces.

## Lazy reference reads

| Source (read-only) | Trigger |
|---|---|
| `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` | before writing prose |
| `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` | before writing HTML |
| `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` | architectural vocabulary, throughout |
| `specs/<NNN>-<slug>/event-model.html` | for user/API-facing features; source the Goal and align task vocabulary with Roles, Business Events, Views named there |
| most recently modified prior spec under `specs/*/` | before writing HTML, for visual coherence |
| `${CLAUDE_SKILL_DIR}/../../references/user-communication.md` | before any chat reply at a gate event |

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Tests** short PascalCase scenario name (`PostSalesOrderWithBlockedCustomer`), match BaseApp style.

## Gate event

Once when the task decomposition lands in `tasks.html`. The Gate report names the slice families decomposed and the dependency shape (linear chain or branching), states the feature Goal in user terms, and names the user's call to greenlight `/al-refine` on the first task.

## Composition

- `/al-design` is the precondition; `architecture.html` must exist.
- `/al-event-model` is also a precondition for user/API-facing features; `event-model.html` carries the Goal source.
- `/al-research` for non-trivial BC areas before drafting.
- `/bc-standard-reference` when grounding scope in BaseApp behaviour.
- `/al-refine` consumes one task at a time next.
- `/al-steer` owns replan when a gap surfaces.

## Out of scope

- No grilling. `/al-grill-adr` ran already.
- No branch or spec-folder creation. `/al-design` did that.
- No Gherkin. `/al-refine`.
- No code edits, no per-task seam decisions. `/al-implement` step 2.
- No replan mutations. `/al-steer`.
- No markdown-mode output. Legacy markdown specs are frozen; this skill refuses to run on a folder that lacks `architecture.html`.
