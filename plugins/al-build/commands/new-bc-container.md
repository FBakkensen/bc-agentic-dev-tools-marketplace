---
description: Create a new BC Docker container (golden container for snapshots)
---

# AL Build New BC Container

Create and configure a Business Central Docker container. This is the "golden" container that can be committed to a snapshot image for spawning agent containers.

## Prerequisites
- Docker Desktop running
- BcContainerHelper module installed

## Command
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-build/scripts/new-bc-container.ps1"
```

## Options
- `-ApplicationInsightsConnectionString <string>` - Azure Application Insights connection string for telemetry

## What it does
1. Creates a BC container with test toolkit
2. Configures development settings (symbol loading, debugging)
3. Installs AL Test Runner Service
4. Installs AL-Go dependencies
5. Prepares container for commit (stops IIS, removes web client folder)
6. Stops the container

## Next Steps
After creating the golden container:
1. **Restart your computer** to release locked files
2. Run `/al-build:commit-bc-container` to create a snapshot image
