#Requires -Version 7.2

BeforeAll {
    $script:ReplayScriptPath = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts' 'pagescript-replay.ps1')
    $script:ReplayScript = Get-Content -LiteralPath $script:ReplayScriptPath -Raw

    $tokens = $null
    $parseErrors = $null
    $script:ReplayAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:ReplayScriptPath,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        throw "pagescript-replay.ps1 has parse errors: $($parseErrors.Message -join '; ')"
    }
}

Describe 'pagescript-replay batch mode' {
    It 'constructs a serial Playwright invocation without CI retries' {
        $commands = @($script:ReplayAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true))

        $playwrightTestCommands = @($commands | Where-Object {
            $_.CommandElements.Count -ge 3 -and
            $_.CommandElements[0].Extent.Text -eq 'npx' -and
            $_.CommandElements[1].Extent.Text -eq 'playwright' -and
            $_.CommandElements[2].Extent.Text -eq 'test'
        })

        $playwrightTestCommands | Should -HaveCount 1
        $commandText = $playwrightTestCommands[0].Extent.Text
        $commandText | Should -Match '--workers=1'
        $commandText | Should -Match '--retries=0'
        $script:ReplayScript | Should -Not -Match '\$env:CI'
        $script:ReplayScript | Should -Not -Match 'CI=1'
    }

    It 'sets the bc-replay player environment for direct batch replay' {
        $requiredEnvVars = @(
            'bc_player_testDir',
            'bc_player_workingDir',
            'bc_player_tests',
            'bc_player_resultDir',
            'bc_player_startAddress',
            'bc_player_auth',
            'bc_player_username_key',
            'bc_player_password_key'
        )

        foreach ($envVar in $requiredEnvVars) {
            $script:ReplayScript | Should -Match ([regex]::Escape("env:$envVar"))
        }
    }

    It 'keeps single-file mode on the bc-replay wrapper' {
        $script:ReplayScript | Should -Match '&\s+\$replayExe\s+-Tests\s+\$testsArg'
        $script:ReplayScript | Should -Match 'single-file mode'
    }

    It 'keeps batch mode on the pagescripts recordings glob' {
        $script:ReplayScript | Should -Match '(?m)^\s*\$testsArg\s*=\s*''recordings/\*\.yml'''
    }
}
