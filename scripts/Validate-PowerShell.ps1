#Requires -Version 7.2
<#
.SYNOPSIS
    Validates PowerShell syntax for all .ps1 files in the repository.
.DESCRIPTION
    Recursively finds all .ps1 files and validates their syntax using the PowerShell parser.
    Returns exit code 1 if any file fails validation.
.EXAMPLE
    pwsh scripts/Validate-PowerShell.ps1
#>
[CmdletBinding()]
param()

$errors = @()
Get-ChildItem -Path $PSScriptRoot/.. -Recurse -Filter "*.ps1" | ForEach-Object {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        $_.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        $errors += "FAIL: $($_.FullName)"
        $parseErrors | ForEach-Object { $errors += "  - $($_.Message)" }
        Write-Host "FAIL: $($_.FullName)" -ForegroundColor Red
    } else {
        Write-Host "OK: $($_.FullName)" -ForegroundColor Green
    }
}

# Validate module exports
Write-Host "`n--- Module Export Validation ---" -ForegroundColor Cyan
Get-ChildItem -Path $PSScriptRoot/.. -Recurse -Filter "*.psm1" | ForEach-Object {
    try {
        $module = Import-Module $_.FullName -PassThru -Force -DisableNameChecking -ErrorAction Stop

        # Parse for Export-ModuleMember to find expected exports
        $content = Get-Content -LiteralPath $_.FullName -Raw
        if ($content -match "Export-ModuleMember\s+-Function\s+@\(([\s\S]*?)\)") {
            $exportBlock = $matches[1]
            $expectedFunctions = [regex]::Matches($exportBlock, "'([^']+)'") |
                ForEach-Object { $_.Groups[1].Value }

            foreach ($func in $expectedFunctions) {
                if (-not ($module.ExportedCommands.Keys -contains $func)) {
                    $errors += "FAIL: $($_.FullName) - Function '$func' declared in Export-ModuleMember but not found"
                    Write-Host "FAIL: $($_.FullName) - Function '$func' not exported" -ForegroundColor Red
                }
            }
        }

        Remove-Module $module -Force -ErrorAction SilentlyContinue
        Write-Host "OK: $($_.FullName) (module exports validated)" -ForegroundColor Green
    } catch {
        $errors += "FAIL: $($_.FullName) - Import failed: $($_.Exception.Message)"
        Write-Host "FAIL: $($_.FullName) - Import failed" -ForegroundColor Red
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`nAll PowerShell files validated successfully." -ForegroundColor Cyan
