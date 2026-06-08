#requires -Version 7.2

<#
.SYNOPSIS
    Validate the AL app against the provisioned baseline for breaking changes.

.DESCRIPTION
    The heavyweight AppSource-style check (per-country, install/upgrade) that the
    compile-time AppSourceCop pass cannot do. Reads the previous release + its
    dependencies from the baseline package cache that provision.ps1 populated
    (download-baseline.ps1) and runs Run-AlValidation against them.

    Does NOT download — the cache is the single source of truth. Empty cache ->
    fails loud with "run provision.ps1", never a silent pass.

    Uses AppSourceCop.json for affixes and supported countries.

.EXAMPLE
    pwsh -File validate-breaking-changes.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

$Exit = Get-ExitCode

Write-BuildHeader 'Breaking Change Validation'

if (-not $config.BreakingChangeEnabled) {
    Write-BuildMessage -Type Detail -Message "breakingChange.enabled is false - skipping validation."
    exit 0
}

# Build the current app
Write-BuildMessage -Type Step -Message "Building current app..."
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)

$absoluteAppDir = (Resolve-Path -Path $config.AppDir).Path
Write-BuildMessage -Type Detail -Message "App Directory: $absoluteAppDir"

# ConvertTo-Boolean handles bool/'1'/'true'/'True' uniformly — the env round-trip
# stringifies the JSON boolean, so a plain -eq "1" test silently reads false.
$validateCurrent = ConvertTo-Boolean $config.ValidateCurrent
Write-BuildMessage -Type Detail -Message "Validate Current: $validateCurrent"

Write-BuildHeader 'AppSourceCop Configuration'

$appSourceCopPath = Join-Path $absoluteAppDir "AppSourceCop.json"
if (-not (Test-Path $appSourceCopPath)) {
    Write-BuildMessage -Type Error -Message "AppSourceCop.json not found"
    exit $Exit.Contract
}

$appSourceCop = Get-Content $appSourceCopPath | ConvertFrom-Json

$affixes = $appSourceCop.mandatoryAffixes
if (-not $affixes -or $affixes.Count -eq 0) {
    Write-BuildMessage -Type Error -Message "No mandatoryAffixes found"
    exit $Exit.Contract
}
Write-BuildMessage -Type Detail -Message "Affixes: $($affixes -join ', ')"

$supportedCountries = $appSourceCop.supportedCountries
if (-not $supportedCountries -or $supportedCountries.Count -eq 0) {
    Write-BuildMessage -Type Error -Message "No supportedCountries found"
    exit $Exit.Contract
}
Write-BuildMessage -Type Detail -Message "Countries: $($supportedCountries -join ', ')"

Write-BuildHeader 'Current App'

$currentAppPath = Get-OutputPath $absoluteAppDir
if (-not $currentAppPath -or -not (Test-Path $currentAppPath)) {
    Write-BuildMessage -Type Error -Message "Current app not found"
    exit $Exit.Contract
}

$currentApp = Get-Item $currentAppPath
Write-BuildMessage -Type Success -Message "Found: $($currentApp.Name)"

Write-BuildHeader 'Baseline Cache'

# Resolve repo root + absolute cache directory (same convention as download-baseline.ps1)
$repoRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    $repoRoot = (Get-Location).Path
}
if ($IsWindows -or $env:OS -match 'Windows') {
    $repoRoot = $repoRoot -replace '/', '\'
}
$cacheDir = if ([System.IO.Path]::IsPathRooted($config.BaselinePackageCachePath)) {
    $config.BaselinePackageCachePath
} else {
    Join-Path $repoRoot $config.BaselinePackageCachePath
}

# provision.ps1 owns the fetch. No cache -> stop loud; never a silent green.
$cachedApps = @()
if (Test-Path $cacheDir) {
    $cachedApps = @(Get-ChildItem -Path $cacheDir -Filter '*.app' -File -ErrorAction SilentlyContinue)
}
if ($cachedApps.Count -eq 0) {
    Write-BuildMessage -Type Error -Message "Baseline cache empty at $cacheDir - run provision.ps1 (breakingChange.enabled) to populate it."
    exit $Exit.Contract
}

# Split the flat cache: the previous main app vs its dependencies, by app name.
$appJson = Get-AppJsonObject $config.AppDir
$previousApps = @($cachedApps | Where-Object { $_.Name -like "*$($appJson.name)*" } | ForEach-Object { $_.FullName })
$dependencyApps = @($cachedApps | Where-Object { $_.Name -notlike "*$($appJson.name)*" } | ForEach-Object { $_.FullName })

if ($previousApps.Count -eq 0) {
    Write-BuildMessage -Type Error -Message "No baseline for '$($appJson.name)' in cache - re-run provision.ps1."
    exit $Exit.Contract
}
Write-BuildMessage -Type Success -Message "Baseline: $([System.IO.Path]::GetFileName($previousApps[0]))"
if ($dependencyApps.Count -gt 0) {
    Write-BuildMessage -Type Detail -Message "Dependencies: $($dependencyApps.Count)"
}

Write-BuildHeader 'Running Validation'

Import-BCContainerHelper

$validationParams = @{
    countries          = $supportedCountries
    apps               = @($currentAppPath)
    previousApps       = $previousApps
    installApps        = $dependencyApps
    affixes            = $affixes
    supportedCountries = $supportedCountries
    validateCurrent    = $validateCurrent
    failOnError        = $true
    includeWarnings    = $true
}

Write-BuildMessage -Type Step -Message "Running AL validation..."

try {
    Run-AlValidation @validationParams

    Write-BuildHeader 'Validation Complete'
    Write-BuildMessage -Type Success -Message "No breaking changes detected"
} catch {
    Write-BuildHeader 'Validation Failed'
    Write-BuildMessage -Type Error -Message "Breaking changes detected"
    if ($_.Exception.Message) {
        Write-BuildMessage -Type Detail -Message $_.Exception.Message
    }
    exit $Exit.Analysis
}
