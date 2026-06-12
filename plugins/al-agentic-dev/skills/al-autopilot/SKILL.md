---
name: al-autopilot
description: Drive the AL/Business Central slice cycle unattended under the runtime goal feature. Use after /al-scope when the user wants the remaining tasks.md work completed autonomously — refine, implement, review, page-script, feature-done review rounds — with self-answered triage and a decision log; parks at each user-facing verify task for the human-driven /al-user-verification walk. Composes the goal line; the user fires it once.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-autopilot, Unattended slice-cycle driver

Drive `specs/<NNN>-<slug>/tasks.md` from its current state to feature-done without waiting on a human — parking at user-driven verify walks rather than substituting them — under the runtime's goal feature (`/goal` on Claude Code and Codex). Entry is post-`/al-scope`; the upstream pipeline (`/al-grill-adr` → `/al-event-model` → `/al-design` → `/al-scope`) settles intent and stays off-limits — an agent self-answering intent questions compounds its own assumptions through every slice. Resume-aware: `tasks.md` status lines are the state machine; tasks the user already drove to `done` manually stay trusted as-is.

## Per-turn protocol

This section leads the file on purpose: skill bodies are re-injected after compaction but truncated from the end, so the loop's spine sits where truncation cannot reach it. Every autonomous turn:

1. **Self-locate.** Read `tasks.md` status lines and the `decision-log.md` tail. Never trust remembered state — compaction and `--resume` then cost nothing.
2. **One step.** Route the single next step the state names, via the owning skill:

   | State | Step |
   |---|---|
   | `kind=provision` task `ready` (the feature's `T-001`) | `/al-provision T-NNN` |
   | technical task `ready` | `/al-refine T-NNN` |
   | technical task `ready-for-implementation` | `/al-implement T-NNN` |
   | slice technical tasks `done`, verify task `ready` | `/al-refine T-NNN` (verify) |
   | verify task `ready-for-verification` without `review=clean` on its comment line | `/al-code-review T-NNN` |
   | backend-only slice all `done` (no `kind=verify`), and the next slice's first task **or** the `kind=breaking-change` task still `blocked` | `/al-code-review` per-slice — its clean-review gate opens the next slice, or (at the last backend slice) opens the `kind=breaking-change` task |
   | verify task carries `review=clean`, `Journey Examples` present, no `.yml` recording | `/al-page-script T-NNN` |
   | verify task carries `review=clean`, `.yml` present or no E2E recording needed | **park** — `AUTONOMY STOP REPORT`, blocker `verify walk T-NNN is user-driven`, resume `/al-user-verification T-NNN` then relaunch `/al-autopilot`. The walk is the human's; no autonomous turn runs it |
   | `kind=breaking-change` task `ready` (all feature work `done`, its `Depends on:` satisfied) | `/al-validate-breaking-changes T-NNN` — a detected break flips it `blocked` → `AUTONOMY STOP REPORT` (intent decision: accept vs fix is the human's at merge) |
   | every task in feature `done` | feature-done `/al-code-review` rounds |

3. **Close.** End the turn by surfacing the status-line table, the freshest gate evidence, and the line `AUTONOMY RUN ACTIVE — specs/<NNN>-<slug>`. That line is proof for the evaluator, never a seat selector — seat selection per [autonomy-seat.md](../../references/autonomy-seat.md). The goal evaluator judges only what the conversation surfaces; re-surfacing each turn keeps its proof fresher than any compaction summary. The turn that satisfies the final completion clause re-surfaces **all three proofs together** — status table, feature review closer, final gate report — because the other two may by then exist only as compaction summaries, and the evaluator must never need an earlier turn.

One step per turn is the integrity spine: the external judge fires between steps, a failed step leaves one task in a known state, and the turn bound stays a budget you can reason about. Chaining steps inside a turn trades all three for seconds of overhead.

## Launch

First invocation, before any goal exists:

- **Preflight, refuse to emit the goal line on any miss.** Unattended permissions active (auto mode or equivalent — the first `docker` prompt otherwise parks the run); container snapshot image from `al-build.json` `container.imageName` exists; `bc-replay` and the browser MCP respond when the feature has user-facing slices; the opposite-runtime CLI for `/al-second-opinion` answers; on Codex, `features.goals` enabled (`codex features enable goals`).
- **Read state**, report remaining work per slice.
- **Write the `decision-log.md` header**: run header (date, feature, goal condition) plus the sentence `This log records decisions; it never selects a seat.`, the per-turn protocol in three lines, the stop-report rule, both entry skeletons from the Decision log section, and the `## Entries` append marker. The header is inert run metadata — nothing closes it on stop, nothing reads it for routing (seat selection per [autonomy-seat.md](../../references/autonomy-seat.md)). The header is the turn-one anchor — a cold start reads the file whole and restores the discipline. Mid-run turns read only the tail, so the entry shape rides the append marker and the previous entry, not the header.
- **Compose the goal line and emit it for the user to fire.** One human keypress at launch; zero mid-run. Never let the user hand-write the condition — the escape clause below is load-bearing, and a condition without it resurrects infinite retry against a dead container.

## Goal condition

Disjunctive, mechanical clauses only:

```text
/goal Feature <NNN>-<slug> is complete: every task in specs/<NNN>-<slug>/tasks.md
shows status=done on its comment line, the feature-done /al-code-review closed with
zero unresolved correctness findings, and the final full /al-build gate passed —
Claude must surface the status-line table, the review closer, and the gate report
as proof. OR an AUTONOMY STOP REPORT naming a blocker and resume point has been
issued. Stop after 150 turns either way.
```

Mechanical clauses (status values, gate exit, review closer) are mandatory, not stylistic: on Codex the goal is self-judged, and a model self-judging a mechanical checklist has little latitude; self-judging "good enough" has lots. The stop-report clause makes fail-fast a legitimate goal exit instead of a condition violation — without it, every infrastructure stop re-fires a turn against the same dead gate. 150 turns is a runaway backstop, not a target; scale it to the feature's remaining task count at launch.

## Never wait, never self-judge alone

No autonomous turn waits on a human. Seats that contracts reserve for one:

- **Interview seats** (`/al-code-review`'s per-finding triage, any question a skill would put to the user) → `/al-second-opinion` answers; the agent reconciles against the independent view and records the entry in `decision-log.md`. Disagreement on drop-vs-fix → fix wins. Correctness findings always become tasks; hygiene may settle as notes.
- **Physical-presence seats** (`/al-user-verification`'s guided user walk) → never substituted, never run autonomously; the state table parks the run with a stop report before the skill. That gate's point is a human exercised the surface. Verify-walk parks are the run's natural checkpoints: autopilot completes a slice up to the walk, the human walks, relaunches.
- **Hard-to-reverse picks** (data loss, breaking change, AppSource compliance) → don't wait, but take the most reversible option available and flag the entry `irreversible-class`. The human's merge-time read of the log is the checkpoint that replaces waiting.

## Decision log

`specs/<NNN>-<slug>/decision-log.md`, append-only, exempt from `/al-doc-verify` (a log, not a canonical artifact). The log dies reviewed at merge; it exists so the human audits afterwards what they were not asked during — which makes it the one sanctioned workflow-chatter venue: second-opinion verdicts and reversibility live here by design, inverting the artifact ban in `voice-contract.md`. Landing-line discipline still applies.

Two entry kinds, both labeled landing lines — one fact per line, lede word first. Splicing facts into an arrowed paragraph is density, not concision; the post-run reader scans labels top to bottom, then slow-reads the one line that catches the eye. Overflow facts become lede-word bullets under the entry, never spliced into a line. A line earns its place only if the post-run reader acts differently because of it; a line whose fact did not occur is dropped or reads `none`, never invented.

**Decision entry** — one per interview seat answered:

```markdown
### 2026-06-07 — Decision: deferred T-003 walk in autonomy scope?

Question: is the deferred T-003 walk in scope for the autonomy run?
Answer: yes — ran it.
Why: the deferral postponed the walk, did not waive it; tasks.md still gates feature-done on it.
Second opinion: concur — deferral text names completion, not exemption.
Reversible: yes — re-walk any time; evidence retained.
```

`irreversible-class` flags land on the `Reversible:` line. A decision's evidence is its `Why:` — gate evidence lives in the Turn entry and tasks.md closeouts, not here.

**Turn entry** — one per gate verdict (review verdict, verification outcome, build gate at a status flip), never per housekeeping turn:

```markdown
### 2026-06-07 — /al-implement T-003: PASS

Step: /al-implement T-003 → done
Evidence: full /al-build gate green 14/14; mutation round clean, zero survivors
Next: /al-refine T-004
```

The shape's standing corrective is in the tail, not the header: the `## Entries` marker reads `(append-only below — every entry follows the Decision or Turn skeleton above)`, and the previous entry is the live template every later turn mimics. One blobbed entry propagates; the marker is what breaks the chain.

## Replan boundary: additive stays, reshaping stops

Replan triggers fire mid-run as anywhere else. The line: **inserting one additive fix task in the current slice** (verification defect, hidden pre-req with an obvious single task) stays in-loop — insert, log, continue. **Anything reshaping existing tasks** — split, reorder, delete, slice or `kind` changes, `architecture.md` no longer matching reality, goal drift — re-enters `/al-scope`/`/al-design` judgment territory, the same territory walled off at entry → stop report. Never-wait covers questions; plan invalidation is not a question.

## Infrastructure ladder

Mid-run gate infrastructure failure, in order: restart the container → recreate from snapshot via `new-agent-container.ps1` → stop report. Browser MCP failure: one retry on a fresh tab → stop report. Degraded verification is forbidden — flipping a verify task `done` without its walk poisons the regression batch every later slice trusts. Stopping with a precise resume point is honest; a green flip without evidence is gate theatre.

## Feature-done review rounds

Findings → triage (seats above) → fix tasks open `ready` → refine → implement → re-review the diff since the previous round. Rounds cap at 3: lens findings never reach zero, and an unattended loop will chase hygiene nits at full gate cost forever. At cap, remaining correctness findings → stop report; remaining hygiene-level findings → decision-log notes, feature completes. Correctness is never waved through; hygiene never holds the feature hostage.

## Safety

Autopilot owns the checkpoint: after every task flips `done`, verify the work is committed and commit it if the owning skill did not (`/al-implement` only guarantees a WIP commit before `/al-mutate`; `/al-page-script` commits recordings on green). Commits are the checkpoints that make every stop resumable; an uncommitted stop loses the resume point. **Never push, never merge** — the run ends local on the feature branch; the human's first post-run act is reading the stop report or decision-log, then pushing. The turn bound is the only hard spend control; the user can end any run with `/goal clear`.

## Runtime envelope

| | Claude Code | Codex |
|---|---|---|
| Goal feature | `/goal`, v2.1.139+ | `/goal`, behind `codex features enable goals` |
| Completion judged by | external evaluator (fresh small-model instance) | the working model itself |
| Consequence | per-turn evidence read by an outside judge | mechanical condition is the only restraint — non-negotiable |

`/al-second-opinion` dispatches to the opposite runtime on both sides, so triage keeps an external voice everywhere; only goal-completion judgment loses independence on Codex. State the asymmetry to the user at launch; do not paper over it.

## Stop report

```text
AUTONOMY STOP REPORT
Blocker: <one line, BC vocabulary>
State: <2-col table — slice, task, status, last gate verdict>
Resume: <exact command(s) to continue after the blocker is cleared>
```

Emit the marker only from this path, never in prose — the goal condition's escape clause keys on the exact string, and an accidental emission ends the run.

## Chat shape

Gate events report per the Gate report skeleton in [voice-contract.md](../../references/voice-contract.md) — Did / Was / Fits / Next at app altitude. Each turn's closing block is the status table + evidence + active-run line from the per-turn protocol; that block is for the evaluator as much as the user.

## Composition

| | |
|---|---|
| **Invoked from**     | user at launch (post-`/al-scope`, any amount of manual progress already in `tasks.md`); every later turn re-enters via the goal loop, not re-invocation |
| **Routes to**        | `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script` per the state table; **parks before `/al-user-verification`** (walk is user-driven); `/al-steer` for in-loop additive insertion only |
| **Sidebands**        | `/al-second-opinion` (every interview seat), `/al-research` (evidence-bar escalation mid-task), `/al-build` (via owning skills) |
| **Stops to**         | `AUTONOMY STOP REPORT` → human reads, clears blocker, relaunches `/al-autopilot` (resume-aware by state) |
