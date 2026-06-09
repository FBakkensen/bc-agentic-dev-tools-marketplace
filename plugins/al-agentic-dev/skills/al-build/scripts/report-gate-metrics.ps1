#requires -Version 7.2

<#
.SYNOPSIS
    Summarize gate timing metrics by workspace signature and gate scope.

.DESCRIPTION
    Reads the gate-metrics JSONL log (repo-local .output/logs/build-timing.jsonl
    by default, or the user-level mirror with -GlobalLog) and prints one row per
    signature × gate combination: run count, outcome counts, total minutes,
    median and p95 duration.

    The signature derives from recorded workspace evidence (git dirty-state at
    gate time), never from a caller-supplied tag:
      prod-only — mutation-shaped (app dirty, tests clean; /al-mutate's
                  clean-baseline-then-mutant contract produces exactly this)
      test-only — RED-first runs (test apps dirty, app clean)
      mixed     — TDD inner loop (both dirty)
      clean     — closeout / baseline runs
      unknown   — entries predating evidence capture

    Answers "where does the wall-clock go": mutation share vs TDD inner-loop
    share, unit vs full gate split, red rate per signature, suite growth.

.PARAMETER LogPath
    Explicit path to a JSONL log. Defaults to .output/logs/build-timing.jsonl
    under the current repo root.

.PARAMETER GlobalLog
    Read the user-level mirror (~/.al-build/gate-metrics.jsonl or
    ALBT_GATE_METRICS_GLOBAL_PATH) instead — aggregates across consumer repos
    and survives .output wipes.

.PARAMETER SinceDays
    Only include entries newer than N days. 0 (default) = no filter.

.PARAMETER Task
    Only include entries for these task names (e.g. 'test','unit-test').
    Default: gate tasks ('test','unit-test'). Pass an empty array for all tasks.

.EXAMPLE
    pwsh -File report-gate-metrics.ps1
    # Gate breakdown for the current repo

.EXAMPLE
    pwsh -File report-gate-metrics.ps1 -GlobalLog -SinceDays 21
    # Cross-repo breakdown for the last three weeks
#>

[CmdletBinding()]
param(
    [string]$LogPath,

    [switch]$GlobalLog,

    [int]$SinceDays = 0,

    [string[]]$Task = @('test', 'unit-test')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking

if (-not $LogPath) {
    if ($GlobalLog) {
        $LogPath = Get-GateMetricsGlobalPath
    } else {
        $repoRoot = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
            $repoRoot = (Get-Location).Path
        }
        $LogPath = Join-Path $repoRoot '.output' 'logs' 'build-timing.jsonl'
    }
}

Write-BuildHeader 'Gate Metrics'
Write-BuildMessage -Type Info -Message "Log: $LogPath"
if ($SinceDays -gt 0) {
    Write-BuildMessage -Type Info -Message "Window: last $SinceDays day(s)"
}

if (-not (Test-Path $LogPath)) {
    Write-BuildMessage -Type Warning -Message "No metrics log found. Run gates first; entries accumulate during regular usage."
    exit 0
}

$rows = @(Get-GateMetricsSummary -LogPath $LogPath -SinceDays $SinceDays -Task $Task)

if ($rows.Count -eq 0) {
    Write-BuildMessage -Type Warning -Message "No matching entries in the log."
    exit 0
}

$rows | Format-Table -Property Signature, Gate, Runs, Passed, Failed, Errors, Untagged, TotalMin, MedianSec, P95Sec -AutoSize | Out-Host

$grandTotalMin = [math]::Round((($rows | Measure-Object -Property TotalMin -Sum).Sum), 1)
$firstSeen = ($rows | ForEach-Object { $_.FirstSeen } | Sort-Object | Select-Object -First 1)
$lastSeen = ($rows | ForEach-Object { $_.LastSeen } | Sort-Object | Select-Object -Last 1)

Write-BuildMessage -Type Info -Message "Total gate time: $grandTotalMin min across $(($rows | Measure-Object -Property Runs -Sum).Sum) runs ($firstSeen -> $lastSeen)"

foreach ($row in $rows) {
    if ($row.Signature -eq 'unknown' -and $row.Runs -gt 0) {
        Write-BuildMessage -Type Detail -Message "signature=unknown rows are entries written before workspace-evidence capture."
        break
    }
}
