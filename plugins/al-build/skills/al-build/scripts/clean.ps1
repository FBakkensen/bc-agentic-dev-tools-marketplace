#requires -Version 7.2

<#
.SYNOPSIS
    Remove build artifacts (.app files).

.DESCRIPTION
    Cleans compiled .app files from app/ and test/ directories.
    Also clears publish state to force republish on next run.

.EXAMPLE
    pwsh -File clean.ps1
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

Write-BuildHeader 'Clean: Build Artifact Removal'

$cleanedCount = 0

# Clean main app
if (Test-Path $config.AppDir) {
    $appOutputPath = Get-OutputPath $config.AppDir
    if ($appOutputPath -and (Test-Path $appOutputPath)) {
        $fileInfo = Get-Item $appOutputPath
        $sizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
        Remove-Item -Force $appOutputPath
        Write-BuildMessage -Type Success -Message "Removed: $(Split-Path -Leaf $appOutputPath) ($sizeKB KB)"
        $cleanedCount++

        # Clear publish state
        $appJson = Get-AppJsonObject $config.AppDir
        if ($appJson) {
            Clear-PublishState -AppJson $appJson -ContainerName $config.ContainerName
        }
    } else {
        Write-BuildMessage -Type Detail -Message "Main app: no artifact to clean"
    }
}

# Clean test app
if (Test-Path $config.TestDir) {
    $testOutputPath = Get-OutputPath $config.TestDir
    if ($testOutputPath -and (Test-Path $testOutputPath)) {
        $fileInfo = Get-Item $testOutputPath
        $sizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
        Remove-Item -Force $testOutputPath
        Write-BuildMessage -Type Success -Message "Removed: $(Split-Path -Leaf $testOutputPath) ($sizeKB KB)"
        $cleanedCount++

        # Clear publish state
        $testJson = Get-AppJsonObject $config.TestDir
        if ($testJson) {
            Clear-PublishState -AppJson $testJson -ContainerName $config.ContainerName
        }
    } else {
        Write-BuildMessage -Type Detail -Message "Test app: no artifact to clean"
    }
}

Write-BuildHeader 'Clean Complete'
if ($cleanedCount -gt 0) {
    Write-BuildMessage -Type Success -Message "$cleanedCount artifact(s) removed"
} else {
    Write-BuildMessage -Type Info -Message "Workspace is already clean"
}
