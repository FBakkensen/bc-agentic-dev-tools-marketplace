---
name: al-page-script
description: Generate the slice's BC Page Scripting recording (`.yml` replayed by `@microsoft/bc-replay`) from a verify task's `Verification Plan` Journey Examples in `tasks.md`. Example-by-example inner loop against a fresh container; commits the file on green. Used as a prerequisite to `/al-user-verification`; also covers standalone authoring against the reverse-engineered grammar.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-page-script — Generate slice bc-replay recording

User-invoked generator. Reads a verify task's `Verification Plan` `Journey Examples` with `Scope: E2E`, the page AL behind each example, and the grammar reference; emits the slice's `.yml` recording by appending one example's actions and observable checks at a time and replaying the accumulating file against a fresh container after each append. Final example green → also replay the full pre-flight batch (this `.yml` + every prior slice's `.yml`) to catch cross-file collisions, then commit.

**Layer.** This is the **E2E layer** of the test pyramid (see [`test-strategy.md`](../../references/test-strategy.md)): a regression guard written *after* the slice, from verify-task Journey Examples — not a red-first driver. Its oracle is bc-replay's equality/visibility checks, which are **oracle-limited** (a recording can pass against broken code where the platform absorbs the fault). So a red here doesn't get fixed here by default: it **pushes down** to the layer that can pin it. See *Failure classification* below.

Grammar (envelope, `target:` locator, 19 step types, operators, Power Fx, `include`, locator-by-page-kind) lives in [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md). Six recorder-captured replay-green recordings (`01`–`06`) plus two hand-authored shape examples (`07` No. Series + `copy-value`, `08` `Error()` dialog — dialog steps recorder-verbatim, wrapper schematic) live in [`references/examples/`](references/examples/) — pattern-match a full file before authoring from prose.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside in-flight feature.
- Grammar reference was reverse-engineered on BC **v28** and verified stable across minor platform bumps. It is *not* pinned to an exact build — re-derive (the reference's intro says how) only when a replay red is a grammar-**shape** mismatch (wrong nesting/step type the player rejects), not when it is a missing control or a dialog. A platform version number alone is not a reason to **Stop**.
- Target task is `kind=verify` with `status=ready-for-verification` and populated `Verification Plan` containing `Journey Examples`. Plain `ready` → **Stop**, `Next: /al-refine T-NNN`. `ready-for-verification` with an empty plan → **Stop**, `Next: /al-steer T-NNN`; status and proof disagree. No `Scope: E2E` examples → **Stop**, `Next: /al-user-verification T-NNN` if the plan contains only `Contract` / `Exploration`, otherwise `/al-steer T-NNN` for malformed plan routing. Status `blocked` → **Stop**, `Next: /al-steer T-NNN`. Status `done` → downstream evidence exists; do not regenerate here.
- `review=clean` present on the verify task's comment-anchor line — the durable clean per-slice `/al-code-review` evidence. Missing → **Stop**, `Next: /al-code-review T-NNN`. Page-script is a verification pre-flight artifact, not the code-review gate.
- `.yml` already at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml` → **Stop**, `Next: /al-user-verification T-NNN`. Regeneration is a replan call (route via `/al-steer`); silently overwriting an existing recording loses the bc-replay state the pre-flight depends on.
- **Login is permitted.** Agent types `container.username` / `container.password` from repo-root `al-build.json` (defaults `admin` / `P@ssw0rd`) into the Web Client's UserPassword form and signs in. User-authorized, non-secret throwaway dev credentials. Local container hosts only (`http://<container>/BC/`) — never `*.dynamics.com` or any non-local host. Login form ≠ blocker; never hand sign-in to the user.
- Author blind first. Names come from page AL + grammar reference + worked examples + the repo's committed `pagescripts/recordings/*.yml` (replay-proven local ground truth). Locators bind the AL control/field **name**, not the display caption (grammar §10.1). A name not live-rendered at replay → `Field '<name>' was not found.` Recorder session = escalation for an unknown only (generated action/repeater ID, uncertain invoke type, unclear gesture) → capture the smallest gesture that answers it → back to authoring. Recording is slow; the inner replay loop already proves the file. Drive by pixel coordinates — BC's iframe stack defeats role/text/title locators (locator clicks → `steps: []`). Chrome MCP (`claude-in-chrome`) = session-proven drive (agent signs in per the login grant; HTTP containers strand the download as `Unconfirmed *.crdownload` — bytes complete, copy it out). No Chrome MCP (Codex, headless) → plugin harness: owns lifecycle, auth, download capture; drive its coordinate `click`, not locator commands. Codex in-app browser: download support blocked → not a capture path. Neither opens BC/recorder → report the exact limitation, fall back to user-provided recorder YAML or hand-authored YAML plus replay.

## What this session answers

- **Which verify task?** One `T-NNN` of `kind=verify` named in opener with its `slice=` value and matching `event-model.md` timeline step.
- **Which page surface?** Per `E2E` Journey Example, which Page object, which actions, which fields. Resolved before authoring via `al-symbols-mcp` / `grep` on the page AL.
- **Which examples green?** Append Journey Example K's actions and observable checks to the accumulating `.yml`, replay the full accumulating file via `pagescript-replay.ps1 -File <path>` against the spawned container, classify outcome, advance.
- **Was the cross-file pre-flight clean?** After the final Journey Example greens, run `pagescript-replay.ps1` in batch mode (every `pagescripts/recordings/*.yml`) once before commit. Cross-file collisions surface here, not in the inner loop.
- **What flips at end?** File committed at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Verify task `status=` stays `ready-for-verification` and keeps `review=clean` — the commit adds a recording, no production AL, so the per-slice review still vouches for the slice diff. Gate report names `Next: /al-user-verification T-NNN`.

## Output path

`pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Flat folder at repo root; `<NNN>` matches the spec folder number, `<slug>` is the feature slug, `<slice>` is the verify task's `slice=` value. Double-underscore between feature-slug and slice-slug. `pagescript-replay.ps1`'s batch glob is `pagescripts/recordings/*.yml`; this path joins it automatically.

## Generation runtime

### Container lifecycle

One `new-agent-container.ps1` spawn per `/al-page-script` invocation. Fresh container at start; publish apps once; the same container hosts every inner-loop replay. Container is left running on exit — `/al-user-verification`'s spawn #1 will replace it with another fresh container regardless, so explicit teardown here would just add churn. No spawn-per-example — that would multiply container churn for no benefit; the inner-loop replay re-uses the same backend state.

### Recorder harvest for unknowns

Blind authoring is the default; recorder session = escalation when AL can't answer. Drive by coordinates — iframes defeat locators. Chrome MCP where available (session-proven; agent signs in per the login grant, `.crdownload` copy-out). Otherwise (Codex, headless) the plugin harness:

```powershell
node <plugin>/scripts/bc-pagescript-recorder.mjs --repo-root <repo>
```

`<plugin>` is the installed `al-agentic-dev` plugin root. The target repo must contain `al-build.json` and `pagescripts/package.json` with `@microsoft/bc-replay` installed; the harness resolves Playwright from the target repo's `pagescripts/package.json`, not from plugin dependencies. It reads `serverInstance` and container auth from `al-build.json`, derives the default container host from the current branch like the AL build scripts, and accepts overrides: `--container` / `BC_CONTAINER`, `--company` / `BC_COMPANY`, `--page` / `BC_PAGE`, `--output`, `--headed`.

The harness only opens the BC Web Client, authenticates, opens Settings -> `Page scripting (Preview)`, starts recording, emits `READY_FOR_AGENT_FLOW`, stops/saves/downloads on command, and reads the YAML. It must not contain the business/user flow. After `READY_FOR_AGENT_FLOW`: smallest gesture that answers the unknown, coordinate clicks from screenshots, `stopSave`. Coordinate drive not yet session-proven — verify on first use.

Machine-readable JSON lines include:

```json
{ "event": "start", "url": "...", "runDir": "..." }
{ "event": "recording", "state": "started" }
{ "event": "READY_FOR_AGENT_FLOW" }
{ "event": "download", "path": "...", "suggestedFilename": "Recording.yml" }
{ "event": "yml", "path": "...", "bytes": 543, "preview": "..." }
```

Stdin commands: `screenshot`, `click`, `key`, `type`, `wait`, `stopSave`, `readYml`, `close` — JSON lines, e.g. `{"cmd":"click","x":640,"y":312}`, `{"cmd":"key","key":"Enter"}`. Locator forms (`{"cmd":"click","text":"Open"}`) reach recorder chrome and dialog buttons only; business-page controls sit behind the iframe stack → coordinates. Screenshots and `error.log` land under repo-local `.tmp/bc-pagescript-recorder/...`.

Successful proof shape for the first known harness capture: recording started; the agent opened a list row; the harness downloaded `Recording.yml`; the YAML contained the row `invoke` on the list's repeater and `page-shown` for the card. (Drive path unrecorded, predates the locator refutation → proves lifecycle, not drive mode.)

### Example-by-example inner loop

Read `Scope: E2E` Journey Examples from the verify task's `Verification Plan` in order. Ignore `Contract Examples` and `Exploration Charters`; they belong to `/al-user-verification`. For each Journey Example K (K = 1..N):

1. **Locate page AL.** Every BC-specific symbol in Journey Example K's actions and observable checks (page, action, field, Role Center cue) meets the evidence bar in [voice-contract.md](../../references/voice-contract.md): workspace hit this session or quoted fetch; training-data BC names ship confidently-wrong.
2. **Append steps.** Emit Journey Example K's bc-replay steps onto the accumulating `.yml`. First example opens with `navigate` from the role center; subsequent examples start where the previous one left off (close-page to return to a known surface, or navigate fresh if the example describes a different journey).
3. **Replay.** `pwsh <plugin>/skills/al-build/scripts/pagescript-replay.ps1 -File pagescripts/recordings/<NNN>-<slug>__<slice>.yml` against the spawned container. `-File` mode replays the single accumulating file, not the batch glob.
4. **Classify outcome.** Green → Journey Example K is sealed; advance to K+1. Red → **read the artifacts, don't trust the exit code alone**: the run writes `error-context.md` (an ARIA snapshot of the frozen surface — where an unexpected dialog is *visible*) and `replay-log.yml` (the full step list; the failing step carries an inline `error: { type, message, target }`) under `<cwd>/test-results/dist-player--…--chromium/`. A **hang** (timeout, no error string) is a red too — the snapshot shows what blocked it. Then route per *Failure classification* below.
5. **Final example green → cross-file pre-flight.** After example N greens, run `pagescript-replay.ps1` in batch mode (no `-File`) against the same container. Catches collisions where this new `.yml` invalidates a prior slice's recording (e.g. seeding a Customer that a prior recording assumed absent). Batch-green → commit the file. Batch-red names which prior `.yml` collided; route per *Failure classification* below (typically Sequence collision, restructure example N to use No. Series + `copy-value` so it stops colliding). If a prior `.yml` reds because a control it targets no longer exists — the surface legitimately moved (a field was removed) — quarantine or delete it so the batch stops false-redding on a behaviour that no longer exists. If the control's removal is itself unexpected, that is a production bug → push down.

### Failure classification

A red is a question — *can this layer pin the truth, and if not, which layer can?* Classify by the **outcome** read from `error-context.md` + `replay-log` (error / hang / false-green / wrong-behaviour), then route by **push-down** (see [`test-strategy.md`](../../references/test-strategy.md)). Three resolutions stay in-loop; the rest move the test to another layer.

**Stay in-loop — the recording is wrong, not the system:**

- **YAML defect.** Error reads as a shape/locator problem (wrong `target:` nest, `invokeType` typo, missing `runtimeRef` after `page-shown`, `operation:` outside the enum) — or an *expected* dialog the recording forgot to answer. Self-fix against the grammar reference (a Confirm is answered with `invoke invokeType: Yes`|`No`), retry. No prompt. An `Error()` the Journey Example *expects* (a guard error, e.g. blank-filter) is this case, not push-down: script the grammar §4 composition (`page-shown` on the Error automationId immediately after the trigger → `invoke Ok` → `page-closed`). Error *text* not assertable (no `contains`) → wording checks stay Exploration Charters. Expected per plan → script; unexpected → route below.
- **Un-derivable ID / uncertain invoke type.** AL search misses and the failure references a runtime-generated control ID (`Action37`, `Control1`, `b71`-style), or the gesture serializes an unclear `invokeType`. Harvest it from the BC Page Scripting recorder — coordinate-driven via Chrome MCP, or the plugin harness where Chrome MCP is unavailable. Custom-action IDs, repeater names, and some modal close actions are not derivable from AL — lookup modal close actions, for instance, record as `invokeType: LookupOk` and `invokeType: LookupCancel`. If no recorder session can open BC or the recorder, report the exact limitation and fall back to user-provided recorder YAML or hand-authored YAML plus replay. Single resolution, not a back-and-forth.
- **Sequence collision.** Error names a record that already exists, a precondition an earlier example in this file left behind, or a prior slice's `.yml` colliding in the batch pre-flight. Restructure in-loop — page No. Series for a fresh value per replay, `copy-value` to capture the auto-assigned No., `=Clipboard.'name'` downstream. Literal IDs only for a record the example must hit by value (demo data, system-defined account). Same posture as `/al-implement` iterating on test setup. No routing.

**Push down — the system is wrong, and a lower layer should own the proof:**

- **Production bug (pinnable lower).** The named element exists, the locator is valid, but the asserted surface behaviour is wrong (Status flips wrong, the Business Event doesn't fire, the factbox doesn't refresh) — and an integration/unit test *could* assert it. **Push the proof down to the integration layer.** But the slice was thought done, so there is no fix task yet: leave verify task status unchanged and `Route: /al-steer T-NNN`. `/al-steer` blocks the verify task if the route confirms missing context, opens the integration fix task (the slice re-opens), and `/al-implement` drives it red-first at the cheapest sensitive layer. This recording stays the acceptance guard and re-greens once the fix lands. **Page-script diagnoses and routes — it does not edit production, create the task itself, flip task status, or hand-inject `Error()` probes.**
- **Unexpected platform dialog (a hang).** The run times out with no error string; `error-context.md` shows an open Confirm (`RecordChangeDialog`: "Your change might update related records…", default focus No). An unexpected `Error()` fails *fast* instead — `Invalid state: Unexpected error dialog. <value>{error text}</value>` on the next step — same routing. Either the dialog is *expected* → YAML defect, answer it; or it is *triggered by a production AL pattern* (the page key-writes its bound `Rec`, a mis-set `AutoSplitKey`) → production bug, route as above (status unchanged; `/al-steer` opens the integration fix task). The AL fix lands in `/al-implement`, not here.

**Escalate — no assertion oracle exists at a layer below:**

- **Runner-absorbed false-green.** The recording greens against code you know is broken — bc-replay re-reads the bound `Rec` exactly as a TestPage does, so its oracle is blind to that fault class. Per the oracle problem it is a **false net**: delete or quarantine the recording so the batch stops vouching for nothing, and pin the behaviour where an oracle can see it (a TestPage if one can; otherwise it is genuinely sapient-only). Never "fix and trust the green."
- **Example unscriptable.** The step asks for a judgment no assertion can encode — look-and-feel, error-message tone, accessibility. Leave verify task status unchanged and `Route: /al-steer T-NNN`. `/al-steer` decides whether to reopen the verify task to `ready` for `/al-refine` to reshape it into observable checks, or keep it `ready-for-verification` and carry the judgment as an `Exploration Charter` for `/al-user-verification`.

## Authoring discipline

**No. Series first.** When an example creates a record on a page whose underlying table uses No. Series, the task prose says "Create a Customer" (No. auto-assigned), not "Create Customer C00010". The page assigns a fresh No. per replay; recordings sidestep cross-example and cross-file collisions naturally. Literal IDs only when the example must reference a seeded record — demo data, system-defined accounts, anything the example's intent depends on by exact value. Same instinct for row selection: a positional `relative:N` pick drifts when demo data differs from your assumption (the CRONUS attribute set includes `Height`, so the "3rd row" may not be what you think) — anchor to a record you seed, not whatever demo data happens to sit there. A **just-created** row: never positional — `relative:N` drifts as the container accumulates rows, `set-current-row` can silently fail to move, and a new row inserts *above* the current row, not at the bottom → `SortColumn` toggle (newest No. on top) or a column-filter pin on the captured No. (grammar §4 *Anchoring a just-created row*).

**One written row per grid visit.** A pending new grid row commits on row-leave (`close-page`, click another row); a second `Control_New` silently discards it — the row never inserts, no error, downstream reads fewer rows than authored. Author `Control_New` → `input` one cell → `close-page`; re-open for the next row. Never `validate` straight after a grid `input` — the cursor sits on the blank new-row placeholder and the read returns `'0'`/blank; re-open the page or re-anchor first (grammar §4 *Editable-grid new-row lifecycle*).

**Round-trippable fixtures for derived values.** Two fields linked by a conversion re-derive and round on the stored side — a typed 80 reads back `79.99999` and fails `=`; `validate` has no tolerance operator (grammar §5 enum is complete). Assert the stored canonical field, or pick fixture values that round-trip exactly (markup 100 ↔ margin 50).

**`copy-value` capture for auto-assigned values.** Auto-assigned No. is unknown at authoring time. The first step on the new record captures the No. via `copy-value` (`source` ends in `field: No.`, `name: <slug>-no`); every later step that needs the No. references it via `=Clipboard.'<slug>-no'`. Same shape applies to any auto-generated ledger entry No., document No., journal line No.

**Prose matches discipline.** `/al-refine` writes `Journey Examples` in the same shape the page-script will emit — *"Create a Sales Order, capture the No., assert No equals the captured value"* matches the `copy-value` + `=Clipboard.'name'` shape. No prose/YAML divergence; the recording reads like the example and the example reads like the recording.

**No Power Fx for fake uniqueness.** Power Fx (`=Today()`, `=Session.'User ID'`) is used where the page legitimately needs an expression — date filters, today's posting date, current-user contexts. It is not used to fabricate uniqueness in IDs; that is what No. Series + `copy-value` does. Magic-string Power Fx in a No. field is an anti-pattern that masks the real shape.

**Blind reliability envelope.** Hand-authoring is reliable for `navigate` + named `field`/known system-action (`Control_New`, `Cancel`, `CloseOk`, `Yes`/`No`) and already-proven invoke types. Custom-action generated IDs (`Action37`), repeater control names (`Control1`), and uncertain modal close invoke types are **not** derivable from AL — when the AL search misses or the gesture shape is unclear, harvest the real value with a recorder session per *Failure classification* › Un-derivable ID / uncertain invoke type, rather than guessing.

## Canonical example

```yaml
name: Smoke - Item List opens and No. is set
description: Navigate to Items, open first row's card, assert No. is non-empty.
start:
  profile: ORDER PROCESSOR
steps:
  - type: navigate
    target: [ { page: Order Processor Role Center }, { action: Items } ]
  - type: page-shown
    source: { page: Item List }
    runtimeId: pg1
  - type: invoke
    target: [ { page: Item List, runtimeRef: pg1 }, { repeater: Control1 } ]
    invokeType: Edit
    parameters: { AlwaysCommit: false }
  - type: page-shown
    source: { page: Item Card }
    runtimeId: pg2
  - type: validate
    target: [ { page: Item Card, runtimeRef: pg2 }, { field: No. } ]
    operation: "<>"
    value: ""
```

For the No. Series + `copy-value` discipline end-to-end, see [`references/examples/07-noseries-copyvalue-validate.yml`](references/examples/07-noseries-copyvalue-validate.yml).

## Running a recording

Replay needs **Node 22–25** (`@microsoft/bc-replay` bundles `@playwright/test`; Node 26+ hangs in Playwright's browser-install per upstream `microsoft/playwright#40724`). Manage Node version via **[Volta](https://volta.sh)** — install once on the box, then `volta install node@22`. On first run, `pagescript-replay.ps1` writes a minimal `pagescripts/package.json` and invokes `volta pin node@22`, which resolves to the exact installed version (e.g. `"22.22.3"`) and writes it into the file's `volta.node` field. Every `node` / `npm` / `npx` invocation inside `pagescripts/` then routes through Volta's shim to that pinned version regardless of the user's global Node. No per-shell setup; no `fnm use` dance; no `$PROFILE` editing. Inside `/al-page-script`'s inner loop, the spawn-then-replay is encapsulated by `pwsh <plugin>/skills/al-build/scripts/pagescript-replay.ps1` — `-File <path>` for single-file replay during generation, no flag for batch replay (pre-commit cross-file check). The script handles app publish, npm install (writes the package.json + Volta pin on first call), and the `replay` invocation; spawn the container once via `pwsh <plugin>/skills/al-build/scripts/new-agent-container.ps1` at the start of the invocation.

Standalone replay (without going through the generator), from a folder with `@microsoft/bc-replay` installed:

```powershell
npx replay .\recordings\*.yml -StartAddress http://<host>/<instance>/ -ResultDir .\results
```

- **Auth** (supplied at invocation, never hard-coded): `-Authentication Windows` (default) | `AAD` | `UserPassword`, plus `-UserNameKey` / `-PasswordKey` naming the env vars that hold the values. Full option surface in [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md).
- `replay` exits **non-zero** if any recording fails — that is the green/red gate.
- **Where the artifacts land** (verified, bc-replay 0.1.139): `-ResultDir` gets only `results.xml` + `playwright-report/`. The **diagnosis** artifacts — `error-context.md`, `replay-log.yml`, `attachments/Replay-log-*.yml`, `video.webm` — write to `<cwd>/test-results/dist-player--…--chromium/`, *not* `-ResultDir`. Read a red there, not in the report.
- `-UseServerReplay` swaps the browser for a bundled .NET client-service engine (faster, headless) — but it **cannot render control add-ins / canvas**, so a feature whose deliverable paints inside a canvas is unverifiable this way (only the browser path, or the exploratory guided user walk, can see it). `npx playwright install` still runs unconditionally regardless of the flag.

## Gate event

Once when the slice's `.yml` lands at the committed path. Gate report names slice (slug + `event-model.md` step), E2E example count, what user surface the recording exercises (Page action), next handoff `/al-user-verification T-NNN`. Stop shape on routing failures (production bug or unscriptable example → status unchanged, route `/al-steer`) follows [voice-contract.md](../../references/voice-contract.md): one stop line naming example / step / observed-vs-expected, state table (verify task ID, examples completed, example blocked on), next action.

<claude-only>

**Advisor checkpoint.** Call `advisor()` on the recording as it will be committed — the batch-pre-flight-green version, not a mid-fight draft a restructure superseded. The recording joins every future slice's pre-flight; a fragile or wrongly-asserting one multiplies false-red across the feature.

</claude-only>

## Composition

| | |
|---|---|
| **Invoked by**     | user. Suggested by `/al-code-review` per-slice (next-action when verify task `ready-for-verification` and `.yml` missing), `/al-steer` (state-read routing on a `review=clean` verify task with `Verification Plan` and no `.yml`) |
| **Runs after**     | `/al-refine` filled the verify task's `Verification Plan`, `/al-code-review` per-slice stamped `review=clean` on the verify task at `ready-for-verification` |
| **Hands off to**   | `/al-user-verification` on green (the recording joins the pre-flight batch). `/al-steer` on a production-bug red (status unchanged; push down — `/al-steer` opens the integration fix task, `/al-implement` drives it, recording stays as guard). `/al-steer` on an unscriptable example red (status unchanged; `/al-steer` decides whether to reopen to `ready` for `/al-refine` or keep the judgment in `Exploration Charters`). |
| **Uses**           | `new-agent-container.ps1` (one spawn per invocation), `pagescript-replay.ps1` (`-File` mode in the inner loop, batch mode for the pre-commit cross-file check), `al-symbols-mcp` / `grep` for page AL lookup, the repo's committed `pagescripts/recordings/*.yml` as replay-proven pattern source, recorder harvest by coordinate drive — Chrome MCP (`claude-in-chrome`) or the plugin-local Playwright harness `scripts/bc-pagescript-recorder.mjs` (Codex/headless), [`../../references/test-specification.md`](../../references/test-specification.md) (`Verification Plan` grammar), [`../../references/test-strategy.md`](../../references/test-strategy.md) (layer + push-down frame), [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md) grammar, [`references/examples/`](references/examples/) |
| **Replan venue**   | `/al-steer` — production-bug and unscriptable reds route here with status unchanged (it opens the integration fix task or reopens the verify task to `ready` for `/al-refine`); push-down then lands the fix in `/al-implement` |
| **Sidebands**      | `/al-research` (BC surface behaviour the example asserts), `/grill-me` (intent on an example step the user must adjudicate) |

## Out of scope

- **Writing the examples themselves.** Journey Examples live in the verify task's `Verification Plan` in `tasks.md`, written by `/al-refine`. This skill consumes `Scope: E2E` only.
- **Copilot `run-prompt`.** SaaS-tenant feature (gated by `Features.RunPrompt`); not runnable in a container. Grammar documented in the reference, not exercised here.
- **Inventing custom-action / repeater control IDs.** When AL search misses, harvest the real value from the BC Page Scripting recorder — coordinate-driven via Chrome MCP or the plugin-local Playwright harness; if BC or the recorder cannot be opened, report the exact limitation and use user-provided recorder YAML or hand-authored YAML plus replay. This skill never guesses an ID.
- **Standalone YAML authoring outside the slice-cycle flow.** The grammar reference and examples support that use case directly; pattern-match a worked file and write by hand. This SKILL's generator is shaped for verify-task input.
