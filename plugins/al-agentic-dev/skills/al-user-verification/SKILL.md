---
name: al-user-verification
description: Walk a user through one slice's verify task in tasks.md for AL/Business Central. Use when a verify task (kind=verify) flips to ready, after `/al-code-review` per-slice ran clean for the slice.
---

**Style:** Drop articles, filler, hedging. Fragments OK. Arrows for causality. Technical terms exact, code unchanged, errors quoted exact. **Exception**: shift to prose where clarity or safety would be hurt.

# /al-user-verification, Walk a slice's user test plan

Pick a ready verify task. Walk each scenario's numbered steps with the user. Capture pass / fail per step. All pass → flip to `done`, hand off to the next slice's first technical task (or `/al-code-review` per-feature if this was the last slice). Any fail → flip to `blocked`, record failure inline, route to `/al-steer` with trigger #8.

Skill facilitates; user is the runner. No AL writes, no `/al-build` run, no codebase walk. Work is reading scenarios aloud, asking *"what did you see?"*, recording the answer.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside in-flight feature.
- `specs/<branch>/tasks.md` holds `kind=verify` task with `status=ready` and populated Tests area. Empty Tests → run `/al-refine <T-NNN>`. Status `blocked` → run `/al-steer`. Status anything else (`in-progress` from prior session, `done`) → surface and ask before reopening.
- Verify task `status=ready` means `/al-code-review` per-slice ran clean and flipped it from `blocked`. Still `blocked` → code-review has not run cleanly yet; re-enter via `/al-code-review` (or `/al-implement` if technical tasks are still open), not here.
- `event-model.md` present alongside; verify tasks only exist for user/API-facing features. Verify task without `event-model.md` → contract violation, **Stop**, route to `/al-steer`.
- Latest code published to verification environment. Skill does not run `/al-build`; user confirms publish before walking, or skill surfaces *"publish first via `/al-build`, then re-enter"* and stops. Verification against stale code signs off on wrong thing.
## What this session answers

- **Which slice in flight?** One `T-NNN` of `kind=verify`, named in opener with its `slice=` value and matching `event-model.md` timeline step.
- **What is user exercising?** Read each scenario's body (numbered steps) aloud. User touches surface (page action, API call, factbox view) and reports what they see.
- **Did every scenario pass?** Per scenario, walk every step. User confirms (*"yes, Status flipped to Released"*) or names what they saw instead (*"no, the cue didn't increment, it stayed at 2"*).
- **What flips at end?** `status=` goes `ready` → `in-progress` at first step, then `done` on full pass or `blocked` on first fail. No partial-pass state.

Unanswerable → halt. *"I can't tell which scenario we're on"* → re-read task block. *"The user sandbox is down"* → **Stop**, fix environment, re-enter. *"The scenario step references a page that doesn't exist"* → trigger #8, route to `/al-steer`.

## Workflow

### Opener, one scenario at a time

Announce verify task: `T-NNN` ID, slice slug, scenario count, first scenario. Flip status to `in-progress` before reading first step. One scenario open at a time; walking three scenarios in parallel loses failure context when one of them goes red.

### Read steps, capture answers

Per step: read user-action line, ask *"what did you see?"*, record answer in chat. Match against step's expected outcome. User's phrasing is authoritative observation; do not paraphrase *"the Status changed"* into *"Status flipped to Released"* if user did not say which value.

Step's expected outcome is implicit (step says *"click Release"* and next step asserts the Status) → wait for asserting step to capture observation. Do not interrupt with *"and what was the Status?"* between an action step and its assertion; that's the next step's job.

### Failure: stop the scenario, flip blocked, route

First fail in any scenario: stop the walk. Do not continue to later steps in same scenario, do not move to later scenarios. Record inside task block:

- Which scenario (`T-NNN#K`) and which step (1-indexed within scenario).
- Observed vs expected, in user's words.
- `**Replan flag**: trigger #8 (verification failed)`.

Flip `status=blocked` on the task's comment-anchor line, sync heading marker to `[!]`. Edit shape:

```
old_string: <!-- task=T-NNN status=in-progress slice=<slug> kind=verify -->
new_string: <!-- task=T-NNN status=blocked slice=<slug> kind=verify -->
```

Announce route to `/al-steer` with task ID. `/al-steer` decides between defect (insert `Fixes:` task in same `slice=`), wrong scenario (rewrite via `/al-refine`), wrong slice boundary (split via `/al-scope`). This skill does not propose the fix; surface failure and stop.

### Pass: continue to next scenario

User confirms step matches → move to next step. Last step of scenario passes → move to next scenario. Last step of last scenario passes → flip `status=done` on the comment-anchor line, sync heading marker to `[x]`. Then flip every technical task in *next* slice (slice whose first technical task carries `Depends on:` this verify task) from `blocked` to `ready`, so `/al-implement` picks up cleanly. Cross-slice gate is the only mechanism that opens the next slice; without this flip pipeline stalls. Run the Gate report.

### Partial walks survive session boundaries

Session interrupted mid-walk leaves verify task at `in-progress` with partial record inline (which scenario / step walk reached). Re-entering this skill on `in-progress` verify task resumes from next unwalked step; do not restart from `T-NNN#1`. Inline record is the resume point.

## Gate event

Once when verify task flips to `done`. Gate report names slice (slug + `event-model.md` step), what user confirmed in BC vocabulary (Role action, Business Event, View state, Status value), next handoff: `/al-implement` on first technical task of next slice (or `/al-refine` if its Tests slot is empty), or `/al-code-review` per-feature if this was last slice.

Gate report on failure (flipping to `blocked`) is the Stop shape from [voice-contract.md](../../references/voice-contract.md): one stop line naming scenario / step / observed-vs-expected, state table (verify task ID, scenarios completed, scenario blocked on), next action (route to `/al-steer`).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-code-review` per-slice ran clean for this slice and flipped verify task `blocked` → `ready` |
| **Hands off to**   | next slice's first technical task (`/al-refine` if Tests empty, else `/al-implement`); or `/al-code-review` per-feature if this was last slice. `/al-steer` on failure (after `status=blocked`). |
| **Replan venue**   | `/al-steer` (trigger #8 on failure) |
| **Sidebands**      | `/grill-me` (user uncertain whether what they saw matches expected outcome), `/al-research` (BC surface behaviour user wants verified against documentation) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping verify task to `done`. The flip greenlights the next slice; if user confirmations don't actually cover every scenario step the plan named, gate is theatre.

</claude-only>
