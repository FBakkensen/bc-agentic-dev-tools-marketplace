---
description: Run AL build gate (compile, publish, test)
---

# AL Build Test

Run the canonical build gate after modifying AL code or tests.

## Prerequisites
- Project config exists (`al-build.json` in repo root)
- Provision completed (run `/al-build:provision` once)
- Docker container healthy

## Command
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-build/scripts/test.ps1"
```

## Options
- `-TestCodeunit <id>` - Run specific test codeunit only
- `-Force` - Force republish apps

## Outputs
- `test/TestResults/last.xml` - JUnit test results
- `test/TestResults/telemetry.jsonl` - Merged telemetry
