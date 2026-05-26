---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev. Reads tasks.html, the goal, the codebase, and recent commits, names what is next or blocked or drifting, owns .out-of-scope/, and is the canonical replan venue.
---

# /al-steer, Coach / navigator

Read `tasks.html`, `architecture.html`, `event-model.html` when present, the goal, the codebase, recent commits, and `.out-of-scope/`. Name what's next, what's blocked, what's drifting. Name the next handoff; never force one. Canonical replan venue. Owner of `.out-of-scope/`.

The user invokes `/al-steer` in natural language ("where are we?", "what's next?", "clear the replan queue", "T-007 is blocked, walk me through it", "split T-009 into three tasks"). Interpret and act.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend features).
- Spec folder `specs/<branch>/` holds `tasks.html`. If missing but `architecture.html` is present, **Stop** and run `/al-scope`. If `architecture.html` is also missing, **Stop** and run `/al-design` (or `/al-event-model` first for user/API-facing features).
- Legacy markdown spec (`tasks.md` without `tasks.html`): frozen. Surface the choice to the user before touching anything.

## Power model

Read anything in the workspace. Write `tasks.html` structurally, only after explicit user ack; silent restructuring is the anti-pattern that loses the audit trail. Write `.out-of-scope/<concept>.md` when a substantive rejection earns durable memory. Nothing else.

## Read first, then name

Read `tasks.html`, scan `architecture.html`, `event-model.html` when present, recent commits, and `.out-of-scope/` before opening your mouth. Surface what the state already says; coaching from stale memory is the failure mode that drove the user here. Name the entries that need a decision: severity, ID, the symptom in the codebase's terms (object names, table fields, codeunit calls), one line per entry. Distinguish kinds explicitly: a verify task (`data-kind="verify"`) ready or blocked is a user-verification gate, not a TDD cycle; name it as such (*"slice `release-sales-order` is ready for user verification"*, *"slice `approve-override` verify is blocked, scenario `#3 Boundary` failed at step 4"*) so the user picks the right next skill. Prose paragraphs and generic CRUD words bury the seam; let the user pick which entry to walk. See [voice-contract.md](../../references/voice-contract.md) for prose voice.

## Route to the next skill, do not perform it

`/al-steer` names the handoff and stops. The downstream skill owns the work; doing the next skill's work inside this one collapses the boundary the pipeline depends on. If the user is uncertain which way to jump, run `/grill-me` on the branch; if they have clarity, no handoff is needed.

## Eight replan triggers

Patterns the agent learns to recognise, not a checklist to walk. Other skills flag triggers as `**Replan flag**: trigger #N`; the numbering is an ID, not a state.

| # | Name | Pattern |
|---|---|---|
| 1 | Task too big | One task balloons past a session, or its scenarios cluster around two distinct subjects. |
| 2 | Hidden pre-req | A referenced table, codeunit, permission, or behaviour has no task covering it. |
| 3 | Wrong order | A task's scenarios reference behaviour a later task introduces. |
| 4 | Sibling now wrong | The current task invalidates another task's context or scenarios. |
| 5 | New behaviour emerges | A surfaced code path needs its own test, not a bullet appended to an existing scenario. |
| 6 | Architecture decomposition wrong | R → P → W cuts across tasks, or `architecture.html` itself no longer matches reality. |
| 7 | Goal drift | The Goal slot no longer describes what `tasks.html` delivers. |
| 8 | Verification failed | A user-facing scenario in `/al-user-verification` does not match observed behaviour. Judgement call between defect (insert a `Fixes:` task), wrong scenario (rewrite via `/al-refine`), or wrong slice boundary (split via `/al-scope`). |

## Trigger response is intent, not mechanics

When a trigger means the plan is invalid for the task, halt by flipping `data-status="blocked"` and recording the trigger ID and reason inside the task block. When a trigger means new information surfaced that does not invalidate the plan, leave the status alone and note the trigger inside the task block. The choice is judgement; fixed enforcement mechanics turn replan into form-filling.

## Mutations come from the trigger, not a menu

Name candidate mutations that match what the trigger surfaced. Splitting, inserting, reordering, deleting, rewriting a description, stripping a stale Tests slot are all in scope; pick what the situation needs. Run `/grill-me` on non-trivial choices. Apply only after explicit ack. A prescribed mutation menu is the same anti-pattern as a prescribed checklist; the trigger says what shape is wrong, the response shape varies with the codebase.

## False halt closes the loop

If grilling vetoes the trigger, restore the prior `data-status` and rewrite the alert body to record the resolution. Silent un-flag loses the reasoning, and the gate scanner can't see what changed.

## Owns `.out-of-scope/`

When grilling vetoes a recurring scope item with a substantive reason (project scope, technical constraint, strategic decision, referenced ADR; not a deferral), record it at `.out-of-scope/<concept>.md`. Scan `.out-of-scope/*.md` during replan and grilling; on a match, surface the prior rejection in the user's words. The file's job is to stop the next session from re-litigating the same rejection. Template `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` materialises on first need; matches append a *Prior requests* entry rather than spawning a second file.

## Composition

| | |
|---|---|
| **Invoked from**     | any SKILL on replan trigger, or by user for "where are we" |
| **Routes to**        | `/al-design` (architecture-decomposition trigger), `/al-refine` (scenario gap), `/al-implement` (next ready technical task), `/al-user-verification` (verify task ready), `.out-of-scope/` (durable rejection) |
