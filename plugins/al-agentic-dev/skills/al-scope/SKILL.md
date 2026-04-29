---
name: al-scope
description: Decompose a feature, issue, or idea into a scoped task list in tasks.md for AL/Business Central work. Produces Goal + bare task entries (title + one context line each). Use at the start of any new feature, before /al-refine runs. Requires /grill-me to confirm scope before writing.
---

# /al-scope — Feature → task list

Turn a feature, issue, or idea into a scoped task list in `tasks.md`. Use `/grill-me` to confirm scope. Output is a `## Goal` + bare task entries — no Gherkin yet.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Understand** the request; explore the codebase to identify which behaviors need tasks. Run `/al-research` if non-trivial.
2. **Draft** a task list: one imperative title + one context line per task.
3. **`/grill-me`** — confirm scope with the user. Resolve every open branch before writing.
4. **Write** `tasks.md`: `## Goal` + bare task entries. Stop.

## tasks.md output

```markdown
## Goal
<one paragraph — what the feature delivers, stated in user-visible terms>

### [ ] T-001 — <imperative title>
<one context line: the bug, gap, or constraint in BC vocabulary>

### [ ] T-002 — <imperative title>
<one context line>
```

- **One context line only.** Use BC field names, codeunit names, table names as compression. No prose sections.
- If two context lines feel necessary, the task likely splits into two — try splitting first. If splitting doesn't make sense, take the second line and flag with `/grill-me`.
- **No `**Tests**` block.** Gherkin is `/al-refine`'s job.
- **No Resolved Questions, Cross-cutting Notes, or any other sections.**
- Task IDs `T-001`, `T-002`, … monotonic, never reused.
- Apply ZOMBIES order when sequencing tasks: Zero cases first, walking outward to Many, Boundaries, Exceptions.

## Grilling

- **`/grill-me` is mandatory** — scope must be confirmed before writing the task list.
- Do not invent business rules. If a scope question can't be resolved by grilling, leave the task out.

## Composition

- `/grill-me` — mandatory scope confirmation.
- `/al-research` for non-trivial BC areas before drafting.
- `/bc-standard-reference` when grounding scope in BaseApp behaviour.

## Out of scope

- No Gherkin. No code edits. No implementation choices.
- No Resolved Questions or Cross-cutting Notes sections.
