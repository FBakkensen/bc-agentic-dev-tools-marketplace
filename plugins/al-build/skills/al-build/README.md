# AL Build

Self-contained build system for AL/Business Central development. No external task runners required.

## Prerequisites

- PowerShell 7.2+
- Docker Desktop (for BC containers)
- .NET SDK (for AL compiler installation)
- [BcContainerHelper](https://github.com/microsoft/navcontainerhelper) PowerShell module

## Quick Start

```powershell
# 1. Install compiler and download symbols
pwsh scripts/provision.ps1

# 2. Create golden BC container (once per BC version)
pwsh scripts/new-bc-container.ps1

# 3. Restart PC (required for Docker networking/hosts file changes)

# 4. Create branch-specific agent container
pwsh scripts/new-agent-container.ps1

# 5. Build and test
pwsh scripts/test.ps1
```

## Commands Reference

| Command | Script | Purpose |
|---------|--------|---------|
| `test` | `test.ps1` | **Canonical gate** - Build, publish, run tests |
| `provision` | `provision.ps1` | One-time setup (compiler + symbols) |
| `clean` | `clean.ps1` | Remove build artifacts |
| `pagescript-replay` | `pagescript-replay.ps1` | Run page script YAML replays |
| `new-bc-container` | `new-bc-container.ps1` | Create BC Docker container |
| `commit-bc-container` | `commit-bc-container.ps1` | Commit container to snapshot image |
| `new-agent-container` | `new-agent-container.ps1` | Create agent container from snapshot |
| `prune` | `prune.ps1` | Remove orphaned containers |
| `validate-breaking-changes` | `validate-breaking-changes.ps1` | Check public API changes |

## Usage Examples

### First-Time Setup

```powershell
# Install compiler and download symbols
pwsh scripts/provision.ps1
```

### Daily Development

**First time**:
1. Copy template config to repo root:
   ```powershell
   Copy-Item "<plugin-path>/config/al-build.json" -Destination "<repo-root>/al-build.json"
   ```
2. Customize `al-build.json` (especially `testAppName`)
3. Run provision: `pwsh scripts/provision.ps1`

**Every change**:

```powershell
# Build and test (full gate)
pwsh scripts/test.ps1

# Run specific test codeunit
pwsh scripts/test.ps1 -TestCodeunit 50123

# Force republish (after container recreation)
pwsh scripts/test.ps1 -Force
```

### Container Management

```powershell
# Create golden container (once per BC version)
pwsh scripts/new-bc-container.ps1

# Commit to snapshot (after stopping)
docker stop bctest
pwsh scripts/commit-bc-container.ps1
docker start bctest

# Create branch-specific agent container
pwsh scripts/new-agent-container.ps1

# Clean up orphaned containers
pwsh scripts/prune.ps1 -Preview  # dry run
pwsh scripts/prune.ps1           # execute
```

## Configuration

### Three-Tier Resolution

Configuration values are resolved in order:

1. **Script parameters** — highest priority
2. **Environment variables** — for CI/automation
3. **Config file defaults** — `config/al-build.json`

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
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

### Project-Level Configuration

**Manual Setup**: Copy the template config to your repo root:

```powershell
Copy-Item "<plugin-path>/config/al-build.json" -Destination "<repo-root>/al-build.json"
```

**Note**: Claude Code users get this automatically via session-start hook.

**Customize for your project**:

```json
{
  "appDir": "app",
  "testDir": "test",
  "testAppName": "Your Test App Name Here",

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

**Config Resolution Priority**:
1. Script parameters (`-AppDir "src"`)
2. Environment variables (`ALBT_APP_DIR`)
3. **Project config** (`al-build.json` in repo root) ← **Required**

**Note**: Plugin config is only a template - not loaded during build. Project config is required.

## Architecture

### File Structure

```
.claude/skills/al-build/
├── SKILL.md                    # Agent-facing documentation (minimal)
├── README.md                   # User-facing documentation (this file)
├── config/
│   └── al-build.json           # Default configuration
└── scripts/
    ├── common.psm1             # Shared utilities
    ├── build-operations.psm1   # Build/publish/test operations
    ├── provision.ps1           # Compiler + symbol setup
    ├── test.ps1                # Full build-test gate
    ├── clean.ps1               # Artifact cleanup
    ├── prune.ps1               # Container cleanup
    ├── new-bc-container.ps1    # Golden container creation
    ├── commit-bc-container.ps1 # Snapshot image creation
    ├── new-agent-container.ps1 # Agent container spawning
    ├── pagescript-replay.ps1   # Page script testing
    └── validate-breaking-changes.ps1
```

### Container Strategy

The build system uses a three-tier container approach:

1. **Golden container** (`bctest`): Fully configured BC container with all base dependencies
2. **Snapshot image** (`bctest:snapshot`): Committed Docker image for fast spawning
3. **Agent containers**: Branch-specific containers derived from snapshot (named after git branch)

This allows fast container creation (~30 seconds from snapshot vs ~10 minutes from scratch).

### Incremental Publish

The system tracks publish state to skip redundant operations:

- **Source file hash comparison** — Only republish when code changes
- **Container recreation detection** — Force republish after container recreate
- **Manual override** — Use `-Force` flag to bypass caching

State files are stored per-container in the symbol cache directory.

## Troubleshooting

### Build Failures

1. Check compiler output for error messages
2. Ensure symbols are provisioned: `pwsh scripts/provision.ps1`
3. Verify container is healthy: `docker ps`

### Test Failures

1. Check `test/TestResults/last.xml` for assertion failures
2. Use telemetry for debugging: see `telemetry-first-test-debugging` skill
3. Run specific codeunit: `pwsh scripts/test.ps1 -TestCodeunit <id>`

### Container Issues

1. Check container health: `docker inspect <name> --format '{{.State.Health.Status}}'`
2. View container logs: `docker logs <name>`
3. Recreate if unhealthy: `pwsh scripts/new-agent-container.ps1`

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Compiler not found" | Provision not run | Run `pwsh scripts/provision.ps1` |
| "Container unhealthy" | Docker issues | Restart Docker, recreate container |
| "Symbol not found" | Missing dependency | Check app.json dependencies, re-provision |
| "Test timeout" | Long-running tests | Increase timeout or isolate test |

## Output Files

| File | Location | Description |
|------|----------|-------------|
| Test results | `test/TestResults/last.xml` | JUnit XML format |
| Telemetry | `test/TestResults/telemetry.jsonl` | Feature telemetry logs |
| Build timing | `logs/build-timing.jsonl` | Historical timing data |
| Publish state | `~/.bc-symbol-cache/.../publish-state.*.json` | Incremental publish tracking |
