# AL Build

Self-contained build/test gate for AL/Business Central. No external task runners.

## Prerequisites

- PowerShell 7.2+ (`pwsh`, not `powershell`).
- Docker Desktop. Use container, not VM.
- .NET SDK (compiler install).
- Node.js (`npx`) — ALCops analyzers install via the official `@alcops/core` CLI. Recommended: `winget install Volta.Volta`, new shell, `volta install node@22`.
- [BcContainerHelper](https://github.com/microsoft/navcontainerhelper) PowerShell module.

## Quick start

```powershell
# 1. Install compiler, download symbols
pwsh scripts/provision.ps1

# Optional: force AL compiler update
pwsh scripts/provision.ps1 -UpdateCompiler

# 2. Golden BC container (once per BC version)
pwsh scripts/new-bc-container.ps1

# 3. Restart PC — Docker networking + hosts file changes need it

# 4. Branch-specific agent container
pwsh scripts/new-agent-container.ps1

# 5. Build + test
pwsh scripts/test.ps1
```

## Scripts

| Script | Purpose |
|---|---|
| `test.ps1` | **Canonical gate.** Build, publish, run tests. |
| `init.ps1` | Drop `al-build.json` in repo root. |
| `provision.ps1` | One-time setup (compiler + analyzers + symbols). Reuses an installed compiler unless `-UpdateCompiler` is passed; refreshes ALCops analyzers on every run. |
| `clean.ps1` | Remove build artifacts. |
| `new-bc-container.ps1` | Create golden BC container. |
| `commit-bc-container.ps1` | Commit container to snapshot image. |
| `new-agent-container.ps1` | Create agent container from snapshot. |
| `prune.ps1` | Remove orphaned containers. |
| `pagescript-replay.ps1` | Run page script YAML replays. |
| `validate-breaking-changes.ps1` | Check public API changes. |

## Daily loop

```powershell
# Full gate
pwsh scripts/test.ps1

# Force republish (after container recreate)
pwsh scripts/test.ps1 -Force
```

## Container management

```powershell
# Golden container — once per BC version
pwsh scripts/new-bc-container.ps1

# Snapshot it
docker stop bctest
pwsh scripts/commit-bc-container.ps1
docker start bctest

# Agent container — branch-scoped, fast spawn from snapshot
pwsh scripts/new-agent-container.ps1

# Prune orphans
pwsh scripts/prune.ps1 -Preview   # dry run
pwsh scripts/prune.ps1            # execute
```

**Never fix the container manually.** Restart, then delete and re-run. The scripts own reproducibility.

## Configuration

### Resolution order

Highest wins:

1. **CLI flag** — script switches such as `-Force`; app/test paths come from env/config.
2. **Env var** — `ALBT_APP_DIR`.
3. **`al-build.json`** in repo root. **Required.**
4. **Built-in defaults.**

The plugin's `config/al-build.json` is a template, not the live config. Copy it to repo root once.

### Env vars

| Variable | Description | Default |
|---|---|---|
| `ALBT_APP_DIR` | Main app directory | `app` |
| `ALBT_TEST_DIR` | Test app directory | `test` |
| `WARN_AS_ERROR` | Treat warnings as errors | `1` |
| `RULESET_PATH` | Analyzer ruleset file | `al.ruleset.json` |
| `ALBT_BC_CONTAINER_NAME` | Container name | (from git branch) |
| `ALBT_BC_SERVER_INSTANCE` | BC server instance | `BC` |
| `ALBT_BC_CONTAINER_USERNAME` | Container username | `admin` |
| `ALBT_BC_CONTAINER_PASSWORD` | Container password | `P@ssw0rd` |
| `ALBT_BC_ARTIFACT_COUNTRY` | BC artifact country | `w1` |
| `ALBT_BC_ARTIFACT_SELECT` | BC version selection | `Latest` |
| `ALBT_BC_MEMORY_LIMIT` | Docker container memory limit | `8g` |

### Project config

```powershell
Copy-Item "<plugin-path>/config/al-build.json" -Destination "<repo-root>/al-build.json"
```

Claude Code users get this via session-start hook.

```json
{
  "appDir": "app",
  "testApps": ["test"],

  "warnAsError": true,
  "rulesetPath": "al.ruleset.json",

  "container": {
    "username": "admin",
    "password": "P@ssw0rd",
    "artifactCountry": "w1",
    "artifactSelect": "Latest"
  }
}
```

## Analyzers

The compiler ships Microsoft's analyzers (CodeCop, UICop, AppSourceCop, PerTenantExtensionCop). `provision.ps1` adds the community [ALCops](https://alcops.dev) analyzers — six cops plus `ALCops.Common.dll` — into the compiler's `Analyzers` folder via the official `@alcops/core` CLI. Always the latest ALCops release, refreshed on every provision run; no pinning. ALCops replaces the discontinued BusinessCentral.LinterCop (shared diagnostic IDs — the two must never load together; provision removes a leftover LinterCop DLL).

Which analyzers run is controlled by `al.codeAnalyzers` in `.vscode/settings.json`, official AL notation only — the same file drives the AL extension in VS Code:

```json
{
  "al.codeAnalyzers": [
    "${CodeCop}",
    "${UICop}",
    "${AppSourceCop}",
    "${PerTenantExtensionCop}",
    "${analyzerFolder}ALCops.ApplicationCop.dll",
    "${analyzerFolder}ALCops.DocumentationCop.dll",
    "${analyzerFolder}ALCops.FormattingCop.dll",
    "${analyzerFolder}ALCops.LinterCop.dll",
    "${analyzerFolder}ALCops.PlatformCop.dll",
    "${analyzerFolder}ALCops.TestAutomationCop.dll",
    "${analyzerFolder}ALCops.Common.dll"
  ]
}
```

Resolution is per app: `<appDir>/.vscode/settings.json` wins, repo-root `.vscode/settings.json` is the shared fallback — so the main app can run the full set including AppSourceCop while test apps run a reduced set (TestAutomationCop, no AppSourceCop). In `-UnitTestOnly` mode the unit-test app is not analyzed (AL Runner compiles it internally); test-app analyzers apply in the full gate. No `settings.json` → no analyzers. A requested analyzer that cannot be resolved fails the build — the gate never silently compiles with less lint coverage than the settings ask for. `ALCops.Common.dll` (and `Microsoft.Dynamics.Nav.Analyzers.Common.dll` when no Microsoft analyzer is enabled) is appended automatically when missing from the list. Diagnostic prefixes: `AA` CodeCop, `AW` UICop, `AS` AppSourceCop, `PTE` PerTenantExtensionCop, `AC` ApplicationCop, `DC` DocumentationCop, `FC` FormattingCop, `LC` LinterCop (code-quality subset), `PC` PlatformCop, `TA` TestAutomationCop.

## Architecture

### Three-tier containers

1. **Golden container** (`bctest`) — fully configured BC, all base dependencies.
2. **Snapshot image** (`bctest:snapshot`) — committed Docker image, fast spawn.
3. **Agent containers** — branch-scoped, derived from snapshot, named after git branch.

~30 seconds from snapshot vs ~10 minutes from scratch.

### Incremental publish

Skip redundant publishes via state tracking:

- **Source hash compare** — republish only when code changed.
- **Container recreate detect** — force republish after recreate.
- **Manual override** — `-Force`.

State files live per-container in the symbol cache directory.

## Troubleshooting

### Build failures

1. Read compiler output for errors.
2. Symbols provisioned? `pwsh scripts/provision.ps1`.
3. Container healthy? `docker ps`.

### Test failures

1. Read `.output/TestResults/last.xml` for assertion failures.
2. Use telemetry — `/al-debug-logging` consumes `.output/TestResults/telemetry.jsonl`.
3. Fix the failing test or code, then rerun the full gate.

### Container issues

1. `docker inspect <name> --format '{{.State.Health.Status}}'`.
2. `docker logs <name>`.
3. Recreate: `pwsh scripts/new-agent-container.ps1`.

### Common

| Symptom | Cause | Fix |
|---|---|---|
| "Compiler not found" | Provision not run | `pwsh scripts/provision.ps1` |
| "Container unhealthy" | Docker | Restart Docker, recreate container |
| "Symbol not found" | Missing dependency | Check `app.json` deps, re-provision |
| "Test timeout" | Long-running tests | Raise timeout or optimize the slow suite |

## Output files

| File | Location |
|---|---|
| Test results (JUnit) | `.output/TestResults/last.xml` |
| Telemetry | `.output/TestResults/telemetry.jsonl` |
| Build timing | `.output/logs/build-timing.jsonl` |
| Publish state | `~/.bc-symbol-cache/.../publish-state.*.json` |
