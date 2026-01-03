---
description: Commit BC container to a Docker snapshot image
---

# AL Build Commit BC Container

Commit a stopped BC Docker container to a snapshot image that can be used to spawn agent containers.

## Prerequisites
- Golden container exists (created via `/al-build:new-bc-container`)
- Container must be stopped
- Computer restarted after creating the golden container

## Command
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-build/scripts/commit-bc-container.ps1"
```

## Options
- `-ContainerName <string>` - Name of the container to commit (default: from `al-build.json`)
- `-ImageName <string>` - Name for the snapshot image (default: from `al-build.json`)

## Next Steps
After committing the snapshot:
1. Start the golden container if needed: `docker start <container-name>`
2. Spawn agent containers: `/al-build:new-agent-container`
