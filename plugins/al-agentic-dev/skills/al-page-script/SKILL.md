---
name: al-page-script
description: Guide the user to record the slice's framework-limited E2E Journey Examples in BC's Page Scripting recorder — one scenario at a time in chat, punchline-first. The user records and downloads the `.yml`; the agent replays each on a fresh container and classifies reds. Recordings are reserved for behaviour no AL test layer can automate (generation-time push-down). Prerequisite to `/al-user-verification`.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-page-script — Guide the user to record a slice's bc-replay recordings

User-invoked. Reads the verify task's `Verification Plan` Journey Examples marked **`Record: yes`** from its file under `tasks/`, and guides the user — **one scenario at a time, in chat, punchline first** — to record each in BC's built-in **Page Scripting (Preview)** recorder. The user performs the gestures, validates the outcomes, downloads the `.yml`, and hands back the path; the agent replays each recording on a **fresh** container, classifies any red, and on green moves to the next scenario. Final scenario green → replay the full pre-flight batch (this slice's recordings + every prior slice's) to catch cross-file collisions, then commit.

**The recorder is the generator — the agent does not author `.yml`.** The bc-replay YAML format is reverse-engineered and undocumented; authoring it blind is a token-and-error sink, and the recorder is the *intended* way to produce these (Microsoft Learn, `devenv-page-scripting`). So the agent's job is to **coach the recording and read the replay** — never to write a recording from scratch. The one carve-out: a **surgical, approval-gated edit** to an existing recorder-produced file (bump a wait, fix one operator, add a missed Validate) when that is plainly the shortest path to green — ask, edit, replay. Everything else routes back to a guided re-record.

**Layer.** This is the **E2E layer** of the test pyramid (see [`test-strategy.md`](../../references/test-strategy.md)) — the slow, brittle apex, **reserved for behaviour no lower layer can automate**. A recording exists *only* where AL Runner / TestPage genuinely cannot assert the behaviour (control add-ins, canvas, web-client-only behaviour); `/al-refine` makes that call when it marks a Journey Example `Record: yes` (generation-time push-down — most slices get zero). Never a recording that doubles a unit or integration test. Its oracle is bc-replay's equality/visibility checks, which are **oracle-limited** (a recording can pass against broken code the platform absorbs), so a red here does not get faked green — see *Failure classification* below.

The recorder's gestures (how the user expresses No. Series, copy-value, anchored rows, validations, conditionals, Power Fx) and the recording-coaching that keeps a recording re-runnable live in [`references/recorder-gestures.md`](references/recorder-gestures.md). The YAML format itself — read to classify a replay red or to scope a surgical edit, **not** to author — lives in [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md).

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside an in-flight feature.
- Target task is `kind: verify` with `status: ready-for-verification` and a populated `Verification Plan` containing at least one Journey Example marked `Record: yes`. Plain `ready` → **Stop**, `Next: /al-refine T-NNN`. `ready-for-verification` with an empty plan → **Stop**, `Next: /al-steer T-NNN`; status and proof disagree. **No `Record: yes` Journey Example** (all examples are `Record: no`, `Contract`, or `Exploration`) → **Stop**, `Next: /al-user-verification T-NNN`; this slice needs no recording. Status `blocked` → **Stop**, `Next: /al-steer T-NNN`. Status `done` → downstream evidence exists; do not regenerate here.
- `review: clean` present in the verify task's frontmatter — the durable clean per-slice `/al-code-review` evidence. Missing → **Stop**, `Next: /al-code-review T-NNN`. Page-script is a verification pre-flight artifact, not the code-review gate.
- The slice's recordings already exist at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` for every `Record: yes` example → **Stop**, `Next: /al-user-verification T-NNN`. Regeneration is a replan call (route via `/al-steer`); silently overwriting loses the replay-proven state the pre-flight depends on. A *partial* set (some scenarios recorded, some not) → resume at the first un-recorded `Record: yes` example.
- **The recording user needs the `PAGESCRIPTING - REC` permission set** (Microsoft Learn). The container's `admin` / SUPER user carries it; if a restricted user reds the recorder at start, surface the exact permission and re-enter. (`PAGESCRIPTING - PLAY` covers replay and already works — today's flow replays.)
- **Login is the user's.** The agent hands the Web Client URL and the throwaway dev credentials ready to paste: `container.username` / `container.password` from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`). User-authorized, non-secret. Local container hosts only (`http://<container>/BC/`) — never `*.dynamics.com` or any non-local host. User cannot reach the container URL → **Stop**, fix environment, re-enter.

## Output path

`pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml` — one file per recorded scenario. Flat folder at repo root; `<NNN>` matches the spec folder number, `<slug>` the feature slug, `<slice>` the verify task's `slice:` value, `NN` the Journey Example's order within the slice (`01`, `02`, …). Double-underscore between feature-slug and slice-slug, and before the scenario number. `pagescript-replay.ps1`'s batch glob is `pagescripts/recordings/*.yml`; every per-scenario file joins it automatically.

## The recording session

### Opener, sized for a human

Announce the verify task: `T-NNN` id, slice slug + its `event-model.md` step, the **count of `Record: yes` scenarios** to record and a rough time, **plus the infra wait before it** — container spawn and publish run minutes, not seconds; say so, so the user isn't poised over a URL that hasn't arrived. Then spawn the recording container, publish, and hand the user the entry (URL + credentials + deep link). One scenario open at a time; the next opens only after the current scenario's `.yml` replays green.

### Container choreography

**One container exists at a time.** `new-agent-container.ps1` destroys and recreates the branch-named agent container from the snapshot, so every spawn is clean state. There is no second concurrent container — the re-runnability guarantee comes from **spawning fresh immediately before each replay**, which wipes the data the recording just created.

- **Record.** Spawn (`new-agent-container.ps1` → `publish-apps.ps1`) and hand the user the URL; the user records the current scenario against whatever container is up (the one left by the prior step). Recording captures gestures, so its accumulated data does not matter.
- **Replay on clean state.** Once the user pastes the downloaded `.yml`, **spawn fresh again** (`new-agent-container.ps1` → `publish-apps.ps1`) — recreating the container wipes the records the user just made — then replay (`pagescript-replay.ps1 -File`). That clean-state replay is the **re-runnability gate**: a recording that hardcoded a value or picked a row positionally reds here and gets re-recorded. (`pagescript-replay.ps1` only spawns when the container is unhealthy, so the fresh spawn must precede it; the user records the *next* scenario on the container this replay leaves up.)
- **Batch pre-flight.** After the final scenario greens, spawn fresh once more and batch-replay the slice's recordings plus every prior slice's (`pagescript-replay.ps1`, no `-File`) on that clean container — catches cross-file collisions before commit.

Per scenario that is one spawn to record on (carried over from the prior replay) and one fresh spawn to replay on; each spawn runs minutes, so the opener warns the user. A slice's `Record: yes` set is usually one or two scenarios.

Spawn invocations (every replay is preceded by a fresh spawn + publish):
- spawn fresh container: `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/new-agent-container.ps1"`
- publish all apps: `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/publish-apps.ps1"`
- replay one file on the freshly-spawned container (re-runnability gate): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1" -File pagescripts/recordings/<…>__NN.yml`
- batch replay (final pre-flight): `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1"` (no `-File`)

### Per-scenario card

Each `Record: yes` Journey Example becomes one card — **punchline first, then a bullet of actions and validations the user performs**, then a recording-coaching tip. One card at a time; the next card only after this scenario replays green (the "exponential reveal" gate sits between scenarios; the opener already gave the total count).

> **Scenario 1 of 2 — A posted sales order locks its lines.**
> *Recorder on (Settings ⚙ → Page Scripting). Do these, then Save → download the `.yml` and paste me the path.*
>
> **Do**
> - Open **Sales Orders** → **New** → pick a customer → add one line
> - **Post** → **Ship and Invoice**
>
> **Check** (right-click the control → *Page Scripting → Validate*)
> - **Status** *is* `Released`
> - The posted line is locked (read-only)
>
> *Recording tip: let the No. auto-assign — don't type one. (More in recorder-gestures.)*
>
> → Download, paste me the path. I'll replay it on a fresh container.

The **Do** bullets are the example's `Action`; the **Check** bullets are its `Observable Checks`, each phrased as the recorder gesture that asserts it (right-click → Validate; copy-value → Validate *is equal to clipboard entry* for a captured No.). The coaching tip carries the one re-runnability rule that scenario most needs (see [`recorder-gestures.md`](references/recorder-gestures.md)) — stated *before* the user records, so the recording is born re-runnable rather than patched after.

### Replay and seal

User pastes the downloaded path → agent spawns a fresh container (+ publish) and replays it (`-File` mode) on that clean state. Download mechanics: on an HTTP container the browser leaves it as `Unconfirmed *.crdownload` — the bytes are complete; the user copies it out and pastes the path. **Read the artifacts, don't trust the exit code alone**: a red writes `error-context.md` (an ARIA snapshot of the frozen surface — where an unexpected dialog is *visible*) and `replay-log.yml` (the failing step carries an inline `error: { type, message, target }`) under `<cwd>/test-results/dist-player--…--chromium/` (see [`bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md) §9). Green → the scenario seals; move the recorded `.yml` to its committed path and advance to the next card. Red → route per *Failure classification*.

After the final scenario greens, spawn fresh once more and run the batch pre-flight (no `-File`) on that clean container. Batch-green → commit every per-scenario file. Batch-red names which `.yml` collided → classify (typically a *bad recording* — the new scenario seeds a record a prior recording assumed absent; re-record it to use the No. Series so it stops colliding). If a prior `.yml` reds because a control it targets no longer exists — the surface legitimately moved — that is a `/al-steer` decision (regenerate the prior recording or quarantine it), not this skill's.

## Failure classification

A replay red is a question: *is the recording wrong, or is the system?* The recorder emits valid YAML with real control IDs, so the old authoring-failure classes (YAML defect, un-derivable ID) are gone. Three outcomes remain.

**Isolate before you debug.** A red buried in a long recording masks its cause, and every full replay costs minutes. Reproduce the smallest shape that triggers it (drop `timeout:` low so a hang fails fast), name the cause, then act.

- **Bad recording → re-record (in-loop, the default fix).** The recording is brittle or wrong: it hardcoded a No. that collided on fresh replay, picked a row positionally, forgot to answer a dialog it triggered, or asserted the displayed field instead of the stored one. **Diagnose in chat and coach a re-record** — *"sort newest-first before picking the row," "let the No. auto-assign," "Validate the posted entry, not the document line"* (the re-runnability rules, [`recorder-gestures.md`](references/recorder-gestures.md)). The agent never authors the `.yml`. **Carve-out:** when the fix is a single well-understood transform on the existing recorder-produced file (bump a `wait`, fix one `operation:`, add one missed Validate), the agent may **ask for approval, make that surgical edit, and replay** — re-recording a 30-step scenario to add one assertion is waste, not discipline.

- **Real production bug → push down, route `/al-steer`.** The recording is valid, replays the real behaviour, and the asserted behaviour is wrong (Status flips wrong, Business Event doesn't fire, factbox doesn't refresh) — and a lower layer *could* pin it. Leave the verify task status unchanged and `Route: /al-steer T-NNN`. `/al-steer` opens the integration fix task and strips `review: clean`; `/al-implement` drives it red-first; this recording re-greens once the fix lands. **Page-script diagnoses and routes — it does not edit production, create tasks, or flip status.** (An *unexpected* platform dialog is this case when an AL pattern triggers it; an *expected* dialog the recording forgot to answer is a bad recording — re-record to answer it.)

- **Oracle-blind / unscriptable → escalate, route `/al-steer`.** The recording greens against code you know is broken — bc-replay re-reads the bound `Rec` exactly as a TestPage does, so its oracle is blind to that fault class (delete/quarantine; pin it where an oracle can see it; never "fix and trust the green"). Or the check asks for a judgment no assertion can encode — look-and-feel, error-message tone, accessibility. Leave status unchanged and `Route: /al-steer T-NNN`; `/al-steer` decides whether it reopens for `/al-refine` or becomes an `Exploration Charter` for `/al-user-verification`.

## Gate event

Once when the slice's recordings land committed. Verify task `status:` stays `ready-for-verification` and keeps `review: clean` — the commit adds recordings, no production AL, so the per-slice review still vouches for the slice diff. Gate report names the slice (slug + `event-model.md` step), the count of scenarios recorded, what user surface each exercises (Page action), and next handoff `/al-user-verification T-NNN`. Stop shape on a routing failure (production bug or unscriptable red → status unchanged, route `/al-steer`) follows [voice-contract.md](../../references/voice-contract.md): one stop line naming scenario / step / observed-vs-expected, state table (verify task id, scenarios recorded, scenario blocked on), next action.

**Advisor checkpoint.** Call `advisor()` on the recordings as they will be committed — the batch-pre-flight-green set, not a mid-fight draft a re-record superseded. Each recording joins every future slice's pre-flight; a fragile or wrongly-asserting one multiplies false-red across the feature.

## Feed

Four moments narrate to the branch feed; the per-scenario record-download-replay grind stays silent. At each, hand `/al-feed` a brief — what happened, why a wary dev should care, the kind — and `/al-feed` composes the punchline + layers and appends the card. Compose by name; never inline its append.

- **verdict** · a recorded scenario seals green on a fresh container → the user's click-through replays clean from nothing, so it is a real re-runnable regression guard; note scenario/surface and the equality/visibility-limited oracle.
- **surprise** · a red read as a real system bug, the recording *not* patched to fake the green → name the failing step, why this layer can't pin it, the route.
- **verdict** · the cross-file pre-flight batch greens with the new recordings joined → every prior recording still plays together.
- **landing** · the recordings land committed and hand to `/al-user-verification` → the slice now has saved replayable walkthroughs for the behaviour no AL test could reach.

## Composition

| | |
|---|---|
| **Invoked by**     | user. Suggested by `/al-code-review` per-slice (next-action when a verify task is `ready-for-verification` with `Record: yes` examples and no recordings yet), `/al-steer` (state-read routing on a `review: clean` verify task with un-recorded `Record: yes` examples) |
| **Runs after**     | `/al-refine` filled the `Verification Plan` and marked the framework-limited examples `Record: yes`, `/al-code-review` per-slice stamped `review: clean` on the verify task at `ready-for-verification` |
| **Hands off to**   | `/al-user-verification` on green (every `Record: yes` scenario recorded + batch pre-flight green). `/al-steer` on a production-bug or unscriptable red, status unchanged (routing per *Failure classification*). |
| **Uses**           | `new-agent-container.ps1` (fresh spawn before each replay; one container at a time), `publish-apps.ps1`, `pagescript-replay.ps1` (`-File` per-scenario, batch pre-commit), BC's Page Scripting recorder driven by the user, Web Client deep links + `al-build.json` credentials (the user's entry), [`references/recorder-gestures.md`](references/recorder-gestures.md) (recording coaching), [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md) (read a red / scope a surgical edit), [`../../references/test-specification.md`](../../references/test-specification.md) (`Verification Plan` grammar + `Record:` flag), [`../../references/test-strategy.md`](../../references/test-strategy.md) (layer + push-down frame) |
| **Replan venue**   | `/al-steer` — production-bug and unscriptable reds route here with status unchanged (it opens the integration fix task or reopens the verify task to `ready` for `/al-refine`); push-down then lands the fix in `/al-implement` |
| **Sidebands**      | `al-research` agent (BC surface behaviour an example asserts), `/grill-me` (intent on an example step the user must adjudicate) |

## Running a recording

Replay needs **Node 22–25** (`@microsoft/bc-replay` bundles `@playwright/test`; Node 26+ hangs in Playwright's browser-install per upstream `microsoft/playwright#40724`). Manage Node via **[Volta](https://volta.sh)**; on first run, `pagescript-replay.ps1` writes a minimal `pagescripts/package.json` and pins `node@22`. The script encapsulates spawn-then-replay (`-File <path>` single-file, no flag for batch); it handles app publish, npm install, and the `replay` invocation. The full option surface and failure-reading detail live in [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md) §9.

## Out of scope

- **Authoring `.yml` from scratch.** The recorder is the generator; the agent coaches and replays. The only write the agent makes is a surgical, approval-gated edit to an existing recorder-produced file (above).
- **Writing the examples themselves.** Journey Examples live in the verify task's `Verification Plan`, written by `/al-refine`, which also marks `Record: yes` / `Record: no`. This skill records the `Record: yes` set only.
- **Walking the non-recorded scenarios.** `Record: no` Journey Examples, Contract Examples, and Exploration Charters belong to `/al-user-verification`.
- **Copilot `run-prompt`.** SaaS-tenant feature (gated by `Features.RunPrompt`); not runnable in a container.
