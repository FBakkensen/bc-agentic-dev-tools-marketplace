---
name: al-user-verification
description: Drive the agent browser through one slice's `ready-for-verification` verify task in tasks.md for AL/Business Central. Agent runs and judges; functional outcomes gate, usability observations become findings → tasks; al-second-opinion + visual evidence guard against gate theatre.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-user-verification, Run a slice's Verification Plan

Pick a `ready-for-verification` verify task. Run its fresh `Verification Plan`: pre-flight E2E recordings, execute Contract examples with the named client/harness, drive E2E examples and Exploration charters through the browser, capture evidence, judge observable outcomes. All functional-pass + required pre-flight checks + second-opinion-reconciled → flip `done`, hand off to the next slice's technical tasks (or `/al-code-review` per-feature if this was the last slice). Any functional fail → flip `blocked`, record inline, route to `/al-steer` with trigger #8.

**Agent is the runner.** It drives the browser for `E2E` and `Exploration`, runs or coordinates the named client for `Contract`, captures evidence, and judges. No AL writes, no `/al-build` run, no codebase walk. Two outcome dimensions split by *checking vs testing*: **functional/observable** outcomes (a Status value, a cue count, an HTTP status, an error) are *checked* and **gate** the verify task; **subjective usability** outcomes (clunky, unclear, flow isn't one motion) are *sapient testing* → **findings → tasks**, never an opaque agent thumbs-up and never a gate on the agent's opinion. Two guards against gate theatre: `/al-second-opinion` reviews the written verdict (reasoning/coverage gaps), durable visual evidence lets the human spot-check observation.

**Layer.** Owns E2E pre-flight, Contract checks, and the exploratory layer (see [`test-strategy.md`](../../references/test-strategy.md)). Per checking-vs-testing: functional outcomes gate; subjective usability is findings → tasks. `/al-second-opinion` guards reasoning, visual evidence guards observation — neither replaces the human, who can review the evidence and override.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside in-flight feature.
- `specs/<branch>/tasks.md` holds `kind=verify` task with `status=ready-for-verification` and populated `Verification Plan`. Plain `ready` → **Stop**, `/al-refine T-NNN`. `ready-for-verification` with an empty plan → **Stop**, `/al-steer`; status and proof disagree. `blocked` → `/al-steer`. `done` → downstream evidence exists; do not reopen here.
- `review=clean` present on the verify task's comment-anchor line. `status=ready-for-verification` alone means only that `/al-refine` wrote fresh proof — the byte reads identically before and after review; the marker is the durable clean per-slice `/al-code-review` evidence. Missing → **Stop**, re-enter via `/al-code-review T-NNN` (or `/al-implement` if technical tasks are still open), not here.
- `event-model.md` present alongside; verify tasks only exist for user/API-facing features. Verify task without `event-model.md` → contract violation, **Stop**, route to `/al-steer`.
- Read [`test-specification.md`](../../references/test-specification.md) and [`test-strategy.md`](../../references/test-strategy.md) before driving; this skill consumes the `Verification Plan` grammar and layer rules.
- Inline partial-run record present → resume from the next undriven check. No partial-run record → start from the first check. Status is `ready-for-verification` in both cases; the inline record is the differentiator.
- Latest code published to verification environment. Skill spawns its own fresh container per cycle (see *Container lifecycle* below); user does not need to publish manually. Skill does not run the inner `/al-build`-test loop; container spawn covers publish.
- If the plan has `Journey Examples`, the slice's bc-replay recording exists at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Missing → **Stop**, `Next: /al-page-script T-NNN`. The pre-flight regression batch runs the slice's `.yml` plus every prior slice's `.yml` before the browser walk.
- If the plan has `Contract Examples`, the named client/harness is available and configured for the verification environment. Missing harness/config → **Stop**, surface exact blocker.
- `claude-in-chrome` drives browser work. The skill connects/selects a browser as part of spawn #2. **Login is permitted.** Agent types `container.username` / `container.password` from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`) into the Web Client's UserPassword form and signs in. User-authorized, non-secret throwaway dev credentials. Local container hosts only (`http://<container>/BC/`) — never `*.dynamics.com` or any non-local host. Login form ≠ can't-drive; never route to the human walk over credentials. If a browser genuinely cannot be driven, **fall back** to facilitating a human walk against the surfaced URL (agent reads each Journey Example or Exploration Charter, user reports what they saw) — the gate flips on the same functional criteria either way. **Autonomous seat** (`/al-autopilot` run active — `AUTONOMY RUN ACTIVE` announced, `decision-log.md` carries an open run): never offer the human walk — there is no walker. Return the browser failure to the caller; `/al-autopilot`'s infrastructure ladder and stop report own what happens next. Degraded verification never flips `done`.

## Container lifecycle

Three `new-agent-container.ps1` spawns per cycle. Fresh-each-time discipline isolates verification from prior session state and leaves the next consumer with a clean container.

**Spawn #1 (pre-flight).** `new-agent-container.ps1` → `publish-apps.ps1` → `pagescript-replay.ps1` (batch mode, every `pagescripts/recordings/*.yml`) when E2E recordings exist. Three explicit primitives: fresh container, publish all configured apps, run the regression batch. Catches both current-slice regressions and cross-slice collisions before the agent walk. Green → continue. Red → flip verify task `status=blocked`, record transcript with `**Replan flag**: trigger #4 (sibling now wrong)` for any prior-slice `.yml` red, `**Replan flag**: trigger #8 (verification failed)` for current-slice red. Announce route to `/al-steer T-NNN`. Run spawn #3 for cleanup and exit. No E2E recordings → publish only, then continue to Contract / Exploration work.

**Spawn #2 (agent walk + contract check).** Only on pre-flight green. `new-agent-container.ps1` → `publish-apps.ps1` → run Contract examples through their named client/harness, then drive `claude-in-chrome` against the BC Web Client URL (`http://<container-name>/BC/`) for Journey Examples and Exploration Charters — sign in per the Preconditions login grant. Symmetric with spawn #1's first two primitives; no replay step (batch already greened on spawn #1). The agent captures durable evidence per example/charter. Chrome can't be driven → fall back to a facilitated human walk against the same URL.

**Spawn #3 (exit).** Always runs at end of cycle, pass or fail. `new-agent-container.ps1` only — leaves a fresh container for the next consumer (next slice's `/al-implement`, or merge prep). Skill exits after spawn returns.

Spawn invocations:
- container spawn (any): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/new-agent-container.ps1"`
- publish all apps (spawn #1, #2): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/publish-apps.ps1"`
- batch replay (spawn #1): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1"`

## What this session answers

- **Which slice in flight?** One `T-NNN` of `kind=verify`, named in opener with its `slice=` value and matching `event-model.md` timeline step.
- **What is the agent exercising?** Read `Verification Plan`: `Journey Examples`, `Contract Examples`, and `Exploration Charters`. Drive the relevant surface or client and observe the result.
- **Did every checkable example functionally pass?** Per `E2E` / `Contract` example, execute actions and match `Observable Checks`. The agent records observed-vs-expected with evidence.
- **What usability findings surfaced?** Any friction the walk reveals (clunky flow, unclear label, slow refresh) — recorded as findings, routed to tasks, **not** gating.
- **What flips at end?** `status=` goes `ready-for-verification` → `done` on full functional-pass (+ batch-green + second-opinion reconciled) or `blocked` on first functional fail. No partial-pass state and no `in-progress` status.

Unanswerable → halt. *"Chrome won't drive the surface"* → fall back to the human walk (Preconditions). *"The sandbox is down"* → **Stop**, fix environment, re-enter. *"The example references a page/API/client that doesn't exist"* → trigger #8, route to `/al-steer`.

## Workflow

### Opener, one example at a time

Announce verify task: `T-NNN` ID, slice slug, counts by scope (`E2E`, `Contract`, `Exploration`), first example. Leave status `ready-for-verification` while driving checks. One example open at a time; running three in parallel loses failure context when one goes red.

### Drive examples, observe two dimensions

Per `E2E` action: drive the user-action line via `claude-in-chrome`, observe what renders, capture a frame. Per `Contract` action: run the named client/harness and capture request/response or harness output. Then judge two dimensions:

- **Functional (checking, gates).** Match observable checks. State observed-vs-expected verbatim (*"Status = Released"* / *"cue stayed at 2, expected 3"* / *"HTTP 400 returned"*). Read the value from the screen or client output; do not infer it from what the AL "should" do. Evidence is required.
- **Usability (testing, findings).** For Exploration Charters, follow prompts and note friction: clunky sequencing, ambiguous caption, slow or missing refresh, error message that reads wrong. These are observations, not gate signals unless a functional failure is discovered.

An action's expected outcome is implicit and observable checks are listed later → wait for the check to capture the functional observation; do not gate on the action alone.

### Pre-flight failure routing (spawn #1 red)

Pre-flight batch surfaces failures BEFORE the agent walks. Two failure shapes; both route to `/al-steer` but the trigger names what `/al-steer` is being asked to triage.

- **Current slice's `.yml` red.** The recording `/al-page-script` just generated and committed fails on a fresh container. `/al-page-script`'s example-by-example inner loop ran replay-validation per example, so a current-slice pre-flight red means the failure didn't surface inside that loop — likely a non-deterministic recording (timing-dependent assertion, flaky locator), or a real regression introduced between `/al-page-script`'s green and `/al-user-verification`'s entry (a hotfix commit, a CI republish of a different version). Flag `**Replan flag**: trigger #8 (verification failed)`. `/al-steer` triages: re-author the Journey Example (rewrite via `/al-refine`) if the recording is fragile, or insert a `Fixes:` task in the current slice if a real defect surfaced.

- **Prior slice's `.yml` red.** A recording from an earlier slice's verify task fails on the current slice's published code. Current slice introduced a change that broke the prior slice's user-facing surface — a renamed action, removed field, altered factbox refresh shape, changed Status-flip behaviour. Flag `**Replan flag**: trigger #4 (sibling now wrong)`. `/al-steer` triages: regenerate the prior slice's `.yml` via `/al-page-script` if the surface change was intentional (the prior recording is stale, not wrong), rewrite the prior slice's Verification Plan via `/al-refine` if the change invalidates the user-facing contract, or insert a `Fixes:` task in the current slice if the surface change was unintentional regression. Re-opening a prior slice's verify task is a `/al-steer` decision, not this skill's.

Mixed-red (both current AND prior slices red) is one root cause more often than two; transcript names every failed `.yml`, both flags stamped, `/al-steer` picks one.

Flip `status=blocked` on the comment-anchor line, stripping `review=clean` in the same Edit, sync heading marker to `[!]`. Run spawn #3 for cleanup before exiting.

### Functional fail: stop the example, flip blocked, route

First functional fail in any E2E/Contract example, or functional failure discovered during Exploration: stop the walk/check. Do not continue to later steps in the same example, do not move to later examples. Record inside the task block:

- Which example (`V#`, `C#`, or `X#`) and which step/check/prompt.
- Observed vs expected, read off the screen, with the captured frame referenced.
- `**Replan flag**: trigger #8 (verification failed)`.

Flip `status=blocked` on the task's comment-anchor line, sync heading marker to `[!]`. The flip strips `review=clean` in the same Edit — the live line carries the marker (this skill's precondition required it); anchoring on a marker-less form fails the byte match. Edit shape:

```
old_string: <!-- task=T-NNN status=ready-for-verification slice=<slug> kind=verify review=clean -->
new_string: <!-- task=T-NNN status=blocked slice=<slug> kind=verify -->
```

Announce route to `/al-steer T-NNN`. `/al-steer` decides between defect (insert `Fixes:` task in same `slice=`), wrong Verification Plan (rewrite via `/al-refine`), wrong slice boundary (split via `/al-scope`). This skill does not propose the fix; surface failure and stop. A usability finding is **never** a functional fail — it does not stop the walk or block the gate.

### Second opinion before the gate

All checkable examples pass → before flipping `done`, run `/al-second-opinion` on the written verdict to mitigate gate theatre (the agent judging its own work). Compose the artifact: per example/charter, the actions driven, observed-vs-expected functional outcome, evidence reference, and usability findings. The gate reviews **reasoning and coverage**: does the verdict address every observable check and prompt; does any pass rest on inference rather than observed value. It is text-only: it cannot see the browser/client output, so it does not catch a misread screen — captured evidence does. Reconcile returned bullets per line: real coverage gap → re-run that example; real reasoning gap → re-state verdict. `Second opinion skipped: …` → absorb and proceed (checkpoint, not hard gate). Dispatch and independence model: [`../al-second-opinion/SKILL.md`](../al-second-opinion/SKILL.md).

### Pass: continue, then flip on the functional gate

Functional outcome matches → move to next check; last check of example → next example/charter. All checkable examples pass + required pre-flight checks green + second-opinion reconciled → flip `status=done` on the comment-anchor line, stripping `review=clean` in the same Edit (the marker is transient evidence; `done` already means downstream evidence exists), sync heading marker to `[x]`. Materialise usability findings as candidate tasks in the slice (non-gating; triaged like `/al-code-review` findings — `/grill-me` adjudicates ambiguous ones). Then flip every technical task in the *next* slice (slice whose first task carries `Depends on:` this verify task) from `blocked` to `ready`, so `/al-refine` picks up cleanly. Cross-slice gate is the only mechanism that opens the next slice; without this flip the pipeline stalls. Run the Gate report. The human can review captured evidence and findings and override the flip.

### Partial walks survive session boundaries

Session interrupted mid-walk leaves the verify task at `ready-for-verification` with a partial record inline (which example/check the run reached). Re-entering this skill on the same `ready-for-verification` verify task resumes from the next undriven check; do not restart from the first example. Inline record is the resume point.

## Gate event

Once when the verify task flips to `done`. Gate report names slice (slug + `event-model.md` step), what the agent confirmed in BC vocabulary (Role action, Business Event, View state, Status value, API/client result), the usability findings surfaced (→ candidate tasks), the evidence captured, the second-opinion outcome (reconciled / skipped), next handoff: `/al-refine` on first technical task of next slice; or, if this was the last slice, **open the `kind=breaking-change` task `blocked` → `ready`** (its `Depends on:` this verify task is now satisfied — this skill is its named flip-owner) and hand off to `/al-validate-breaking-changes`, then `/al-code-review` per-feature.

Gate report on failure (flipping to `blocked`) is the Stop shape from [voice-contract.md](../../references/voice-contract.md): one stop line naming example / check / observed-vs-expected, state table (verify task ID, examples completed, example blocked on), next action (route to `/al-steer`).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-page-script` committed the slice's `.yml` when `Journey Examples` exist, and `/al-code-review` per-slice stamped `review=clean` on the verify task at `ready-for-verification` |
| **Hands off to**   | next slice's technical tasks opened to `ready` for `/al-refine`; or — if this was the last slice — the `kind=breaking-change` task opened `blocked` → `ready`, then `/al-validate-breaking-changes` (then `/al-code-review` per-feature). `/al-steer` on failure (after `status=blocked`, whether pre-flight red or functional-walk fail). Usability findings → candidate tasks in the slice. |
| **Uses**           | `new-agent-container.ps1` (three spawns per cycle), `pagescript-replay.ps1` (batch mode for spawn #1's pre-flight), `publish-apps.ps1` (spawn #2 publish before the agent walk), `claude-in-chrome` (spawn #2 drives the walk + captures evidence), `/al-second-opinion` (verdict review before the gate), [`../../references/test-specification.md`](../../references/test-specification.md) (`Verification Plan` grammar), [`../../references/test-strategy.md`](../../references/test-strategy.md) (layer + checking-vs-testing frame) |
| **Replan venue**   | `/al-steer` — trigger #4 (pre-flight prior-slice red), trigger #8 (pre-flight current-slice red or functional-walk fail) |
| **Sidebands**      | `/grill-me` (adjudicate an ambiguous usability finding, or whether an observation matches the expected outcome), `/al-research` (BC surface behaviour to verify against documentation) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping the verify task to `done`. The flip greenlights the next slice; if the agent's functional verdict doesn't actually cover every observable check the plan named — or rests on inference rather than an observed, evidenced value — the gate is theatre. (This is the Claude-Code-local complement to the cross-runtime `/al-second-opinion` gate above.)

</claude-only>
