#requires -Version 7.2

<#
.SYNOPSIS
    One-time setup: install AL compiler and download symbol packages.

.DESCRIPTION
    Runs provisioning for both main app and test app:
    - Installs/updates AL compiler from NuGet
    - Downloads symbol packages for app/
    - Downloads symbol packages for test/

.EXAMPLE
    pwsh -File provision.ps1
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

Write-BuildHeader 'Provision: One-Time Setup'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Directory: $($config.TestDir)"

# Collect workspace app IDs (apps that are built locally, not downloaded from NuGet)
$workspaceAppIds = @()
foreach ($dir in @($config.AppDir, $config.TestDir)) {
    if ($dir -and (Test-Path $dir)) {
        $appJsonPath = Join-Path $dir 'app.json'
        if (Test-Path $appJsonPath) {
            $appJson = Get-Content -Path $appJsonPath -Raw | ConvertFrom-Json
            if ($appJson.id) {
                $workspaceAppIds += $appJson.id
                Write-BuildMessage -Type Detail -Message "Workspace app: $($appJson.name) ($($appJson.id))"
            }
        }
    }
}

# Step 1: Install/update compiler
Install-ALCompiler

# Step 2: Download symbols for main app
if (Test-Path $config.AppDir) {
    & "$PSScriptRoot/download-symbols.ps1" -AppDir $config.AppDir -WorkspaceAppIds $workspaceAppIds
    if ($LASTEXITCODE -ne 0) {
        throw "Symbol download failed for $($config.AppDir)"
    }
} else {
    Write-BuildMessage -Type Warning -Message "App directory not found: $($config.AppDir)"
}

# Step 3: Download symbols for test app
if (Test-Path $config.TestDir) {
    & "$PSScriptRoot/download-symbols.ps1" -AppDir $config.TestDir -WorkspaceAppIds $workspaceAppIds
    if ($LASTEXITCODE -ne 0) {
        throw "Symbol download failed for $($config.TestDir)"
    }
} else {
    Write-BuildMessage -Type Detail -Message "Test directory not found: $($config.TestDir) (skipping)"
}

Write-BuildHeader 'Provision Complete'
Write-BuildMessage -Type Success -Message "Environment is ready for development"
Write-BuildMessage -Type Info -Message "Next: Run 'pwsh $PSScriptRoot/test.ps1' to build and test"
