---
name: al-user-verification
description: Walk a user through one slice's verify task in tasks.html for AL/Business Central. Use when a verify task (data-kind="verify") flips to ready, after its slice's technical tasks all hit done.
---

# /al-user-verification, Walk a slice's user test plan

Pick a ready verify task. Walk each scenario's numbered steps with the user. Capture pass / fail per step. All pass → flip to `done`, hand off to `/al-code-review` at slice-done. Any fail → flip to `blocked`, record the failure inline, route to `/al-steer` with trigger #8.

The skill facilitates; the user is the runner. No AL writes, no `/al-build` run, no codebase walk. The work is reading scenarios aloud, asking *"what did you see?"*, recording the answer.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. The verify task only exists inside an in-flight feature.
- `specs/<branch>/tasks.html` holds a `data-kind="verify"` task with `data-status="ready"` and a populated Tests area. Empty Tests → run `/al-refine <T-NNN>`. Status `blocked` → run `/al-steer`. Status anything else (`in-progress` from a prior session, `done`) → surface and ask before reopening.
- `event-model.html` is present alongside; verify tasks only exist for user/API-facing features. A verify task without `event-model.html` is a contract violation, **Stop** and route to `/al-steer`.
- Latest code published to the verification environment. This skill does not run `/al-build`; the user confirms publish before walking, or the skill surfaces *"publish first via `/al-build`, then re-enter"* and stops. A verification against stale code signs off on the wrong thing.
- Legacy markdown spec (`tasks.md` without `tasks.html`): frozen. Hand-migrate first.

## What this session answers

- **Which slice is in flight?** One `T-NNN` of `data-kind="verify"`, named in the opener with its `data-slice` slug and the matching `event-model.html` timeline step.
- **What is the user exercising?** Read each scenario's body (numbered steps) aloud. The user touches the surface (page action, API call, factbox view) and reports what they see.
- **Did every scenario pass?** Per scenario, walk every step. The user confirms (*"yes, Status flipped to Released"*) or names what they saw instead (*"no, the cue didn't increment, it stayed at 2"*).
- **What flips at the end?** `data-status` goes `ready` → `in-progress` at the first step, then `done` on full pass or `blocked` on first fail. No partial-pass state.

Unanswerable question, halt. *"I can't tell which scenario we're on"* → re-read the task block. *"The user sandbox is down"* → **Stop**, fix the environment, re-enter. *"The scenario step references a page that doesn't exist"* → trigger #8, route to `/al-steer`.

## Workflow

### Opener, one scenario at a time

Announce the verify task: `T-NNN` ID, slice slug, scenario count, first scenario. Flip status to `in-progress` before reading the first step. One scenario open at a time; walking three scenarios in parallel loses the failure context when one of them goes red.

### Read steps, capture answers

Per step: read the user-action line, ask *"what did you see?"*, record the answer in chat. Match against the step's expected outcome. The user's phrasing is the authoritative observation; do not paraphrase *"the Status changed"* into *"Status flipped to Released"* if the user did not say which value.

Where the step's expected outcome is implicit (the step says *"click Release"* and the next step asserts the Status), wait for the asserting step to capture the observation. Do not interrupt with *"and what was the Status?"* between an action step and its assertion; that's the next step's job.

### Failure: stop the scenario, flip blocked, route

First fail in any scenario: stop the walk. Do not continue to later steps in the same scenario, do not move to later scenarios. Record inside the task block:

- Which scenario (`T-NNN#K`) and which step (1-indexed within the scenario).
- Observed vs expected, in the user's words.
- `**Replan flag**: trigger #8 (verification failed)`.

Flip `data-status` to `blocked`. Announce route to `/al-steer` with the task ID. `/al-steer` decides between defect (insert a `Fixes:` task in the same `data-slice`), wrong scenario (rewrite via `/al-refine`), wrong slice boundary (split via `/al-scope`). This skill does not propose the fix; surface the failure and stop.

### Pass: continue to next scenario

User confirms the step matches. Move to the next step. Last step of a scenario passes: move to the next scenario. Last step of the last scenario passes: flip `data-status` to `done`. Then flip every technical task in the *next* slice (the slice whose first technical task carries `Depends on:` this verify task) from `blocked` to `ready`, so `/al-implement` picks up cleanly. The cross-slice gate is the only mechanism that opens the next slice; without this flip the pipeline stalls. Run the Gate report.

### Partial walks survive session boundaries

A session interrupted mid-walk leaves the verify task at `in-progress` with a partial record inline (which scenario / step the walk reached). Re-entering this skill on an `in-progress` verify task resumes from the next unwalked step; do not restart from `T-NNN#1`. The inline record is the resume point.

## Gate event

Once when the verify task flips to `done`. The Gate report names the slice (slug plus the `event-model.html` step), what the user confirmed in BC vocabulary (Role action, Business Event, View state, Status value), and the next handoff: `/al-code-review` per-slice on the just-verified slice's diff, then `/al-implement` on the first technical task of the next slice (or `/al-code-review` per-feature if this was the last slice).

The Gate report on failure (flipping to `blocked`) is the Stop shape from [voice-contract.md](../../references/voice-contract.md): one stop line naming the scenario / step / observed-vs-expected, a state table (verify task ID, scenarios completed, scenario blocked on), and the next action (route to `/al-steer`).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-implement` flipped the last technical task in the slice to `done` and the verify task to `ready` |
| **Hands off to**   | `/al-code-review` (slice-done, after `data-status="done"`) or `/al-steer` (failure, after `data-status="blocked"`) |
| **Replan venue**   | `/al-steer` (trigger #8 on failure) |
| **Sidebands**      | `/grill-me` (user uncertain whether what they saw matches the expected outcome), `/al-research` (BC surface behaviour the user wants verified against documentation) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping the verify task to `done`. The flip greenlights `/al-code-review` and the next slice; if the user confirmations don't actually cover every scenario step the plan named, the gate is theatre.

</claude-only>
