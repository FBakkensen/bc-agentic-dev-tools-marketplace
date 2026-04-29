---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev. Reads tasks.md, the goal, the codebase, and recent commits, then tells the user what's next, what's blocked, and what's drifting. Use when uncertain about the next step, when planning a session, or when asking "where are we?". Recommends a handoff to /al-scope, /al-refine, /al-architect, /al-implement, /al-refactor, /al-mutate, or /al-research — but never forces one.
---

# /al-steer — Coach / navigator

Read `tasks.md`, the goal, the codebase, and recent commits. Tell the user what's next, what's blocked, what's drifting. Run `/grill-me` when intent is unclear. Recommend a handoff — but do not force one.

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-scope` first.

## Power model

- Read anything in the workspace and `tasks.md`.
- Write anything in `tasks.md`, but **only after explicit user acknowledgement**. Never silent.
- **Cannot edit code.**
- **Structural mutations on `tasks.md` allowed during the replan flow** — split, insert, reorder, delete `[ ]` tasks; update context lines; strip stale `**Tests**` or `**Architecture**` blocks. Never writes Gherkin or Architecture content.
- **Default scope:** the current task and the current code. Going beyond (branch state, other repos, external systems) requires explicit user instruction + acknowledgement.
- Push back or run `/grill-me` when the user's request looks off-target.

## Identify state

- Ready tasks (`[ ]`) vs stalled in-progress tasks (`[~]`) across sessions.
- Blocked tasks (`[!]`) and unresolved `**Replan**` Notes lines — these are the replan queue.
- Goal drift — does the goal paragraph still describe what `tasks.md` is delivering?
- Notes lines flagging open questions, blockers, missing scenarios.
- Cross-task issues — broken `Depends-on`, redundancy, gaps.

## Recommend (the menu — pick what fits, never force)

| Situation | Recommend |
|---|---|
| No tasks.md yet / new feature | `/al-scope` |
| Task is `[!]` (replan needed) | `/al-steer` Replan flow |
| Goal drift — `## Goal` no longer describes `tasks.md` | `/al-scope` re-run |
| Task exists but has no Gherkin yet | `/al-refine <T-NNN>` |
| Gherkin done, no Architecture block | `/al-architect <T-NNN>` |
| Implementable task (Gherkin + Architecture present) | `/al-implement <T-NNN>` |
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
| 6 | Architecture decomposition wrong — R→P→W boundary cuts across tasks | hard-halt |
| 7 | Goal drift — `## Goal` no longer describes what `tasks.md` delivers | soft-flag |

**For each entry.** Present 2–3 candidate structural mutations. **Run `/grill-me` on the choice — mandatory.** Walk one branch at a time. Apply only after explicit user ack (existing rule).

**Allowed mutations (structural only):**

| Mutation | Shape |
|---|---|
| Split `[!]` task into N bare tasks | Drop original ID; new IDs at next free `T-NNN`. |
| Insert new bare `[ ]` task at position M | New ID at next free `T-NNN`. |
| Reorder `[ ]` tasks | No ID changes. Never touch `[~]`/`[x]`/`[!]`. |
| Delete redundant `[ ]` task | Never `[~]`, `[x]`, or `[!]`. |
| Update context line on `[ ]` task | One line under the task title. |
| Strip stale `**Tests**` block | Reverts task to bare `[ ]`. |
| Strip stale `**Architecture**` block | Reverts task to bare `[ ]` (if Tests also stripped) or leaves Tests intact. |

**Forbidden:**

- Rewriting Gherkin bullets — that's `/al-refine`.
- Rewriting Architecture block — that's `/al-architect`.
- Editing the `## Goal` paragraph in place — recommend `/al-scope` re-run for goal drift.
- Touching `[x]` tasks. Ever.

**False halt.** If the user vetoes the trigger after grilling, rewrite the Notes line as `**Replan** trigger #N: resolved — false halt: <reason>` and restore the prior status marker. Never silent un-flag.

**No cap on replans per session.** Long grills are the point.

- `/grill-me` whenever intent is ambiguous or the next step isn't obvious from current state. Walk one branch at a time.
- `/al-research` when answering BC questions inside the steering session.

## Out of scope

- No code edits.
- No mutation runs.
- No `/al-build` invocations.
- No silent `tasks.md` restructuring.
- No Gherkin or Architecture rewrites — that's `/al-refine` and `/al-architect`.
- No in-place rewrite of the `## Goal` paragraph — recommend `/al-scope` re-run for goal drift.
- No touching `[x]` tasks. Ever.
- No forcing a handoff. Some sessions legitimately end with clarity, not action.
