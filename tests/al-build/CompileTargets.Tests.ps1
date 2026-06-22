#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    # Get-CompileTargets reads only .TestApps and .UnitTestApp, so a plain object
    # stands in for a full Get-BuildConfig result — keeps the test filesystem-free.
    function New-Config {
        param([string[]]$TestApps = @(), [string]$UnitTestApp = '')
        [PSCustomObject]@{ TestApps = $TestApps; UnitTestApp = $UnitTestApp }
    }
}

Describe 'Get-CompileTargets' {
    Context 'two-peer layout: integration test app + separate unit-test app' {
        BeforeAll {
            $cfg = New-Config -TestApps @('integration-tests') -UnitTestApp 'unit-tests'
            $script:Targets = @(Get-CompileTargets -Config $cfg)
        }

        It 'returns the test app then the unit-test app, in order' {
            $script:Targets.Count | Should -Be 2
            $script:Targets[0].AppDir | Should -Be 'integration-tests'
            $script:Targets[0].Role | Should -Be 'test'
            $script:Targets[1].AppDir | Should -Be 'unit-tests'
            $script:Targets[1].Role | Should -Be 'unit'
        }

        It 'excludes the main app — it is compiled separately in Step 1' {
            $script:Targets.AppDir | Should -Not -Contain 'app'
        }
    }

    Context 'mode independence — the regression this guards' {
        It 'returns the identical set with and without -UnitTestOnly' {
            $cfg = New-Config -TestApps @('test-a', 'test-b') -UnitTestApp 'unit-tests'
            $full = @(Get-CompileTargets -Config $cfg)
            $unit = @(Get-CompileTargets -Config $cfg -UnitTestOnly)

            ($unit | ForEach-Object { "$($_.Role):$($_.AppDir)" }) |
                Should -Be ($full | ForEach-Object { "$($_.Role):$($_.AppDir)" })
        }

        It 'compiles every test app in -UnitTestOnly mode' {
            $cfg = New-Config -TestApps @('test-a', 'test-b') -UnitTestApp 'unit-tests'
            $targets = @(Get-CompileTargets -Config $cfg -UnitTestOnly)
            ($targets | Where-Object Role -eq 'test').AppDir | Should -Be @('test-a', 'test-b')
        }
    }

    Context 'unit-test app also listed in testApps' {
        It 'compiles it once, as a test app — no duplicate unit target' {
            $cfg = New-Config -TestApps @('unit-tests', 'integration-tests') -UnitTestApp 'unit-tests'
            $targets = @(Get-CompileTargets -Config $cfg)
            $targets.Count | Should -Be 2
            ($targets | Where-Object Role -eq 'unit') | Should -BeNullOrEmpty
            $targets.AppDir | Should -Be @('unit-tests', 'integration-tests')
        }
    }

    Context 'unit-only project: testApps empty' {
        It 'returns just the unit-test app' {
            $cfg = New-Config -TestApps @() -UnitTestApp 'unit-tests'
            $targets = @(Get-CompileTargets -Config $cfg)
            $targets.Count | Should -Be 1
            $targets[0].AppDir | Should -Be 'unit-tests'
            $targets[0].Role | Should -Be 'unit'
        }
    }

    Context 'no unit-test app configured' {
        It 'returns just the test apps' {
            $cfg = New-Config -TestApps @('test-a', 'test-b') -UnitTestApp ''
            $targets = @(Get-CompileTargets -Config $cfg)
            $targets.Role | Should -Be @('test', 'test')
            $targets.AppDir | Should -Be @('test-a', 'test-b')
        }
    }

    Context 'no secondary targets at all' {
        It 'returns an empty list (main app still compiles in Step 1)' {
            $cfg = New-Config -TestApps @() -UnitTestApp ''
            @(Get-CompileTargets -Config $cfg).Count | Should -Be 0
        }
    }
}
