---
name: al-scope
description: Decompose a feature-level architecture.md into a ZOMBIES-ordered task list in tasks.md for AL/Business Central work. Reads specs/<branch>/architecture.md, derives bare task entries (title + one context line each), and writes tasks.md. Run after /al-design, before /al-refine. No grilling, no branch creation — those happen upstream.
---

# /al-scope — architecture.md → task list

Decompose `architecture.md` into bare task entries in `tasks.md`. Output: `## Goal` (copied from architecture.md) + `## Tasks` with `T-NNN` entries — title + one context line each. No Gherkin, no architecture per task.

**Resolve target paths:** Check the current branch — if it matches `^\d{3}-`, use `specs/<branch>/`. Otherwise stop: run `/al-design` first. `architecture.md` must exist in the spec folder — if missing, stop: run `/al-design` first.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Read** `architecture.md`. Take the `## Goal`, the module map, the R→P→W boundary, and the test strategy as inputs.
2. **Derive task entries** — one imperative title + one context line per task. Each task should map to a coherent slice of behaviour (typically a single scenario family from architecture.md's test strategy).
3. **Apply ZOMBIES ordering** when sequencing tasks: Zero cases first, walking outward to Many, Boundaries, Exceptions.
4. **Write** `specs/<branch>/tasks.md`: `## Goal` (verbatim copy from architecture.md) + bare task entries. Stop.

## tasks.md output

```markdown
## Goal
<one paragraph — copied verbatim from architecture.md ## Goal>

### [ ] T-001 — <imperative title>
<one context line: the bug, gap, or constraint in BC vocabulary>

### [ ] T-002 — <imperative title>
<one context line>
```

- **One context line only.** Use BC field names, codeunit names, table names as compression. No prose sections.
- If two context lines feel necessary, the task likely splits into two — try splitting first. If splitting doesn't make sense, take the second line and flag for `/al-steer`.
- **No `**Tests**` block.** Gherkin is `/al-refine`'s job.
- **No `**Architecture**` block.** Feature architecture lives in `architecture.md`; per-task seam decisions land in `/al-implement` step 2.
- **No Resolved Questions, Cross-cutting Notes, or any other sections.**
- Task IDs `T-001`, `T-002`, … monotonic, never reused.

## Replan check (gate)

If decomposition surfaces a gap that architecture.md doesn't cover (a missing module, a pattern conflict, a brownfield touchpoint nobody named), **do not invent**. Stop, recommend `/al-steer`. The replan venue clears the gap; either `/al-grill-adr` re-runs to sharpen or `/al-design` re-runs to reshape.

## Composition

- `/al-design` — required precondition (`architecture.md` must exist).
- `/al-research` for non-trivial BC areas before drafting.
- `/bc-standard-reference` when grounding scope in BaseApp behaviour.

## Out of scope

- No grilling — `/al-grill-adr` ran already.
- No branch creation — `/al-design` did that.
- No Gherkin. No code edits. No implementation choices.
- No Resolved Questions or Cross-cutting Notes sections.
- No replan mutations — `/al-steer`.
