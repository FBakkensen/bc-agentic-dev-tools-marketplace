---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev — reads tasks.md, the goal, the codebase, and recent commits, then names what's next, what's blocked, what's drifting, and owns the .out-of-scope/ rejection knowledge base. Use when uncertain about the next step, planning a session, asking "where are we?", or clearing the replan queue.
---

# /al-steer — Coach / navigator

Read `tasks.md`, `architecture.md`, the goal, the codebase, and recent commits. Tell the user what's next, what's blocked, what's drifting. Run `/grill-me` when intent is unclear. Recommend a handoff — never force one. Canonical replan venue. Owner of `.out-of-scope/`.

All output is telegraphic — BC vocabulary, structured facts, no prose.

**Resolve `tasks.md`:** branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise `Stop.` — run `/al-design` first.

## Power model

- **Read** anything: workspace, `tasks.md`, `architecture.md`, `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`.
- **Write `tasks.md`** structurally — split, insert, reorder, delete `[ ]` tasks; update context lines; strip stale `**Tests**` blocks. Only after explicit user ack. Never silent. Never Gherkin. Telegraphic.
- **Write `.out-of-scope/<concept>.md`** when grilling vetoes a recurring scope item.
- **Cannot edit code.** Cannot edit `architecture.md` in place — recommend `/al-design` re-run. Cannot edit `CONTEXT.md` or `docs/adr/` — owned by `/al-grill-adr` and `/al-design`. Never touch `[x]` tasks.
- **Default scope:** current task, current code. Beyond requires explicit instruction + ack.
- Push back or run `/grill-me` when the request looks off-target.

## Identify state

Ready `[ ]` vs stalled `[~]`. Blocked `[!]` and `**Replan**` Notes lines — that's the queue. Goal drift (does `## Goal` still describe `tasks.md`?). Architecture drift (does `architecture.md`'s module map still describe the code?). Open-question Notes. Broken `Depends-on`, redundancy, gaps.

## Recommend (situation → action)

| Situation | Action |
|---|---|
| No `tasks.md` / new feature | `/al-grill-adr` then `/al-design` |
| `architecture.md` exists, no `tasks.md` | `/al-scope` |
| Task is `[!]` or `**Replan**` Notes line present | Replan flow (below) |
| `## Goal` no longer describes `tasks.md` | `/al-design` re-run |
| Code shape diverges from `architecture.md` | `/al-design` re-run |
| Term fuzzy or contested | `/al-grill-adr` |
| Task exists, no Gherkin | `/al-refine <T-NNN>` |
| Gherkin present, architecture present | `/al-implement <T-NNN>` |
| Code lacks coverage | `/al-mutate <area>` |
| Code shape wrong, tests green | `/al-refactor <area>` |
| "How does X work in BC?" | `/al-research <topic>` (or `/bc-standard-reference` for pure BaseApp) |
| User uncertain | `/grill-me`, then recommend |
| User has clarity | No handoff |

## Replan flow

Other skills (`/al-refine`, `/al-implement`, `/al-refactor`) hit the **Replan check (gate)** and either set the task `[!]` (hard-halt) or append a `**Replan** trigger #N: <reason>` Notes line (soft-flag). `/al-steer` clears the queue.

**Read the queue.** Scan `tasks.md` for `[!]` and `**Replan**` Notes. Order by trigger severity, then task ID.

**The seven triggers — name them this way every time:**

| # | Trigger | Symptom | Response |
|---|---|---|---|
| 1 | Task too big | `>5` scenarios after refinement, or scenarios cluster around two distinct subjects | soft-flag |
| 2 | Hidden pre-req | Referenced table/codeunit/permission has no task | hard-halt |
| 3 | Wrong order | Gherkin references behavior a later task introduces | hard-halt |
| 4 | Sibling now wrong | Current task invalidates another's context line or scenarios | hard-halt |
| 5 | New behavior emerges | Code path needs its own test, not a bullet-extension | soft-flag |
| 6 | Architecture decomposition wrong | R → P → W cuts across tasks, or `architecture.md` itself is wrong | hard-halt |
| 7 | Goal drift | `## Goal` no longer describes what `tasks.md` delivers | soft-flag |

**Per entry.** Present 2–3 candidate structural mutations. Telegraphic. Run `/grill-me` on the choice — mandatory. Walk one branch at a time. Apply only after explicit ack.

**Allowed structural mutations:**

| Mutation | Shape |
|---|---|
| Split `[!]` task into N bare tasks | Drop original ID; new IDs at next free `T-NNN`. |
| Insert new bare `[ ]` task at position M | New ID at next free `T-NNN`. |
| Reorder `[ ]` tasks | No ID changes. Never touch `[~]`/`[x]`/`[!]`. |
| Delete redundant `[ ]` task | Never `[~]`, `[x]`, or `[!]`. |
| Update context line on `[ ]` task | One line under the task title. |
| Strip stale `**Tests**` block | Reverts task to bare `[ ]`. |

**Forbidden.** Rewriting Gherkin (`/al-refine`). Rewriting `architecture.md` (`/al-design`). Editing `## Goal` in place — recommend `/al-design` re-run. Editing `CONTEXT.md` or `docs/adr/`. Touching `[x]`.

**False halt.** User vetoes the trigger after grilling → rewrite the Notes line as `**Replan** trigger #N: resolved — false halt: <reason>` and restore the prior status marker. Never silent un-flag.

**No cap on replans per session.** Long grills are the point.

## Out-of-scope rejection knowledge base

Grilling vetoes a recurring scope item with a substantive reason → record at `.out-of-scope/<concept>.md` so future replans don't re-litigate.

- **When to write** — user rejected a recurring scope item with a substantive reason (project scope, technical constraint, strategic decision, referenced ADR). Not every "not now".
- **First need** — materialise from `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` into `.out-of-scope/<concept>.md`. `<concept>` is short kebab-case (`multi-currency-rounding`, `auto-create-customers`).
- **Match on existing** — append to the *Prior requests* list. One file per concept, not per request.
- **Scan first** during replan and grilling; on a match, surface the prior rejection and ask whether the user still feels the same way.

## Composition

- `/grill-me` whenever intent is ambiguous or the next step isn't obvious. One branch at a time.
- `/al-research` for BC questions mid-session; `/bc-standard-reference` when purely BaseApp.
- `/al-grill-adr` when a fuzzy term or hidden trade-off surfaces.

## Out of scope

- No code edits, no mutation runs, no `/al-build`. No silent `tasks.md` restructuring.
- No Gherkin or architecture rewrites — `/al-refine` and `/al-design`. No in-place `## Goal` rewrite — `/al-design` re-run.
- No edits to `CONTEXT.md` or `docs/adr/`. No touching `[x]`. No forcing a handoff.
