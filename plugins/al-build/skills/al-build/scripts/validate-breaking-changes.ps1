#requires -Version 7.2

<#
.SYNOPSIS
    Validate AL app against previous release for breaking changes.

.DESCRIPTION
    Downloads the latest release from GitHub and runs Run-AlValidation
    to check for breaking changes. Uses AppSourceCop.json for affixes
    and supported countries configuration.

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

# First build the app
Write-BuildMessage -Type Step -Message "Building current app..."
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:($config.WarnAsError -eq '1')

# Resolve app directory
$absoluteAppDir = (Resolve-Path -Path $config.AppDir).Path
Write-BuildMessage -Type Detail -Message "App Directory: $absoluteAppDir"

$validateCurrent = $config.ValidateCurrent -eq "1"
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

Write-BuildHeader 'Previous Release'

# Check gh CLI
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-BuildMessage -Type Error -Message "GitHub CLI (gh) not found"
    exit $Exit.MissingTool
}

if (-not (Test-GhAuthentication)) {
    Write-BuildMessage -Type Error -Message "GitHub CLI not authenticated. Run 'gh auth login'"
    exit $Exit.Contract
}

# Get latest release
Write-BuildMessage -Type Step -Message "Fetching latest release..."
$releaseInfo = gh release view --json tagName,assets 2>$null | ConvertFrom-Json

if (-not $releaseInfo) {
    Write-BuildMessage -Type Warning -Message "No releases found - skipping validation"
    exit 0
}

Write-BuildMessage -Type Detail -Message "Latest release: $($releaseInfo.tagName)"

# Download previous app
$tempDir = New-TemporaryDirectory
try {
    Write-BuildMessage -Type Step -Message "Downloading previous release..."

    $appAsset = $releaseInfo.assets | Where-Object { $_.name -like '*.app' -and $_.name -notlike '*Test*' } | Select-Object -First 1
    if (-not $appAsset) {
        Write-BuildMessage -Type Warning -Message "No .app file in release - skipping validation"
        exit 0
    }

    $previousAppPath = Join-Path $tempDir $appAsset.name
    gh release download $releaseInfo.tagName --pattern $appAsset.name --dir $tempDir

    if (-not (Test-Path $previousAppPath)) {
        Write-BuildMessage -Type Error -Message "Failed to download previous app"
        exit $Exit.Integration
    }

    Write-BuildMessage -Type Success -Message "Downloaded: $($appAsset.name)"

    Write-BuildHeader 'Running Validation'

    Import-BCContainerHelper

    # Get BC artifact for validation
    $artifactUrl = Get-BcArtifactUrl -type 'OnPrem' -country $config.ArtifactCountry -select $config.ArtifactSelect

    $validationParams = @{
        apps                  = @($currentAppPath)
        previousApps          = @($previousAppPath)
        affixes               = $affixes
        supportedCountries    = $supportedCountries
        validateCurrent       = $validateCurrent
        failOnError           = $true
        includeWarnings       = $true
    }

    Write-BuildMessage -Type Step -Message "Running AL validation..."

    try {
        Run-AlValidation @validationParams

        Write-BuildHeader 'Validation Complete'
        Write-BuildMessage -Type Success -Message "No breaking changes detected"
    } catch {
        Write-BuildHeader 'Validation Failed'
        Write-BuildMessage -Type Error -Message "Breaking changes detected"
        Write-BuildMessage -Type Detail -Message $_.Exception.Message
        exit $Exit.Analysis
    }

} finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
