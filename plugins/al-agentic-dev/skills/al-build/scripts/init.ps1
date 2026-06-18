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

# Copy template - resolve path relative to script location
$templatePath = Join-Path $PSScriptRoot '..' 'config' 'al-build.json' | Resolve-Path -ErrorAction Stop

if (-not (Test-Path -LiteralPath $templatePath)) {
    Write-Error "Template config not found: $templatePath"
    exit 1
}

Copy-Item -LiteralPath $templatePath -Destination $projectConfigPath -Force

# Auto-detect app and test directories
$detectedAppDir = $null
$detectedTestDirs = @()

$appJsonFiles = Get-ChildItem -Path $repoRoot -Filter 'app.json' -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/]\.' }

foreach ($appJsonFile in $appJsonFiles) {
    try {
        $appJson = Get-Content -LiteralPath $appJsonFile.FullName -Raw | ConvertFrom-Json
        $relativeDir = [System.IO.Path]::GetRelativePath($repoRoot, $appJsonFile.Directory.FullName)

        $isTestApp = $appJson.name -match 'test' -or
                     $relativeDir -match 'test' -or
                     ($appJson.dependencies | Where-Object { $_.name -match 'test' })

        if ($isTestApp) {
            $detectedTestDirs += $relativeDir
        } elseif (-not $detectedAppDir) {
            $detectedAppDir = $relativeDir
        }
    } catch {
        # Skip malformed app.json files
    }
}

# Update config with detected values
$configUpdated = $false
try {
    if ($detectedAppDir -or $detectedTestDirs.Count -gt 0) {
        $config = Get-Content -LiteralPath $projectConfigPath -Raw | ConvertFrom-Json

        if ($detectedAppDir) {
            $config.appDir = $detectedAppDir
            $configUpdated = $true
        }
        if ($detectedTestDirs.Count -gt 0) {
            $config.testApps = @($detectedTestDirs)
            $configUpdated = $true
        }

        $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $projectConfigPath -Force
    }
} catch {
    Write-Warning "Failed to auto-update config: $_"
    $configUpdated = $false
}

# Ensure .output/ is in .gitignore (test results are stored there)
$gitignorePath = Join-Path $repoRoot '.gitignore'
$outputEntry = '.output/'
$gitignoreUpdated = $false

if (Test-Path -LiteralPath $gitignorePath) {
    $gitignoreContent = Get-Content -LiteralPath $gitignorePath -Raw
    if ($gitignoreContent -notmatch '(?m)^\.output/?\s*$') {
        Add-Content -LiteralPath $gitignorePath -Value "`n# AL Build output`n$outputEntry"
        $gitignoreUpdated = $true
    }
} else {
    Set-Content -LiteralPath $gitignorePath -Value "# AL Build output`n$outputEntry"
    $gitignoreUpdated = $true
}

# Ensure the branch-feed projection is ignored: feed.jsonl is the committed
# source of truth, feed.html is a regenerated view (see /al-feed).
if ((Get-Content -LiteralPath $gitignorePath -Raw) -notmatch '(?m)^specs/\*/feed\.html\s*$') {
    Add-Content -LiteralPath $gitignorePath -Value "`n# Branch-feed projection (regenerated from feed.jsonl)`nspecs/*/feed.html"
    $gitignoreUpdated = $true
}

# Output results
Write-Host "Created: $projectConfigPath" -ForegroundColor Green

if ($configUpdated) {
    Write-Host "Auto-configured:" -ForegroundColor Cyan
    if ($detectedAppDir) { Write-Host "  appDir: $detectedAppDir" }
    if ($detectedTestDirs.Count -gt 0) { Write-Host "  testApps: $($detectedTestDirs -join ', ')" }
}

if ($gitignoreUpdated) {
    Write-Host "Added .output/ to .gitignore" -ForegroundColor Cyan
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Review al-build.json and customize if needed"
Write-Host "  2. Run pwsh <skill-folder>/scripts/provision.ps1 to install compiler and symbols"
Write-Host "  3. Run pwsh <skill-folder>/scripts/test.ps1 to verify the build"
