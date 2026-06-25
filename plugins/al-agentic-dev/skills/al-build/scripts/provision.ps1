#requires -Version 7.2

<#
.SYNOPSIS
    Per-feature setup: install both AL compiler channels and download symbol packages.

.DESCRIPTION
    Runs provisioning for main app and all configured test apps:
    - Installs both AL compiler channels (stable + prerelease) side-by-side under the
      tool cache, refreshed to latest every run. The global 'al' dotnet tool is the
      user's own and is left untouched; the build picks a channel per app.json runtime.
    - Downloads symbol packages for app/
    - Downloads symbol packages for each test app

.PARAMETER UpdateCompiler
    Force a clean reinstall of both compiler channels. By default each channel is
    refreshed to latest in place every run.

.EXAMPLE
    pwsh -File provision.ps1

.EXAMPLE
    pwsh -File provision.ps1 -UpdateCompiler
#>

[CmdletBinding()]
param(
    [switch]$UpdateCompiler
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

Write-BuildHeader 'Provision: One-Time Setup'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"

# Step 1: Ensure compiler
Install-ALCompiler -Update:$UpdateCompiler

# Step 1b: Ensure AL Runner (if unitTestApp is configured)
if ($config.UnitTestApp) {
    Install-ALRunner -Update:$UpdateCompiler
}

# Step 2: Download symbols for main app
if (Test-Path $config.AppDir) {
    & "$PSScriptRoot/download-symbols.ps1" -AppDir $config.AppDir
    if ($LASTEXITCODE -ne 0) {
        throw "Symbol download failed for $($config.AppDir)"
    }
} else {
    Write-BuildMessage -Type Warning -Message "App directory not found: $($config.AppDir)"
}

# Step 3: Download symbols for each test app
foreach ($testAppDir in $config.TestApps) {
    if (Test-Path $testAppDir) {
        & "$PSScriptRoot/download-symbols.ps1" -AppDir $testAppDir
        if ($LASTEXITCODE -ne 0) {
            throw "Symbol download failed for $testAppDir"
        }
    } else {
        $dirName = Split-Path $testAppDir -Leaf
        Write-BuildMessage -Type Detail -Message "Test app directory not found: $dirName (skipping)"
    }
}

# Step 4: Download symbols for unitTestApp (if not already covered by testApps)
if ($config.UnitTestApp -and (Test-Path $config.UnitTestApp)) {
    $alreadyCovered = $config.TestApps | Where-Object {
        [IO.Path]::GetFullPath($_) -eq [IO.Path]::GetFullPath($config.UnitTestApp)
    }
    if (-not $alreadyCovered) {
        & "$PSScriptRoot/download-symbols.ps1" -AppDir $config.UnitTestApp
        if ($LASTEXITCODE -ne 0) {
            throw "Symbol download failed for unit test app: $($config.UnitTestApp)"
        }
    }
}

# Step 5: Refresh the breaking-change baseline (when enabled). Cache the previous
# release + deps and point AppSourceCop at them, so AS00xx surfaces at compile.
if ($config.BreakingChangeEnabled) {
    & "$PSScriptRoot/download-baseline.ps1"
    if ($LASTEXITCODE -ne 0) {
        throw "Breaking-change baseline refresh failed"
    }
}

Write-BuildHeader 'Provision Complete'
Write-BuildMessage -Type Success -Message "Environment is ready for development"
Write-BuildMessage -Type Info -Message "Next: Run 'pwsh $PSScriptRoot/test.ps1' to build and test"
