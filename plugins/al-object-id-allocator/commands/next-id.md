---
description: Get next available AL object ID
---

# Next AL Object ID

Allocate the next available AL object number by scanning existing .al files and idRanges in app.json.

## Usage
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-object-id-allocator/scripts/Get-NextALObjectNumber.ps1" -AppPath "<app-folder>" -ObjectType "<type>"
```

## Examples
```powershell
# Get next table ID for main app
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-object-id-allocator/scripts/Get-NextALObjectNumber.ps1" -AppPath "./app" -ObjectType "table"

# Get next codeunit ID for test app
pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/skills/al-object-id-allocator/scripts/Get-NextALObjectNumber.ps1" -AppPath "./test" -ObjectType "codeunit"
```

## Supported Object Types
table, page, codeunit, report, query, xmlport, enum, interface, controladdin, pageextension, tableextension, enumextension, reportextension, permissionset, entitlement, profile, pagecustomization

## Output
- Success: Single integer (allocated ID) to stdout, exit code 0
- Error: `ERROR-XXX: <message>` to stderr, exit code 1
