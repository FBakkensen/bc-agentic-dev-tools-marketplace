#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking

    # Isolate the global mirror: never touch the real ~/.al-build log from tests
    $script:OldGlobalPath = $env:ALBT_GATE_METRICS_GLOBAL_PATH
    $script:MirrorPath = Join-Path $TestDrive 'mirror' 'gate-metrics.jsonl'
    $env:ALBT_GATE_METRICS_GLOBAL_PATH = $script:MirrorPath

    # Deterministic repo identity: run from $TestDrive (not a git repo) so
    # branch capture yields nothing and repoPath falls back to cwd
    Push-Location $TestDrive

    function Read-LastJsonLine {
        param([string]$Path)
        $lines = @(Get-Content -Path $Path | Where-Object { $_ -and $_.Trim() })
        return $lines[-1] | ConvertFrom-Json
    }
}

AfterAll {
    Pop-Location
    if ($null -ne $script:OldGlobalPath) {
        $env:ALBT_GATE_METRICS_GLOBAL_PATH = $script:OldGlobalPath
    } else {
        Remove-Item Env:ALBT_GATE_METRICS_GLOBAL_PATH -ErrorAction SilentlyContinue
    }
}

Describe 'Get-DirtyFileCounts' {
    It 'buckets modified app files under app' {
        $c = Get-DirtyFileCounts -AppDir 'app' -TestDirs @('test') -StatusLines @(' M app/SmokeGateCalc.Codeunit.al')
        $c.app | Should -Be 1
        $c.tests | Should -Be 0
        $c.other | Should -Be 0
    }

    It 'buckets untracked test files under tests, across multiple test dirs' {
        $c = Get-DirtyFileCounts -AppDir 'app' -TestDirs @('test', 'test-integration') -StatusLines @(
            '?? test/NewTest.Codeunit.al',
            ' M test-integration/Existing.Codeunit.al'
        )
        $c.tests | Should -Be 2
        $c.app | Should -Be 0
    }

    It 'counts a rename by its target location' {
        $c = Get-DirtyFileCounts -AppDir 'app' -TestDirs @('test') -StatusLines @('R  docs/Old.al -> app/New.al')
        $c.app | Should -Be 1
        $c.other | Should -Be 0
    }

    It 'handles quoted and backslash paths' {
        $c = Get-DirtyFileCounts -AppDir 'app' -TestDirs @('test') -StatusLines @(
            '?? "app/with space.al"',
            ' M app\Sub\File.al'
        )
        $c.app | Should -Be 2
    }

    It 'buckets everything else under other' {
        $c = Get-DirtyFileCounts -AppDir 'app' -TestDirs @('test') -StatusLines @(
            ' M al-build.json',
            '?? specs/001-feature/tasks.md'
        )
        $c.other | Should -Be 2
    }

    It 'normalizes dotted and slashed dir configs' {
        $c = Get-DirtyFileCounts -AppDir './app/' -TestDirs @('.\test\') -StatusLines @(
            ' M app/A.al',
            ' M test/T.al'
        )
        $c.app | Should -Be 1
        $c.tests | Should -Be 1
    }

    It 'skips blank lines and returns zero counts for a clean tree' {
        $c = Get-DirtyFileCounts -AppDir 'app' -TestDirs @('test') -StatusLines @('', '   ')
        $c.app | Should -Be 0
        $c.tests | Should -Be 0
        $c.other | Should -Be 0
    }

    It 'matches absolute config dirs against repo-relative porcelain paths' {
        # Get-BuildConfig resolves dirs absolute; repo root falls back to cwd
        # ($TestDrive) outside a git repo
        $c = Get-DirtyFileCounts -AppDir (Join-Path (Get-Location).Path 'app') `
            -TestDirs @((Join-Path (Get-Location).Path 'test')) -StatusLines @(
            ' M app/A.al',
            '?? test/T.al'
        )
        $c.app | Should -Be 1
        $c.tests | Should -Be 1
        $c.other | Should -Be 0
    }

    It 'ignores compiled .app artifacts in any bucket' {
        $c = Get-DirtyFileCounts -AppDir 'app' -TestDirs @('test') -StatusLines @(
            ' M "app/Smoke Publisher_SmokeGate App_1.0.0.0.app"',
            ' M test/Pub_Tests_1.0.0.0.APP',
            ' M app/Real.Codeunit.al'
        )
        $c.app | Should -Be 1
        $c.tests | Should -Be 0
        $c.other | Should -Be 0
    }
}

Describe 'Save-BuildTimingEntry' {
    Context 'evidence-tagged entry (new shape)' {
        BeforeAll {
            $script:LocalLog = Join-Path $TestDrive 'tagged' 'build-timing.jsonl'
            Save-BuildTimingEntry -Task 'test' -Steps @{ build = 12.34; publish = 45.6 } -TotalSeconds 100.5 `
                -Gate 'full' -Outcome 'passed' -Tests @{ 'al-runner' = 563; 'container' = 601 } `
                -Dirty @{ app = 1; tests = 0; other = 2 } -HeadSha 'abc1234' `
                -LogPath $script:LocalLog
            $script:Entry = Read-LastJsonLine $script:LocalLog
        }

        It 'writes gate and outcome' {
            $script:Entry.gate | Should -Be 'full'
            $script:Entry.outcome | Should -Be 'passed'
        }

        It 'writes the dirty fingerprint and headSha' {
            $script:Entry.dirty.app | Should -Be 1
            $script:Entry.dirty.tests | Should -Be 0
            $script:Entry.dirty.other | Should -Be 2
            $script:Entry.headSha | Should -Be 'abc1234'
        }

        It 'writes per-runner test totals' {
            $script:Entry.tests.'al-runner' | Should -Be 563
            $script:Entry.tests.container | Should -Be 601
        }

        It 'keeps the legacy timing fields' {
            $script:Entry.task | Should -Be 'test'
            $script:Entry.totalSec | Should -Be 100.5
            $script:Entry.steps.build | Should -Be 12.3
        }

        It 'mirrors the entry with repo identity' {
            Test-Path $script:MirrorPath | Should -BeTrue
            $mirror = Read-LastJsonLine $script:MirrorPath
            $mirror.dirty.app | Should -Be 1
            $mirror.repo | Should -Be (Split-Path -Path (Get-Location).Path -Leaf)
            $mirror.repoPath | Should -Be (Get-Location).Path
        }
    }

    Context 'legacy call shape (existing callers)' {
        BeforeAll {
            $script:LegacyLog = Join-Path $TestDrive 'legacy' 'build-timing.jsonl'
            Save-BuildTimingEntry -Task 'publish-apps' -Steps @{ publish = 5.0 } -TotalSeconds 5.0 -LogPath $script:LegacyLog
            $script:LegacyEntry = Read-LastJsonLine $script:LegacyLog
        }

        It 'still writes the entry' {
            $script:LegacyEntry.task | Should -Be 'publish-apps'
            $script:LegacyEntry.totalSec | Should -Be 5.0
        }

        It 'omits the telemetry fields entirely' {
            $names = @($script:LegacyEntry.PSObject.Properties.Name)
            $names | Should -Not -Contain 'gate'
            $names | Should -Not -Contain 'outcome'
            $names | Should -Not -Contain 'tests'
            $names | Should -Not -Contain 'dirty'
            $names | Should -Not -Contain 'headSha'
        }
    }

    Context 'mirror failure' {
        BeforeAll {
            # Parent of the mirror path is a FILE -> directory creation must fail
            $blocker = Join-Path $TestDrive 'blocker'
            Set-Content -LiteralPath $blocker -Value 'occupied'
            $script:SavedGlobal = $env:ALBT_GATE_METRICS_GLOBAL_PATH
            $env:ALBT_GATE_METRICS_GLOBAL_PATH = Join-Path $blocker 'sub' 'gate-metrics.jsonl'
            $script:FailLog = Join-Path $TestDrive 'mirror-fail' 'build-timing.jsonl'
        }

        AfterAll {
            $env:ALBT_GATE_METRICS_GLOBAL_PATH = $script:SavedGlobal
        }

        It 'warns but does not throw, and the local entry still lands' {
            { Save-BuildTimingEntry -Task 'test' -Steps @{ build = 1.0 } -TotalSeconds 1.0 `
                -Gate 'unit' -Outcome 'failed' -LogPath $script:FailLog -WarningAction SilentlyContinue 3>$null } | Should -Not -Throw
            (Read-LastJsonLine $script:FailLog).outcome | Should -Be 'failed'
        }
    }
}

Describe 'Get-GateMetricsSummary' {
    BeforeAll {
        $script:SummaryLog = Join-Path $TestDrive 'summary' 'metrics.jsonl'
        New-Item -ItemType Directory -Force (Split-Path $script:SummaryLog -Parent) | Out-Null

        $recent = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
        # Legacy culture-written shape (da-DK time separator) — entries logged
        # before timestamps went invariant must still parse
        $recentDotted = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd HH.mm.ss', [Globalization.CultureInfo]::InvariantCulture)

        function Add-FixtureEntry {
            param([hashtable]$Fields)
            $json = ([ordered]@{} + $Fields) | ConvertTo-Json -Compress -Depth 5
            Add-Content -Path $script:SummaryLog -Value $json -Encoding UTF8
        }

        # Five mutation-shaped entries (prod-only dirty) with known durations: p50=30, p95=50
        foreach ($sec in @(10, 20, 30, 40, 50)) {
            Add-FixtureEntry @{ timestamp = $recent; task = 'test'; gate = 'full'; outcome = 'passed'; totalSec = $sec; dirty = @{ app = 1; tests = 0; other = 0 } }
        }
        # Two RED-shaped unit entries (test-only dirty), one failed one error
        Add-FixtureEntry @{ timestamp = $recent; task = 'unit-test'; gate = 'unit'; outcome = 'failed'; totalSec = 60; dirty = @{ app = 0; tests = 2; other = 0 } }
        Add-FixtureEntry @{ timestamp = $recent; task = 'unit-test'; gate = 'unit'; outcome = 'error'; totalSec = 30; dirty = @{ app = 0; tests = 1; other = 1 } }
        # One TDD-inner-loop entry (both dirty)
        Add-FixtureEntry @{ timestamp = $recent; task = 'test'; gate = 'full'; outcome = 'passed'; totalSec = 80; dirty = @{ app = 2; tests = 3; other = 0 } }
        # Legacy entry: no dirty/gate/outcome -> unknown/full via task name,
        # with the dotted timestamp shape older entries carry
        Add-FixtureEntry @{ timestamp = $recentDotted; task = 'test'; totalSec = 120; total = '2:00.0' }
        # Old clean-tree entry outside any -SinceDays window
        Add-FixtureEntry @{ timestamp = '2020-01-01 00:00:00'; task = 'test'; gate = 'full'; outcome = 'passed'; totalSec = 600; dirty = @{ app = 0; tests = 0; other = 0 } }
        # Non-gate task: excluded by the task filter
        Add-FixtureEntry @{ timestamp = $recent; task = 'pagescript-replay'; totalSec = 90 }
        # Malformed + blank lines: skipped, never crash
        Add-Content -Path $script:SummaryLog -Value '{"timestamp": "2026-' -Encoding UTF8
        Add-Content -Path $script:SummaryLog -Value '' -Encoding UTF8

        $script:Rows = @(Get-GateMetricsSummary -LogPath $script:SummaryLog -Task @('test', 'unit-test'))
    }

    It 'groups by signature and gate' {
        ($script:Rows | ForEach-Object { "$($_.Signature)|$($_.Gate)" }) | Sort-Object |
            Should -Be @('clean|full', 'mixed|full', 'prod-only|full', 'test-only|unit', 'unknown|full')
    }

    It 'computes nearest-rank p50 and p95' {
        $prodOnly = $script:Rows | Where-Object { $_.Signature -eq 'prod-only' }
        $prodOnly.Runs | Should -Be 5
        $prodOnly.MedianSec | Should -Be 30
        $prodOnly.P95Sec | Should -Be 50
        $prodOnly.TotalMin | Should -Be 2.5
    }

    It 'counts outcomes per group' {
        $testOnly = $script:Rows | Where-Object { $_.Signature -eq 'test-only' }
        $testOnly.Failed | Should -Be 1
        $testOnly.Errors | Should -Be 1
        $testOnly.Passed | Should -Be 0
    }

    It 'buckets legacy entries as unknown with gate derived from task' {
        $legacy = $script:Rows | Where-Object { $_.Signature -eq 'unknown' }
        $legacy.Gate | Should -Be 'full'
        $legacy.Runs | Should -Be 1
        $legacy.Untagged | Should -Be 1
    }

    It 'excludes tasks outside the filter' {
        ($script:Rows | Measure-Object -Property Runs -Sum).Sum | Should -Be 10
    }

    It 'applies the SinceDays window' {
        $windowed = @(Get-GateMetricsSummary -LogPath $script:SummaryLog -SinceDays 7 -Task @('test', 'unit-test'))
        ($windowed | Where-Object { $_.Signature -eq 'clean' }) | Should -BeNullOrEmpty
        ($windowed | Measure-Object -Property Runs -Sum).Sum | Should -Be 9
    }

    It 'returns empty for a missing log' {
        @(Get-GateMetricsSummary -LogPath (Join-Path $TestDrive 'nope.jsonl')) | Should -BeNullOrEmpty
    }
}
