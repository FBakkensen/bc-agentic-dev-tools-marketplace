---
name: al-user-verification
description: Guide the user through one slice's `ready-for-verification` verify task in the `tasks/` folder for AL/Business Central — punchline-first, one scenario at a time, in chat. The user walks the non-recorded Journey Examples in their own browser and reports what they see; the agent runs containers, the pre-flight recording batch, and Contract checks, asks one check at a time (ask-before-reveal), records, and routes. Functional outcomes gate; usability observations become findings → tasks.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-user-verification — Walk a slice's Verification Plan

Pick a `ready-for-verification` verify task. Run its fresh `Verification Plan`: pre-flight the slice's recording batch, run Contract examples against the named client, then guide the user — **one scenario at a time, in chat, punchline first** — through the **non-recorded** Journey Examples (`Record: no`) and the Exploration Charters in their own browser. The recorded scenarios (`Record: yes`) the user already walked live while recording in `/al-page-script`, and the pre-flight batch re-confirms them on a fresh container — they are **not re-walked**. All functional-pass + pre-flight green + second-opinion-reconciled → flip `done`, hand off to the next slice (or `/al-validate-breaking-changes` then `/al-code-review` if last). Any functional fail → flip `blocked`, record inline, route to `/al-steer` with trigger #8.

**User is the runner; agent is the guide.** The agent operates everything mechanical — container spawns, publish, the pre-flight regression batch, Contract examples, status flips, the transcript — and turns each `Record: no` Journey Example and each Exploration Charter into single concrete instructions the user performs in the BC Web Client. The user's eyes are the oracle; the user never reads the task file or the plan grammar — they click, look, and answer. No AL writes, no `/al-build` run, no codebase walk (page-ID and option/enum value-range lookups for deep links and structured questions are permitted). Two outcome dimensions split by *checking vs testing*: **functional/observable** outcomes (a Status value, a cue count, an HTTP status, an error) are *checked* — read off the screen by the user — and **gate** the verify task; **subjective usability** outcomes (clunky, unclear, flow isn't one motion) are *sapient testing* → **findings → tasks**, never a gate. Two guards against leading the witness: **ask-before-reveal** (the agent asks what the user sees before naming the expected value), and `/al-second-opinion` reviews the written verdict for coverage.

**Layer.** Owns the human-walked subset of E2E (the `Record: no` Journey Examples), Contract checks, and the exploratory layer (see [`test-strategy.md`](../../references/test-strategy.md)). The user is the direct sapient oracle; `/al-second-opinion` guards coverage and routing, not their eyes. The recorded E2E subset is owned by `/al-page-script` and only **re-confirmed** here by the pre-flight replay.

## What gets walked vs replayed

`/al-refine` marks every Journey Example `Record: yes` or `Record: no` (the framework-limitation call — `Record: yes` only where no AL test layer can automate it; see [`test-specification.md`](../../references/test-specification.md)).

| Plan element | Here | Gate |
|---|---|---|
| Journey Example `Record: yes` | **replayed** in the pre-flight batch (spawn #1); the user already eyeballed it live while recording | replay green |
| Journey Example `Record: no` | **walked** by the user, card by card, ask-before-reveal | observed value vs `Observable Checks` |
| Contract Example | agent runs the named client/harness, no user involvement | captured output vs `Observable Checks` |
| Exploration Charter | user wanders the prompt, narrates | usability → findings/tasks (never gates) |

The sign-off accounts for the `Record: yes` scenarios explicitly: they are confirmed by replay, not unseen.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside an in-flight feature.
- `specs/<branch>/tasks/` holds a `kind: verify` task with `status: ready-for-verification` and a populated `Verification Plan`. Plain `ready` → **Stop**, `/al-refine T-NNN`. `ready-for-verification` with an empty plan → **Stop**, `/al-steer`; status and proof disagree. `blocked` → `/al-steer`. `done` → downstream evidence exists; do not reopen here.
- `review: clean` present in the verify task's frontmatter — the durable clean per-slice `/al-code-review` evidence (`ready-for-verification` reads identically before and after review). Missing → **Stop**, re-enter via `/al-code-review T-NNN`.
- `event-model.md` present alongside; verify tasks only exist for user/API-facing features. Verify task without `event-model.md` → contract violation, **Stop**, route to `/al-steer`.
- Read [`test-specification.md`](../../references/test-specification.md) and [`test-strategy.md`](../../references/test-strategy.md) before guiding; this skill consumes the `Verification Plan` grammar (incl. the `Record:` flag) and layer rules.
- Every `Record: yes` Journey Example has its recording at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml`. A missing recording for a `Record: yes` example → **Stop**, `Next: /al-page-script T-NNN`. The pre-flight batch runs the slice's recordings plus every prior slice's before the user is invited in. (A plan with only `Record: no` / `Contract` / `Exploration` and no recordings is valid — skip the batch, go straight to spawn #2.)
- If the plan has `Contract Examples`, the named client/harness is available and configured. Missing harness/config → **Stop**, surface the exact blocker.
- Inline partial-run record present → resume at example granularity (see *Partial walks*). No partial-run record → start from the first walkable example.
- **A human drives every walkable scope.** `Record: no` Journey Examples and Exploration Charters are user-driven; there is no agent-driven substitute. Contract-only plans (no walkable scope) have no walk — every check is agent-run against captured client output. Degraded verification never flips `done`.
- **Login is the user's.** Agent surfaces the Web Client URL and the throwaway dev credentials ready to paste: `container.username` / `container.password` from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`). Local container hosts only — never `*.dynamics.com`. User cannot reach the container URL → **Stop**, fix environment, re-enter.

## Container lifecycle

Three `new-agent-container.ps1` spawns per cycle. Fresh-each-time isolates verification from prior state and leaves the next consumer a clean container.

**Spawn #1 (pre-flight).** `new-agent-container.ps1` → `publish-apps.ps1` → `pagescript-replay.ps1` (batch mode, every `pagescripts/recordings/*.yml`) when recordings exist. Confirms the `Record: yes` scenarios and catches both current-slice regressions and cross-slice collisions before the user walks.

- Green → continue to spawn #2.
- Red → flip verify task `status: blocked`, record `**Replan flag**: trigger #4` for any prior-slice recording red, `**Replan flag**: trigger #8` for a current-slice recording red. Route `/al-steer T-NNN`. Run spawn #3 for cleanup and exit.
- No recordings at all → skip spawn #1; spawn #2 publishes to its own fresh container.

**Spawn #2 (contract check + guided walk).** Only on pre-flight green. `new-agent-container.ps1` → `publish-apps.ps1` → Contract examples (agent-run, no user involvement) → guided walk when walkable scope (`Record: no` Journey Examples or Exploration Charters) exists.

Hand the user:
- Web Client URL: `http://<container-name>/BC/`
- Credentials per the Preconditions login grant
- Deep link to the starting page: `http://<container>/BC/?page=<id>` (page ID read from the page AL)

Contract-only plan → no handover, no walk; the gate judges captured client output. This handover lives here and only here: spawn #1/#2 each recreate the container, so a user invited in earlier gets their session killed mid-walk. Evidence is the transcript of the user's verbatim answers plus any saved screenshots.

**Spawn #3 (exit).** Always runs at end of cycle, pass or fail. `new-agent-container.ps1` only — leaves a fresh container for the next consumer. Skill exits after spawn returns.

Spawn invocations:
- container spawn (any): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/new-agent-container.ps1"`
- publish all apps (spawn #1, #2): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/publish-apps.ps1"`
- batch replay (spawn #1): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1"`

## Workflow

### Opener, sized for a human

Announce the verify task: `T-NNN` id, slice slug + `event-model.md` step, counts by what the user will do — **scenarios to walk** (`Record: no` Journey Examples), exploration charters, and (run agent-side first) contract examples — plus estimated walk length (*"3 scenarios, ~5 minutes"*) **and the infra wait before it** (container spawns + publish run minutes; say so). Name how many `Record: yes` scenarios will be confirmed by replay rather than walked, so the user knows the slice's full coverage. No URL or credentials yet — that handover happens inside spawn #2. Leave status `ready-for-verification` while guiding. One scenario open at a time.

### Guide the walk — punchline first, ask before revealing

Each `Record: no` Journey Example becomes one card. **Punchline first** names the *point of the scenario* — the business outcome being checked — **without** naming the expected field value (that would lead the witness). Then the **Do** bullets (the example's `Action`). Then the agent asks the checks one at a time. The next card opens only after this scenario's checks are answered (the exponential-reveal gate sits between scenarios; the opener gave the count).

> **Scenario 1 of 3 — Releasing a blocked customer's order should be refused.**
> *Open the Web Client (link above) and do these — then I'll ask what you see.*
>
> **Do**
> - Open the Sales Order for the blocked customer
> - Choose **Release**

**Functional (checking, gates).** Ask for the observed value **before** naming the expected one: *"What does the Status field show now?"*, never *"Does Status say Open?"*. For a closed enumerable field (an option/enum like `Status`), use `AskUserQuestion` with the field's full value range plus *"Something else — describe"*. For open-ended observables (counts, error text, HTTP bodies), use a free-text question. Record observed-vs-expected verbatim from the user's words, checked against the example's `Observable Checks`. Never infer the value from what the AL "should" do.

**Usability (testing, findings).** For Exploration Charters, give the charter punchline and prompts, let the user wander and narrate. Friction in their own words — clunky sequencing, ambiguous caption, slow refresh — the agent classifies each remark (functional fail vs usability finding) and confirms the classification in one line so misfiles are catchable. Usability observations are never gate signals.

An action's expected outcome is implicit and observable checks are listed later → wait for the check to ask for the functional observation; do not gate on the action alone. User reports an unexpected surface mid-walk (flicker, sudden navigation, wrong page)? Ask what screen they're on, re-orient via deep link, and re-run the in-flight scenario's remaining checks. Reproducible unexpected navigation is a functional observation (the View state is an observable — it gates); a one-off flicker is a usability finding.

### Pre-flight failure routing (spawn #1 red)

Pre-flight surfaces failures BEFORE the user is invited in. Two failure shapes; both route to `/al-steer` but the trigger names what `/al-steer` is asked to triage.

- **Current slice's recording red.** A recording `/al-page-script` just committed fails on a fresh container — a fragile recording or a regression since its green. Flag `**Replan flag**: trigger #8 (verification failed)`. `/al-steer` triages: guided re-record via `/al-page-script` if fragile, or insert a `fixes:` task if a real defect surfaced.
- **Prior slice's recording red.** An earlier slice's recording fails on the current slice's published code — the current slice broke a prior user-facing surface. Flag `**Replan flag**: trigger #4 (sibling now wrong)`. `/al-steer` triages: regenerate the prior recording via `/al-page-script` if the surface change was intentional, rewrite the prior Verification Plan via `/al-refine` if the contract is invalid, or insert a `fixes:` task if it was unintentional regression.

Mixed-red is one root cause more often than two; the transcript names every failed recording, both flags stamped, `/al-steer` picks one. Flip `status: blocked`, stripping `review: clean` in the same Edit. Run spawn #3 for cleanup before exiting.

### Functional fail: stop the scenario, flip blocked, route

First functional fail in any `Record: no` Journey Example or Contract example, or functional failure during Exploration: **stop**. Do not continue to later checks in the same scenario, do not move to later scenarios.

- Walk/Exploration fail → ask the user to save a screenshot under `.output/verification/T-NNN/` (gitignored; agent cannot persist a chat-pasted image) and reference that path in the inline record so `/al-steer` finds it in a later session.
- Contract fail → captured request/response is the evidence; no screenshot needed.

Record inside the task file: which example (`V#`, `C#`, or `X#`) and which step/check/prompt; observed vs expected verbatim from the user's report (or captured output), screenshot referenced by its `.output/verification/T-NNN/` path; `**Replan flag**: trigger #8 (verification failed)`. Flip `status: blocked`, stripping `review: clean` in the same write — a stale `review: clean` would vouch for a diff it never saw. Announce route to `/al-steer T-NNN`. This skill does not propose the fix; surface failure and stop. A usability finding is **never** a functional fail.

### Second opinion before the gate

All checkable examples pass → before flipping `done`, run `/al-second-opinion` on the written verdict. Tell the user they're free first — the cross-family dispatch can take minutes. Compose the artifact: per scenario/charter, the instruction given, **the exact question as posed — verbatim, including any structured-question options offered and any follow-up questions asked while triaging a remark**, the user's verbatim reported observation (or captured client output), the expected value, evidence reference, and usability findings with their classification; plus the list of `Record: yes` scenarios confirmed by replay (with the pre-flight result). The question goes in as asked, never paraphrased — a neutral paraphrase of a led question hides exactly the defect this gate exists to catch. The gate reviews **coverage and routing**: was every observable check and prompt asked and answered with an observed value; were the replay-confirmed scenarios accounted for; did any pass rest on a led question, a bare yes/no, or an inferred value; was every user remark routed correctly (functional vs usability). It does not re-see the screen. Reconcile per line: real coverage gap → re-ask that check; real routing gap → re-classify and re-state verdict. `Second opinion skipped: …` → absorb and proceed (checkpoint, not hard gate).

### Pass: continue, then flip on the functional gate

- **Check passes** → move to next check.
- **Last check of a scenario** → append the scenario's line to the inline partial-run record (example id, verdict, observed values, exact questions as posed — the second-opinion artifact needs them verbatim, and a session boundary erases the chat transcript). Then move to the next scenario/charter.
- **All checkable examples pass + pre-flight green + second-opinion reconciled** → flip `status: done`, stripping `review: clean` in the same write. Collapse the inline partial-run record into the Closeout shape from [`test-specification.md`](../../references/test-specification.md), including the `Record: yes` scenarios as replay-confirmed.
- **Usability findings** → materialise as candidate task files in the slice, named `NNN-T-MMM-<slug>.md` with a fresh `T-MMM` id and a run-order prefix per the gap rule in [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md), frontmatter `status: ready`, `kind: technical`, same `slice:`. Non-gating; `/grill-me` adjudicates ambiguous ones. They queue *after* the next slice's opened tasks unless the user promotes one.
- **Next slice** → flip every technical task in the next slice (whose first task carries `depends_on:` this verify task) from `blocked` to `ready`. The cross-slice gate is the only mechanism that opens the next slice.

Run the Gate report. The gate flips on the user's own reported observations plus replay-confirmation of the recorded scenarios (Contract-only: captured client output); the user can halt or veto at any step.

### Partial walks survive session boundaries

A session interrupted mid-walk leaves the verify task at `ready-for-verification` with the incrementally appended partial record inline (written per completed scenario in the Pass step). Re-entry resumes at **scenario granularity**: completed scenarios stay closed, but the in-flight scenario restarts from its first action, because re-entry spawns fresh containers and the data its earlier actions created is gone. Re-ask only that scenario's checks. Closed scenarios whose data the in-flight one depends on: re-drive their *actions* as setup on the fresh container without re-asking their checks — their verdicts stand on the record. Contract examples re-run on every spawn #2 (agent-side, free); the recording batch re-runs in spawn #1; only walk scenarios stay closed.

## Gate event

Once when the verify task flips to `done`. Gate report names the slice (slug + `event-model.md` step), what the user confirmed by walking and what was confirmed by replay (the `Record: yes` scenarios) in BC vocabulary (Role action, Business Event, View state, Status value, API/client result), the usability findings surfaced (→ candidate tasks), the evidence (transcript + replay result + any saved screenshots), the second-opinion outcome (reconciled / skipped), next handoff: `/al-refine` on the first technical task of the next slice; or, if this was the last slice, **open the `kind: breaking-change` task `blocked` → `ready`** (its `depends_on:` this verify task is now satisfied — this skill is its named flip-owner) and hand off to `/al-validate-breaking-changes`, then `/al-code-review` per-feature.

Gate report on failure (flipping to `blocked`) is the Stop shape from [voice-contract.md](../../references/voice-contract.md): one stop line naming scenario / check / observed-vs-expected, state table (verify task id, scenarios completed, scenario blocked on), next action (route to `/al-steer`).

## Feed

The wary developer is the oracle here, so the feed narrates the commitments and outcomes they care about — never the one-instruction walk. At each moment below, hand `/al-feed` a brief (what happened, why it matters to someone who didn't watch the walk, the kind); `/al-feed` composes the card and appends it.

- **verdict** · pre-flight regression batch returns (spawn #1), before the user is invited in → every recorded scenario re-ran on a fresh app; all pass, or one broke and the slice paused. Brief carries own-recording vs cross-slice collision and the stamped trigger/route.
- **surprise** · first functional fail stops the walk and flips the slice `blocked` → the user saw something wrong, so it stopped right there. Brief carries which check, observed-vs-expected in the user's own words, the saved screenshot, the stripped `review: clean`.
- **verdict** · `/al-second-opinion` coverage review before the `done` flip → a second reviewer confirmed every check was asked and answered and the replay-confirmed scenarios were accounted for, no pass rested on leading the user. Brief carries the verbatim re-read and any gap re-asked.
- **landing** · final gate flip `ready-for-verification → done` → the user personally confirmed the walkable slice on a live screen and the rest replayed clean; it's signed off and the next chunk just opened. Brief carries the slice in BC terms, the evidence, the next tasks (or breaking-change task) opened.
- **decision** · usability findings materialise as queued tasks → the user flagged rough spots that aren't broken, written up as follow-ups. Brief carries non-gating, queued after the next slice, ambiguous ones → `/grill-me`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-page-script` recorded every `Record: yes` Journey Example, and `/al-code-review` per-slice stamped `review: clean` on the verify task at `ready-for-verification` |
| **Hands off to**   | next slice's technical tasks opened to `ready` for `/al-refine`; or — if this was the last slice — the `kind: breaking-change` task opened `blocked` → `ready`, then `/al-validate-breaking-changes` (then `/al-code-review` per-feature). `/al-steer` on failure (after `status: blocked`). Usability findings → candidate tasks in the slice. |
| **Uses**           | `new-agent-container.ps1` (three spawns per cycle), `pagescript-replay.ps1` (batch mode for spawn #1's pre-flight), `publish-apps.ps1` (spawn #1, #2), Web Client deep links + `al-build.json` credentials, `/al-second-opinion` (coverage review before the gate), [`../../references/test-specification.md`](../../references/test-specification.md) (`Verification Plan` grammar + `Record:` flag), [`../../references/test-strategy.md`](../../references/test-strategy.md) (layer + checking-vs-testing frame) |
| **Replan venue**   | `/al-steer` — trigger #4 (pre-flight prior-slice red), trigger #8 (pre-flight current-slice red or functional-walk fail) |
| **Sidebands**      | `/grill-me` (adjudicate an ambiguous usability finding, or whether an observation matches the expected outcome), `al-research` agent (BC surface behaviour to verify against documentation) |

**Advisor checkpoint.** Call `advisor()` before flipping the verify task to `done` — the same-session complement to the `/al-second-opinion` cross-family coverage gate. The flip greenlights the next slice; if the verdict doesn't cover every walked observable check with a user-reported value and every `Record: yes` scenario with a replay result, or any pass rests on a led or inferred value, the gate is theatre.
