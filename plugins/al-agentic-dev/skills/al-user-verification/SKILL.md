---
name: al-user-verification
description: Drive the agent browser through one slice's verify task in tasks.md for AL/Business Central. Agent runs and judges; functional outcomes gate, usability observations become findings → tasks; al-second-opinion + visual evidence guard against gate theatre. Use when a verify task (kind=verify) flips to ready, after `/al-code-review` per-slice ran clean for the slice.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-user-verification, Drive a slice's user test plan

Pick a ready verify task. The agent drives the BC web client through each scenario's numbered steps via `claude-in-chrome`, capturing visual evidence per scenario. All functional-pass + pre-flight batch-green + second-opinion-reconciled → flip `done`, hand off to the next slice's first technical task (or `/al-code-review` per-feature if this was the last slice). Any functional fail → flip `blocked`, record inline, route to `/al-steer` with trigger #8.

**Agent is the runner.** It drives the browser, captures a GIF/screenshots per scenario, and judges. No AL writes, no `/al-build` run, no codebase walk. Two outcome dimensions per scenario, split by *checking vs testing*: **functional/observable** outcomes (a Status value, a cue count, an error) are *checked* and **gate** the verify task; **subjective usability** outcomes (clunky, unclear, flow isn't one motion) are *sapient testing* → **findings → tasks**, never an opaque agent thumbs-up and never a gate on the agent's opinion. Two guards against gate theatre: `/al-second-opinion` reviews the written verdict (reasoning/coverage gaps), durable visual evidence lets the human spot-check observation (did the agent read the screen right).

**Layer.** Owns the **acceptance** pre-flight (the bc-replay regression batch, every slice's `.yml`) and drives the **exploratory** layer (agent-driven browser; see [`test-strategy.md`](../../references/test-strategy.md)). Per checking-vs-testing: functional outcomes gate; subjective usability is findings → tasks. `/al-second-opinion` guards reasoning, visual evidence guards observation — neither replaces the human, who can review the evidence and override.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside in-flight feature.
- `specs/<branch>/tasks.md` holds `kind=verify` task with `status=ready` and populated Tests area. Empty Tests → run `/al-refine <T-NNN>`. Status `blocked` → run `/al-steer`. Status anything else (`in-progress` from prior session, `done`) → surface and ask before reopening.
- Verify task `status=ready` means `/al-code-review` per-slice ran clean and flipped it from `blocked`. Still `blocked` → code-review has not run cleanly yet; re-enter via `/al-code-review` (or `/al-implement` if technical tasks are still open), not here.
- `event-model.md` present alongside; verify tasks only exist for user/API-facing features. Verify task without `event-model.md` → contract violation, **Stop**, route to `/al-steer`.
- Latest code published to verification environment. Skill spawns its own fresh container per cycle (see *Container lifecycle* below); user does not need to publish manually. Skill does not run the inner `/al-build`-test loop; container spawn covers publish.
- Slice's bc-replay recording exists at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Missing → **Stop**, `Next: /al-page-script T-NNN`. The pre-flight regression batch runs the slice's `.yml` plus every prior slice's `.yml` before the agent walk; without a recording the regression net has a hole.
- `claude-in-chrome` drives the walk. The skill connects/selects a browser as part of spawn #2. If a browser genuinely cannot be driven, **fall back** to facilitating a human walk against the surfaced URL (agent reads each scenario, user reports what they saw) — the gate flips on the same functional criteria either way.

## Container lifecycle

Three `new-agent-container.ps1` spawns per cycle. Fresh-each-time discipline isolates verification from prior session state and leaves the next consumer with a clean container.

**Spawn #1 (pre-flight).** `new-agent-container.ps1` → `publish-apps.ps1` → `pagescript-replay.ps1` (batch mode, every `pagescripts/recordings/*.yml`). Three explicit primitives: fresh container, publish all configured apps, run the regression batch. Catches both current-slice regressions and cross-slice collisions before the agent walk. Green → continue. Red → flip verify task `status=blocked`, record transcript with `**Replan flag**: trigger #4 (sibling now wrong)` for any prior-slice `.yml` red, `**Replan flag**: trigger #8 (verification failed)` for current-slice red. Announce route to `/al-steer T-NNN`. Run spawn #3 for cleanup and exit.

**Spawn #2 (agent walk).** Only on pre-flight green. `new-agent-container.ps1` → `publish-apps.ps1` → drive `claude-in-chrome` against the BC Web Client URL (`http://<container-name>/BC/`). Symmetric with spawn #1's first two primitives; no replay step (batch already greened on spawn #1; re-running is wasted work and a second chance to red on something the gate already cleared). The agent walks each scenario, capturing a GIF/screenshots per scenario as durable evidence. Chrome can't be driven → fall back to a facilitated human walk against the same URL. Walk owns the rest of *Workflow* below.

**Spawn #3 (exit).** Always runs at end of cycle, pass or fail. `new-agent-container.ps1` only — leaves a fresh container for the next consumer (next slice's `/al-implement`, or merge prep). Skill exits after spawn returns.

Spawn invocations:
- container spawn (any): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/new-agent-container.ps1"`
- publish all apps (spawn #1, #2): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/publish-apps.ps1"`
- batch replay (spawn #1): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1"`

## What this session answers

- **Which slice in flight?** One `T-NNN` of `kind=verify`, named in opener with its `slice=` value and matching `event-model.md` timeline step.
- **What is the agent exercising?** Read each scenario's body (numbered steps); the agent drives the surface (page action, API call, factbox view) via `claude-in-chrome` and observes what renders.
- **Did every scenario functionally pass?** Per scenario, drive every step. The functional assertion (*"Status flips to Released"*, *"cue increments to 3"*) is observed and matched; the agent records observed-vs-expected with a captured frame as evidence.
- **What usability findings surfaced?** Any friction the walk reveals (clunky flow, unclear label, slow refresh) — recorded as findings, routed to tasks, **not** gating.
- **What flips at end?** `status=` goes `ready` → `in-progress` at first step, then `done` on full functional-pass (+ batch-green + second-opinion reconciled) or `blocked` on first functional fail. No partial-pass state.

Unanswerable → halt. *"Chrome won't drive the surface"* → fall back to the human walk (Preconditions). *"The sandbox is down"* → **Stop**, fix environment, re-enter. *"The scenario step references a page that doesn't exist"* → trigger #8, route to `/al-steer`.

## Workflow

### Opener, one scenario at a time

Announce verify task: `T-NNN` ID, slice slug, scenario count, first scenario. Flip status to `in-progress` before driving the first step. One scenario open at a time; walking three scenarios in parallel loses failure context when one goes red.

### Drive steps, observe two dimensions

Per step: drive the user-action line via `claude-in-chrome`, observe what renders, capture a frame. Then judge two dimensions:

- **Functional (checking, gates).** Match the observable outcome against the step's assertion. State observed-vs-expected verbatim (*"Status = Released"* / *"cue stayed at 2, expected 3"*) — read the value off the screen, do not infer it from what the AL "should" do. The captured frame is the evidence; an inferred pass with no frame is not a pass.
- **Usability (testing, findings).** Note any friction the step reveals — clunky sequencing, ambiguous caption, slow or missing refresh, an error message that reads wrong. These are observations, not gate signals.

A step's expected outcome is implicit (step says *"click Release"* and the next step asserts the Status) → wait for the asserting step to capture the functional observation; do not gate on the action step alone.

### Pre-flight failure routing (spawn #1 red)

Pre-flight batch surfaces failures BEFORE the agent walks. Two failure shapes; both route to `/al-steer` but the trigger names what `/al-steer` is being asked to triage.

- **Current slice's `.yml` red.** The recording `/al-page-script` just generated and committed fails on a fresh container. `/al-page-script`'s scenario-by-scenario inner loop ran replay-validation per scenario, so a current-slice pre-flight red means the failure didn't surface inside that loop — likely a non-deterministic recording (timing-dependent assertion, flaky locator), or a real regression introduced between `/al-page-script`'s green and `/al-user-verification`'s entry (a hotfix commit, a CI republish of a different version). Flag `**Replan flag**: trigger #8 (verification failed)`. `/al-steer` triages: re-author the scenario step (rewrite via `/al-refine`) if the recording is fragile, or insert a `Fixes:` task in the current slice if a real defect surfaced.

- **Prior slice's `.yml` red.** A recording from an earlier slice's verify task fails on the current slice's published code. Current slice introduced a change that broke the prior slice's user-facing surface — a renamed action, removed field, altered factbox refresh shape, changed Status-flip behaviour. Flag `**Replan flag**: trigger #4 (sibling now wrong)`. `/al-steer` triages: regenerate the prior slice's `.yml` via `/al-page-script` if the surface change was intentional (the prior recording is stale, not wrong), rewrite the prior slice's scenarios via `/al-refine` if the change invalidates the user-facing contract, or insert a `Fixes:` task in the current slice if the surface change was unintentional regression. Re-opening a prior slice's verify task is a `/al-steer` decision, not this skill's.

Mixed-red (both current AND prior slices red) is one root cause more often than two; transcript names every failed `.yml`, both flags stamped, `/al-steer` picks one.

Flip `status=blocked` on the comment-anchor line, sync heading marker to `[!]`. Run spawn #3 for cleanup before exiting.

### Functional fail: stop the scenario, flip blocked, route

First functional fail in any scenario: stop the walk. Do not continue to later steps in the same scenario, do not move to later scenarios. Record inside the task block:

- Which scenario (`T-NNN#K`) and which step (1-indexed within scenario).
- Observed vs expected, read off the screen, with the captured frame referenced.
- `**Replan flag**: trigger #8 (verification failed)`.

Flip `status=blocked` on the task's comment-anchor line, sync heading marker to `[!]`. Edit shape:

```
old_string: <!-- task=T-NNN status=in-progress slice=<slug> kind=verify -->
new_string: <!-- task=T-NNN status=blocked slice=<slug> kind=verify -->
```

Announce route to `/al-steer T-NNN`. `/al-steer` decides between defect (insert `Fixes:` task in same `slice=`), wrong scenario (rewrite via `/al-refine`), wrong slice boundary (split via `/al-scope`). This skill does not propose the fix; surface failure and stop. A usability finding is **never** a functional fail — it does not stop the walk or block the gate.

### Second opinion before the gate

All scenarios functionally pass → before flipping `done`, run `/al-second-opinion` on the written verdict to mitigate gate theatre (the agent judging its own walk). Compose the artifact: per scenario, the steps driven, the observed-vs-expected functional outcome, the evidence frame reference, and the usability findings. The gate reviews **reasoning and coverage** — *does the verdict actually address every scenario's asserting step; does any "pass" rest on an inference rather than an observed value*. It is text-only: it cannot see the browser, so it does not catch a misread screen — that is what the captured frames are for. Reconcile the returned bullets per line: a real coverage gap → re-walk that scenario; a real reasoning gap → re-state the verdict. `Second opinion skipped: …` → absorb and proceed (checkpoint, not hard gate). Dispatch and independence model: [`../al-second-opinion/SKILL.md`](../al-second-opinion/SKILL.md).

### Pass: continue, then flip on the functional gate

Functional outcome matches → move to next step; last step of scenario → next scenario. All scenarios functionally pass + pre-flight batch green + second-opinion reconciled → flip `status=done` on the comment-anchor line, sync heading marker to `[x]`. Materialise usability findings as candidate tasks in the slice (non-gating; triaged like `/al-code-review` findings — `/grill-me` adjudicates ambiguous ones). Then flip every technical task in the *next* slice (slice whose first technical task carries `Depends on:` this verify task) from `blocked` to `ready`, so `/al-implement` picks up cleanly. Cross-slice gate is the only mechanism that opens the next slice; without this flip the pipeline stalls. Run the Gate report. The human can review the captured frames and findings and override the flip.

### Partial walks survive session boundaries

Session interrupted mid-walk leaves the verify task at `in-progress` with a partial record inline (which scenario / step the walk reached). Re-entering this skill on an `in-progress` verify task resumes from the next undriven step; do not restart from `T-NNN#1`. Inline record is the resume point.

## Gate event

Once when the verify task flips to `done`. Gate report names slice (slug + `event-model.md` step), what the agent confirmed in BC vocabulary (Role action, Business Event, View state, Status value), the usability findings surfaced (→ candidate tasks), the evidence captured, the second-opinion outcome (reconciled / skipped), next handoff: `/al-implement` on first technical task of next slice (or `/al-refine` if its Tests slot is empty), or `/al-code-review` per-feature if this was the last slice.

Gate report on failure (flipping to `blocked`) is the Stop shape from [voice-contract.md](../../references/voice-contract.md): one stop line naming scenario / step / observed-vs-expected, state table (verify task ID, scenarios completed, scenario blocked on), next action (route to `/al-steer`).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-page-script` committed the slice's `.yml` at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml` (which itself runs after `/al-code-review` per-slice flipped the verify task `blocked` → `ready`) |
| **Hands off to**   | next slice's first technical task (`/al-refine` if Tests empty, else `/al-implement`); or `/al-code-review` per-feature if this was last slice. `/al-steer` on failure (after `status=blocked`, whether pre-flight red or functional-walk fail). Usability findings → candidate tasks in the slice. |
| **Uses**           | `new-agent-container.ps1` (three spawns per cycle), `pagescript-replay.ps1` (batch mode for spawn #1's pre-flight), `publish-apps.ps1` (spawn #2 publish before the agent walk), `claude-in-chrome` (spawn #2 drives the walk + captures evidence), `/al-second-opinion` (verdict review before the gate), [`../../references/test-strategy.md`](../../references/test-strategy.md) (layer + checking-vs-testing frame) |
| **Replan venue**   | `/al-steer` — trigger #4 (pre-flight prior-slice red), trigger #8 (pre-flight current-slice red or functional-walk fail) |
| **Sidebands**      | `/grill-me` (adjudicate an ambiguous usability finding, or whether an observation matches the expected outcome), `/al-research` (BC surface behaviour to verify against documentation) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping the verify task to `done`. The flip greenlights the next slice; if the agent's functional verdict doesn't actually cover every scenario step the plan named — or rests on inference rather than an observed, evidenced value — the gate is theatre. (This is the Claude-Code-local complement to the cross-runtime `/al-second-opinion` gate above.)

</claude-only>
