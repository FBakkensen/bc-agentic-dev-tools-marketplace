---
description: Initialize al-build configuration for this project
---

# AL Build Init

Initialize al-build configuration for the current project.

## What it does
1. Copies `al-build.json` template to project root
2. Auto-detects app and test directories by searching for `app.json` files
3. Updates config with detected settings (appDir, testDir, testAppName)

## Command
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-build/scripts/init.ps1"
```

## Next Steps
After initialization:
1. Review and customize `al-build.json` as needed
2. Run `/al-build:provision` to install compiler and download symbols
3. Run `/al-build:test` to verify the build gate
