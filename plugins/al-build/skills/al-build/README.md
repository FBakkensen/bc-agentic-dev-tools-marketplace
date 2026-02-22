# AL Build - User Guide

Remote test execution infrastructure for Business Central AL development. Compiles apps locally and runs tests on a remote Azure VM.

This document covers prerequisites and manual setup tasks.

## Prerequisites

Before using this skill, ensure:

1. **SSH Access**: SSH key configured for the remote Azure VM
2. **Configuration File**: `al-build.json` exists at repository root
3. **Provisioned Environment**: Run `provision.ps1` at least once

## Configuration (al-build.json)

Create `al-build.json` at repository root:

```json
{
  "appDir": "app",
  "testDir": "test",
  "warnAsError": true,
  "tenant": "default",
  "remote": {
    "vmHost": "<your-vm-hostname>",
    "vmUser": "<ssh-username>",
    "appStagingPath": "C:/temp/apps",
    "sharedBasePath": "C:/shared"
  },
  "container": {
    "username": "admin",
    "password": "<container-password>",
    "imageName": "<your-registry>/bctest:snapshot"
  }
}
```

### Required Fields

| Field | Description |
|-------|-------------|
| `remote.vmHost` | Azure VM hostname or IP |
| `remote.vmUser` | SSH username |

### Optional Fields

| Field | Default | Description |
|-------|---------|-------------|
| `appDir` | `app` | Main app source directory |
| `testDir` | `test` | Test app source directory |
| `warnAsError` | `false` | Treat warnings as errors |
| `tenant` | `default` | BC tenant name |

## Manual Scripts

These scripts are for user setup, not agent use:

### provision.ps1 - First-Time Setup

Installs the AL compiler and downloads symbol packages:

```powershell
pwsh ".agents/skills/al-build/scripts/provision.ps1"
```

Run this:
- When setting up a new development machine
- After updating BC version in `app.json`
- When dependencies change

### download-symbols.ps1 - Update Symbols

Downloads symbol packages for a specific app directory:

```powershell
pwsh ".agents/skills/al-build/scripts/download-symbols.ps1" -AppDir "app"
```

## Build Timing History

Test runs are logged to `.output/logs/build-timing.jsonl` for performance tracking. Each entry includes:
- Timestamp
- Step durations (build, publish, test, etc.)
- Total execution time

View recent history in terminal output after each test run.

## Troubleshooting

### SSH Connection Issues

Verify SSH access:
```powershell
ssh <vmUser>@<vmHost> hostname
```

### Compiler Not Found

Run provisioning:
```powershell
pwsh ".agents/skills/al-build/scripts/provision.ps1"
```

### Symbol Cache Missing

Run provisioning to download symbols:
```powershell
pwsh ".agents/skills/al-build/scripts/provision.ps1"
```

### Container Creation Timeout

The remote VM creates BC containers on-demand. First run on a new branch may take longer. The 20-minute timeout should accommodate this.
