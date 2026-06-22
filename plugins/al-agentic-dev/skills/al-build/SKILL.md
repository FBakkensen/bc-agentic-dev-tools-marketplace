---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-build — Build and test gate

Run after every AL change, and as the required gate before committing. Zero warnings, zero errors. Anything else is red.

**Layer.** Executes the **Unit** (AL-Runner) and **Integration** (container + TestPage) layers. See [`test-strategy.md`](../../references/test-strategy.md).

## First time

1. `pwsh "<skill-folder>/scripts/init.ps1"` → drops `al-build.json` in repo root.
2. Set `testApps` to list your test app directories.
3. `pwsh "<skill-folder>/scripts/provision.ps1"` → one-time symbol + container setup.

`Stop. Run pwsh "<skill-folder>/scripts/provision.ps1" first.` if `test.ps1` complains compiler or symbols are missing.

## Canonical gate

Set location to consumer repo root, then:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Always run full gate. Do not filter tests by codeunit. Not bare `alc.exe` → symbol resolution, container publish, telemetry capture live in `test.ps1`.

Force republish: `pwsh "<skill-folder>/scripts/test.ps1" -Force`

### Gate metrics (automatic)

Every `test.ps1` run self-records one entry to `.output/logs/build-timing.jsonl` plus a user-level mirror at `~/.al-build/gate-metrics.jsonl` (override: `ALBT_GATE_METRICS_GLOBAL_PATH`). No caller flags — phase attribution derives from the recorded evidence at report time. Summarize where gate time goes: `pwsh "<skill-folder>/scripts/report-gate-metrics.ps1"` (repo-local) or `-GlobalLog` (cross-repo).

### Fast unit test (inner loop)

When `unitTestApp` configured in `al-build.json`, run only AL Runner unit tests:

```powershell
pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
```

Compiles all apps — main, every `testApps` entry, and the unit-test app — through the analyzer gate (integration compile errors still surface), runs AL Runner, exits — no container needed. Because `testApps` now compile in this mode too, they must resolve: a unit-only project sets `"testApps": []` (the default is `["test"]`, which fail-loud throws if no `test/` dir exists). Use during the RED→GREEN inner loop in `/al-implement` for fast feedback.

**Outputs (per test run):**

- `.output/TestResults/<dirName>/last.xml` → JUnit XML from the container run.
- `.output/TestResults/<dirName>/al-runner.xml` → JUnit XML from the AL Runner run. Separate file — a full gate must never overwrite the unit result.
- `.output/TestResults/<dirName>/telemetry.jsonl` → feature telemetry per container run. `/al-debug-logging` reads this.
- `.output/TestResults/summary.json` → machine-readable summary: `gate` (`full`/`unit`), `totals` per runner, `runs[]` with one record per test run (`runner`, `appName`, `dir`, `passed`, `counts`, `resultFile`, `telemetryFile`).
- `.output/logs/build-timing.jsonl` → one gate-metrics entry per run (every exit path: pass, fail, throw), mirrored to `~/.al-build/gate-metrics.jsonl`.

Take `resultFile` paths from `summary.json` run records — don't glob; a stale file from an earlier gate may sit beside a fresh one.

Test failures → dispatch `/al-debug-logging`. Don't grep build log for clues telemetry already answers.

## Delegation

Always delegate `/al-build` to one general subagent. Build output is verbose; keep it out of the main session.

After the worker returns the gate report, close the completed subagent thread before interpreting or reporting the result.

Model: `Agent` with `model=haiku`.

### Worker rules

```
Do not edit source, specs, tasks, config, or git state. Running `test.ps1` may write build/test artifacts under `.output`; that is allowed.

Run exactly one requested gate. Do not rerun on failure. Do not run multiple `/al-build` gates in parallel. Do not shadow the worker with an inline build.

Return observed outcome only. Do not make routing decisions. Do not invoke follow-up skills. Do not inspect or summarize telemetry; return the telemetry path when present.
```

### Worker return contract

Return YAML-like plain text in a fenced `text` block.

Take `gate`, `totals`, and all counts from `.output/TestResults/summary.json` — the source of truth; echo `appName`, `dir`, `resultFile`, `telemetryFile`, and every `counts` number verbatim. **Never derive counts from console lines: `Codeunit … Success` lines are test codeunits (containers of tests), not tests.** Report totals per runner; never sum across runners — the unit test app runs through both al-runner and the container, so a cross-runner sum counts the same tests twice. If `counts` is `null` for a run, report `counts: unavailable` — do not substitute zeros. Omit `totals` and `runs` if no summary exists.

On failure, parse the failing run's `resultFile` (JUnit XML, both runners) for failing test names and the `<failure message=…>` text. If XML is unavailable but console output has explicit failure lines, use those. If neither exists, omit `failing_tests`. Omit `first_error` and `log_excerpt` unless corresponding evidence exists. `log_excerpt` is capped at 20 relevant lines. `root_signal` is mandatory for `FAIL` and must compress observed output only; no cause speculation.

PASS example:

```text
VERDICT: PASS
cmd: pwsh "<skill-folder>/scripts/test.ps1"
gate: full
exit_code: 0

totals:
  al-runner: 1 run - 563 tests in 54 test codeunits - 563 passed, 0 failed, 0 skipped
  container: 2 runs - 601 tests in 58 test codeunits - 601 passed, 0 failed, 0 skipped

runs:
- runner: al-runner | app: unit-tests | passed: true | tests: 563 (54 test codeunits)
  resultFile: .output/TestResults/unit-tests/al-runner.xml
- runner: container | app: unit-tests | passed: true | tests: 563 (54 test codeunits)
  resultFile: .output/TestResults/unit-tests/last.xml
  telemetryFile: .output/TestResults/unit-tests/telemetry.jsonl
- runner: container | app: integration-tests | passed: true | tests: 38 (4 test codeunits)
  resultFile: .output/TestResults/integration-tests/last.xml
  telemetryFile: .output/TestResults/integration-tests/telemetry.jsonl
```

FAIL example:

```text
VERDICT: FAIL
cmd: pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
gate: unit
exit_code: 1

totals:
  al-runner: 1 run - 563 tests in 54 test codeunits - 561 passed, 2 failed, 0 skipped

runs:
- runner: al-runner | app: unit-tests | passed: false | tests: 563 (54 test codeunits, 2 failed)
  resultFile: .output/TestResults/unit-tests/al-runner.xml

failed_phase: test
root_signal: two tests failed on `Combination Logic`; expected `OR`, actual `AND`
failing_tests:
- DefaultRuleNestedMintPersistsRevisedDescriptionAndPreservesPriorHeader: Assert.AreEqual failed. Expected: OR. Actual: AND.
- DefaultWarningNestedMintPersistsRevisedDescriptionAndPreservesPriorHeader: Assert.AreEqual failed. Expected: OR. Actual: AND.
```

### Full gate delegation

Run:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Report `gate: full`.

### Fast unit test delegation (inner loop)

Run:

```powershell
pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
```

Report `gate: unit`.

## Configuration

Resolution order, highest wins:

1. **CLI flag** — script switches such as `-Force`; app/test paths come from env/config.
2. **Env var** — `ALBT_APP_DIR`, `ALBT_BC_CONTAINER_NAME`, `WARN_AS_ERROR`.
3. **`al-build.json`** in repo root.
4. **Built-in defaults.**

Key config fields:
- `appDir` — path to main app folder (default: `"app"`)
- `testApps` — array of test app directory paths (default: `["test"]`)
- `unitTestApp` — path to AL Runner unit test app (default: `""`, disabled). When set, `test.ps1` runs AL Runner unit tests as fast gate before container tests. App may also appear in `testApps` → container tests run all `testApps` regardless.
- `unitTestInitEvents` — fire BC lifecycle events (`OnCompanyInitialize`, `OnInstallAppPerCompany`) before AL Runner tests (default: `false`). Enable if unit tests depend on install-time data.
- `breakingChange.enabled` — enable breaking-change detection (default: `false`). See below.
- `breakingChange.baselinePackageCachePath` — baseline package cache dir (default: `.output/baseline-cache`, gitignored).

_Avoid_: editing plugin's template `config/al-build.json`. It's a template, not the live config. Repo-root copy is the live one.

## Breaking-change detection

Off by default (`breakingChange.enabled`). When on, two mechanisms, split by cost:

- **Compile-time, in every gate.** `provision.ps1` caches the latest release + deps and points `AppSourceCop.json` at them. A break then surfaces as a normal `AS00xx` diagnostic inside `test.ps1`'s compile (`-UnitTestOnly` included). `AS0001`–`AS0018` default to Error → red gate, like any cop. Not a special verdict — the rule ID is the signal; tune severity in `al.ruleset.json`. No `summary.json` change.
- **Standalone heavyweight.** `validate-breaking-changes.ps1` runs the broader AppSource sim (per-country, install/upgrade) against the same cache. Reads the cache, never downloads; empty cache → stops with *"run provision.ps1"*. Not wired into `test.ps1` — a feature-end / pre-release check, never the inner loop.

`provision.ps1` is the sole baseline fetcher and now refreshes per feature (re-run when a new release is cut). No release yet → detection stays cleanly off, never a false green.

## Container recovery

Situation → action:

| Symptom | Action |
|---|---|
| `test.ps1` fails on container connect / publish | `docker restart <container>`, re-run `test.ps1`. |
| Restart didn't fix it | `docker rm -f <container>`, re-run `test.ps1`. Script recreates it. |
| Recreate didn't fix it | Re-run `provision.ps1`, then `test.ps1`. |

**Anti-pattern: edit container manually.** No `docker exec`, no `Invoke-ScriptInBcContainer` to patch state, no hand-installing apps. Container is disposable; reproducibility lives in scripts.

## Composition

- `/al-implement` — calls this after every RED, GREEN, `/al-refactor`, before flipping the task `status:` to `done`.
- `/al-debug-logging` — consumes `telemetry.jsonl` produced here (in per-app subfolders).
- `init.ps1`, `provision.ps1` — one-time setup before this skill is usable.

## Out of scope

- Provisioning symbols or installing compiler → `pwsh "<skill-folder>/scripts/provision.ps1"`.
- Debugging test failures → `/al-debug-logging`.
- Editing AL code → caller's job.
