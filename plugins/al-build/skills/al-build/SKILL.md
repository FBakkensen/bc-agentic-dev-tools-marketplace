---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
---

# /al-build — Build and test gate

Run after every AL change. Zero warnings, zero errors. Anything else is red.

Required gate before committing AL changes. `/al-implement` calls this after every RED, GREEN, and `/al-refactor`.

## First time

1. `pwsh "<skill-folder>/scripts/init.ps1"` — drops `al-build.json` in repo root.
2. Set `testApps` to list your test app directories.
3. `pwsh "<skill-folder>/scripts/provision.ps1"` — one-time symbol + container setup.

`Stop. Run pwsh "<skill-folder>/scripts/provision.ps1" first.` if `test.ps1` complains the compiler or symbols are missing.

## Canonical gate

Set location to the consumer repo root, then:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Always run the full gate. Do not filter tests by codeunit.
Force republish: `pwsh "<skill-folder>/scripts/test.ps1" -Force`

### Fast unit test (inner loop)

When `unitTestApp` is configured in `al-build.json`, run only AL Runner unit tests:

```powershell
pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly
```

Compiles all apps, runs AL Runner against the unit test app, exits. No container needed. Use during the RED→GREEN inner loop in `/al-implement` for fast feedback.

**Outputs (per test app):**

- `.output/TestResults/<dirName>/last.xml` — JUnit XML per test app.
- `.output/TestResults/<dirName>/telemetry.jsonl` — feature telemetry per test app. `/al-debug-logging` reads this.
- `.output/TestResults/summary.json` — machine-readable pass/fail summary for all test apps.

To find all test results: `glob .output/TestResults/*/last.xml`

For test failures, dispatch `/al-debug-logging`. Don't grep the build log for clues telemetry already answers.

## Delegation

Prefer a delegated worker when the host supports subagents. Build output is verbose. Contain it.

### Full gate delegation

```
IMPORTANT: READ-ONLY. Do not edit files.

Run: pwsh "<skill-folder>/scripts/test.ps1"

Report:
1. Build result: success or failure
2. Test result: pass / fail counts per test app
3. Failures: error messages and stack traces (from per-app last.xml)
4. Warnings: list them
5. Summary: contents of .output/TestResults/summary.json
6. If telemetry relevant: key entries from .output/TestResults/*/telemetry.jsonl
```

### Fast unit test delegation (inner loop)

```
IMPORTANT: READ-ONLY. Do not edit files.

Run: pwsh "<skill-folder>/scripts/test.ps1" -UnitTestOnly

Report:
1. Build result: success or failure
2. Unit test result: pass / fail counts
3. Failures: error messages from last.xml
4. Summary: contents of .output/TestResults/summary.json
```

## Configuration

Resolution order, highest wins:

1. **CLI flag** — script switches such as `-Force`; app/test paths come from env/config.
2. **Env var** — `ALBT_APP_DIR`, `ALBT_BC_CONTAINER_NAME`, `WARN_AS_ERROR`.
3. **`al-build.json`** in repo root.
4. **Built-in defaults.**

Key config fields:
- `appDir` — path to the main app folder (default: `"app"`)
- `testApps` — array of test app directory paths (default: `["test"]`)
- `unitTestApp` — path to the AL Runner unit test app (default: `""`, disabled). When set, `test.ps1` runs AL Runner unit tests as a fast gate before container tests. The app may also appear in `testApps` — container tests run all `testApps` regardless.
- `unitTestInitEvents` — fire BC lifecycle events (`OnCompanyInitialize`, `OnInstallAppPerCompany`) before AL Runner tests (default: `false`). Enable if unit tests depend on install-time data.

_Avoid_: editing the plugin's template `config/al-build.json`. It's a template, not the live config. The repo-root copy is the live one.

## Container recovery

Situation → action:

| Symptom | Action |
|---|---|
| `test.ps1` fails on container connect / publish | `docker restart <container>`, re-run `test.ps1`. |
| Restart didn't fix it | `docker rm -f <container>`, re-run `test.ps1`. The script recreates it. |
| Recreate didn't fix it | Re-run `provision.ps1`, then `test.ps1`. |

**Anti-pattern: edit the container manually.** No `docker exec`, no `Invoke-ScriptInBcContainer` to patch state, no hand-installing apps. The container is disposable; reproducibility lives in the scripts.

## Yes / No

**No:** `alc.exe app.json` directly. Use `/al-build` for tests, not bare `alc.exe` — symbol resolution, container publish, and telemetry capture live in `test.ps1`.
**Yes:** `pwsh scripts/test.ps1` after every AL edit.

**No:** `docker exec <container> bash` to fix it in place.
**Yes:** `docker rm -f <container>` and re-run.

## Composition

- `/al-implement` — calls this after every RED, GREEN, `/al-refactor`, and before marking `[x]`. Use `-UnitTestOnly` for the RED→GREEN inner loop when `unitTestApp` is configured; use the full gate before committing.
- `/al-debug-logging` — consumes `telemetry.jsonl` produced here (in per-app subfolders).
- `pwsh "<skill-folder>/scripts/init.ps1"`, `pwsh "<skill-folder>/scripts/provision.ps1"` — one-time setup before this skill is usable.

## Out of scope

- Provisioning symbols or installing the compiler — `pwsh "<skill-folder>/scripts/provision.ps1"`.
- Debugging test failures — `/al-debug-logging`.
- Editing AL code — caller's job.
