---
name: al-scope
description: Decompose a feature-level architecture.md into a ZOMBIES-ordered task list in tasks.md for AL/Business Central work. Use after /al-design and before /al-refine — reads the architecture, writes bare T-NNN entries (title + one context line each), no grilling and no branch creation.
---

# /al-scope — architecture.md → task list

Decompose `architecture.md` into bare task entries in `tasks.md`. Output: `## Goal` (architecture.md's `## Solution` verbatim) + `## Tasks` with `T-NNN` entries — title + one context line each. No Gherkin (that is `/al-refine`), no per-task architecture (that is `/al-implement`).

**Resolve target paths:**
- **Branch:** must match `^\d{3}-`. If not, `Stop.` — run `/al-design` first.
- **Spec folder:** `specs/<branch>/` — `architecture.md` must already exist. If missing, `Stop.` — run `/al-design` first.
- **Output:** `specs/<branch>/tasks.md` — created or overwritten here.

## Flow

Prefer parallel subagents for independent work and output-heavy steps.

1. **Read** `architecture.md`. Take `## Solution` (becomes `tasks.md` `## Goal`), the module map, the R → P → W boundary, the brownfield touchpoints, and the test strategy as inputs.
2. **Derive task entries** — one imperative title + one context line per task. Each task maps to a coherent slice of behaviour, typically a single scenario family from the test strategy.
3. **Order ZOMBIES.** Zero, One, Many, Boundary, Interfaces, Exception, Simple — start with the simplest case that exercises the seam, then layer complexity outward.
4. **Replan check (gate).** If decomposition surfaces a gap `architecture.md` doesn't cover (missing module, pattern conflict, unnamed brownfield touchpoint), do not invent. `Stop.` — recommend `/al-steer`. The replan venue routes to `/al-grill-adr` or `/al-design` re-run.
5. **Write** `specs/<branch>/tasks.md` in the canonical shape below. `Stop.` — `/al-refine` consumes it next, one task at a time.

## Output — tasks.md

```markdown
## Goal
<one sentence — architecture.md ## Solution verbatim>

### [ ] T-001 — <imperative title>
<one context line: the bug, gap, or constraint in BC vocabulary>

### [ ] T-002 — <imperative title>
<one context line>
```

- **One context line only.** Use BC field, codeunit, and table names as compression. No prose sections.
- **Two lines feel necessary?** The task likely splits — try splitting first. If it doesn't split, take the second line and flag for `/al-steer`.
- **Status markers:** `[ ]` ready, `[~]` in progress, `[x]` done, `[!]` blocked. Scope writes only `[ ]`.
- **Task IDs `T-NNN` monotonic, never reused.** Start at `T-001`.
- **No `**Tests**`, no `**Architecture**`, no Resolved Questions, no Cross-cutting Notes, no Notes dumping ground.**
- **Scaffolding rides with its object.** Permission set entries, object ID assignment, captions/translations belong to the task that introduces the new codeunit/table/page they grant access to. Never their own task. `<App>All.PermissionSet.al` updates bundle into whichever task introduces the granted object.

## Composition

`/al-design` is the precondition — `architecture.md` must exist. `/al-research` for non-trivial BC areas before drafting. `/bc-standard-reference` when grounding scope in BaseApp behaviour. `/al-refine` consumes one task at a time next. `/al-steer` owns replan when the gate trips.

## Out of scope

- No grilling — `/al-grill-adr` ran already.
- No branch or spec-folder creation — `/al-design` did that.
- No Gherkin (`/al-refine`), no code edits, no per-task seam decisions (`/al-implement` step 2).
- No replan mutations — `/al-steer`.
