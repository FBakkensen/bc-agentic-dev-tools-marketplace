#requires -Version 7.2

<#
.SYNOPSIS
    SessionStart hook: Initialize project-level config if missing

.DESCRIPTION
    Runs automatically when Claude Code starts. Checks if the current project
    has an al-build.json config file in the repo root. If not, and this is an
    AL project, copies the template from the plugin's config directory.

    Non-intrusive: Only copies if file doesn't exist.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitRepoRoot {
    try {
        $root = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $root) {
            if ($IsWindows -or $env:OS -match 'Windows') {
                $root = $root -replace '/', '\'
            }
            return $root
        }
    } catch { }
    return $null
}

# Detect if we're in a git repo
$repoRoot = Get-GitRepoRoot
if (-not $repoRoot) { exit 0 }

# Check if project config already exists
$projectConfigPath = Join-Path $repoRoot 'al-build.json'
if (Test-Path -LiteralPath $projectConfigPath) { exit 0 }

# Check if this looks like an AL project (has app/ or test/ with app.json)
$hasAlProject = $false
foreach ($dir in @('app', 'test')) {
    $appJsonPath = Join-Path $repoRoot $dir 'app.json'
    if (Test-Path -LiteralPath $appJsonPath) {
        $hasAlProject = $true
        break
    }
}
if (-not $hasAlProject) { exit 0 }

# This is an AL project without config - copy template
try {
    $pluginRoot = $env:CLAUDE_PLUGIN_ROOT
    if (-not $pluginRoot) {
        # Fallback: derive from script location
        $pluginRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    }

    $templatePath = Join-Path $pluginRoot 'skills' 'al-build' 'config' 'al-build.json'
    if (-not (Test-Path -LiteralPath $templatePath)) {
        Write-Warning "Template config not found: $templatePath"
        exit 0
    }

    Copy-Item -LiteralPath $templatePath -Destination $projectConfigPath -Force

    # Detect actual app and test directories
    $detectedAppDir = $null
    $detectedTestDir = $null
    $detectedTestAppName = $null

    # Search for app.json files to find app and test directories
    $appJsonFiles = Get-ChildItem -Path $repoRoot -Filter 'app.json' -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.' } # Exclude hidden folders

    foreach ($appJsonFile in $appJsonFiles) {
        try {
            $appJson = Get-Content -LiteralPath $appJsonFile.FullName -Raw | ConvertFrom-Json
            $relativeDir = [System.IO.Path]::GetRelativePath($repoRoot, $appJsonFile.Directory.FullName)

            # Detect if this is a test app (has "test" in name or dependencies reference test libraries)
            $isTestApp = $appJson.name -match 'test' -or
                         $relativeDir -match 'test' -or
                         ($appJson.dependencies | Where-Object { $_.name -match 'test' })

            if ($isTestApp) {
                $detectedTestDir = $relativeDir
                $detectedTestAppName = $appJson.name
            } else {
                $detectedAppDir = $relativeDir
            }
        } catch {
            # Skip malformed app.json files
        }
    }

    # Update the config file with detected values (deterministic)
    $configUpdated = $false
    if ($detectedAppDir -or $detectedTestDir -or $detectedTestAppName) {
        try {
            $config = Get-Content -LiteralPath $projectConfigPath -Raw | ConvertFrom-Json

            if ($detectedAppDir) {
                $config.appDir = $detectedAppDir
                $configUpdated = $true
            }
            if ($detectedTestDir) {
                $config.testDir = $detectedTestDir
                $configUpdated = $true
            }
            if ($detectedTestAppName) {
                $config.testAppName = $detectedTestAppName
                $configUpdated = $true
            }

            # Write updated config back
            $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $projectConfigPath -Force
        } catch {
            Write-Warning "Failed to auto-update config: $_"
            $configUpdated = $false
        }
    }

    # Build context for Claude about what was done
    $contextMessage = "[al-build] Project configuration initialized:`n"
    $contextMessage += "  Location: $projectConfigPath`n`n"

    if ($configUpdated) {
        $contextMessage += "  Auto-configured with detected settings:`n"
        if ($detectedAppDir) {
            $contextMessage += "    - appDir: ""$detectedAppDir""`n"
        }
        if ($detectedTestDir) {
            $contextMessage += "    - testDir: ""$detectedTestDir""`n"
        }
        if ($detectedTestAppName) {
            $contextMessage += "    - testAppName: ""$detectedTestAppName""`n"
        }
        $contextMessage += "`n  Next step: Run provision script to install compiler and download symbols.`n"
        $contextMessage += "  Ask the user if they would like you to run: pwsh <plugin-path>/scripts/provision.ps1"
    } else {
        $contextMessage += "  Configuration created with default template.`n"
        $contextMessage += "  Please review and customize settings in al-build.json, then run provision."
    }

    # Output as hook-specific context
    $hookOutput = @{
        hookEventName = 'SessionStart'
        additionalContext = $contextMessage
    } | ConvertTo-Json -Compress

    Write-Output $hookOutput

} catch {
    # Silent failure - don't disrupt session start
    Write-Warning "Failed to copy al-build.json template: $_"
}

exit 0
