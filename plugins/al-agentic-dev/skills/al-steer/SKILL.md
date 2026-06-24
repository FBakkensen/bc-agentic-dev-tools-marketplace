---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev. Reads the tasks/ folder, the goal, the codebase, and recent commits, names what is next or blocked or drifting, owns .out-of-scope/, and is the canonical replan venue.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-steer, Coach / navigator

Read the `tasks/` folder, `architecture.md`, `event-model.md` when present, the goal, codebase, recent commits, `.out-of-scope/`. Name what's next, blocked, drifting. Name next handoff; never force one. Canonical replan venue. Owner of `.out-of-scope/`.

The status board is computed, not stored: `grep -r '^status:' specs/<branch>/tasks/` gives every task's state; the `NNN-` filename prefix is run order, `depends_on:` lists are the graph. No index file.

User invokes in natural language ("where are we?", "split T-009 into three tasks"). Interpret and act.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only features).
- Spec folder `specs/<branch>/` holds a `tasks/` folder. Missing but `architecture.md` present → **Stop**, run `/al-scope`. `architecture.md` also missing → **Stop**, run `/al-design` (or `/al-event-model` first for user/API-facing features).

## Power model

Read anything in workspace. Write the `tasks/` folder structurally — add, split, delete, reorder, re-prefix task files — only after explicit user ack; silent restructuring loses the audit trail. Re-prefix by inserting into a gap (`025` between `020` and `030`); when a gap fills, rename the minimum local run (the `T-MMM` id inside each file is untouched, so no anchor breaks). Complete the whole rename run before the document-integrity check or any downstream handoff — a half-finished run leaves two files sharing a prefix, which the duplicate-prefix check flags. Write `.out-of-scope/<concept>.md` when substantive rejection earns durable memory. Nothing else.

## Read first, then name

Read the `tasks/` folder, scan `architecture.md`, `event-model.md` when present, recent commits, `.out-of-scope/` before naming anything. Surface what the state says; coaching from stale memory is the failure mode that drove the user here.

Name entries that need a decision: severity, ID, symptom in codebase's terms (object names, table fields, codeunit calls), one line per entry. Distinguish kinds:

- **Technical task** (`kind: technical`): `ready` → `/al-refine T-NNN`. `ready-for-implementation` → `/al-implement T-NNN`. `blocked` reads two ways: all `depends_on:` `done` and no replan flag → stale open, flip it `ready`, not a steering problem; unsatisfied edge or replan flag → name the missing edge or flag. `done` → downstream Unit/Integration/build/mutation evidence exists.

- **Ops task** (`kind: provision` / `kind: breaking-change`, reserved `slice: provision` / `slice: breaking-change`): `ready` → run its owning skill (`/al-provision` / `/al-validate-breaking-changes`), never `/al-refine`, no proof artifact. `blocked` reads two ways:
  - **Waiting** (dependency not yet `done`): normal scope-time state — say "waiting on `T-NNN`", don't name it a problem.
  - **Failed** (dependency `done`, task ran and could not pass): provision → environment not ready (compiler/symbols, container, `gh` auth, unreachable baseline release); breaking-change → a break detected or prerequisite failed. Clear the blocker, re-run the owning skill. A breaking-change `blocked` with deps `done` but never opened → stale gate-open, flip it `ready`.
  - Never open ops tasks to `ready-for-*`.

- **Verify task** (`kind: verify`): `ready` → `/al-refine T-NNN`. `done` → downstream E2E/Contract/Exploration evidence exists. `blocked` → name the failure inline and route per its trigger. `ready-for-verification` routing:
  - No `review: clean` → `/al-code-review T-NNN`.
  - `review: clean` + `Record: yes` Journey Examples whose recordings are missing → `/al-page-script T-NNN`.
  - `review: clean` + all `Record: yes` recordings present (or no `Record: yes` example) → `/al-user-verification T-NNN`.

- **Slice-done, no fresh verify proof** (every technical task `done`, verify task `blocked` only because deps were pending): stale gate-open. Route back to `/al-implement` closeout, or open to `ready` for `/al-refine` only after explicit user ack.

- **Slice-done, no clean code-review** (technical tasks `done`, verify task `ready-for-verification` without `review: clean`, or backend-only last task `done` with next slice still `blocked`): `/al-code-review` per-slice gate.

- **Feature-done** (every `T-NNN` `done`, no merge yet): `/al-code-review` per-feature gate.

Name the gate by name so the user picks the right skill. See [voice-contract.md](../../references/voice-contract.md) for prose voice.

## Route to next skill, do not perform it

`/al-steer` names handoff and stops; doing the next skill's work inside this one collapses a boundary the pipeline depends on. User uncertain which way to jump → run `/grill-me` on the branch.

## Eight replan triggers

Patterns to recognise, not a checklist. Other skills flag triggers as `**Replan flag**: trigger #N`; numbering is ID, not state.

| # | Name | Pattern |
|---|---|---|
| 1 | Task too big | One task balloons past a session, or its proof items cluster around two distinct subjects. |
| 2 | Hidden pre-req | Referenced table, codeunit, permission, or behaviour has no task covering it; or implementation needs a production object the task's assertions require but its `New and Modified Objects` never named — route back through `/al-refine` to extend the section, or open a covering task. |
| 3 | Wrong order | Task's `Test Specification` or `Verification Plan` references behaviour a later task introduces. |
| 4 | Sibling now wrong | Current task invalidates another task's context, `Test Specification`, or `Verification Plan`. |
| 5 | New behaviour emerges | Surfaced code path needs its own test, not an appended assertion. |
| 6 | Architecture decomposition wrong | R → P → W cuts across tasks, or `architecture.md` itself no longer matches reality. |
| 7 | Goal drift | Goal in `000-feature.md` no longer describes what the `tasks/` folder delivers. |
| 8 | Verification failed | `Verification Plan` example does not match observed behaviour. Judgement call between defect (insert a `fixes:` task), wrong `Verification Plan` (rewrite via `/al-refine`), or wrong slice boundary (split via `/al-scope`). |

## Trigger response is intent, not mechanics

Trigger invalidates the plan for the task → flip `status:` to `blocked` in frontmatter, record trigger ID + reason in the task body. Trigger surfaces new info that does not invalidate → leave status, note it in the task body. Judgement, not fixed mechanics.

A trigger resting on a tool diagnosis (compile-error class, AL Runner gap, heuristic "structural blocker") is re-confirmed once before the `blocked` flip — a first-pass diagnosis is frequently a cascade artifact (an AL0305 missing-dependency reads as an AL0327 runner gap), and a block on a phantom is false state the next session has to unwind. A trigger resting on a recorded fact (`depends_on:`, Goal text, an observed verification mismatch) is acted on as-is.

Opening or inserting a technical task in a slice strips `review: clean` from that slice's verify task in the same edit pass — new slice code invalidates the per-slice review, and the push-down path (page-script red → fix task here) moves no status byte on the verify task, so the strip is the only signal routing the slice back through `/al-code-review` after the fix lands. Lifecycle in [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md).

## Mutations come from the trigger, not a menu

Name candidate mutations matching what the trigger surfaced — splitting, inserting, reordering, deleting, rewriting a description, stripping a stale `Test Specification` or `Verification Plan` are all in scope. Run `/grill-me` on non-trivial choices. Apply only after explicit ack.

## Document verification

When restructuring the `tasks/` folder by explicit user ack (add, split, delete, re-prefix), run the document-integrity check yourself, inline (no subagent), after the write and before naming the downstream handoff — verify the folder against [`doc-integrity.md`](../../references/doc-integrity.md): the `tasks/` profile, with the duplicate-prefix and dangling-edge checks load-bearing after a re-prefix.

Skip this gate for simple `status:` flips, closeout notes, or inline replan flags. A **fail** (structural or boundary blocker) blocks the handoff; fix it or leave the task `blocked`. A **warn** does not block; surface it in the steering note.

## False halt closes the loop

Grilling vetoes the trigger → restore the prior `status:` value in frontmatter and rewrite the alert body to record resolution. Silent un-flag loses the reasoning the gate scanner needs.

## Owns `.out-of-scope/`

Grilling vetoes a recurring scope item with a substantive reason (project scope, technical constraint, strategic decision, referenced ADR — not a deferral) → record at `.out-of-scope/<concept>.md`, so the next session can't re-litigate the rejection. Scan `.out-of-scope/*.md` during replan and grilling; on match, surface the prior rejection in the user's words. Template `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` materialises on first need; a match appends a *Prior requests* entry rather than spawning a second file.

## Next step

Naming the next step *is* this skill's deliverable: the steering note ends with the concrete move read off current board state — `Next: /<skill> T-NNN` for the resolved block, or the deliberate `blocked` hold with what must settle first. `/al-steer` never auto-invokes the skill it names; the user takes the step.

## Feed

Card only the plan-changing moments below; routine board reads and handoff naming get nothing. At each, hand `/al-feed` a brief (what happened, why it matters, the kind); it composes and appends the card.

- **surprise** — a replan trigger acted on as a halt: task flipped `blocked`, trigger ID + reason recorded. Brief names which of the eight triggers, the codebase symptom in object terms, and that a tool-diagnosis trigger was re-confirmed before the flip.
- **decision** — the `tasks/` folder structurally rewritten after explicit user ack (split / insert / delete / reorder). Brief names the trigger, the exact mutation, the `review: clean` strip, the document-integrity gate.
- **verdict** — grilling vetoes a trigger: prior `status:` restored, false halt closed. Brief names what the halt suspected, why it was overturned, that the reasoning was recorded.
- **decision** — a recurring scope request vetoed and recorded at `.out-of-scope/`. Brief names the substantive reason, written so the next session can't re-litigate it.

## Composition

| | |
|---|---|
| **Invoked from**     | any SKILL on replan trigger, or by user for "where are we" |
| **Routes to**        | `/al-design`, `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, `/al-user-verification`, `.out-of-scope/` — conditions per the kind-routing bullets above |
