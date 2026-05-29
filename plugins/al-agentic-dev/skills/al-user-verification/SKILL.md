---
name: al-user-verification
description: Walk a user through one slice's verify task in tasks.md for AL/Business Central. Use when a verify task (kind=verify) flips to ready, after `/al-code-review` per-slice ran clean for the slice.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-user-verification, Walk a slice's user test plan

Pick a ready verify task. Walk each scenario's numbered steps with the user. Capture pass / fail per step. All pass → flip to `done`, hand off to the next slice's first technical task (or `/al-code-review` per-feature if this was the last slice). Any fail → flip to `blocked`, record failure inline, route to `/al-steer` with trigger #8.

Skill facilitates; user is the runner. No AL writes, no `/al-build` run, no codebase walk. Work is reading scenarios aloud, asking *"what did you see?"*, recording the answer.

**Layer.** Owns the **acceptance** pre-flight (the bc-replay regression batch, every slice's `.yml`) and facilitates the **exploratory** layer (see [`test-strategy.md`](../../references/test-strategy.md)): sapient verification — judging what no assertion oracle can check (checking vs testing). The runner is the human; output is findings → tasks, not a green/red gate.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside in-flight feature.
- `specs/<branch>/tasks.md` holds `kind=verify` task with `status=ready` and populated Tests area. Empty Tests → run `/al-refine <T-NNN>`. Status `blocked` → run `/al-steer`. Status anything else (`in-progress` from prior session, `done`) → surface and ask before reopening.
- Verify task `status=ready` means `/al-code-review` per-slice ran clean and flipped it from `blocked`. Still `blocked` → code-review has not run cleanly yet; re-enter via `/al-code-review` (or `/al-implement` if technical tasks are still open), not here.
- `event-model.md` present alongside; verify tasks only exist for user/API-facing features. Verify task without `event-model.md` → contract violation, **Stop**, route to `/al-steer`.
- Latest code published to verification environment. Skill spawns its own fresh container per cycle (see *Container lifecycle* below); user does not need to publish manually. Skill does not run the inner `/al-build`-test loop; container spawn covers publish.
- Slice's bc-replay recording exists at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Missing → **Stop**, `Next: /al-page-script T-NNN`. The pre-flight regression batch runs the slice's `.yml` plus every prior slice's `.yml` before the human walk; without a recording the regression net has a hole.

## Container lifecycle

Three `new-agent-container.ps1` spawns per cycle. Fresh-each-time discipline isolates verification from prior session state and leaves the next consumer with a clean container.

**Spawn #1 (pre-flight).** `new-agent-container.ps1` → `publish-apps.ps1` → `pagescript-replay.ps1` (batch mode, every `pagescripts/recordings/*.yml`). Three explicit primitives: fresh container, publish all configured apps, run the regression batch. Catches both current-slice regressions and cross-slice collisions before the human walk. Green → continue. Red → flip verify task `status=blocked`, record transcript with `**Replan flag**: trigger #4 (sibling now wrong)` for any prior-slice `.yml` red, `**Replan flag**: trigger #8 (verification failed)` for current-slice red. Announce route to `/al-steer T-NNN`. Run spawn #3 for cleanup and exit.

**Spawn #2 (pre-walk).** Only on pre-flight green. `new-agent-container.ps1` → `publish-apps.ps1` → surface the BC Web Client URL (`http://<container-name>/BC/`) for the user → human walks scenarios live against this container. Symmetric with spawn #1's first two primitives; no replay step (batch already greened on spawn #1; re-running is wasted work and a second chance to red on something the gate already cleared). Walk owns the rest of *Workflow* below.

**Spawn #3 (exit).** Always runs at end of cycle, pass or fail. `new-agent-container.ps1` only — leaves a fresh container for the next consumer (next slice's `/al-implement`, or merge prep). Skill exits after spawn returns.

Spawn invocations:
- container spawn (any): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/new-agent-container.ps1"`
- publish all apps (spawn #1, #2): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/publish-apps.ps1"`
- batch replay (spawn #1): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1"`

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

### Pre-flight failure routing (spawn #1 red)

Pre-flight batch surfaces failures BEFORE the human walks. Two failure shapes; both route to `/al-steer` but the trigger names what `/al-steer` is being asked to triage.

- **Current slice's `.yml` red.** The recording `/al-page-script` just generated and committed fails on a fresh container. `/al-page-script`'s scenario-by-scenario inner loop ran replay-validation per scenario, so a current-slice pre-flight red means the failure didn't surface inside that loop — likely a non-deterministic recording (timing-dependent assertion, flaky locator), or a real regression introduced between `/al-page-script`'s green and `/al-user-verification`'s entry (a hotfix commit, a CI republish of a different version). Flag `**Replan flag**: trigger #8 (verification failed)`. `/al-steer` triages: re-author the scenario step (rewrite via `/al-refine`) if the recording is fragile, or insert a `Fixes:` task in the current slice if a real defect surfaced.

- **Prior slice's `.yml` red.** A recording from an earlier slice's verify task fails on the current slice's published code. Current slice introduced a change that broke the prior slice's user-facing surface — a renamed action, removed field, altered factbox refresh shape, changed Status-flip behaviour. Flag `**Replan flag**: trigger #4 (sibling now wrong)`. `/al-steer` triages: regenerate the prior slice's `.yml` via `/al-page-script` if the surface change was intentional (the prior recording is stale, not wrong), rewrite the prior slice's scenarios via `/al-refine` if the change invalidates the user-facing contract, or insert a `Fixes:` task in the current slice if the surface change was unintentional regression. Re-opening a prior slice's verify task is a `/al-steer` decision, not this skill's.

Mixed-red (both current AND prior slices red) is one root cause more often than two; transcript names every failed `.yml`, both flags stamped, `/al-steer` picks one.

Flip `status=blocked` on the comment-anchor line, sync heading marker to `[!]`. Run spawn #3 for cleanup before exiting.

### Failure: stop the scenario, flip blocked, route (live-walk red)

First fail in any scenario the human walks: stop the walk. Do not continue to later steps in same scenario, do not move to later scenarios. Record inside task block:

- Which scenario (`T-NNN#K`) and which step (1-indexed within scenario).
- Observed vs expected, in user's words.
- `**Replan flag**: trigger #8 (verification failed)`.

Flip `status=blocked` on the task's comment-anchor line, sync heading marker to `[!]`. Edit shape:

```
old_string: <!-- task=T-NNN status=in-progress slice=<slug> kind=verify -->
new_string: <!-- task=T-NNN status=blocked slice=<slug> kind=verify -->
```

Announce route to `/al-steer T-NNN`. `/al-steer` decides between defect (insert `Fixes:` task in same `slice=`), wrong scenario (rewrite via `/al-refine`), wrong slice boundary (split via `/al-scope`). This skill does not propose the fix; surface failure and stop.

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
| **Runs after**     | `/al-page-script` committed the slice's `.yml` at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml` (which itself runs after `/al-code-review` per-slice flipped the verify task `blocked` → `ready`) |
| **Hands off to**   | next slice's first technical task (`/al-refine` if Tests empty, else `/al-implement`); or `/al-code-review` per-feature if this was last slice. `/al-steer` on failure (after `status=blocked`, whether pre-flight red or live-walk red). |
| **Uses**           | `new-agent-container.ps1` (three spawns per cycle), `pagescript-replay.ps1` (batch mode for spawn #1's pre-flight), `publish-apps.ps1` (spawn #2 publish before the human walk) |
| **Replan venue**   | `/al-steer` — trigger #4 (pre-flight prior-slice red), trigger #8 (pre-flight current-slice red or live-walk fail) |
| **Sidebands**      | `/grill-me` (user uncertain whether what they saw matches expected outcome), `/al-research` (BC surface behaviour user wants verified against documentation) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping verify task to `done`. The flip greenlights the next slice; if user confirmations don't actually cover every scenario step the plan named, gate is theatre.

</claude-only>
