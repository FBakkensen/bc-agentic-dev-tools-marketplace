---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
excludeAgent: "coding-agent"
---

# /al-build — Build and test gate

Run after every AL change. Zero warnings, zero errors is the only passing state.

## First time

1. Run `/al-build:init` → creates `al-build.json` in repo root.
2. Set `testAppName` to match your test app.
3. Run `/al-build:provision` once.

## Canonical gate

Set location to repo root, then:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

Faster iteration: `pwsh "<skill-folder>/scripts/test.ps1" -TestCodeunit <id>`
Force republish: `pwsh "<skill-folder>/scripts/test.ps1" -Force`

**Outputs:** `.output/TestResults/last.xml` and `telemetry.jsonl`. Use `jq` to query both. For test failures, use `/al-debug-logging`.

## Run as subagent (recommended)

Build output is verbose. Contain it in a subagent.

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

## Container recovery

If `test.ps1` fails due to a container infrastructure problem:

1. **Restart** — `docker restart <container-name>`. Re-run `test.ps1`.
2. **Delete** — `docker rm -f <container-name>`. Re-run `test.ps1`. The script recreates the container automatically.

Never fix the container manually.

## Out of scope

- Provisioning symbols or installing the compiler — use `/al-build:provision`.
- Debugging test failures — use `/al-debug-logging`.
