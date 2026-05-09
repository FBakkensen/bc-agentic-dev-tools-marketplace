#requires -Version 7.2

<#
.SYNOPSIS
    Build, publish, and run AL tests for all configured test apps.

.DESCRIPTION
    The canonical build-test gate. Performs the full workflow:
    1. Build main app
    2. For each test app: provision symbols, build, publish, run tests
    3. Write per-app results to .output/TestResults/<dirName>/
    4. Write summary to .output/TestResults/summary.json

    If no test apps are configured, compiles main app only and exits with a warning.

.PARAMETER Force
    Force republish even if apps are unchanged.

.EXAMPLE
    pwsh -File test.ps1
    # Run all tests

.EXAMPLE
    pwsh -File test.ps1 -Force
    # Force republish and run all tests
#>

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Track timing
$script:BuildStartTime = [Diagnostics.Stopwatch]::StartNew()
$script:StepTimings = @{}

function Start-Step {
    param([string]$Name)
    $script:StepTimings[$Name] = [Diagnostics.Stopwatch]::StartNew()
}

function Stop-Step {
    param([string]$Name)
    if ($script:StepTimings.ContainsKey($Name)) {
        $script:StepTimings[$Name].Stop()
    }
}

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

Write-BuildHeader 'Test: Build & Test Gate'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"
Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"

# Step 1: Build main app
Start-Step 'build'
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
Stop-Step 'build'

# If no test apps configured, compile only and exit
if ($config.TestApps.Count -eq 0) {
    Write-BuildMessage -Type Warning -Message "No test apps configured. Skipping publish and tests."
    Write-BuildHeader 'Build Complete (no tests)'
    exit 0
}

# Step 2: Provision main app as local symbol and build each test app
foreach ($testAppDir in $config.TestApps) {
    $dirName = Split-Path $testAppDir -Leaf
    Start-Step "provision-symbols-$dirName"
    Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $testAppDir
    Stop-Step "provision-symbols-$dirName"

    Start-Step "build-test-$dirName"
    Invoke-ALBuild -AppDir $testAppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
    Stop-Step "build-test-$dirName"
}

# Step 3: Ensure agent container is running
Start-Step 'ensure-container'
Ensure-BCAgentContainer -ContainerName $config.ContainerName
Stop-Step 'ensure-container'

# Step 4: Check if main app needs publish
$appJson = Get-AppJsonObject $config.AppDir
$mainAppNeedsPublish = Test-AppNeedsPublish -AppDir $config.AppDir -AppJson $appJson -ContainerName $config.ContainerName -Force:$Force

# Step 5: Unpublish all test apps if main app changed
if ($mainAppNeedsPublish) {
    Start-Step 'unpublish-test-apps'
    foreach ($testAppDir in @($config.TestApps | Sort-Object -Descending)) {
        $testAppJson = Get-AppJsonObject $testAppDir
        if ($testAppJson) {
            Invoke-ALUnpublish -AppName $testAppJson.name
        }
    }
    Stop-Step 'unpublish-test-apps'
}

# Step 6: Publish main app
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force:$Force
Stop-Step 'publish'

# Step 7: Publish and test each test app, collecting results
$repoRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    $repoRoot = (Get-Location).Path
}
if ($IsWindows -or $env:OS -match 'Windows') {
    $repoRoot = $repoRoot -replace '/', '\'
}
$baseResultsPath = Join-Path $repoRoot '.output' 'TestResults'

$testResults = @()

foreach ($testAppDir in $config.TestApps) {
    $dirName = Split-Path $testAppDir -Leaf

    # Publish test app
    Start-Step "publish-test-$dirName"
    $testForcePublish = $Force -or $mainAppNeedsPublish
    Invoke-ALPublish -AppDir $testAppDir -Force:$testForcePublish
    Stop-Step "publish-test-$dirName"

    # Run tests
    Start-Step "test-$dirName"
    $outputDir = Join-Path $baseResultsPath $dirName
    $result = Invoke-ALTest -TestDir $testAppDir -OutputDir $outputDir
    $testResults += $result
    Stop-Step "test-$dirName"

    # Emit JSONL summary line
    $jsonLine = @{
        appName       = $result.AppName
        dir           = $dirName
        passed        = $result.Passed
        resultFile    = $result.ResultFile
        telemetryFile = $result.TelemetryFile
    } | ConvertTo-Json -Compress
    Write-Host $jsonLine
}

# Write summary.json
$summaryPath = Join-Path $baseResultsPath 'summary.json'
$testResults | ForEach-Object {
    @{
        appName       = $_.AppName
        dir           = (Split-Path $_.TestDir -Leaf)
        passed        = $_.Passed
        resultFile    = $_.ResultFile
        telemetryFile = $_.TelemetryFile
    }
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Force
Write-BuildMessage -Type Info -Message "Summary written: $summaryPath"

# Show timing summary
$script:BuildStartTime.Stop()
$totalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

$steps = @{}
foreach ($name in $script:StepTimings.Keys) {
    $steps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
}

Save-BuildTimingEntry -Task 'test' -Steps $steps -TotalSeconds $totalSeconds
Show-BuildTimingHistory -Count 5

# Final pass/fail determination
$failedApps = $testResults | Where-Object { -not $_.Passed }

if ($failedApps) {
    Write-BuildHeader 'Test FAILED'
    Write-BuildMessage -Type Error -Message "Failed test apps:"
    foreach ($failed in $failedApps) {
        Write-BuildMessage -Type Error -Message "  - $($failed.AppName): $($failed.ResultFile)"
    }
    exit 1
}

Write-BuildHeader 'Test Complete'
Write-BuildMessage -Type Success -Message "All tests passed with zero warnings and zero errors"
