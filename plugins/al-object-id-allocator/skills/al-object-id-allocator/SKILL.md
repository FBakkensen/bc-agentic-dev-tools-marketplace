---
name: al-object-id-allocator
description: Allocate the next available Business Central AL object ID/number by scanning .al files and idRanges in app.json using the bundled PowerShell script. Use when creating new tables/pages/codeunits/extensions and you need a free object number.
---

# AL Object ID Allocator

Allocate the next available AL object number using `scripts/Get-NextALObjectNumber.ps1`.

## Usage

Paths are relative to the skill root.
If needed, set it with: `Set-Location ".agents/skills/al-object-id-allocator"`

```powershell
pwsh -File "scripts/Get-NextALObjectNumber.ps1" -AppPath "<AL_APP_FOLDER>" -ObjectType "<type>"
```

Common patterns:
- `pwsh -File "scripts/Get-NextALObjectNumber.ps1" -AppPath "<AL_APP_FOLDER>" -ObjectType "table"`
- `pwsh -File "scripts/Get-NextALObjectNumber.ps1" -AppPath "<AL_APP_FOLDER>" -ObjectType "codeunit"`

## Supported object types

table, page, codeunit, report, query, xmlport, enum, interface, controladdin, pageextension, tableextension, enumextension, reportextension, permissionset, entitlement, profile, pagecustomization

## Output and errors

- On success, the script writes a single integer (the allocated number) to stdout and exits with code `0`.
- On error, it writes `ERROR-XXX: <message>` to stderr and exits with code `1`.

Tip: Capture the result in PowerShell:
- `$nextNumber = & "scripts/Get-NextALObjectNumber.ps1" -AppPath "<AL_APP_FOLDER>" -ObjectType "page"`

## What it does (high level)

1. Reads `idRanges` from `<AppPath>\app.json`
2. Scans `<AppPath>\**\*.al` for existing objects of the requested type
3. Ignores commented-out declarations
4. Returns the smallest available number within the allowed ranges (fills gaps first)
