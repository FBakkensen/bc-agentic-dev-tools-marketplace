---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev, reads tasks.html, the goal, the codebase, and recent commits, then names what's next, what's blocked, what's drifting, and owns the .out-of-scope/ rejection knowledge base. Use when uncertain about the next step, planning a session, asking "where are we?", or clearing the replan queue.
---

# /al-steer, Coach / navigator

Read `tasks.html`, `architecture.html`, `event-model.html` when present, the goal, the codebase, recent commits, and `.out-of-scope/`. Name what's next, what's blocked, what's drifting. Name the next handoff; never force one. Canonical replan venue. Owner of `.out-of-scope/`.

The user invokes `/al-steer` in natural language ("where are we?", "what's next?", "clear the replan queue", "T-007 is blocked, walk me through it", "split T-009 into three tasks"). Interpret and act.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend features).
- Spec folder `specs/<branch>/` holds `tasks.html`. If missing but `architecture.html` is present, **Stop** and run `/al-scope`. If `architecture.html` is also missing, **Stop** and run `/al-design` (or `/al-event-model` first for user/API-facing features).
- Legacy markdown spec (`tasks.md` without `tasks.html`): frozen. Surface the choice to the user before touching anything.

## Power model

You read anything in the workspace. You write `tasks.html` structurally, only after explicit user ack; silent restructuring is the anti-pattern that loses the audit trail. You write `.out-of-scope/<concept>.md` when a substantive rejection earns durable memory. Everything else is Out of scope.

## Disciplines

### Read first, then name

Read `tasks.html`, scan `architecture.html`, `event-model.html` when present, recent commits, and `.out-of-scope/` before opening your mouth. **Why**: the agent's job is to surface what the state already says, not to invent a narrative. Coaching from stale memory is the failure mode that drove the user here.

### Surface what needs attention in BC vocabulary

Name the entries that need a decision. Severity, ID, the symptom in the codebase's terms (object names, table fields, codeunit calls), one line per entry. **Why**: the user is scanning, not slow-reading; prose paragraphs and generic CRUD words bury the seam. Let the user pick which entry to walk.

### Route to the next skill, do not perform it

`/al-steer` names the handoff and stops. The downstream skill owns the work. **Why**: doing the next skill's work inside this one collapses the boundary the pipeline depends on. If the user is uncertain which way to jump, run `/grill-me` on the branch; if they have clarity, no handoff is needed.

### Seven replan triggers as named patterns

The pipeline names seven triggers. They are patterns the agent learns to recognise, not a checklist the agent walks:

| # | Name | Pattern |
|---|---|---|
| 1 | Task too big | One task balloons past a session, or its scenarios cluster around two distinct subjects. |
| 2 | Hidden pre-req | A referenced table, codeunit, permission, or behaviour has no task covering it. |
| 3 | Wrong order | A task's scenarios reference behaviour a later task introduces. |
| 4 | Sibling now wrong | The current task invalidates another task's context or scenarios. |
| 5 | New behaviour emerges | A surfaced code path needs its own test, not a bullet appended to an existing scenario. |
| 6 | Architecture decomposition wrong | R → P → W cuts across tasks, or `architecture.html` itself no longer matches reality. |
| 7 | Goal drift | The Goal slot no longer describes what `tasks.html` delivers. |

**Why**: the names exist so other skills can flag triggers consistently (`**Replan flag**: trigger #N`) and so the user can speak the same language. The numbering is an ID, not a state. The trigger's job is to tell you what kind of mismatch surfaced; the response is your call per situation.

### Trigger response is intent, not mechanics

When a trigger means the plan is invalid for the task, halt the task by flipping `data-status="blocked"` and recording the trigger ID and reason inside the task block (shape per your call). When a trigger means new information surfaced that does not invalidate the plan, leave the status alone and note the trigger inside the task block. The choice is judgement, not a lookup. **Why**: hard-halt and soft-flag as fixed enforcement mechanics turn replan into form-filling; expressing the intent ("does this invalidate the plan?") keeps the judgement where it belongs.

### Mutations come from the trigger, not a menu

Name candidate mutations that match what the trigger surfaced. Splitting, inserting, reordering, deleting, rewriting a description, stripping a stale Tests slot are all in scope; pick what the situation needs. Run `/grill-me` on non-trivial choices. Apply only after explicit ack. **Why**: a prescribed mutation menu is the same anti-pattern as a prescribed checklist; the trigger says what shape is wrong, and the response shape varies with the codebase, not with a template.

### False halt closes the loop

If grilling vetoes the trigger, restore the prior `data-status` and rewrite the alert body to record the resolution. **Why**: silent un-flag loses the reasoning, and the gate scanner can't see what changed.

### Owns `.out-of-scope/` as the rejection knowledge base

When grilling vetoes a recurring scope item with a substantive reason (project scope, technical constraint, strategic decision, referenced ADR; not a deferral), record it at `.out-of-scope/<concept>.md`. Scan `.out-of-scope/*.md` during replan and grilling; on a match, surface the prior rejection in the user's words. **Why**: the file's job is to stop the next session from re-litigating the same rejection. The template at `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` materialises into `.out-of-scope/<concept>.md` on first need; matches append a *Prior requests* entry rather than spawning a second file.

## Floor

`tasks.html` carries one surgical-edit contract: maintaining skills find a task by ID and flip its status. Two attributes hold the floor.

- `data-task="T-NNN"` on the task `<details>`. `T-NNN` is monotonic, never reused, starts at `T-001`. Anchor `id="t-nnn"` matches.
- `data-status="ready | in-progress | done | blocked"` on the same `<details>`. `/al-steer` flips status (typically to `blocked` on hard-halt, back to a prior value on false halt) and clears the replan queue.

Everything else (how status renders, where alerts sit, how the Mermaid task-deps graph or Summary table get re-rendered after a mutation) is your call. The graph lives inside `<div class="mermaid" data-graph="task-deps">` as plain Mermaid text when it earns its place; treat the body as text on edit, let the CDN library re-parse on reload.

**Names are the citation.** No inline `(see: file.al:120)` annotations in `tasks.html`, `.out-of-scope/`, or anything else durable. Future readers grep; the IDE gives line numbers for free.

**Map, not memoir.** Surface state and decisions; do not log how you arrived.

## Lazy reference reads

| Source (read-only) | Target (writable) | Trigger |
|---|---|---|
| `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` | (read, not materialised) | before writing prose to `tasks.html` or `.out-of-scope/` |
| `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md` | (read, not materialised) | before writing inside a task block or escalating to a durable destination |
| `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` | (read, not materialised) | before editing `tasks.html` structure |
| `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` | `.out-of-scope/<concept>.md` | on first rejection write per concept |

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Tests.** Short PascalCase scenario name (`PostSalesOrderWithBlockedCustomer`), match BaseApp style.

Full architectural vocabulary in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`.

## Composition

- `/grill-me`, whenever intent is ambiguous or a mutation isn't obviously right.
- `/al-grill-adr`, when a fuzzy term or hidden trade-off surfaces.
- `/al-event-model`, when a user-facing or API-facing fact (Role, Action, Business Event, View, Status) surfaced downstream invalidates the timeline; route here for reshape.
- `/al-design` and `/al-scope`, when architecture or task list needs to exist or reshape.
- `/al-refine`, `/al-implement`, `/al-refactor`, `/al-mutate`, the in-flight skills you route to.
- `/al-research` and `/bc-standard-reference`, for BC behaviour questions mid-session.
- Replan-check gates in `/al-refine`, `/al-implement`, `/al-refactor` route here.

## Out of scope

- No code edits, no `/al-build`, no mutation runs.
- No silent `tasks.html` restructuring; explicit user ack always.
- No Gherkin rewrites (`/al-refine`), no architecture rewrites (`/al-design`), no event-model rewrites (`/al-event-model`), no in-place Goal edits.
- No edits to `CONTEXT.md` or `docs/adr/`. No touching `data-status="done"`. No forcing a handoff.
- No markdown-mode output. Legacy markdown specs are frozen.
