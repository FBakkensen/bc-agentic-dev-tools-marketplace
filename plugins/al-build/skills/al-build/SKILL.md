---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
---

# AL Build

Self-contained build system for AL/Business Central development. No external task runners required.

## Project Setup (First Time)

**Automatic**: When you first use al-build in an AL project, a config file (`al-build.json`) is created in your repo root.

**Required Steps**:
1. **Customize config** (especially `testAppName` to match your test app)
2. **Run provision** (one-time):
   ```powershell
   pwsh "<skill-folder>/scripts/provision.ps1"
   ```

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
- `test/TestResults/last.xml` — JUnit test results
- `test/TestResults/telemetry.jsonl` — merged telemetry

## Troubleshooting

### Config Issues

1. **Config not loading**: Ensure `al-build.json` is in git repo root (same level as `.git/`)
2. **Provision not found**: Run `pwsh "<skill-folder>/scripts/provision.ps1"` (one-time)
3. **Wrong test app**: Update `testAppName` in `al-build.json` to match your test app

### Build Failures

1. Check compiler output for error messages
2. Ensure symbols are provisioned (user runs: `pwsh provision.ps1`)
3. Verify container is healthy: `docker ps`

### Test Failures

1. Check `test/TestResults/last.xml` for assertion failures
2. Use telemetry for debugging: see `telemetry-first-test-debugging` skill
3. Run specific codeunit: `pwsh "<skill-folder>/scripts/test.ps1" -TestCodeunit <id>`

### Container Issues

1. Check container health: `docker inspect <name> --format '{{.State.Health.Status}}'`
2. View container logs: `docker logs <name>`
