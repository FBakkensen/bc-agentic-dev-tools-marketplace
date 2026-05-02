---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev — reads tasks.md, the goal, the codebase, and recent commits, then names what's next, what's blocked, what's drifting, and owns the .out-of-scope/ rejection knowledge base. Use when uncertain about the next step, planning a session, asking "where are we?", or clearing the replan queue.
---

# /al-steer — Coach / navigator

Read `tasks.md`, `architecture.md`, the goal, the codebase, and recent commits. Name what's next, what's blocked, what's drifting. Run `/grill-me` when intent is unclear. Recommend a handoff — never force one. Canonical replan venue. Owner of `.out-of-scope/`.

**Resolve `tasks.md`:** branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise `Stop.` — run `/al-design` first.

## Reference docs

- [references/out-of-scope.template.md](references/out-of-scope.template.md) — `.out-of-scope/` knowledge base format

## Power model

- **Read** anything: workspace, `tasks.md`, `architecture.md`, `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`.
- **Write `tasks.md`** structurally — only after explicit user ack. Never silent.
- **Write `.out-of-scope/<concept>.md`** when grilling vetoes a recurring scope item with a substantive reason.
- **Cannot edit code.** Cannot edit `architecture.md` in place — recommend `/al-design` re-run. Cannot edit `CONTEXT.md` or `docs/adr/` — owned by `/al-grill-adr` and `/al-design`. Never touch `[x]` tasks.

Status markers in `tasks.md`: `[ ]` ready, `[~]` in progress, `[x]` done, `[!]` blocked. `T-NNN` IDs are monotonic and never reused.

## Invocation

The user invokes `/al-steer` and describes what they want in natural language. Interpret and act. Examples:

- "Where are we?"
- "What's next?"
- "Clear the replan queue"
- "T-007 is `[!]` — walk me through it"
- "Mark T-009 as soft-flagged for goal drift"

## Show what needs attention

Read `tasks.md`, scan `architecture.md` and recent commits. Present three buckets, severity then ID:

1. **Hard halts** — `[!]` tasks. Replan required before work resumes.
2. **Soft flags** — `**Replan** trigger #N: <reason>` Notes lines on `[ ]` / `[~]` tasks.
3. **Drift signals** — `## Goal` no longer matches `tasks.md`; `architecture.md` module map diverges from code shape; broken `Depends-on`; redundancy; gaps; open-question Notes.

One line per entry — task ID, severity tag, the symptom in BC vocabulary. Let the user pick.

| | Entry |
|---|---|
| _Avoid_: | T-007 is currently blocked because the refactor uncovered that the install codeunit needs a permission set entry, and we should probably also revisit T-009's scenarios since they may overlap |
| Use: | `T-007 [!] trigger #2: install codeunit needs permission set entry — no covering task` |

## Identify state and recommend (situation → action)

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

Other skills (`/al-refine`, `/al-implement`, `/al-refactor`) hit a **Replan check (gate)** and either set the task `[!]` (hard-halt) or append a `**Replan** trigger #N: <reason>` Notes line (soft-flag). `/al-steer` clears the queue.

1. **Read the queue.** Scan `tasks.md` for `[!]` and `**Replan**` Notes. Order by trigger severity, then task ID. Read `.out-of-scope/*.md` and surface any prior rejection that resembles the entry.

2. **Name the trigger.** Cite the number every time.

   | # | Trigger | Symptom | Response |
   |---|---|---|---|
   | 1 | Task too big | `>5` scenarios after refinement, or scenarios cluster around two distinct subjects | soft-flag |
   | 2 | Hidden pre-req | Referenced table/codeunit/permission has no task | hard-halt |
   | 3 | Wrong order | Gherkin references behaviour a later task introduces | hard-halt |
   | 4 | Sibling now wrong | Current task invalidates another's context line or scenarios | hard-halt |
   | 5 | New behaviour emerges | Code path needs its own test, not a bullet-extension | soft-flag |
   | 6 | Architecture decomposition wrong | R → P → W cuts across tasks, or `architecture.md` itself is wrong | hard-halt |
   | 7 | Goal drift | `## Goal` no longer describes what `tasks.md` delivers | soft-flag |

   _Avoid_ mismatched markers — `[!]` not `[?]`, never `[ ]`-with-Notes when the trigger is a hard-halt. Mismatched markers fool the gate scanner.

3. **Recommend mutations.** Present 2–3 candidate structural mutations for the entry. Run `/grill-me` on the choice — mandatory. Walk one branch at a time. Apply only after explicit ack.

4. **Apply the outcome:**

   | Mutation | Shape |
   |---|---|
   | Split `[!]` task into N bare tasks | Drop original ID; new IDs at next free `T-NNN`. |
   | Insert new bare `[ ]` task at position M | New ID at next free `T-NNN`. |
   | Reorder `[ ]` tasks | No ID changes. Never touch `[~]` / `[x]` / `[!]`. |
   | Delete redundant `[ ]` task | Never `[~]`, `[x]`, or `[!]`. |
   | Update context line on `[ ]` task | One line under the task title. |
   | Strip stale `**Tests**` block | Reverts task to bare `[ ]`. |

   Forbidden: rewriting Gherkin (`/al-refine`); rewriting `architecture.md` (`/al-design`); editing `## Goal` in place (recommend `/al-design` re-run); editing `CONTEXT.md` or `docs/adr/`; touching `[x]`.

5. **False halt.** User vetoes the trigger after grilling → rewrite the Notes line as `**Replan** trigger #N: resolved — false halt: <reason>` and restore the prior status marker. Never silent un-flag.

No cap on replans per session. Long grills are the point.

**Anti-pattern: silent task restructure.** Splitting, reordering, or deleting tasks without naming the trigger and getting explicit ack. The replan record is the audit trail; bypassing it loses the reasoning and the gate scanner can't see what changed.

## Quick state override

If the user says "split T-007 into three bare tasks" or "delete T-012, redundant", trust them and apply the mutation directly. Confirm what you're about to do (which IDs, which positions, which Notes lines), then act. Skip grilling. If the override touches a `[!]` task, ask whether the **Replan** Notes line should be cleared too.

## Out-of-scope rejection knowledge base

Grilling vetoes a recurring scope item with a substantive reason → record at `.out-of-scope/<concept>.md` so future replans don't re-litigate.

- **When to write** — user rejected a recurring scope item with a substantive reason (project scope, technical constraint, strategic decision, referenced ADR). Not every "not now".
- **First need** — materialise from `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` into `.out-of-scope/<concept>.md`. `<concept>` is short kebab-case (`multi-currency-rounding`, `auto-create-customers`).
- **Match on existing** — append the new request to the *Prior requests* list. One file per concept, not per request.
- **Scan first** during replan and grilling; on a match, surface the prior rejection: "This is similar to `.out-of-scope/<concept>.md` — we rejected this before because <reason>. Do you still feel the same way?"

The user may **confirm** (append the new request and move on), **reconsider** (delete or update the file, proceed with normal replan), or **disagree** (related but distinct, proceed).

## Composition

- `/grill-me` whenever intent is ambiguous or the next step isn't obvious. One branch at a time.
- `/al-research` for BC questions mid-session; `/bc-standard-reference` when purely BaseApp.
- `/al-grill-adr` when a fuzzy term or hidden trade-off surfaces.
- Replan-check gates in `/al-refine`, `/al-implement`, `/al-refactor` route here.

## Out of scope

- No code edits, no mutation runs, no `/al-build`. No silent `tasks.md` restructuring.
- No Gherkin or architecture rewrites — `/al-refine` and `/al-design`. No in-place `## Goal` rewrite — `/al-design` re-run.
- No edits to `CONTEXT.md` or `docs/adr/`. No touching `[x]`. No forcing a handoff.
