---
description: One-time setup for AL build (compiler + symbols)
---

# AL Build Provision

Run once to set up compiler and symbols. Required before first build.

## Command
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-build/scripts/provision.ps1"
```
