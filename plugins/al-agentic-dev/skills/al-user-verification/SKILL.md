---
name: al-user-verification
description: Guide the user through one slice's `ready-for-verification` verify task in tasks.md for AL/Business Central. User drives the browser and reports observations; agent runs containers, publish, pre-flight, and Contract checks, asks one check at a time, records, and routes. Functional outcomes gate, usability observations become findings → tasks; ask-before-reveal + al-second-opinion coverage review guard against leading the witness.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-user-verification, Run a slice's Verification Plan

Pick a `ready-for-verification` verify task. Run its fresh `Verification Plan`: pre-flight E2E recordings, execute Contract examples with the named client/harness, then guide the user through E2E examples and Exploration charters in their own browser — one instruction at a time, agent records the answers and routes. All functional-pass + required pre-flight checks + second-opinion-reconciled → flip `done`, hand off to the next slice's technical tasks (or `/al-code-review` per-feature if this was the last slice). Any functional fail → flip `blocked`, record inline, route to `/al-steer` with trigger #8.

**User is the runner; agent is the guide.** The agent operates everything mechanical — container spawns, publish, pre-flight regression batch, Contract examples, status flips, the transcript — and turns each Journey Example / Exploration Charter into single concrete instructions the user performs in the BC Web Client. The user's eyes are the oracle; the user never reads `tasks.md` or the plan grammar — they click, look, and answer. No AL writes, no `/al-build` run, no codebase walk (page-ID lookup for deep links permitted). Two outcome dimensions split by *checking vs testing*: **functional/observable** outcomes (a Status value, a cue count, an HTTP status, an error) are *checked* — read off the screen by the user — and **gate** the verify task; **subjective usability** outcomes (clunky, unclear, flow isn't one motion) are *sapient testing* → **findings → tasks**, never a gate. Two guards against leading the witness: **ask-before-reveal** (the agent asks what the user sees before naming the expected value), and `/al-second-opinion` reviews the written verdict for coverage (every check asked and answered with an observed value).

**Layer.** Owns E2E pre-flight, Contract checks, and the exploratory layer (see [`test-strategy.md`](../../references/test-strategy.md)). Per checking-vs-testing: functional outcomes gate; subjective usability is findings → tasks. The user is the direct sapient oracle; `/al-second-opinion` guards coverage and routing, not their eyes.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside in-flight feature.
- `specs/<branch>/tasks.md` holds `kind=verify` task with `status=ready-for-verification` and populated `Verification Plan`. Plain `ready` → **Stop**, `/al-refine T-NNN`. `ready-for-verification` with an empty plan → **Stop**, `/al-steer`; status and proof disagree. `blocked` → `/al-steer`. `done` → downstream evidence exists; do not reopen here.
- `review=clean` present on the verify task's comment-anchor line. `status=ready-for-verification` alone means only that `/al-refine` wrote fresh proof — the byte reads identically before and after review; the marker is the durable clean per-slice `/al-code-review` evidence. Missing → **Stop**, re-enter via `/al-code-review T-NNN` (or `/al-implement` if technical tasks are still open), not here.
- `event-model.md` present alongside; verify tasks only exist for user/API-facing features. Verify task without `event-model.md` → contract violation, **Stop**, route to `/al-steer`.
- Read [`test-specification.md`](../../references/test-specification.md) and [`test-strategy.md`](../../references/test-strategy.md) before guiding; this skill consumes the `Verification Plan` grammar and layer rules.
- Inline partial-run record present → resume at example granularity (see *Partial walks* below): completed examples stay closed, the in-flight example restarts from its first action. No partial-run record → start from the first example. Status is `ready-for-verification` in both cases; the inline record is the differentiator.
- Latest code published to verification environment. Skill spawns its own fresh container per cycle (see *Container lifecycle* below); user does not need to publish manually. Skill does not run the inner `/al-build`-test loop; container spawn covers publish.
- If the plan has `Journey Examples`, the slice's bc-replay recording exists at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Missing → **Stop**, `Next: /al-page-script T-NNN`. The pre-flight regression batch runs the slice's `.yml` plus every prior slice's `.yml` before the user is invited in.
- If the plan has `Contract Examples`, the named client/harness is available and configured for the verification environment. Missing harness/config → **Stop**, surface exact blocker.
- **A human drives every walkable scope.** `Journey Examples` / `Exploration Charters` are user-driven; there is no agent-driven substitute. Contract-only plans (no walkable scope) have no walk — every check is agent-run against captured client output. **Autonomous seat** (selected per `${CLAUDE_SKILL_DIR}/../../references/autonomy-seat.md` — the turn was initiated by the goal evaluator, not a human): a walkable plan never runs — there is no walker; `/al-autopilot` parks *before* this skill, so an autonomous invocation with a walkable plan is a routing error → emit the `AUTONOMY STOP REPORT` yourself (blocker `verify walk T-NNN is user-driven`, resume `/al-user-verification T-NNN` then relaunch `/al-autopilot`) — merely ending the turn re-fires the evaluator into the same misroute until the turn cap. A Contract-only plan may run autonomously to the gate. Degraded verification never flips `done`.
- **Login is the user's.** Agent surfaces the Web Client URL and the throwaway dev credentials ready to paste: `container.username` / `container.password` from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`). User-authorized, non-secret. Local container hosts only (`http://<container>/BC/`) — never `*.dynamics.com` or any non-local host. User cannot reach the container URL → **Stop**, fix environment, re-enter; never substitute an agent walk.

## Container lifecycle

Three `new-agent-container.ps1` spawns per cycle. Fresh-each-time discipline isolates verification from prior session state and leaves the next consumer with a clean container.

**Spawn #1 (pre-flight).** `new-agent-container.ps1` → `publish-apps.ps1` → `pagescript-replay.ps1` (batch mode, every `pagescripts/recordings/*.yml`) when E2E recordings exist. Three explicit primitives: fresh container, publish all configured apps, run the regression batch. Catches both current-slice regressions and cross-slice collisions before the user spends a minute walking. Green → continue. Red → flip verify task `status=blocked`, record transcript with `**Replan flag**: trigger #4 (sibling now wrong)` for any prior-slice `.yml` red, `**Replan flag**: trigger #8 (verification failed)` for current-slice red. Announce route to `/al-steer T-NNN`. Run spawn #3 for cleanup and exit. No E2E recordings → publish only, then continue to Contract / Exploration work.

**Spawn #2 (contract check + guided walk).** Only on pre-flight green. `new-agent-container.ps1` → `publish-apps.ps1` → run Contract examples through their named client/harness (agent-run, no user involvement), then hand the user the Web Client URL (`http://<container-name>/BC/`), the credentials per the Preconditions login grant, and a deep link to the starting page (`http://<container>/BC/?page=<id>`, page ID read from the page AL — the user's first action lands on the right screen, not hunting Tell Me), and guide the walk one instruction at a time. This handover lives here and only here: spawn #1/#2 each recreate the container, so a user invited in earlier gets their session killed mid-walk or clicks against a container the replay batch is mutating. Symmetric with spawn #1's first two primitives; no replay step (batch already greened on spawn #1). Evidence is the transcript of the user's verbatim answers plus any saved screenshots.

**Spawn #3 (exit).** Always runs at end of cycle, pass or fail. `new-agent-container.ps1` only — leaves a fresh container for the next consumer (next slice's `/al-implement`, or merge prep). Skill exits after spawn returns.

Spawn invocations:
- container spawn (any): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/new-agent-container.ps1"`
- publish all apps (spawn #1, #2): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/publish-apps.ps1"`
- batch replay (spawn #1): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1"`

## What this session answers

- **Which slice in flight?** One `T-NNN` of `kind=verify`, named in opener with its `slice=` value and matching `event-model.md` timeline step.
- **What is the user exercising?** Read `Verification Plan`: `Journey Examples`, `Contract Examples`, and `Exploration Charters`. Agent translates each into single instructions; the user performs and reports. Contract examples run agent-side.
- **Did every checkable example functionally pass?** Per `E2E` example, the user reports the observed value; the agent records observed-vs-expected verbatim from the user's words. Per `Contract` example, the agent executes and matches `Observable Checks` against captured output.
- **What usability findings surfaced?** Any friction the user mentions in their own words (clunky flow, unclear label, slow refresh) — agent classifies, records as findings, routes to tasks, **not** gating.
- **What flips at end?** `status=` goes `ready-for-verification` → `done` on full functional-pass (+ batch-green + second-opinion reconciled) or `blocked` on first functional fail. No partial-pass state and no `in-progress` status.

Unanswerable → halt. *"User can't reach the container URL"* → **Stop**, fix environment, re-enter. *"The sandbox is down"* → **Stop**, fix environment, re-enter. *"The example references a page/API/client that doesn't exist"* → trigger #8, route to `/al-steer`.

## Workflow

### Opener, sized for a human

Announce verify task: `T-NNN` ID, slice slug, counts by scope (`E2E`, `Contract`, `Exploration`), estimated walk length (*"6 steps, ~5 minutes"*), first example. No URL or credentials yet — that handover happens inside spawn #2 (*Container lifecycle*), after pre-flight greens and Contract checks run. Leave status `ready-for-verification` while guiding checks. One example open at a time; running three in parallel loses failure context when one goes red.

### Guide the walk, ask before revealing

Per `E2E` action: give one concrete instruction in BC vocabulary — *"You're on Sales Orders. Click **Post**, choose **Ship and Invoice**."* — and wait. Never a wall of steps to follow from memory. Per `Contract` action: agent runs the named client/harness and captures request/response or harness output; no user involvement. Then judge two dimensions:

- **Functional (checking, gates).** Ask for the observed value **before** naming the expected one: *"What does the Status field show now?"*, never *"Does Status say Released?"*. Where the runtime offers a structured question UI (Claude Code: `AskUserQuestion`) **and the observable is a closed enumerable field** (an option field like `Status`), present the field's full value range as options plus *"Something else — describe"*; never flag the expected value, never a bare yes/no on it. Open-ended observables (counts, error text, HTTP bodies) get a free-text question — improvising a short option list around the expected value re-introduces leading by inclusion. Record observed-vs-expected verbatim from the user's words (*"Status = Released"* / *"cue stayed at 2, expected 3"* / *"HTTP 400 returned"*). The value comes from the user's screen or the captured client output; never infer it from what the AL "should" do.
- **Usability (testing, findings).** For Exploration Charters, give the prompt, let the user wander and narrate. Friction in their own words — clunky sequencing, ambiguous caption, slow or missing refresh, error message that reads wrong — the agent classifies each remark (functional fail vs usability finding) and confirms the classification in one line so misfiles are catchable. Observations, not gate signals unless a functional failure surfaces.

An action's expected outcome is implicit and observable checks are listed later → wait for the check to ask for the functional observation; do not gate on the action alone.

### Pre-flight failure routing (spawn #1 red)

Pre-flight batch surfaces failures BEFORE the user is invited in. Two failure shapes; both route to `/al-steer` but the trigger names what `/al-steer` is being asked to triage.

- **Current slice's `.yml` red.** The recording `/al-page-script` just generated and committed fails on a fresh container. `/al-page-script`'s example-by-example inner loop ran replay-validation per example, so a current-slice pre-flight red means the failure didn't surface inside that loop — likely a non-deterministic recording (timing-dependent assertion, flaky locator), or a real regression introduced between `/al-page-script`'s green and `/al-user-verification`'s entry (a hotfix commit, a CI republish of a different version). Flag `**Replan flag**: trigger #8 (verification failed)`. `/al-steer` triages: re-author the Journey Example (rewrite via `/al-refine`) if the recording is fragile, or insert a `Fixes:` task in the current slice if a real defect surfaced.

- **Prior slice's `.yml` red.** A recording from an earlier slice's verify task fails on the current slice's published code. Current slice introduced a change that broke the prior slice's user-facing surface — a renamed action, removed field, altered factbox refresh shape, changed Status-flip behaviour. Flag `**Replan flag**: trigger #4 (sibling now wrong)`. `/al-steer` triages: regenerate the prior slice's `.yml` via `/al-page-script` if the surface change was intentional (the prior recording is stale, not wrong), rewrite the prior slice's Verification Plan via `/al-refine` if the change invalidates the user-facing contract, or insert a `Fixes:` task in the current slice if the surface change was unintentional regression. Re-opening a prior slice's verify task is a `/al-steer` decision, not this skill's.

Mixed-red (both current AND prior slices red) is one root cause more often than two; transcript names every failed `.yml`, both flags stamped, `/al-steer` picks one.

Flip `status=blocked` on the comment-anchor line, stripping `review=clean` in the same Edit, sync heading marker to `[!]`. Run spawn #3 for cleanup before exiting.

### Functional fail: stop the example, flip blocked, route

First functional fail in any E2E/Contract example, or functional failure discovered during Exploration: stop the walk/check. Do not continue to later steps in the same example, do not move to later examples. E2E/Exploration fail → ask the user for a screenshot at the failure moment — the one point where visual evidence pays — save it under `.output/verification/T-NNN/` (gitignored; transient triage evidence belongs there) and reference that path in the inline record so `/al-steer` finds it in a later session. Contract fail → the captured request/response is the evidence; there is no screen to shoot. Record inside the task block:

- Which example (`V#`, `C#`, or `X#`) and which step/check/prompt.
- Observed vs expected, verbatim from the user's report (or captured client output), with any saved screenshot referenced by its `.output/verification/T-NNN/` path.
- `**Replan flag**: trigger #8 (verification failed)`.

Flip `status=blocked` on the task's comment-anchor line, sync heading marker to `[!]`. The flip strips `review=clean` in the same Edit — the live line carries the marker (this skill's precondition required it); anchoring on a marker-less form fails the byte match. Edit shape:

```
old_string: <!-- task=T-NNN status=ready-for-verification slice=<slug> kind=verify review=clean -->
new_string: <!-- task=T-NNN status=blocked slice=<slug> kind=verify -->
```

Announce route to `/al-steer T-NNN`. `/al-steer` decides between defect (insert `Fixes:` task in same `slice=`), wrong Verification Plan (rewrite via `/al-refine`), wrong slice boundary (split via `/al-scope`). This skill does not propose the fix; surface failure and stop. A usability finding is **never** a functional fail — it does not stop the walk or block the gate.

### Second opinion before the gate

All checkable examples pass → before flipping `done`, run `/al-second-opinion` on the written verdict. Compose the artifact: per example/charter, the instruction given, **the exact question as posed — verbatim, including any structured-question options offered**, the user's verbatim reported observation (or captured client output), the expected value, evidence reference, and usability findings with their classification. The question goes in as asked, never paraphrased — a neutral paraphrase of a led question hides exactly the defect this gate exists to catch. The gate reviews **coverage and routing**: was every observable check and prompt asked and answered with an observed value; did any pass rest on a led question, a bare yes/no, or an inferred value; was every user remark routed correctly (functional vs usability). It does not re-see the screen — the user already did; that is the point of the mode. Reconcile returned bullets per line: real coverage gap → re-ask that check; real routing gap → re-classify and re-state verdict. `Second opinion skipped: …` → absorb and proceed (checkpoint, not hard gate). Dispatch and independence model: [`../al-second-opinion/SKILL.md`](../al-second-opinion/SKILL.md).

### Pass: continue, then flip on the functional gate

Functional outcome matches → move to next check. Last check of example → append the example's line to the inline partial-run record inside the task block (example ID, verdict, observed values) — this incremental append is what makes interruption survivable; an interruption gives no exit moment to write — then next example/charter. All checkable examples pass + required pre-flight checks green + second-opinion reconciled → flip `status=done` on the comment-anchor line, stripping `review=clean` in the same Edit (the marker is transient evidence; `done` already means downstream evidence exists), sync heading marker to `[x]`. Materialise usability findings as candidate tasks in the slice (non-gating; triaged like `/al-code-review` findings — `/grill-me` adjudicates ambiguous ones). Then flip every technical task in the *next* slice (slice whose first task carries `Depends on:` this verify task) from `blocked` to `ready`, so `/al-refine` picks up cleanly. Cross-slice gate is the only mechanism that opens the next slice; without this flip the pipeline stalls. Run the Gate report. The gate flips on the user's own reported observations; the user can halt or veto at any step.

### Partial walks survive session boundaries

Session interrupted mid-walk leaves the verify task at `ready-for-verification` with the incrementally appended partial record inline (written per completed example in the Pass step — an interruption gives no exit moment to write, so the last appended line *is* the resume point). Humans get interrupted far more than agents; this is the normal case, not the exception. Re-entry resumes at **example granularity**: completed examples stay closed — do not make the user re-walk greens — but the in-flight example restarts from its first action, because re-entry spawns fresh containers and the data its earlier actions created is gone; resuming mid-example would ask about records that no longer exist. Re-ask only that example's checks.

## Gate event

Once when the verify task flips to `done`. Gate report names slice (slug + `event-model.md` step), what the user confirmed in BC vocabulary (Role action, Business Event, View state, Status value, API/client result), the usability findings surfaced (→ candidate tasks), the evidence (transcript + any saved screenshots), the second-opinion outcome (reconciled / skipped), next handoff: `/al-refine` on first technical task of next slice; or, if this was the last slice, **open the `kind=breaking-change` task `blocked` → `ready`** (its `Depends on:` this verify task is now satisfied — this skill is its named flip-owner) and hand off to `/al-validate-breaking-changes`, then `/al-code-review` per-feature.

Gate report on failure (flipping to `blocked`) is the Stop shape from [voice-contract.md](../../references/voice-contract.md): one stop line naming example / check / observed-vs-expected, state table (verify task ID, examples completed, example blocked on), next action (route to `/al-steer`).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-page-script` committed the slice's `.yml` when `Journey Examples` exist, and `/al-code-review` per-slice stamped `review=clean` on the verify task at `ready-for-verification` |
| **Hands off to**   | next slice's technical tasks opened to `ready` for `/al-refine`; or — if this was the last slice — the `kind=breaking-change` task opened `blocked` → `ready`, then `/al-validate-breaking-changes` (then `/al-code-review` per-feature). `/al-steer` on failure (after `status=blocked`, whether pre-flight red or functional-walk fail). Usability findings → candidate tasks in the slice. |
| **Uses**           | `new-agent-container.ps1` (three spawns per cycle), `pagescript-replay.ps1` (batch mode for spawn #1's pre-flight), `publish-apps.ps1` (spawn #1, #2 publish before the walk), Web Client deep links + `al-build.json` credentials (the user's entry into the walk), `/al-second-opinion` (coverage review before the gate), [`../../references/test-specification.md`](../../references/test-specification.md) (`Verification Plan` grammar), [`../../references/test-strategy.md`](../../references/test-strategy.md) (layer + checking-vs-testing frame) |
| **Replan venue**   | `/al-steer` — trigger #4 (pre-flight prior-slice red), trigger #8 (pre-flight current-slice red or functional-walk fail) |
| **Sidebands**      | `/grill-me` (adjudicate an ambiguous usability finding, or whether an observation matches the expected outcome), `/al-research` (BC surface behaviour to verify against documentation) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before flipping the verify task to `done`. The flip greenlights the next slice; if the verdict doesn't cover every observable check the plan named with a user-reported value — or any pass rests on a led question or an inferred value rather than what the user said they saw — the gate is theatre. (This is the Claude-Code-local complement to the cross-runtime `/al-second-opinion` coverage gate above.)

</claude-only>
