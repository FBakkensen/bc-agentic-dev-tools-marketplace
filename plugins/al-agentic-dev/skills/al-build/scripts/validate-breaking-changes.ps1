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
    Write-BuildMessage -Type Info -Message "breakingChange.enabled is false - skipping validation."
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

# No throwOnError: Run-AlValidation RETURNS its result lines (findings and
# environment errors alike — its internal catch swallows container failures
# into the same list). The verdict comes from classifying those lines via
# Get-AlValidationVerdict; a throw-based gate cannot tell a breaking change
# from a docker hiccup, and an unthrown result is a silent green.
# Warnings stay at the compile-time AppSourceCop pass; this gate is errors-only.
$validationParams = @{
    countries          = $supportedCountries
    apps               = @($currentAppPath)
    previousApps       = $previousApps
    installApps        = $dependencyApps
    affixes            = $affixes
    supportedCountries = $supportedCountries
    validateCurrent    = $validateCurrent
    failOnError        = $true
    includeWarnings    = $false
    # Locally built apps are unsigned by construction and AL-Go CI builds
    # unsigned baselines unless codesigning is configured — without this switch
    # every run yields "...is not signed, result is NotSigned", which classifies
    # as a finding and the gate can never pass. Signing is the publish
    # pipeline's concern, not this schema gate's.
    skipVerification   = $true
    # Mirror the module's default NewBcContainer scriptblock, forcing process
    # isolation: Run-AlValidation has no isolation parameter and auto-detection
    # picks hyperv on host/image kernel mismatch — failing hosts without
    # Hyper-V. al-build standardizes on process isolation everywhere.
    NewBcContainer     = {
        Param([Hashtable]$parameters)
        $parameters.isolation = 'process'
        New-BcContainer @parameters
        Invoke-ScriptInBcContainer $parameters.ContainerName -scriptblock { $progressPreference = 'SilentlyContinue' }
    }
}

Write-BuildMessage -Type Step -Message "Running AL validation..."

try {
    $validationResult = @(Run-AlValidation @validationParams)
} catch {
    # Backstop for genuine throws (artifact resolution, parameter validation)
    # that never reach the result list — environment-shaped, never a finding.
    Write-BuildHeader 'Validation Failed'
    Write-BuildMessage -Type Error -Message "Validation could not run"
    if ($_.Exception.Message) {
        Write-BuildMessage -Type Error -Message $_.Exception.Message
    }
    exit $Exit.GeneralError
}

$verdict = Get-AlValidationVerdict -ValidationResult $validationResult

switch ($verdict.Verdict) {
    'BreakingChange' {
        Write-BuildHeader 'Validation Failed'
        Write-BuildMessage -Type Error -Message "Breaking changes detected"
        # Verdict evidence, not diagnostics: Detail is verbose-gated and would
        # leave a detected break undiagnosable in default runs.
        $verdict.Findings | ForEach-Object { Write-BuildMessage -Type Error -Message $_ }
        exit $Exit.Analysis
    }
    'EnvironmentError' {
        Write-BuildHeader 'Validation Failed'
        Write-BuildMessage -Type Error -Message "Environment failure during validation - no verdict on breaking changes; fix and re-run"
        $verdict.EnvironmentErrors | ForEach-Object { Write-BuildMessage -Type Error -Message $_ }
        exit $Exit.GeneralError
    }
    default {
        Write-BuildHeader 'Validation Complete'
        Write-BuildMessage -Type Success -Message "No breaking changes detected"
    }
}
