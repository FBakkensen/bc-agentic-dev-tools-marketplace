---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
---

# /al-build — Build and test gate

Run after every AL change. Zero warnings, zero errors. Anything else is red.

Required gate before committing AL changes. `/al-implement` calls this after every RED, GREEN, and `/al-refactor`.

## First time

1. `pwsh "<skill-folder>/scripts/init.ps1"` — drops `al-build.json` in repo root.
2. Set `testAppName` to match your test app.
3. `pwsh "<skill-folder>/scripts/provision.ps1"` — one-time symbol + container setup.

`Stop. Run pwsh "<skill-folder>/scripts/provision.ps1" first.` if `test.ps1` complains the compiler or symbols are missing.

## Canonical gate

Set location to the consumer repo root, then:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Faster iteration: `pwsh "<skill-folder>/scripts/test.ps1" -TestCodeunit <id>`
Force republish: `pwsh "<skill-folder>/scripts/test.ps1" -Force`

**Outputs:**

- `.output/TestResults/last.xml` — JUnit XML. Query with `jq` or read directly.
- `.output/TestResults/telemetry.jsonl` — feature telemetry. `/al-debug-logging` reads this.

For test failures, dispatch `/al-debug-logging`. Don't grep the build log for clues telemetry already answers.

## Delegation

Prefer a delegated worker when the host supports subagents. Build output is verbose. Contain it.

```
IMPORTANT: READ-ONLY. Do not edit files.

Run: pwsh "<skill-folder>/scripts/test.ps1"

Report:
1. Build result: success or failure
2. Test result: pass / fail counts
3. Failures: error messages and stack traces
4. Warnings: list them
5. If telemetry relevant: key entries from .output/TestResults/telemetry.jsonl
```

## Configuration

Resolution order, highest wins:

1. **CLI flag** — `-AppDir "src"`, `-TestCodeunit 50123`.
2. **Env var** — `ALBT_APP_DIR`, `ALBT_BC_CONTAINER_NAME`, `WARN_AS_ERROR`.
3. **`al-build.json`** in repo root.
4. **Built-in defaults.**

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

- `/al-implement` — calls this after every RED, GREEN, `/al-refactor`, and before marking `[x]`.
- `/al-debug-logging` — consumes `telemetry.jsonl` produced here.
- `pwsh "<skill-folder>/scripts/init.ps1"`, `pwsh "<skill-folder>/scripts/provision.ps1"` — one-time setup before this skill is usable.

## Out of scope

- Provisioning symbols or installing the compiler — `pwsh "<skill-folder>/scripts/provision.ps1"`.
- Debugging test failures — `/al-debug-logging`.
- Editing AL code — caller's job.
