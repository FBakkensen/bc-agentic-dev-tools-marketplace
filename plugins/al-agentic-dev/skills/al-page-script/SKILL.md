---
name: al-page-script
description: Generate the slice's BC Page Scripting recording (`.yml` replayed by `@microsoft/bc-replay`) from a verify task's user-test-plan scenarios in `tasks.md`. Scenario-by-scenario inner loop against a fresh container; commits the file on green. Used as a prerequisite to `/al-user-verification`; also covers standalone authoring against the reverse-engineered grammar.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-page-script — Generate slice bc-replay recording

User-invoked generator. Reads a verify task's Tests scenarios, the page AL behind each scenario, and the grammar reference; emits the slice's `.yml` recording by appending one scenario's steps at a time and replaying the accumulating file against a fresh container after each append. Final scenario green → also replay the full pre-flight batch (this `.yml` + every prior slice's `.yml`) to catch cross-file collisions, then commit.

Grammar (envelope, `target:` locator, 18 step types, operators, Power Fx, `include`, locator-by-page-kind) lives in [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md). Six recorder-captured replay-green recordings (`01`–`06`) plus one hand-authored shape example for the No. Series + `copy-value` discipline (`07`) live in [`references/examples/`](references/examples/) — pattern-match a full file before authoring from prose.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Verify task only exists inside in-flight feature.
- Reference is **version-bound** to BC platform `28.0.49873.0`. Replaying on a newer platform → re-derive the grammar first (the reference's intro says how).
- Target task is `kind=verify` with `status=ready` and populated Tests area. Empty Tests → **Stop**, `Next: /al-refine T-NNN`. Status `blocked` → **Stop**, `Next: /al-steer T-NNN`.
- `.yml` already at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml` → **Stop**, `Next: /al-user-verification T-NNN`. Regeneration is a replan call (route via `/al-steer`); silently overwriting an existing recording loses the bc-replay state the pre-flight depends on.
- Author against the page AL: every `field`/`action`/`page` name referenced in a scenario step must be a live rendered control at replay time, or replay fails `Field '<caption>' was not found.` Read the page AL via `al-symbols-mcp` / `grep` before authoring its locator.

## What this session answers

- **Which verify task?** One `T-NNN` of `kind=verify` named in opener with its `slice=` value and matching `event-model.md` timeline step.
- **Which page surface?** Per scenario, which Page object, which actions, which fields. Resolved before authoring via `al-symbols-mcp` / `grep` on the page AL.
- **Which scenarios green?** Append scenario K's steps to the in-progress `.yml`, replay the full accumulating file via `pagescript-replay.ps1 -File <path>` against the spawned container, classify outcome, advance.
- **Was the cross-file pre-flight clean?** After the final scenario greens, run `pagescript-replay.ps1` in batch mode (every `pagescripts/recordings/*.yml`) once before commit. Cross-file collisions surface here, not in the inner loop.
- **What flips at end?** File committed at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Verify task `status=` stays `ready`. Gate report names `Next: /al-user-verification T-NNN`.

## Output path

`pagescripts/recordings/<NNN>-<slug>__<slice>.yml`. Flat folder at repo root; `<NNN>` matches the spec folder number, `<slug>` is the feature slug, `<slice>` is the verify task's `slice=` value. Double-underscore between feature-slug and slice-slug. `pagescript-replay.ps1`'s batch glob is `pagescripts/recordings/*.yml`; this path joins it automatically.

## Generation runtime

### Container lifecycle

One `new-agent-container.ps1` spawn per `/al-page-script` invocation. Fresh container at start; publish apps once; the same container hosts every inner-loop replay. Container is left running on exit — `/al-user-verification`'s spawn #1 will replace it with another fresh container regardless, so explicit teardown here would just add churn. No spawn-per-scenario — that would multiply container churn for no benefit; the inner-loop replay re-uses the same backend state.

### Scenario-by-scenario inner loop

Read scenarios from the verify task's Tests area in order. For each scenario K (K = 1..N):

1. **Locate page AL.** Every BC-specific symbol in scenario K's steps (page, action, field, Role Center cue) backed this session by `al-symbols-mcp` / `grep` hit or cited via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Recall does not satisfy; training-data BC names ship confidently-wrong.
2. **Append steps.** Emit scenario K's bc-replay steps onto the accumulating `.yml`. First scenario opens with `navigate` from the role center; subsequent scenarios start where the previous one left off (close-page to return to a known surface, or navigate fresh if the scenario describes a different journey).
3. **Replay.** `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1" -File pagescripts/recordings/<NNN>-<slug>__<slice>.yml` against the spawned container. `-File` mode replays the single accumulating file, not the batch glob.
4. **Classify outcome.** Green → scenario K is sealed; advance to scenario K+1. Red → name the failure pattern (below) and act.
5. **Final scenario green → cross-file pre-flight.** After scenario N greens, run `pagescript-replay.ps1` in batch mode (no `-File`) against the same container. Catches collisions where this new `.yml` invalidates a prior slice's recording (e.g. seeding a Customer that a prior recording assumed absent). Batch-green → commit the file. Batch-red names which prior `.yml` collided; route per *Failure classification* below (typically Sequence collision, restructure scenario N to use No. Series + `copy-value` so it stops colliding).

### Failure classification

Five patterns, applied during inner-loop classification. Pattern names are intent labels for the agent; choose by what the replay error actually surfaces.

- **YAML defect.** Replay error reads as a syntax or locator-shape problem (wrong `target:` nest, `invokeType` typo, missing `runtimeRef` after `page-shown`, `operation:` outside the enum). Self-fix: re-read the offending step against the grammar reference, correct, retry the replay. No user prompt.

- **Un-derivable ID.** AL search for the scenario's named action or field returns no hit, and the failure references a runtime-generated control ID (`Action37`, `Control1`, `b71`-style). Custom-action IDs and repeater control names are not derivable from AL — one user prompt for the harvested value (recorder paste, or the AL mapping if available), merge into the step, retry the replay. Single prompt, not a back-and-forth.

- **Sequence collision.** Replay error names a record that already exists (`Customer No. C00010 already exists`), a precondition violated by an earlier scenario in this file (Customer X created in scenario 2 still present in scenario 3), or a precondition violated by a prior slice's `.yml` (cross-file collision surfaced by the batch pre-flight). Restructure the scenario in-loop — prefer the page's No. Series so each replay gets a fresh value, `copy-value` to capture the auto-assigned No., `=Clipboard.'name'` to reference it downstream. Literal IDs only when the scenario must hit a seeded record (demo data, system-defined account). No routing — same posture as `/al-implement` iterating on test setup.

- **Production bug.** AL `grep` confirms the named element exists, the locator shape is valid against the grammar, but the surface behaviour the scenario asserts is wrong. The page genuinely does not do what the scenario claims (Status flips to wrong value, action runs but the Business Event doesn't fire, factbox doesn't refresh). **Stop**. Gate report names `Route: /al-steer T-NNN` with the full replay transcript. `/al-steer` decides whether this is a fix task back into `/al-implement`, a scenario rewrite via `/al-refine`, or a slice-boundary split via `/al-scope`.

- **Scenario unspeakable.** Scenario step describes a judgment the bc-replay grammar cannot encode — look-and-feel ("the cue looks busy"), error-message tone, accessibility behaviour, anything without a `validate`/`page-shown`/`invoke` equivalent. **Stop**. Gate report names `Route: /al-refine T-NNN` to reshape the scenario into something a recording can assert (or to mark it as walk-only and lift it out of the bc-replay batch).

## Authoring discipline

**No. Series first.** When a scenario creates a record on a page whose underlying table uses No. Series, the scenario prose says "Create a Customer" (No. auto-assigned), not "Create Customer C00010". The page assigns a fresh No. per replay; recordings sidestep cross-scenario and cross-file collisions naturally. Literal IDs only when the scenario must reference a seeded record — demo data, system-defined accounts, anything the scenario's intent depends on by exact value.

**`copy-value` capture for auto-assigned values.** Auto-assigned No. is unknown at authoring time. The scenario's first step on the new record captures the No. via `copy-value` (`source` ends in `field: No.`, `name: <slug>-no`); every later step that needs the No. references it via `=Clipboard.'<slug>-no'`. Same shape applies to any auto-generated ledger entry No., document No., journal line No.

**Prose matches discipline.** `/al-refine` writes verify-task scenarios in the same shape the page-script will emit — *"Create a Sales Order, capture the No., assert No equals the captured value"* matches the `copy-value` + `=Clipboard.'name'` shape. No prose/YAML divergence; the recording reads like the scenario and the scenario reads like the recording.

**No Power Fx for fake uniqueness.** Power Fx (`=Today()`, `=Session.'User ID'`) is used where the page legitimately needs an expression — date filters, today's posting date, current-user contexts. It is not used to fabricate uniqueness in IDs; that is what No. Series + `copy-value` does. Magic-string Power Fx in a No. field is an anti-pattern that masks the real shape.

**Blind reliability envelope.** Hand-authoring is reliable for `navigate` + named `field`/system-action (`Control_New`, `Cancel`, `CloseOk`, `Yes`/`No`); custom-action generated IDs (`Action37`) and repeater control names (`Control1`) are **not** derivable from AL — when the AL search misses, prompt the user once for the harvested value (recorder paste) rather than guessing.

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

Replay needs **Node 22–25** (`@microsoft/bc-replay` bundles `@playwright/test`; Node 26+ hangs in Playwright's browser-install per upstream `microsoft/playwright#40724`). Manage Node version via **[Volta](https://volta.sh)** — install once on the box, then `volta install node@22`. On first run, `pagescript-replay.ps1` writes a minimal `pagescripts/package.json` and invokes `volta pin node@22`, which resolves to the exact installed version (e.g. `"22.22.3"`) and writes it into the file's `volta.node` field. Every `node` / `npm` / `npx` invocation inside `pagescripts/` then routes through Volta's shim to that pinned version regardless of the user's global Node. No per-shell setup; no `fnm use` dance; no `$PROFILE` editing. Inside `/al-page-script`'s inner loop, the spawn-then-replay is encapsulated by `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/pagescript-replay.ps1"` — `-File <path>` for single-file replay during generation, no flag for batch replay (pre-commit cross-file check). The script handles app publish, npm install (writes the package.json + Volta pin on first call), and the `replay` invocation; spawn the container once via `pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/new-agent-container.ps1"` at the start of the invocation.

Standalone replay (without going through the generator), from a folder with `@microsoft/bc-replay` installed:

```powershell
npx replay .\recordings\*.yml -StartAddress http://<host>/<instance>/ -ResultDir .\results
```

- **Auth** (supplied at invocation, never hard-coded): `-Authentication Windows` (default) | `AAD` | `UserPassword`, plus `-UserNameKey` / `-PasswordKey` naming the env vars that hold the values.
- `replay` exits **non-zero** if any recording fails — that is the green/red gate.
- Inspect the run: `npx playwright show-report .\results\playwright-report` (native bc-replay HTML report + `results.xml`).

## Gate event

Once when the slice's `.yml` lands at the committed path. Gate report names slice (slug + `event-model.md` step), scenario count, what user surface the recording exercises (Page action, API endpoint), next handoff `/al-user-verification T-NNN`. Stop shape on routing failures (production bug → `/al-steer`, unspeakable scenario → `/al-refine`) follows [voice-contract.md](../../references/voice-contract.md): one stop line naming scenario / step / observed-vs-expected, state table (verify task ID, scenarios completed, scenario blocked on), next action.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before committing the `.yml`. The recording becomes part of the regression batch every future slice's pre-flight runs; a fragile or wrongly-asserting recording multiplies false-red across the rest of the feature.

</claude-only>

## Composition

| | |
|---|---|
| **Invoked by**     | user. Suggested by `/al-implement` (precondition halt on `kind=verify` task), `/al-refine` (Composition handoff on `kind=verify` task), `/al-code-review` per-slice (next-action when verify task `ready` and `.yml` missing), `/al-steer` (state-read routing on verify task with prose Tests and no `.yml`) |
| **Runs after**     | `/al-refine` filled the verify task's Tests area, `/al-code-review` per-slice flipped the verify task `blocked` → `ready` |
| **Hands off to**   | `/al-user-verification` on green (the recording joins the pre-flight batch). `/al-steer` on production-bug red. `/al-refine` on scenario-unspeakable red. |
| **Uses**           | `new-agent-container.ps1` (one spawn per invocation), `pagescript-replay.ps1` (`-File` mode in the inner loop, batch mode for the pre-commit cross-file check), `al-symbols-mcp` / `grep` for page AL lookup, [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md) grammar, [`references/examples/`](references/examples/) |
| **Replan venue**   | `/al-steer` (production-bug pattern) |
| **Sidebands**      | `/al-research` (BC surface behaviour the scenario asserts), `/grill-me` (intent on a scenario step the user must adjudicate) |

## Out of scope

- **Writing the scenarios themselves.** Scenarios live in the verify task's Tests area in `tasks.md`, written by `/al-refine`. This skill consumes them.
- **Copilot `run-prompt`.** SaaS-tenant feature (gated by `Features.RunPrompt`); not runnable in a container. Grammar documented in the reference, not exercised here.
- **Harvesting custom-action / repeater control IDs without a recorder pass.** When AL search misses, one user prompt for the harvested value; this skill does not invent IDs.
- **Standalone YAML authoring outside the slice-cycle flow.** The grammar reference and examples support that use case directly; pattern-match a worked file and write by hand. This SKILL's generator is shaped for verify-task input.
