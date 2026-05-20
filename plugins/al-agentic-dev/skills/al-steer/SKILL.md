---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev, reads tasks.html, the goal, the codebase, and recent commits, then names what's next, what's blocked, what's drifting, and owns the .out-of-scope/ rejection knowledge base. Use when uncertain about the next step, planning a session, asking "where are we?", or clearing the replan queue.
---

# /al-steer, Coach / navigator

Read `tasks.html`, `architecture.html`, the goal, the codebase, and recent commits. Name what's next, what's blocked, what's drifting. Run `/grill-me` when intent is unclear. Name the next handoff, never force one. Canonical replan venue. Owner of `.out-of-scope/`.

**Resolve `tasks.html`:** branch matches `^\d{3}-` → `specs/<branch>/tasks.html`. Otherwise `Stop.`, run `/al-design` first. Legacy markdown spec (`tasks.md` without `tasks.html`) → frozen; surface the choice to the user before touching anything.

Read before writing:
- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`, voice rules for the prose itself; applies to both `tasks.html` and `.out-of-scope/`.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md`, `tasks.html` Notes-line trigger test, valid shapes, escalation routing. Does not apply to `.out-of-scope/`.
- `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md`, data-attribute contract and surgical-edit discipline.

## Reference docs

- [references/out-of-scope.template.md](references/out-of-scope.template.md), `.out-of-scope/` knowledge base format

## Power model

- **Read** anything: workspace, `tasks.html`, `architecture.html`, `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`.
- **Write `tasks.html`** structurally, only after explicit user ack. Never silent.
- **Write `.out-of-scope/<concept>.md`** when grilling vetoes a recurring scope item with a substantive reason.
- **Cannot edit code.** Cannot edit `architecture.html` in place; run `/al-design` again. Cannot edit `CONTEXT.md` or `docs/adr/`; owned by `/al-grill-adr` and `/al-design`. Never touch tasks at `data-status="done"`.

Status values on `data-status`: `ready`, `in-progress`, `done`, `blocked`. `T-NNN` IDs are monotonic and never reused.

## Invocation

The user invokes `/al-steer` and describes what they want in natural language. Interpret and act. Examples:

- "Where are we?"
- "What's next?"
- "Clear the replan queue"
- "T-007 is blocked, walk me through it"
- "Mark T-009 as soft-flagged for goal drift"

## Show what needs attention

Read `tasks.html`, scan `architecture.html` and recent commits. Present three buckets, severity then ID:

1. **Hard halts**: tasks with `data-status="blocked"`. Replan required before work resumes.
2. **Soft flags**: tasks whose body carries an `<aside data-alert="important">` containing `**Replan flag**: trigger #N` and whose `data-status` is still `ready` or `in-progress`.
3. **Drift signals**: Goal slot no longer matches `tasks.html`; `architecture.html` module map diverges from code shape; broken `Depends on:` reference to a non-existent task; redundancy; gaps; open-question Notes entries.

One line per entry: task ID, severity tag, the symptom in BC vocabulary. Let the user pick.

| | Entry |
|---|---|
| _Avoid_: | T-007 is currently blocked because the refactor uncovered that the install codeunit needs a permission set entry, and we should probably also revisit T-009's scenarios since they may overlap |
| Use: | `T-007 blocked, trigger #2: install codeunit needs permission set entry, no covering task` |

## Identify state and route (situation → action)

| Situation | Action |
|---|---|
| No `tasks.html` / new feature | `/al-grill-adr` then `/al-design` |
| `architecture.html` exists, no `tasks.html` | `/al-scope` |
| Task `data-status="blocked"` or task body carries an IMPORTANT replan-flag alert | Replan flow (below) |
| Goal slot no longer describes `tasks.html` | `/al-design` re-run |
| Code shape diverges from `architecture.html` | `/al-design` re-run |
| Term fuzzy or contested | `/al-grill-adr` |
| Task exists, Tests slot empty | `/al-refine <T-NNN>` |
| Gherkin present, architecture present | `/al-implement <T-NNN>` |
| Code lacks coverage | `/al-mutate <area>` |
| Code shape wrong, tests green | `/al-refactor <area>` |
| "How does X work in BC?" | `/al-research <topic>` (or `/bc-standard-reference` for pure BaseApp) |
| User uncertain | `/grill-me`, then route |
| User has clarity | No handoff |

## Replan flow

Other skills (`/al-refine`, `/al-implement`, `/al-refactor`) hit a **Replan check (gate)** and either flip the task's `data-status` to `blocked` and add an IMPORTANT alert (hard-halt) or add an IMPORTANT alert while keeping the existing status (soft-flag). `/al-steer` clears the queue.

1. **Read the queue.** Scan `tasks.html` for `data-status="blocked"` and `<aside data-alert="important">` elements containing `**Replan flag**`. Order by trigger severity, then task ID. Read `.out-of-scope/*.md` and surface any prior rejection that resembles the entry.

2. **Name the trigger.** Cite the number every time. Canonical names and modes: see `notes-discipline.md` *Replan triggers*. Per-skill symptoms (queue-triage perspective):

   | # | Trigger | Symptom |
   |---|---|---|
   | 1 | Task too big | `>5` scenarios after refinement, or scenarios cluster around two distinct subjects |
   | 2 | Hidden pre-req | Referenced table/codeunit/permission has no task |
   | 3 | Wrong order | Gherkin references behaviour a later task introduces |
   | 4 | Sibling now wrong | Current task invalidates another's context line or scenarios |
   | 5 | New behaviour emerges | Code path needs its own test, not a bullet-extension |
   | 6 | Architecture decomposition wrong | R → P → W cuts across tasks, or `architecture.html` itself is wrong |
   | 7 | Goal drift | Goal slot no longer describes what `tasks.html` delivers |

   _Avoid_ mismatched status. A hard-halt task must carry `data-status="blocked"`. Never leave a hard-halt at `ready` or `in-progress` while the IMPORTANT alert is present; mismatched state fools the gate scanner.

3. **Name candidate mutations.** Present 2–3 candidate structural mutations for the entry. Run `/grill-me` on the choice, mandatory. Walk one branch at a time. Apply only after explicit ack.

4. **Apply the outcome:**

   | Mutation | Shape |
   |---|---|
   | Split blocked task into N bare tasks | Drop original ID; new IDs at next free `T-NNN`. Write each as a fresh `<details data-task="T-NNN" data-status="ready">` block with edges, description paragraph, empty `data-section="tests"` slot. Regenerate the Mermaid task-deps graph (inside `<div class="mermaid" data-graph="task-deps">`) and Summary table. |
   | Insert new bare task at position M | New ID at next free `T-NNN`. Same block shape as above. Assign to an existing subgraph phase, or add a new phase label if none fits (Edit inside the `data-graph="task-deps"` div). Regenerate the graph and Summary. |
   | Reorder ready tasks | No ID changes. Never touch `data-status` of `in-progress`, `done`, or `blocked` tasks. Regenerate the Summary table (graph edges follow the declared lines and do not change with reorder). |
   | Delete redundant ready task | Delete the whole `<details data-task="T-NNN">` block. Update any `Depends on:` / `Refactors:` / `Fixes:` lines on other tasks that point at the deleted ID. Never delete `in-progress`, `done`, or `blocked` tasks. Regenerate graph and Summary. |
   | Update description paragraph on ready task | Replace the description paragraph inside the block. Chips / alerts / edge content above stay. |
   | Strip stale Tests slot | Empty the `data-section="tests"` slot; flip `data-status` back to `ready` if it was `in-progress`; regenerate the Summary Tests cell. |

   Forbidden: rewriting Gherkin (`/al-refine`); rewriting `architecture.html` (`/al-design`); editing the Goal slot in place (run `/al-design` again); editing `CONTEXT.md` or `docs/adr/`; touching `data-status="done"`.

5. **False halt.** User vetoes the trigger after grilling → rewrite the IMPORTANT alert body as `**Replan flag**: trigger #N, resolved (false halt): <reason>.` and restore the prior `data-status` value. Regenerate the Summary row. Never silent un-flag.

No cap on replans per session. Long grills are the point.

**Anti-pattern: silent task restructure.** Splitting, reordering, or deleting tasks without naming the trigger and getting explicit ack. The replan record is the audit trail; bypassing it loses the reasoning and the gate scanner can't see what changed.

## Quick state override

If the user says "split T-007 into three bare tasks" or "delete T-012, redundant", trust them and apply the mutation directly. Confirm what you are about to do (which IDs, which positions, which alerts, which edge lines), then act. Skip grilling. If the override touches a blocked task, ask whether the IMPORTANT replan-flag alert should be cleared too.

## Mermaid graph maintenance

The task-dependency graph lives in `<div class="mermaid" data-graph="task-deps">` near the top of `tasks.html`. The body is plain Mermaid text inside the div; treat it as text, not as HTML, when editing.

- **Adding a phase**: Edit anchored on the closing `</div>` of the `data-graph="task-deps"` block. Insert a new `subgraph "Phase Label" ... end` block before the closing div, between the existing subgraphs in the appropriate position.
- **Adding a task node to an existing phase**: Edit anchored on the `subgraph "Phase Label"` opening line. Insert the new `TNNN[T-NNN short label]` line after the opening.
- **Adding an edge**: Edit anchored on the existing edges section (after all subgraphs, before the closing `</div>`). Append the new edge line.
- **Removing a task**: Delete its node line and any edges referencing it.

Re-render is implicit when the page is reloaded; the CDN library re-parses the div content on every page load.

## Out-of-scope rejection knowledge base

Grilling vetoes a recurring scope item with a substantive reason → record at `.out-of-scope/<concept>.md` so future replans don't re-litigate.

- **When to write**: user rejected a recurring scope item with a substantive reason (project scope, technical constraint, strategic decision, referenced ADR). Not every "not now".
- **First need**: materialise from `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` into `.out-of-scope/<concept>.md`. `<concept>` is short kebab-case (`multi-currency-rounding`, `auto-create-customers`).
- **Match on existing**: append the new request to the *Prior requests* list. One file per concept, not per request.
- **Scan first** during replan and grilling; on a match, surface the prior rejection: "This is similar to `.out-of-scope/<concept>.md`, we rejected this before because <reason>. Do you still feel the same way?"

The user may **confirm** (append the new request and move on), **reconsider** (delete or update the file, proceed with normal replan), or **disagree** (related but distinct, proceed).

## Composition

- `/grill-me` whenever intent is ambiguous or the next step isn't obvious. One branch at a time.
- `/al-research` for BC questions mid-session; `/bc-standard-reference` when purely BaseApp.
- `/al-grill-adr` when a fuzzy term or hidden trade-off surfaces.
- Replan-check gates in `/al-refine`, `/al-implement`, `/al-refactor` route here.

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `voice-contract.md`, voice rules for prose.
- `notes-discipline.md`, destination map for chips, alerts, Notes lines.
- `html-spec-discipline.md`, data-attribute contract and surgical-edit discipline.

## Out of scope

- No code edits, no mutation runs, no `/al-build`. No silent `tasks.html` restructuring.
- No Gherkin or architecture rewrites; `/al-refine` and `/al-design`. No in-place Goal rewrite; `/al-design` re-run.
- No edits to `CONTEXT.md` or `docs/adr/`. No touching `data-status="done"`. No forcing a handoff.
