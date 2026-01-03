---
name: al-build
description: Build and test AL/Business Central projects. Use after modifying AL code or tests to verify the build gate passes. Runs compilation, publishing, and test execution in a single command. Required gate before committing AL changes.
---

# AL Build

Self-contained build system for AL/Business Central development. No external task runners required.

## Canonical Gate

After modifying AL code or tests, run:

```powershell
pwsh "<skill-folder>/scripts/test.ps1"
```

**Requirements:**
- Zero warnings, zero errors
- For faster iteration: `pwsh "<skill-folder>/scripts/test.ps1" -TestCodeunit <id>`
- Force republish (after container recreation): `pwsh "<skill-folder>/scripts/test.ps1" -Force`

**Outputs:**
- `test/TestResults/last.xml` — JUnit test results
- `test/TestResults/telemetry.jsonl` — merged telemetry

## Troubleshooting

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
