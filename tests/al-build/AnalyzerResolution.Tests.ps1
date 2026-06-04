#Requires -Version 7.2

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    function New-AnalyzerFixture {
        <#
            Creates <root>\compiler with the Microsoft analyzer DLLs flat (matching the
            dotnet-tool layout) and <root>\compiler\Analyzers with the ALCops DLLs
            (matching what Install-ALCops produces). Returns the compiler dir path.
        #>
        param([string]$Root)

        $compilerDir = Join-Path $Root 'compiler'
        $analyzersDir = Join-Path $compilerDir 'Analyzers'
        New-Item -ItemType Directory -Path $analyzersDir -Force | Out-Null

        $microsoftDlls = @(
            'Microsoft.Dynamics.Nav.CodeCop.dll'
            'Microsoft.Dynamics.Nav.UICop.dll'
            'Microsoft.Dynamics.Nav.AppSourceCop.dll'
            'Microsoft.Dynamics.Nav.PerTenantExtensionCop.dll'
            'Microsoft.Dynamics.Nav.Analyzers.Common.dll'
        )
        foreach ($dll in $microsoftDlls) {
            New-Item -ItemType File -Path (Join-Path $compilerDir $dll) -Force | Out-Null
        }

        $alcopsDlls = @(
            'ALCops.ApplicationCop.dll'
            'ALCops.Common.dll'
            'ALCops.DocumentationCop.dll'
            'ALCops.FormattingCop.dll'
            'ALCops.LinterCop.dll'
            'ALCops.PlatformCop.dll'
            'ALCops.TestAutomationCop.dll'
        )
        foreach ($dll in $alcopsDlls) {
            New-Item -ItemType File -Path (Join-Path $analyzersDir $dll) -Force | Out-Null
        }

        return $compilerDir
    }

    function New-AppFixture {
        param([string]$Root, [string[]]$CodeAnalyzers)

        $appDir = Join-Path $Root 'app'
        $vscodeDir = Join-Path $appDir '.vscode'
        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
        @{ 'al.codeAnalyzers' = $CodeAnalyzers } | ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $vscodeDir 'settings.json') -Encoding UTF8
        return $appDir
    }
}

Describe 'Get-EnabledAnalyzerPath' {
    It 'resolves Microsoft tokens from the flat compiler directory' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @('${CodeCop}', '${UICop}')

        $result = @(Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir)

        @($result | Split-Path -Leaf) | Should -Be @(
            'Microsoft.Dynamics.Nav.CodeCop.dll'
            'Microsoft.Dynamics.Nav.UICop.dll'
        )
    }

    It 'resolves the official ${analyzerFolder} ALCops notation and auto-appends both companion DLLs' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @('${analyzerfolder}ALCops.PlatformCop.dll')

        $result = @(Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir)

        $leaves = @($result | Split-Path -Leaf)
        $leaves | Should -Contain 'ALCops.PlatformCop.dll'
        $leaves | Should -Contain 'ALCops.Common.dll'
        # No Microsoft analyzer enabled, so the Microsoft common DLL must ride along too
        $leaves | Should -Contain 'Microsoft.Dynamics.Nav.Analyzers.Common.dll'
        $leaves.Count | Should -Be 3
    }

    It 'skips the Microsoft common DLL when a Microsoft analyzer is enabled alongside ALCops' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @(
            '${CodeCop}'
            '${analyzerfolder}ALCops.LinterCop.dll'
        )

        $result = @(Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir)

        $leaves = @($result | Split-Path -Leaf)
        $leaves | Should -Contain 'ALCops.Common.dll'
        $leaves | Should -Not -Contain 'Microsoft.Dynamics.Nav.Analyzers.Common.dll'
    }

    It 'does not duplicate an explicitly listed ALCops.Common.dll' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @(
            '${analyzerfolder}ALCops.FormattingCop.dll'
            '${analyzerFolder}ALCops.Common.dll'
        )

        $result = @(Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir)

        @($result | Split-Path -Leaf | Where-Object { $_ -eq 'ALCops.Common.dll' }).Count | Should -Be 1
    }

    It 'throws when a requested analyzer cannot be resolved' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        Remove-Item (Join-Path $compilerDir 'Analyzers' 'ALCops.PlatformCop.dll') -Force
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @('${analyzerfolder}ALCops.PlatformCop.dll')

        { Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir } |
            Should -Throw '*not resolvable*'
    }

    It 'throws when a Microsoft token cannot be resolved' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        Remove-Item (Join-Path $compilerDir 'Microsoft.Dynamics.Nav.AppSourceCop.dll') -Force
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @('${AppSourceCop}')

        { Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir } |
            Should -Throw '*not resolvable*'
    }

    It 'no longer supports the retired LinterCop token' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @('${LinterCop}')

        { Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir } |
            Should -Throw '*not resolvable*'
    }

    It 'throws when settings.json exists but cannot be parsed' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = Join-Path $TestDrive 'malformed-app'
        New-Item -ItemType Directory -Path (Join-Path $appDir '.vscode') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $appDir '.vscode' 'settings.json') -Value '{ "al.codeAnalyzers": [' -Encoding UTF8

        { Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir } |
            Should -Throw '*could not be parsed*'
    }

    It 'returns an empty list when no settings.json exists' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = Join-Path $TestDrive 'bare-app'
        New-Item -ItemType Directory -Path $appDir -Force | Out-Null

        $result = @(Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir)

        $result.Count | Should -Be 0
    }

    It 'prefers app-local settings over workspace-root settings' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = New-AppFixture -Root $TestDrive -CodeAnalyzers @('${CodeCop}')
        New-Item -ItemType Directory -Path (Join-Path $TestDrive '.vscode') -Force | Out-Null
        @{ 'al.codeAnalyzers' = @('${UICop}', '${AppSourceCop}') } | ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $TestDrive '.vscode' 'settings.json') -Encoding UTF8

        Push-Location $TestDrive
        try {
            $result = @(Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir)
        } finally {
            Pop-Location
        }

        @($result | Split-Path -Leaf) | Should -Be @('Microsoft.Dynamics.Nav.CodeCop.dll')
    }

    It 'falls back to workspace-root settings when the app has none' {
        $compilerDir = New-AnalyzerFixture -Root $TestDrive
        $appDir = Join-Path $TestDrive 'bare-app'
        New-Item -ItemType Directory -Path $appDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $TestDrive '.vscode') -Force | Out-Null
        @{ 'al.codeAnalyzers' = @('${UICop}') } | ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $TestDrive '.vscode' 'settings.json') -Encoding UTF8

        Push-Location $TestDrive
        try {
            $result = @(Get-EnabledAnalyzerPath -AppDir $appDir -CompilerDir $compilerDir)
        } finally {
            Pop-Location
        }

        @($result | Split-Path -Leaf) | Should -Be @('Microsoft.Dynamics.Nav.UICop.dll')
    }
}

Describe 'Select-CompilerCandidate' {
    BeforeEach {
        $script:net8 = [pscustomobject]@{
            FullName      = 'C:\tools\.store\pkg\1.0\pkg\1.0\tools\net8.0\any\alc.exe'
            LastWriteTime = [datetime]'2026-05-28T12:36:36'
        }
        $script:net10 = [pscustomobject]@{
            FullName      = 'C:\tools\.store\pkg\1.0\pkg\1.0\tools\net10.0\any\alc.exe'
            LastWriteTime = [datetime]'2026-05-28T12:36:42'
        }
    }

    It 'prefers the highest target framework when all runtimes are installed' {
        $chosen = Select-CompilerCandidate -Candidates @($net8, $net10) -InstalledRuntimeMajors @(8, 10)
        $chosen.FullName | Should -Be $net10.FullName
    }

    It 'prefers a runnable candidate over a higher framework without its runtime' {
        $chosen = Select-CompilerCandidate -Candidates @($net8, $net10) -InstalledRuntimeMajors @(8)
        $chosen.FullName | Should -Be $net8.FullName
    }

    It 'is deterministic regardless of candidate order' {
        $a = Select-CompilerCandidate -Candidates @($net8, $net10) -InstalledRuntimeMajors @(8, 10)
        $b = Select-CompilerCandidate -Candidates @($net10, $net8) -InstalledRuntimeMajors @(8, 10)
        $a.FullName | Should -Be $b.FullName
    }

    It 'falls back to newest file when no target framework appears in the path' {
        $old = [pscustomobject]@{ FullName = 'C:\x\alc.exe'; LastWriteTime = [datetime]'2026-01-01' }
        $new = [pscustomobject]@{ FullName = 'C:\y\alc.exe'; LastWriteTime = [datetime]'2026-02-01' }
        $chosen = Select-CompilerCandidate -Candidates @($old, $new) -InstalledRuntimeMajors @(8)
        $chosen.FullName | Should -Be $new.FullName
    }

    It 'ranks unknown-framework candidates as runnable' {
        $plain = [pscustomobject]@{ FullName = 'C:\x\alc.exe'; LastWriteTime = [datetime]'2026-01-01' }
        $chosen = Select-CompilerCandidate -Candidates @($plain, $net10) -InstalledRuntimeMajors @(8)
        $chosen.FullName | Should -Be $plain.FullName
    }

    It 'returns null for empty candidates' {
        Select-CompilerCandidate -Candidates @() -InstalledRuntimeMajors @(8) | Should -BeNullOrEmpty
    }
}
