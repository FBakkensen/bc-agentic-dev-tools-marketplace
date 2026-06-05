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
    5. Write per-run results to .output/TestResults/<dirName>/
       (al-runner.xml for AL Runner, last.xml + telemetry.jsonl for container)
    6. Write summary to .output/TestResults/summary.json
       (gate, per-runner totals, one record per run with test counts)

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

function ConvertTo-RunRecord {
    param($Result)
    [ordered]@{
        runner        = $Result.Runner
        appName       = $Result.AppName
        dir           = (Split-Path $Result.TestDir -Leaf)
        passed        = $Result.Passed
        counts        = $Result.Counts
        resultFile    = $Result.ResultFile
        telemetryFile = $Result.TelemetryFile
    }
}

function Get-RunnerTotals {
    # Totals are aggregated per runner, never across runners: the unit test app
    # runs through both al-runner and the container, so a grand total would
    # count the same tests twice.
    param($Results)
    $totals = [ordered]@{}
    foreach ($runner in @($Results | ForEach-Object { $_.Runner } | Select-Object -Unique)) {
        $runnerResults = @($Results | Where-Object { $_.Runner -eq $runner })
        $counted = @($runnerResults | Where-Object { $_.Counts })
        if ($counted.Count -eq 0) {
            # Counts unknown for every run of this runner — null, never zeros
            $totals[$runner] = $null
            continue
        }
        $totals[$runner] = [ordered]@{
            runs          = $runnerResults.Count
            testCodeunits = [int](($counted | ForEach-Object { $_.Counts.testCodeunits } | Measure-Object -Sum).Sum)
            tests         = [int](($counted | ForEach-Object { $_.Counts.tests } | Measure-Object -Sum).Sum)
            testsPassed   = [int](($counted | ForEach-Object { $_.Counts.testsPassed } | Measure-Object -Sum).Sum)
            testsFailed   = [int](($counted | ForEach-Object { $_.Counts.testsFailed } | Measure-Object -Sum).Sum)
            testsSkipped  = [int](($counted | ForEach-Object { $_.Counts.testsSkipped } | Measure-Object -Sum).Sum)
        }
    }
    return $totals
}

function Write-TestSummary {
    param(
        [string]$Gate,
        $Results,
        [string]$Path
    )
    [ordered]@{
        gate   = $Gate
        totals = Get-RunnerTotals $Results
        runs   = @($Results | ForEach-Object { ConvertTo-RunRecord $_ })
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path -Force
}

function Show-RunnerTotals {
    param($Results)
    $totals = Get-RunnerTotals $Results
    foreach ($runner in $totals.Keys) {
        $t = $totals[$runner]
        if ($null -eq $t) {
            Write-BuildMessage -Type Warning -Message "${runner}: test counts unavailable (no parseable result XML)"
            continue
        }
        $runWord = if ($t.runs -eq 1) { 'run' } else { 'runs' }
        Write-BuildMessage -Type Info -Message "${runner}: $($t.runs) $runWord - $($t.tests) tests in $($t.testCodeunits) test codeunits - $($t.testsPassed) passed, $($t.testsFailed) failed, $($t.testsSkipped) skipped"
    }
}

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

# Validate -UnitTestOnly requires unitTestApp
if ($UnitTestOnly -and -not $config.UnitTestApp) {
    Write-BuildMessage -Type Error -Message "unitTestApp not configured in al-build.json. Cannot run -UnitTestOnly."
    exit 1
}

# Validate unitTestApp path exists when configured
if ($config.UnitTestApp -and -not (Test-Path $config.UnitTestApp)) {
    Write-BuildMessage -Type Error -Message "unitTestApp directory not found: $($config.UnitTestApp)"
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
# In -UnitTestOnly mode, skip standard compilation — AL Runner compiles from source internally
if (-not $UnitTestOnly) {
    foreach ($testAppDir in $config.TestApps) {
        $dirName = Split-Path $testAppDir -Leaf
        Start-Step "provision-symbols-$dirName"
        Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $testAppDir
        Stop-Step "provision-symbols-$dirName"

        Start-Step "build-test-$dirName"
        Invoke-ALBuild -AppDir $testAppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
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

    # The al-runner run is a first-class record in summary.json in every mode
    $testResults += $unitResult
    Write-Host (ConvertTo-RunRecord $unitResult | ConvertTo-Json -Compress -Depth 4)

    $gateName = if ($UnitTestOnly) { 'unit' } else { 'full' }

    if (-not $unitResult.Passed) {
        # Unit tests failed — write summary and fail fast
        $summaryPath = Join-Path $baseResultsPath 'summary.json'
        Write-TestSummary -Gate $gateName -Results $testResults -Path $summaryPath

        Write-BuildHeader 'Test FAILED (AL Runner)'
        Show-RunnerTotals $testResults
        Write-BuildMessage -Type Error -Message "Unit tests failed: $($unitResult.AppName)"
        Write-BuildMessage -Type Error -Message "Results: $($unitResult.ResultFile)"
        exit 1
    }

    if ($UnitTestOnly) {
        # Unit tests passed — write summary and exit
        $summaryPath = Join-Path $baseResultsPath 'summary.json'
        Write-TestSummary -Gate 'unit' -Results $testResults -Path $summaryPath

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
        Show-RunnerTotals $testResults
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

    # Emit JSONL run record
    Write-Host (ConvertTo-RunRecord $result | ConvertTo-Json -Compress -Depth 4)
}

# Write summary.json
$summaryPath = Join-Path $baseResultsPath 'summary.json'
Write-TestSummary -Gate 'full' -Results $testResults -Path $summaryPath
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
$failedRuns = $testResults | Where-Object { -not $_.Passed }

if ($failedRuns) {
    Write-BuildHeader 'Test FAILED'
    Show-RunnerTotals $testResults
    Write-BuildMessage -Type Error -Message "Failed test runs:"
    foreach ($failed in $failedRuns) {
        Write-BuildMessage -Type Error -Message "  - $($failed.Runner) - $($failed.AppName): $($failed.ResultFile)"
    }
    exit 1
}

Write-BuildHeader 'Test Complete'
Show-RunnerTotals $testResults
Write-BuildMessage -Type Success -Message "All tests passed with zero warnings and zero errors"
