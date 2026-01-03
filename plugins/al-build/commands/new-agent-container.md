---
description: Create an agent container from BC snapshot image
---

# AL Build New Agent Container

Spawn a new container from a committed BC Docker snapshot image. If no agent name is provided, uses the current Git branch name.

## Prerequisites
- Snapshot image exists (created via `/al-build:commit-bc-container`)
- Docker Desktop running

## Command
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-build/scripts/new-agent-container.ps1"
```

## Options
- `-AgentName <string>` - Name for the agent container (default: current git branch)
- `-ImageName <string>` - Docker image to use (default: from `al-build.json`)
- `-MemoryLimit <string>` - Memory limit for the container (default: `8g`)

## What it does
1. Auto-detects agent name from current git branch (if not provided)
2. Removes orphaned containers from deleted branches
3. Creates container from snapshot image
4. Waits for container to become healthy
5. Configures network and hosts entry
6. Updates PublicWebBaseUrl for the new hostname
