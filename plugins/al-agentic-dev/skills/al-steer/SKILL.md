---
name: al-steer
description: Coach and navigator for AL/Business Central agentic dev. Reads tasks.md, the goal, the codebase, and recent commits, names what is next or blocked or drifting, owns .out-of-scope/, and is the canonical replan venue.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-steer, Coach / navigator

Read `tasks.md`, `architecture.md`, `event-model.md` when present, the goal, codebase, recent commits, `.out-of-scope/`. Name what's next, blocked, drifting. Name next handoff; never force one. Canonical replan venue. Owner of `.out-of-scope/`.

User invokes `/al-steer` in natural language ("where are we?", "what's next?", "clear the replan queue", "T-007 is blocked, walk me through it", "split T-009 into three tasks"). Interpret and act.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only features).
- Spec folder `specs/<branch>/` holds `tasks.md`. Missing but `architecture.md` present → **Stop**, run `/al-scope`. `architecture.md` also missing → **Stop**, run `/al-design` (or `/al-event-model` first for user/API-facing features).

## Power model

Read anything in workspace. Write `tasks.md` structurally, only after explicit user ack; silent restructuring is the anti-pattern that loses the audit trail. Write `.out-of-scope/<concept>.md` when substantive rejection earns durable memory. Nothing else.

**Autonomous seat** (selected per `${CLAUDE_SKILL_DIR}/../../references/autonomy-seat.md` — the turn was initiated by the goal evaluator, not a human): the ack seat is empty by design. Additive single-task insertion in the current slice → write it, record the entry in `specs/<NNN>-<slug>/decision-log.md`; the log replaces the ack as the audit trail. Reshaping mutations (split, reorder, delete, slice or `kind` changes) never reach this skill under autonomy — `/al-autopilot` stops the run first; if one is requested anyway, refuse and return the replan-class verdict to the caller.

## Read first, then name

Read `tasks.md`, scan `architecture.md`, `event-model.md` when present, recent commits, `.out-of-scope/` before opening your mouth. Surface what the state already says; coaching from stale memory is the failure mode that drove the user here. Name entries that need a decision: severity, ID, symptom in codebase's terms (object names, table fields, codeunit calls), one line per entry. Distinguish kinds explicitly:

- Technical task (`kind=technical`) `ready` means `/al-refine T-NNN` only. `ready-for-implementation` means `/al-implement T-NNN`. `blocked` means dependency/context missing; name the missing edge or replan flag. `done` means downstream Unit/Integration/build/mutation evidence exists.
- Ops task (`kind=provision` / `kind=breaking-change`, on reserved `slice=provision` / `slice=breaking-change`) `ready` means run its owning skill (`/al-provision` / `/al-validate-breaking-changes`) — never `/al-refine`, no proof artifact. `blocked` reads two ways, told apart by whether the task's `Depends on:` is satisfied:
  - **Waiting** (dependency not yet `done`): the normal scope-time state. Breaking-change sits here until the last slice lands; no action — its flip-owner (`/al-user-verification` last verify, or `/al-code-review` last backend slice) opens it. Naming it as a problem is the error; say "waiting on `T-NNN`".
  - **Failed** (dependency `done`, task ran and could not pass): provision → environment not ready (compiler/symbols, container, `gh` auth, unreachable baseline release); breaking-change → a break detected (intent decision — accept the major bump or open a fix task) or a prerequisite failed (empty cache → re-run `/al-provision`). Clear the blocker, then re-run the owning skill. A breaking-change task `blocked` with deps `done` but never opened is a stale-gate-open bug (its flip-owner missed it) — name it and open it `ready`.

  Never open ops tasks to `ready-for-*`.
- Verify task (`kind=verify`) `ready` means `/al-refine T-NNN` only. `ready-for-verification` means fresh `Verification Plan` exists, not that verification may bypass review; clean per-slice `/al-code-review` evidence is the `review=clean` key on the comment-anchor line. No `review=clean` → `/al-code-review T-NNN`. `review=clean` present and `Journey Examples` present but no `.yml` at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml` → `/al-page-script T-NNN`; `review=clean` present and `.yml` exists or no E2E recording is needed → `/al-user-verification T-NNN`. `blocked` → name the failure inline and route per its trigger (*"slice `approve-override` verify is blocked, `V2` failed at observable check 3"*). `done` means downstream E2E/Contract/Exploration evidence exists.
- Slice-done with no fresh verify proof yet (every technical task in a user/API-facing `slice=` is `done`, slice's verify task is `blocked` only because dependencies were pending) is a stale gate-open state. Name it and route back to `/al-implement` closeout ownership, or open it to `ready` for `/al-refine` only after explicit user ack.
- Slice-done with fresh verify proof and no clean code-review yet (every technical task in a `slice=` is `done`, slice's verify task is `ready-for-verification` without `review=clean`, or backend-only slice's last task is `done` with next slice's first task still `blocked`) is the `/al-code-review` per-slice gate (*"slice `release-sales-order` is code-review ready: 4 technical tasks done, verify ready-for-verification"*).
- Feature-done (every `T-NNN` in feature `done`, no merge yet) is the `/al-code-review` per-feature gate.

Naming the gate by name lets user pick the right next skill. Prose paragraphs and generic CRUD words bury the seam; let user pick which entry to walk. See [voice-contract.md](../../references/voice-contract.md) for prose voice.

## Route to next skill, do not perform it

`/al-steer` names handoff and stops. Downstream skill owns the work; doing next skill's work inside this one collapses boundary the pipeline depends on. User uncertain which way to jump → run `/grill-me` on the branch; if they have clarity, no handoff is needed.

## Eight replan triggers

Patterns the agent learns to recognise, not a checklist to walk. Other skills flag triggers as `**Replan flag**: trigger #N`; numbering is ID, not state.

| # | Name | Pattern |
|---|---|---|
| 1 | Task too big | One task balloons past a session, or its proof items cluster around two distinct subjects. |
| 2 | Hidden pre-req | Referenced table, codeunit, permission, or behaviour has no task covering it. |
| 3 | Wrong order | Task's `Test Specification` or `Verification Plan` references behaviour a later task introduces. |
| 4 | Sibling now wrong | Current task invalidates another task's context, `Test Specification`, or `Verification Plan`. |
| 5 | New behaviour emerges | Surfaced code path needs its own test, not an appended assertion. |
| 6 | Architecture decomposition wrong | R → P → W cuts across tasks, or `architecture.md` itself no longer matches reality. |
| 7 | Goal drift | Goal slot no longer describes what `tasks.md` delivers. |
| 8 | Verification failed | `Verification Plan` example does not match observed behaviour. Judgement call between defect (insert `Fixes:` task), wrong `Verification Plan` (rewrite via `/al-refine`), or wrong slice boundary (split via `/al-scope`). |

## Trigger response is intent, not mechanics

When trigger means plan is invalid for the task → halt by flipping `status=blocked` on the comment-anchor line (sync heading marker to `[!]`) and recording trigger ID + reason inside the task block. When trigger means new information surfaced that does not invalidate plan → leave status alone and note trigger inside task block. Choice is judgement; fixed enforcement mechanics turn replan into form-filling.

Opening or inserting a technical task in a slice strips `review=clean` from that slice's verify task in the same edit pass. New slice code invalidates the per-slice review, and the push-down path (page-script red → fix task here) moves no status byte on the verify task — the strip is the only signal that routes the slice back through `/al-code-review` after the fix lands. Lifecycle in [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md).

## Mutations come from the trigger, not a menu

Name candidate mutations that match what the trigger surfaced. Splitting, inserting, reordering, deleting, rewriting a description, stripping a stale `Test Specification` or `Verification Plan` all in scope; pick what situation needs. Run `/grill-me` on non-trivial choices. Apply only after explicit ack. Prescribed mutation menu is same anti-pattern as prescribed checklist; trigger says what shape is wrong, response shape varies with codebase.

## Document verification

When restructuring `tasks.md` by explicit user ack, run `/al-doc-verify` after the write and before naming downstream handoff:

```text
/al-doc-verify --producer al-steer --artifacts specs/<NNN>-<slug>/tasks.md --task <T-NNN> --slice <slice> --handoff <next-skill>
```

Do not run this gate for simple `status=` flips, closeout notes, or inline replan flags. `verdict=fail` blocks the handoff; fix the structural/boundary issue or leave the relevant task `blocked`. `verdict=warn` does not block; surface the warning in the steering note.

## False halt closes the loop

Grilling vetoes the trigger → restore prior `status=` value on the comment-anchor line (sync heading marker) and rewrite alert body to record resolution. Silent un-flag loses reasoning, and gate scanner can't see what changed.

## Owns `.out-of-scope/`

Grilling vetoes a recurring scope item with substantive reason (project scope, technical constraint, strategic decision, referenced ADR; not a deferral) → record at `.out-of-scope/<concept>.md`. Scan `.out-of-scope/*.md` during replan and grilling; on match, surface prior rejection in user's words. File's job is to stop next session from re-litigating same rejection. Template `${CLAUDE_SKILL_DIR}/references/out-of-scope.template.md` materialises on first need; matches append *Prior requests* entry rather than spawning second file.

## Composition

| | |
|---|---|
| **Invoked from**     | any SKILL on replan trigger, or by user for "where are we" |
| **Routes to**        | `/al-design` (architecture-decomposition trigger), `/al-refine` (`status=ready` task needs fresh `Test Specification` / `Verification Plan`), `/al-implement` (`ready-for-implementation` technical task), `/al-code-review` (slice-done with verify task `ready-for-verification` without `review=clean`, backend-only slice-done, or feature-done), `/al-page-script` (`review=clean` verify task with `Journey Examples` but no `.yml` yet), `/al-user-verification` (`review=clean` verify task with `.yml` present or no E2E recording needed), `.out-of-scope/` (durable rejection) |
