---
name: al-scope
description: Decompose a feature-level architecture.md into a ZOMBIES-ordered task list in tasks.md for AL/Business Central work. Use after /al-design and before /al-refine — reads the architecture, writes bare T-NNN entries (title + one context line each), no grilling and no branch creation.
---

# /al-scope — architecture.md to task list

Decompose `architecture.md` into bare task entries in `tasks.md`. Output is `## Goal` (architecture.md `## Solution` verbatim) plus `## Tasks` with `T-NNN` entries — one imperative title, one context line. No Gherkin (that is `/al-refine`), no per-task seam (that is `/al-implement`).

## Resolve target paths

- **Branch** must match `^\d{3}-`. If not, `Stop.` — run `/al-design`.
- **Spec folder** `specs/<branch>/` must already contain `architecture.md`. If missing, `Stop.` — run `/al-design`.
- **Output** `specs/<branch>/tasks.md` — created or overwritten.

## Process

### 1. Read the architecture

Take `## Solution` (becomes `## Goal` verbatim), the module map, the R to P to W boundary, brownfield touchpoints, and test strategy as inputs. Do not re-derive any of these.

### 2. Derive task entries

One imperative title plus one context line per task. Each task maps to a coherent slice of behaviour, typically a single scenario family from the test strategy. Use BC field, codeunit, and table names as compression.

### 3. Order ZOMBIES

Zero, One, Many, Boundary, Interfaces, Exception, Simple. Start with the simplest case that exercises the seam, then layer complexity outward.

### 4. Replan check (gate)

If decomposition surfaces a gap `architecture.md` doesn't cover — missing module, pattern conflict, unnamed brownfield touchpoint — do not invent. `Stop.` — run `/al-steer`. The replan venue routes to `/al-grill-adr` or an `/al-design` re-run.

### 5. Write tasks.md

Use the slot-fill template below. `Stop.` — `/al-refine` consumes the list one task at a time next.

## Output — tasks.md

```markdown
## Goal
<architecture.md ## Solution verbatim — one sentence>

### [ ] T-001 — <imperative title>
<one context line: BC site, then gap>

### [ ] T-002 — <imperative title>
<one context line: BC site, then gap>
```

## Context-line cadence

One fact. One line. BC vocabulary as compression.

**Drop list.** Articles (`the`, `a`). Conjunctions (`and`, `but`, `so`). Hedging (`should probably`, `may need to`). Semicolon-glue. Stacked clauses (`"which also … and then …"`). Prescriptive verbs (`implement`, `add support for`).

**Positional pattern.** `[BC site] [gap]`. The site names a codeunit, table, field, page, or event publisher. The gap names what is missing or wrong, not how to fix it.

**Yes/No.**

- No: `Codeunit 80 Sales-Post.OnAfterPostSalesDoc subscriber should be added; needs to handle returns and credit memos, and update the new "External Doc Status" field on Sales Header.`
- Yes: `Sales Header "External Doc Status" not set on credit memo posting.`

**Two lines feel necessary?** Split the task. If it doesn't split, the second line is a gap — flag for `/al-steer`.

_Avoid_: not semicolon-glued clauses, not subordinate-clause stacking, not embedding `/al-refine` fixture work, not embedding `/al-mutate` outcomes.

**Anti-pattern: context-line prose drift.** Multi-fact, hedged, prescriptive sentences masquerading as one line. Symptom of skipping the split.

## Notes

- **Status markers** `[ ]` ready, `[~]` in progress, `[x]` done, `[!]` blocked. Scope writes only `[ ]`.
- **Task IDs** `T-NNN` monotonic, never reused. Start at `T-001`.
- **Scaffolding rides with its object.** Permission set entries, object ID assignment, captions, translations bundle into the task that introduces the new codeunit, table, or page they cover. Never their own task. `<App>All.PermissionSet.al` updates ride with whichever task introduces the granted object.
- **No** `**Tests**`, **no** `**Architecture**`, **no** Resolved Questions, **no** Cross-cutting Notes, **no** Notes dumping ground.

## Composition

`/al-design` is the precondition — `architecture.md` must exist. `/al-research` for non-trivial BC areas before drafting. `/bc-standard-reference` when grounding scope in BaseApp behaviour. `/al-refine` consumes one task at a time next. `/al-steer` owns replan when the gate trips.

## Out of scope

- No grilling — `/al-grill-adr` ran already.
- No branch or spec-folder creation — `/al-design` did that.
- No Gherkin — `/al-refine`.
- No code edits, no per-task seam decisions — `/al-implement` step 2.
- No replan mutations — `/al-steer`.
