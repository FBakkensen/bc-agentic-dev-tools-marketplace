---
description: Update BC W1 source mirror
---

# Update BC W1 Mirror

Fast-forward update the local BC W1 source mirror.

## Command
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/bc-w1-reference/scripts/update-bc-w1.ps1"
```

## Options
- `-TargetPath <path>` - Override folder (default: `_aldoc/bc-w1`)
- `-RepoRoot <path>` - Repo root if not running from it
