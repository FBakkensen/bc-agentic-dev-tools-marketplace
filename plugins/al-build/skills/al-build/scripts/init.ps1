#requires -Version 7.2

<#
.SYNOPSIS
    Initialize al-build configuration for the current project

.DESCRIPTION
    Creates al-build.json in the repo root with auto-detected settings.
    Searches for app.json files to identify app and test directories.

.EXAMPLE
    pwsh init.ps1
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

# Get repo root
$repoRoot = Get-GitRepoRoot
if (-not $repoRoot) {
    Write-Error "Not in a git repository"
    exit 1
}

# Check if config already exists
$projectConfigPath = Join-Path $repoRoot 'al-build.json'
if (Test-Path -LiteralPath $projectConfigPath) {
    Write-Host "Config already exists: $projectConfigPath" -ForegroundColor Yellow
    exit 0
}

# Copy template
$pluginRoot = $env:CLAUDE_PLUGIN_ROOT
$templatePath = Join-Path $pluginRoot 'skills' 'al-build' 'config' 'al-build.json'

if (-not (Test-Path -LiteralPath $templatePath)) {
    Write-Error "Template config not found: $templatePath"
    exit 1
}

Copy-Item -LiteralPath $templatePath -Destination $projectConfigPath -Force

# Auto-detect app and test directories
$detectedAppDir = $null
$detectedTestDir = $null
$detectedTestAppName = $null

$appJsonFiles = Get-ChildItem -Path $repoRoot -Filter 'app.json' -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]\.' }

foreach ($appJsonFile in $appJsonFiles) {
    try {
        $appJson = Get-Content -LiteralPath $appJsonFile.FullName -Raw | ConvertFrom-Json
        $relativeDir = [System.IO.Path]::GetRelativePath($repoRoot, $appJsonFile.Directory.FullName)

        $isTestApp = $appJson.name -match 'test' -or
                     $relativeDir -match 'test' -or
                     ($appJson.dependencies | Where-Object { $_.name -match 'test' })

        # First match wins - don't overwrite if already found
        if ($isTestApp -and -not $detectedTestDir) {
            $detectedTestDir = $relativeDir
            $detectedTestAppName = $appJson.name
        } elseif (-not $isTestApp -and -not $detectedAppDir) {
            $detectedAppDir = $relativeDir
        }
    } catch {
        # Skip malformed app.json files
    }
}

# Update config with detected values
$configUpdated = $false
try {
    if ($detectedAppDir -or $detectedTestDir -or $detectedTestAppName) {
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

        $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $projectConfigPath -Force
    }
} catch {
    Write-Warning "Failed to auto-update config: $_"
    $configUpdated = $false
}

# Output results
Write-Host "Created: $projectConfigPath" -ForegroundColor Green

if ($configUpdated) {
    Write-Host "Auto-configured:" -ForegroundColor Cyan
    if ($detectedAppDir) { Write-Host "  appDir: $detectedAppDir" }
    if ($detectedTestDir) { Write-Host "  testDir: $detectedTestDir" }
    if ($detectedTestAppName) { Write-Host "  testAppName: $detectedTestAppName" }
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Review al-build.json and customize if needed"
Write-Host "  2. Run /al-build:provision to install compiler and symbols"
Write-Host "  3. Run /al-build:test to verify the build"
