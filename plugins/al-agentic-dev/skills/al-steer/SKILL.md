---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev. Reads tasks.md, the goal, the codebase, and recent commits, then tells the user what's next, what's blocked, and what's drifting. Use when uncertain about the next step, when planning a session, or when asking "where are we?". Recommends a handoff to /al-grill-adr, /al-design, /al-scope, /al-refine, /al-implement, /al-refactor, /al-mutate, or /al-research — but never forces one. Owns the .out-of-scope/ rejection knowledge base.
---

# /al-steer — Coach / navigator

Read `tasks.md`, `architecture.md`, the goal, the codebase, and recent commits. Tell the user what's next, what's blocked, what's drifting. Run `/grill-me` when intent is unclear. Recommend a handoff — but do not force one.

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-design` first.

## Power model

- Read anything in the workspace, `tasks.md`, `architecture.md`, `CONTEXT.md`, `docs/adr/`, and `.out-of-scope/`.
- Write anything in `tasks.md`, but **only after explicit user acknowledgement**. Never silent.
- Write to `.out-of-scope/<concept>.md` when the user vetoes scope during a replan or grilling — see *Out-of-scope rejection knowledge base*.
- **Cannot edit code.**
- **Cannot edit `architecture.md`** in place — recommend `/al-design` re-run if the design is wrong.
- **Cannot edit `CONTEXT.md` or `docs/adr/`** — those are owned by `/al-grill-adr` and `/al-design`.
- **Structural mutations on `tasks.md` allowed during the replan flow** — split, insert, reorder, delete `[ ]` tasks; update context lines; strip stale `**Tests**` blocks. Never writes Gherkin.
- **Default scope:** the current task and the current code. Going beyond (branch state, other repos, external systems) requires explicit user instruction + acknowledgement.
- Push back or run `/grill-me` when the user's request looks off-target.

## Identify state

- Ready tasks (`[ ]`) vs stalled in-progress tasks (`[~]`) across sessions.
- Blocked tasks (`[!]`) and unresolved `**Replan**` Notes lines — these are the replan queue.
- Goal drift — does the goal paragraph still describe what `tasks.md` is delivering? Cross-check against `architecture.md`.
- Architecture drift — does `architecture.md`'s module map still describe the code being written?
- Notes lines flagging open questions, blockers, missing scenarios.
- Cross-task issues — broken `Depends-on`, redundancy, gaps.

## Recommend (the menu — pick what fits, never force)

| Situation | Recommend |
|---|---|
| No tasks.md yet / new feature | `/al-grill-adr` then `/al-design` |
| `architecture.md` exists, no tasks.md | `/al-scope` |
| Task is `[!]` (replan needed) | `/al-steer` Replan flow |
| Goal drift — `## Goal` no longer describes `tasks.md` | `/al-design` re-run |
| Architecture drift — code shape diverges from `architecture.md` | `/al-design` re-run |
| Term is fuzzy or contested | `/al-grill-adr` |
| Task exists but has no Gherkin yet | `/al-refine <T-NNN>` |
| Implementable task (Gherkin present, architecture.md present) | `/al-implement <T-NNN>` |
| Code lacks coverage | `/al-mutate <area>` |
| Code shape is wrong, tests green | `/al-refactor <area>` |
| "How does X work in BC?" | `/al-research <topic>` |
| User uncertain about direction | `/grill-me` first, then recommend |
| User has clarity now | No handoff — sometimes that's the right answer |

## Replan flow

`/al-steer` is the canonical replan venue. Other skills surface replan triggers via the **Replan check (gate)** — they set the task `[!]` (hard-halt) or append a Notes line (soft-flag) and stop. `/al-steer` clears the queue.

**Read the queue.** Scan `tasks.md` for `[!]` tasks and Notes lines of shape `**Replan** trigger #N: <reason>`. Order by trigger severity, then by task ID.

**The seven triggers — name them this way every time:**

| # | Trigger | Mode |
|---|---|---|
| 1 | Task too big — `>5` scenarios after refinement, or scenarios cluster around two distinct subjects | soft-flag |
| 2 | Hidden pre-req — referenced table/codeunit/permission has no task | hard-halt |
| 3 | Wrong order — Gherkin references behavior a later task introduces | hard-halt |
| 4 | Sibling task now wrong — current task invalidates another's context line or scenarios | hard-halt |
| 5 | New behavior emerges — code path needs its own test, not a bullet-extension | soft-flag |
| 6 | Architecture decomposition wrong — R→P→W boundary cuts across tasks, or `architecture.md` itself is wrong | hard-halt |
| 7 | Goal drift — `## Goal` no longer describes what `tasks.md` delivers | soft-flag |

**For each entry.** Present 2–3 candidate structural mutations. **Run `/grill-me` on the choice — mandatory.** Walk one branch at a time. Apply only after explicit user ack.

**Allowed mutations (structural only):**

| Mutation | Shape |
|---|---|
| Split `[!]` task into N bare tasks | Drop original ID; new IDs at next free `T-NNN`. |
| Insert new bare `[ ]` task at position M | New ID at next free `T-NNN`. |
| Reorder `[ ]` tasks | No ID changes. Never touch `[~]`/`[x]`/`[!]`. |
| Delete redundant `[ ]` task | Never `[~]`, `[x]`, or `[!]`. |
| Update context line on `[ ]` task | One line under the task title. |
| Strip stale `**Tests**` block | Reverts task to bare `[ ]`. |

**Forbidden:**

- Rewriting Gherkin bullets — that's `/al-refine`.
- Rewriting `architecture.md` — that's `/al-design`.
- Editing the `## Goal` paragraph in place — recommend `/al-design` re-run for goal drift.
- Editing `CONTEXT.md` or `docs/adr/` — those are owned by `/al-grill-adr` and `/al-design`.
- Touching `[x]` tasks. Ever.

**False halt.** If the user vetoes the trigger after grilling, rewrite the Notes line as `**Replan** trigger #N: resolved — false halt: <reason>` and restore the prior status marker. Never silent un-flag.

**No cap on replans per session.** Long grills are the point.

## Out-of-scope rejection knowledge base

When grilling vetoes a scope item — a feature, an enhancement, a design alternative — record it under `.out-of-scope/<concept>.md` at repo root so future replans don't re-litigate the same idea.

**When to write:** the user has clearly rejected a recurring or recognisable scope item with a substantive reason. Not every "not now" — only rejections that would otherwise resurface across features.

**On first need:** materialise from `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` into `.out-of-scope/<concept>.md`. `<concept>` is a short kebab-case name describing the rejected idea (e.g. `multi-currency-rounding`, `auto-create-customers`).

**On a matching pre-existing rejection:** append the new request to the file's *Prior requests* list. Don't open a duplicate.

**Discipline:**
- Reasons must be substantive — project scope, technical constraint, strategic decision, referenced ADR. Skip ephemeral reasons.
- One file per concept, not per request — group related rejections.
- During replan and grilling, scan `.out-of-scope/` first; if a new request matches, surface the prior rejection and ask whether the user still feels the same way.

## Composition

- `/grill-me` whenever intent is ambiguous or the next step isn't obvious from current state. Walk one branch at a time.
- `/al-research` when answering BC questions inside the steering session.
- `/al-grill-adr` when fuzzy term or hidden trade-off surfaces in a steered conversation.

## Out of scope

- No code edits.
- No mutation runs.
- No `/al-build` invocations.
- No silent `tasks.md` restructuring.
- No Gherkin or architecture rewrites — that's `/al-refine` and `/al-design`.
- No in-place rewrite of the `## Goal` paragraph — recommend `/al-design` re-run for goal drift.
- No edits to `CONTEXT.md` or `docs/adr/` — those belong to `/al-grill-adr` and `/al-design`.
- No touching `[x]` tasks. Ever.
- No forcing a handoff. Some sessions legitimately end with clarity, not action.
