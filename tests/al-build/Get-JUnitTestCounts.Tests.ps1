#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    $script:FixtureDir = Join-Path $TestDrive 'junit-fixtures'
    New-Item -ItemType Directory -Force $script:FixtureDir | Out-Null

    function New-Fixture {
        param([string]$Name, [string]$Content)
        $path = Join-Path $script:FixtureDir $Name
        Set-Content -LiteralPath $path -Value $Content
        return $path
    }
}

Describe 'Get-JUnitTestCounts' {
    Context 'green run, multiple test codeunits' {
        BeforeAll {
            # Container shape: no aggregate attrs on the testsuites root (BcContainerHelper)
            $script:GreenFile = New-Fixture 'green.xml' @'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="60000 Conf Attr Accept Test" tests="12" errors="0" failures="0" skipped="0" time="0.138">
    <testcase classname="60000 Conf Attr Accept Test" name="EmptySuggestionSetInsertsNothing" time="0.023" />
  </testsuite>
  <testsuite name="60001 Conf Attr Classify Test" tests="9" errors="0" failures="0" skipped="0" time="0.181">
    <testcase classname="60001 Conf Attr Classify Test" name="ClassifiesKnownAttribute" time="0.012" />
  </testsuite>
</testsuites>
'@
        }

        It 'counts testsuites as test codeunits' {
            (Get-JUnitTestCounts -ResultFile $script:GreenFile).testCodeunits | Should -Be 2
        }

        It 'sums tests across testsuites' {
            $c = Get-JUnitTestCounts -ResultFile $script:GreenFile
            $c.tests | Should -Be 21
            $c.testsPassed | Should -Be 21
            $c.testsFailed | Should -Be 0
            $c.testsSkipped | Should -Be 0
        }
    }

    Context 'red run with failures, errors, and skips' {
        BeforeAll {
            # AL Runner shape: aggregate attrs present on the testsuites root
            $script:RedFile = New-Fixture 'red.xml' @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites tests="5" failures="1" errors="1" time="0.000">
  <testsuite name="Red Probe Test" tests="5" failures="1" errors="1" skipped="1" time="0.000">
    <testcase name="FailingTest" classname="Red Probe Test" time="0.000">
      <failure message="boom: expected OR, actual AND">boom: expected OR, actual AND</failure>
    </testcase>
    <testcase name="PassingTest" classname="Red Probe Test" time="0.000" />
  </testsuite>
</testsuites>
'@
        }

        It 'folds errors into testsFailed' {
            $c = Get-JUnitTestCounts -ResultFile $script:RedFile
            $c.tests | Should -Be 5
            $c.testsFailed | Should -Be 2
            $c.testsSkipped | Should -Be 1
            $c.testsPassed | Should -Be 2
        }

        It 'ignores aggregate attrs on the testsuites root' {
            # Root says failures=1 but the testsuite says failures=1 errors=1; suite-level wins
            (Get-JUnitTestCounts -ResultFile $script:RedFile).testsFailed | Should -Be 2
        }
    }

    Context 'testsuite with missing optional attributes' {
        It 'treats absent errors/skipped attrs as zero' {
            $f = New-Fixture 'sparse.xml' @'
<testsuites>
  <testsuite name="Sparse Test" tests="3" failures="1" />
</testsuites>
'@
            $c = Get-JUnitTestCounts -ResultFile $f
            $c.tests | Should -Be 3
            $c.testsFailed | Should -Be 1
            $c.testsPassed | Should -Be 2
            $c.testsSkipped | Should -Be 0
        }
    }

    Context 'empty result' {
        It 'reports zeros for a parseable file with no testsuites' {
            $f = New-Fixture 'empty.xml' '<testsuites />'
            $c = Get-JUnitTestCounts -ResultFile $f
            $c | Should -Not -BeNullOrEmpty
            $c.testCodeunits | Should -Be 0
            $c.tests | Should -Be 0
        }
    }

    Context 'unknown counts are null, never zeros' {
        It 'returns null for a missing file' {
            Get-JUnitTestCounts -ResultFile (Join-Path $script:FixtureDir 'does-not-exist.xml') | Should -BeNullOrEmpty
        }

        It 'returns null for an empty path' {
            Get-JUnitTestCounts -ResultFile '' | Should -BeNullOrEmpty
        }

        It 'returns null for malformed XML' {
            $f = New-Fixture 'malformed.xml' '<testsuites><testsuite tests="not closed'
            Get-JUnitTestCounts -ResultFile $f 3>$null | Should -BeNullOrEmpty
        }
    }
}

Describe 'Format-TestCountSummary' {
    It 'keeps tests and test codeunits labeled and adjacent' {
        $counts = [PSCustomObject]@{
            testCodeunits = 54
            tests         = 563
            testsPassed   = 561
            testsFailed   = 2
            testsSkipped  = 0
        }
        Format-TestCountSummary -Counts $counts |
            Should -Be '563 tests in 54 test codeunits - 561 passed, 2 failed, 0 skipped'
    }
}
