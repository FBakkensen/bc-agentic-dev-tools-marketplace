---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
---

# AL Build

Self-contained build system for AL/Business Central development. No external task runners required.

## Project Setup (First Time)

**Required Steps**:
1. **Initialize config**: Run `/al-build:init` to create `al-build.json`
2. **Customize config** (especially `testAppName` to match your test app)
3. **Run provision** (one-time): Run `/al-build:provision`

**Config Priority** (highest to lowest):
1. Script parameters (e.g., `-AppDir "custom"`)
2. Environment variables (e.g., `ALBT_APP_DIR`)
3. Project config (`al-build.json` in repo root)

## Canonical Gate

After modifying AL code or tests, run:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

**Prerequisites:**
- Project config exists and customized (`al-build.json`)
- Provision completed (run `provision.ps1` once)
- Docker container healthy

**Requirements:**
- Zero warnings, zero errors
- Faster iteration: `pwsh "<skill-folder>/scripts/test.ps1" -TestCodeunit <id>`
- Force republish: `pwsh "<skill-folder>/scripts/test.ps1" -Force`

**Outputs:**
- `.output/TestResults/last.xml` — JUnit test results
- `.output/TestResults/telemetry.jsonl` — merged telemetry

## Troubleshooting

### Build fails and no config exists

If `/al-build:test` fails and `al-build.json` doesn't exist in repo root:
1. Run `/al-build:init` to create config
2. Customize settings as needed
3. Run `/al-build:provision` once
4. Re-run `/al-build:test`

### Config Issues

1. **Config not loading**: Ensure `al-build.json` is in git repo root (same level as `.git/`)
2. **Provision not found**: Run `/al-build:provision` (one-time)
3. **Wrong test app**: Update `testAppName` in `al-build.json` to match your test app

### Build Failures

1. Check compiler output for error messages
2. Ensure symbols are provisioned (user runs: `pwsh provision.ps1`)
3. Verify container is healthy: `docker ps`

### Test Failures

1. Check `.output/TestResults/last.xml` for assertion failures
2. Use telemetry for debugging: see `telemetry-first-test-debugging` skill
3. Run specific codeunit: `pwsh "<skill-folder>/scripts/test.ps1" -TestCodeunit <id>`

### Container Issues

1. Check container health: `docker inspect <name> --format '{{.State.Health.Status}}'`
2. View container logs: `docker logs <name>`
