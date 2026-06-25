#requires -Version 7.2

<#
.SYNOPSIS
    Build, publish, and run AL tests for all configured test apps.

.DESCRIPTION
    The canonical build-test gate. Performs the full workflow:
    1. Build main app
    2. For each test app: provision symbols, build (analyzer gate, host alc)
    3. If unitTestApp configured: build it (analyzer gate), then run AL Runner
       unit tests (fast, no container)
    4. Publish and run container tests for each test app
    5. Write per-run results to .output/TestResults/<dirName>/
       (al-runner.xml for AL Runner, last.xml + telemetry.jsonl for container)
    6. Write summary to .output/TestResults/summary.json
       (gate, per-runner totals, one record per run with test counts)

    If -UnitTestOnly is specified and unitTestApp is configured, compile every app
    (the analyzer gate runs over the whole solution) and run AL Runner unit tests.
    Skips container publish and container tests entirely.

.PARAMETER Force
    Force republish even if apps are unchanged.

.PARAMETER UnitTestOnly
    Compile every app through the analyzer gate, then run AL Runner unit tests.
    Skips container publish and container tests. Requires unitTestApp configured.

.EXAMPLE
    pwsh -File test.ps1
    # Run all tests (unit + container)

.EXAMPLE
    pwsh -File test.ps1 -UnitTestOnly
    # Inner loop: compile all apps (analyzer gate) + AL Runner unit tests, no container

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

# Gate metrics: outcome defaults to 'error' and is only upgraded at the
# verdict points below — any throw (compile, publish, container) keeps it.
# Workspace evidence (dirty fingerprint + HEAD sha) is captured up front;
# phase attribution derives from it at report time, never from a caller tag.
$gateName = if ($UnitTestOnly) { 'unit' } else { 'full' }
$gateOutcome = 'error'

$headSha = $null
try {
    $headSha = & git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { $headSha = $null }
} catch {
    $headSha = $null
}

$dirtyDirs = @($config.TestApps)
if ($config.UnitTestApp) { $dirtyDirs += $config.UnitTestApp }
$dirtyCounts = Get-DirtyFileCounts -AppDir $config.AppDir -TestDirs $dirtyDirs

# Repo-wide compiler channel: the highest app.json runtime across all apps picks
# stable vs prerelease once, so every app compiles on the same compiler.
$requiredRuntimeMajor = Get-RequiredRuntimeMajor -Config $config

try {

# Step 1: Build main app
Start-Step 'build'
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError) -RequiredRuntimeMajor $requiredRuntimeMajor
Stop-Step 'build'

# If no test apps and not unit-test-only, compile only and exit
if ($config.TestApps.Count -eq 0 -and -not $UnitTestOnly) {
    if (-not $config.UnitTestApp) {
        Write-BuildMessage -Type Warning -Message "No test apps configured. Skipping publish and tests."
        Write-BuildHeader 'Build Complete (no tests)'
        $gateOutcome = 'passed'
        exit 0
    }
}

# Step 2: Provision main app as local symbol and build each secondary target.
# Get-CompileTargets resolves the post-main compile set (test apps, then the
# unit-test app) — identical in every mode. Compilation runs the analyzer gate
# (alc /analyzer:) on the host; -UnitTestOnly skips the container publish/run,
# not the compile. The unit-test app is here so its code goes through the
# analyzer gate (AL Runner's internal compile in Step 3 carries no /analyzer:).
foreach ($target in (Get-CompileTargets -Config $config -UnitTestOnly:$UnitTestOnly)) {
    $dirName = Split-Path $target.AppDir -Leaf
    Start-Step "provision-symbols-$dirName"
    Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $target.AppDir
    Stop-Step "provision-symbols-$dirName"

    Start-Step "build-$($target.Role)-$dirName"
    Invoke-ALBuild -AppDir $target.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError) -RequiredRuntimeMajor $requiredRuntimeMajor
    Stop-Step "build-$($target.Role)-$dirName"
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

    if (-not $unitResult.Passed) {
        # Unit tests failed — write summary and fail fast
        $summaryPath = Join-Path $baseResultsPath 'summary.json'
        Write-TestSummary -Gate $gateName -Results $testResults -Path $summaryPath

        Write-BuildHeader 'Test FAILED (AL Runner)'
        Show-RunnerTotals $testResults
        Write-BuildMessage -Type Error -Message "Unit tests failed: $($unitResult.AppName)"
        Write-BuildMessage -Type Error -Message "Results: $($unitResult.ResultFile)"
        $gateOutcome = 'failed'
        exit 1
    }

    if ($UnitTestOnly) {
        # Unit tests passed — write summary and exit
        $summaryPath = Join-Path $baseResultsPath 'summary.json'
        Write-TestSummary -Gate 'unit' -Results $testResults -Path $summaryPath

        Write-BuildHeader 'Unit Test Complete'
        Show-RunnerTotals $testResults
        Write-BuildMessage -Type Success -Message "All unit tests passed"
        $gateOutcome = 'passed'
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

# Step 8: Publish every test app, wait for the sync to settle, then run tests.
# A dev-endpoint ForceSync publish returns before the server-side schema sync
# commits; opening a test session against settling metadata — or publishing
# under an already-open session — invalidates the session's page metadata
# ("Sorry, we just updated this page") and truncates the run, which can surface
# as a partial pass. Publishing all apps before any test session opens, and
# waiting for SyncState to reach Synced, removes that race without a service-tier
# restart (the container stays warm).

# Step 8a: Publish all test apps
foreach ($testAppDir in $config.TestApps) {
    $dirName = Split-Path $testAppDir -Leaf
    Start-Step "publish-test-$dirName"
    $testForcePublish = $Force -or $mainAppNeedsPublish
    Invoke-ALPublish -AppDir $testAppDir -Force:$testForcePublish
    Stop-Step "publish-test-$dirName"
}

# Step 8b: Sync-completion barrier — wait until the main app and every test app
# report Synced before the first test session opens.
Start-Step 'wait-apps-synced'
$publishedAppNames = @()
$mainAppJsonForSync = Get-AppJsonObject $config.AppDir
if ($mainAppJsonForSync) { $publishedAppNames += $mainAppJsonForSync.name }
foreach ($testAppDir in $config.TestApps) {
    $testAppJsonForSync = Get-AppJsonObject $testAppDir
    if ($testAppJsonForSync) { $publishedAppNames += $testAppJsonForSync.name }
}
Wait-BCAppsSynced -ContainerName $config.ContainerName -AppNames $publishedAppNames -Tenant $config.Tenant
Stop-Step 'wait-apps-synced'

# Step 8c: Run tests for each test app, now against committed metadata
foreach ($testAppDir in $config.TestApps) {
    $dirName = Split-Path $testAppDir -Leaf
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

# Final pass/fail determination
$failedRuns = $testResults | Where-Object { -not $_.Passed }

if ($failedRuns) {
    Write-BuildHeader 'Test FAILED'
    Show-RunnerTotals $testResults
    Write-BuildMessage -Type Error -Message "Failed test runs:"
    foreach ($failed in $failedRuns) {
        Write-BuildMessage -Type Error -Message "  - $($failed.Runner) - $($failed.AppName): $($failed.ResultFile)"
    }
    $gateOutcome = 'failed'
    exit 1
}

Write-BuildHeader 'Test Complete'
Show-RunnerTotals $testResults
Write-BuildMessage -Type Success -Message "All tests passed with zero warnings and zero errors"
$gateOutcome = 'passed'

} finally {
    # One timing entry per gate, on every exit path: pass, fail, and throw.
    # PowerShell runs finally on `exit`, so the AL Runner fail-fast path and
    # compile/publish throws land here too.
    if ($script:BuildStartTime.IsRunning) { $script:BuildStartTime.Stop() }
    $finalTotalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

    $finalSteps = @{}
    foreach ($name in $script:StepTimings.Keys) {
        $finalSteps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
    }

    # Executed-test totals per runner (omitted when counts are unavailable)
    $testsByRunner = @{}
    $runnerTotals = Get-RunnerTotals $testResults
    foreach ($runnerName in @($runnerTotals.Keys)) {
        if ($runnerTotals[$runnerName]) {
            $testsByRunner[$runnerName] = $runnerTotals[$runnerName].tests
        }
    }

    $timingTask = if ($UnitTestOnly) { 'unit-test' } else { 'test' }
    $saveArgs = @{
        Task         = $timingTask
        Steps        = $finalSteps
        TotalSeconds = $finalTotalSeconds
        Gate         = $gateName
        Outcome      = $gateOutcome
        Tests        = $testsByRunner
    }
    if ($dirtyCounts) { $saveArgs.Dirty = $dirtyCounts }
    if ($headSha) { $saveArgs.HeadSha = $headSha }
    Save-BuildTimingEntry @saveArgs
    Show-BuildTimingHistory -Count 5
}
