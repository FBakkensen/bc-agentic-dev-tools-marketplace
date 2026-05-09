#requires -Version 7.2

<#
.SYNOPSIS
    Build, publish, and run AL tests for all configured test apps.

.DESCRIPTION
    The canonical build-test gate. Performs the full workflow:
    1. Build main app
    2. For each test app: provision symbols, build
    3. If unitTestApp configured: run AL Runner unit tests (fast, no container)
    4. Publish and run container tests for each test app
    5. Write per-app results to .output/TestResults/<dirName>/
    6. Write summary to .output/TestResults/summary.json

    If -UnitTestOnly is specified and unitTestApp is configured, only compile and
    run AL Runner unit tests. Skips container publish and container tests entirely.

.PARAMETER Force
    Force republish even if apps are unchanged.

.PARAMETER UnitTestOnly
    Compile and run AL Runner unit tests only. Skips container tests.
    Requires unitTestApp to be configured in al-build.json.

.EXAMPLE
    pwsh -File test.ps1
    # Run all tests (unit + container)

.EXAMPLE
    pwsh -File test.ps1 -UnitTestOnly
    # Fast inner loop: compile + AL Runner unit tests only

.EXAMPLE
    pwsh -File test.ps1 -Force
    # Force republish and run all tests
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$UnitTestOnly
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

# Validate -UnitTestOnly requires unitTestApp
if ($UnitTestOnly -and -not $config.UnitTestApp) {
    Write-BuildMessage -Type Error -Message "unitTestApp not configured in al-build.json. Cannot run -UnitTestOnly."
    exit 1
}

$modeName = if ($UnitTestOnly) { 'Unit Test Only' } else { 'Build & Test Gate' }
Write-BuildHeader "Test: $modeName"

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"
if ($config.UnitTestApp) {
    Write-BuildMessage -Type Detail -Message "Unit Test App: $($config.UnitTestApp)"
}
if (-not $UnitTestOnly) {
    Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"
}

# Initialize results path early (needed for both AL Runner and container)
$repoRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    $repoRoot = (Get-Location).Path
}
if ($IsWindows -or $env:OS -match 'Windows') {
    $repoRoot = $repoRoot -replace '/', '\'
}
$baseResultsPath = Join-Path $repoRoot '.output' 'TestResults'
$testResults = @()

# Step 1: Build main app
Start-Step 'build'
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
Stop-Step 'build'

# If no test apps and not unit-test-only, compile only and exit
if ($config.TestApps.Count -eq 0 -and -not $UnitTestOnly) {
    if (-not $config.UnitTestApp) {
        Write-BuildMessage -Type Warning -Message "No test apps configured. Skipping publish and tests."
        Write-BuildHeader 'Build Complete (no tests)'
        exit 0
    }
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

# Step 2b: If unitTestApp is not in testApps, provision and build it separately
if ($config.UnitTestApp) {
    $unitTestAlreadyBuilt = $config.TestApps | Where-Object {
        [IO.Path]::GetFullPath($_) -eq [IO.Path]::GetFullPath($config.UnitTestApp)
    }
    if (-not $unitTestAlreadyBuilt -and (Test-Path $config.UnitTestApp)) {
        $dirName = Split-Path $config.UnitTestApp -Leaf
        Start-Step "provision-symbols-$dirName"
        Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $config.UnitTestApp
        Stop-Step "provision-symbols-$dirName"

        Start-Step "build-test-$dirName"
        Invoke-ALBuild -AppDir $config.UnitTestApp -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
        Stop-Step "build-test-$dirName"
    }
}

# Step 3: AL Runner unit tests (fast gate, before container)
if ($config.UnitTestApp) {
    $unitDirName = Split-Path $config.UnitTestApp -Leaf
    $unitOutputDir = Join-Path $baseResultsPath $unitDirName

    Start-Step 'al-runner'
    $unitResult = Invoke-ALRunnerTest -AppDir $config.AppDir -TestDir $config.UnitTestApp -OutputDir $unitOutputDir -InitEvents:($config.UnitTestInitEvents)
    Stop-Step 'al-runner'

    if (-not $unitResult.Passed) {
        # Unit tests failed — write summary and fail fast
        $testResults += $unitResult
        $summaryPath = Join-Path $baseResultsPath 'summary.json'
        @($testResults | ForEach-Object {
            @{
                appName       = $_.AppName
                dir           = (Split-Path $_.TestDir -Leaf)
                passed        = $_.Passed
                resultFile    = $_.ResultFile
                telemetryFile = $_.TelemetryFile
            }
        }) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Force

        Write-BuildHeader 'Test FAILED (AL Runner)'
        Write-BuildMessage -Type Error -Message "Unit tests failed: $($unitResult.AppName)"
        Write-BuildMessage -Type Error -Message "Results: $($unitResult.ResultFile)"
        exit 1
    }

    if ($UnitTestOnly) {
        # Unit tests passed — write summary and exit
        $testResults += $unitResult
        $summaryPath = Join-Path $baseResultsPath 'summary.json'
        @($testResults | ForEach-Object {
            @{
                appName       = $_.AppName
                dir           = (Split-Path $_.TestDir -Leaf)
                passed        = $_.Passed
                resultFile    = $_.ResultFile
                telemetryFile = $_.TelemetryFile
            }
        }) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Force

        # Show timing
        $script:BuildStartTime.Stop()
        $totalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds
        $steps = @{}
        foreach ($name in $script:StepTimings.Keys) {
            $steps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
        }
        Save-BuildTimingEntry -Task 'unit-test' -Steps $steps -TotalSeconds $totalSeconds
        Show-BuildTimingHistory -Count 5

        Write-BuildHeader 'Unit Test Complete'
        Write-BuildMessage -Type Success -Message "All unit tests passed"
        exit 0
    }

    Write-BuildMessage -Type Success -Message "AL Runner gate passed — proceeding to container tests"
}

# Step 4: Ensure agent container is running
Start-Step 'ensure-container'
Ensure-BCAgentContainer -ContainerName $config.ContainerName
Stop-Step 'ensure-container'

# Step 5: Check if main app needs publish
$appJson = Get-AppJsonObject $config.AppDir
$mainAppNeedsPublish = Test-AppNeedsPublish -AppDir $config.AppDir -AppJson $appJson -ContainerName $config.ContainerName -Force:$Force

# Step 6: Unpublish all test apps if main app changed
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

# Step 7: Publish main app
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force:$Force
Stop-Step 'publish'

# Step 8: Publish and test each test app, collecting results
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
@($testResults | ForEach-Object {
    @{
        appName       = $_.AppName
        dir           = (Split-Path $_.TestDir -Leaf)
        passed        = $_.Passed
        resultFile    = $_.ResultFile
        telemetryFile = $_.TelemetryFile
    }
}) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Force
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
