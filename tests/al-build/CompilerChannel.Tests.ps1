#Requires -Version 7.2

# Unit tests for the stable-vs-prerelease compiler channel selection. al-build
# installs two private side-by-side compilers (stable + prerelease) via
# --tool-path and picks one per app.json runtime; the global dotnet tool is the
# user's own and is never touched. These tests cover the pure decision
# (Resolve-CompilerChannel), runtime parsing (Get-AppRuntimeMajor /
# Get-RequiredRuntimeMajor), the offline sentinel-based resolver
# (Get-LatestCompilerInfo), and the channel installer's dotnet dispatch
# (Install-ALCompilerChannel) with dotnet mocked — no real install, no network.

BeforeAll {
    $scriptsDir = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'plugins' 'al-agentic-dev' 'skills' 'al-build' 'scripts')
    Import-Module (Join-Path $scriptsDir 'common.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $scriptsDir 'build-operations.psm1') -Force -DisableNameChecking

    function New-AppDir {
        param([string]$Name, [object]$Runtime = '__none__', [string]$RawJson)
        $dir = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        if ($PSBoundParameters.ContainsKey('RawJson')) {
            Set-Content -LiteralPath (Join-Path $dir 'app.json') -Value $RawJson -Encoding UTF8
        } else {
            $obj = [ordered]@{ id = '00000000-0000-0000-0000-000000000001'; name = $Name; publisher = 'Test' }
            if ($Runtime -ne '__none__') { $obj['runtime'] = $Runtime }
            Set-Content -LiteralPath (Join-Path $dir 'app.json') -Value ($obj | ConvertTo-Json) -Encoding UTF8
        }
        return $dir
    }
}

Describe 'Resolve-CompilerChannel' {
    Context 'stable channel covers everything up to its own major' {
        It 'picks stable when required is below stable (R16,S17,P18)' {
            Resolve-CompilerChannel -RequiredMajor 16 -StableMajor 17 -PrereleaseMajor 18 | Should -Be 'stable'
        }
        It 'picks stable at the boundary required equals stable (R17,S17,P18)' {
            Resolve-CompilerChannel -RequiredMajor 17 -StableMajor 17 -PrereleaseMajor 18 | Should -Be 'stable'
        }
        It 'picks stable when no app pins a runtime (R0,S17,P18)' {
            Resolve-CompilerChannel -RequiredMajor 0 -StableMajor 17 -PrereleaseMajor 18 | Should -Be 'stable'
        }
    }

    Context 'prerelease channel only when required exceeds stable' {
        It 'picks prerelease when required equals stable+1 equals prerelease (R18,S17,P18)' {
            Resolve-CompilerChannel -RequiredMajor 18 -StableMajor 17 -PrereleaseMajor 18 | Should -Be 'prerelease'
        }
        It 'picks prerelease even when prerelease major is unknown (P0) and required exceeds stable' {
            # P0 = prerelease not installed; the on-disk check fails loud later, not here.
            Resolve-CompilerChannel -RequiredMajor 18 -StableMajor 17 -PrereleaseMajor 0 | Should -Be 'prerelease'
        }
    }

    Context 'a runtime newer than even prerelease cannot be satisfied' {
        It 'throws when required exceeds prerelease (R19,S17,P18)' {
            { Resolve-CompilerChannel -RequiredMajor 19 -StableMajor 17 -PrereleaseMajor 18 } |
                Should -Throw -ExpectedMessage '*No installed AL compiler supports runtime major 19*'
        }
    }
}

Describe 'Get-AppRuntimeMajor' {
    Context 'parses the major from a version string' {
        It 'reads "17.0" as 17' { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'a170' -Runtime '17.0') | Should -Be 17 }
        It 'reads bare "17" as 17'   { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'a17' -Runtime '17') | Should -Be 17 }
        It 'reads "1.0" as 1'        { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'a10' -Runtime '1.0') | Should -Be 1 }
        It 'reads "18.0" as 18'      { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'a180' -Runtime '18.0') | Should -Be 18 }
        It 'trims surrounding whitespace' { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'aws' -Runtime '  18.0  ') | Should -Be 18 }
    }

    Context 'absent runtime contributes nothing (pinned to stable by the caller)' {
        It 'returns $null when app.json omits runtime' { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'none' -Runtime '__none__') | Should -BeNullOrEmpty }
        It 'returns $null when runtime is an empty string' { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'empty' -Runtime '') | Should -BeNullOrEmpty }
        It 'returns $null when runtime is whitespace' { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'wsonly' -Runtime '   ') | Should -BeNullOrEmpty }
        It 'returns $null when the directory has no app.json' {
            $dir = Join-Path $TestDrive 'noappjson'; New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Get-AppRuntimeMajor -AppDir $dir | Should -BeNullOrEmpty
        }
        It 'returns $null for an empty AppDir argument' { Get-AppRuntimeMajor -AppDir '' | Should -BeNullOrEmpty }
    }

    Context 'a misconfigured runtime fails loud' {
        It 'throws on an unparseable runtime' {
            { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'bad' -Runtime 'abc') } |
                Should -Throw -ExpectedMessage '*unparseable runtime*'
        }
        It 'throws on malformed app.json' {
            { Get-AppRuntimeMajor -AppDir (New-AppDir -Name 'badjson' -RawJson '{ not json') } | Should -Throw
        }
    }
}

Describe 'Get-RequiredRuntimeMajor' {
    It 'returns the max runtime major across main, test, and unit apps' {
        $cfg = [PSCustomObject]@{
            AppDir      = New-AppDir -Name 'main17' -Runtime '17.0'
            TestApps    = @((New-AppDir -Name 'test18' -Runtime '18.0'), (New-AppDir -Name 'test16' -Runtime '16.0'))
            UnitTestApp = New-AppDir -Name 'unit15' -Runtime '15.0'
        }
        Get-RequiredRuntimeMajor -Config $cfg | Should -Be 18
    }

    It 'a test app newer than the main app drags the whole build up' {
        $cfg = [PSCustomObject]@{
            AppDir      = New-AppDir -Name 'main17b' -Runtime '17.0'
            TestApps    = @((New-AppDir -Name 'test18b' -Runtime '18.0'))
            UnitTestApp = ''
        }
        Get-RequiredRuntimeMajor -Config $cfg | Should -Be 18
    }

    It 'returns 0 when no app pins a runtime' {
        $cfg = [PSCustomObject]@{
            AppDir      = New-AppDir -Name 'mainnone' -Runtime '__none__'
            TestApps    = @((New-AppDir -Name 'testnone' -Runtime '__none__'))
            UnitTestApp = ''
        }
        Get-RequiredRuntimeMajor -Config $cfg | Should -Be 0
    }

    It 'ignores a configured test app dir that does not exist on disk' {
        $cfg = [PSCustomObject]@{
            AppDir      = New-AppDir -Name 'main17c' -Runtime '17.0'
            TestApps    = @((Join-Path $TestDrive 'ghost-test-app'))
            UnitTestApp = ''
        }
        Get-RequiredRuntimeMajor -Config $cfg | Should -Be 17
    }
}

Describe 'Get-LatestCompilerInfo' {
    BeforeEach {
        $script:cacheRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString('N'))
        $script:alDir = Join-Path $script:cacheRoot 'al'
        New-Item -ItemType Directory -Path $script:alDir -Force | Out-Null
        $env:ALBT_TOOL_CACHE_ROOT = $script:cacheRoot

        # Dummy on-disk compilers so the resolver's existence checks pass.
        $script:stableRoot = Join-Path $script:alDir 'stable'
        $script:preRoot = Join-Path $script:alDir 'prerelease'
        $script:stableAlcDir = Join-Path $script:stableRoot 'alc'
        $script:preAlcDir = Join-Path $script:preRoot 'alc'
        New-Item -ItemType Directory -Path $script:stableAlcDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:preAlcDir -Force | Out-Null
        $script:stableCmd = Join-Path $script:stableRoot 'al.exe'; Set-Content -LiteralPath $script:stableCmd -Value 'x'
        $script:preCmd = Join-Path $script:preRoot 'al.exe'; Set-Content -LiteralPath $script:preCmd -Value 'x'
        $script:stableAlc = Join-Path $script:stableAlcDir 'alc.exe'; Set-Content -LiteralPath $script:stableAlc -Value 'x'
        $script:preAlc = Join-Path $script:preAlcDir 'alc.exe'; Set-Content -LiteralPath $script:preAlc -Value 'x'

        function Write-Sentinel {
            param([hashtable]$Override = @{})
            $s = [ordered]@{
                schemaVersion   = 2
                stableMajor     = 17
                prereleaseMajor = 18
                channels        = [ordered]@{
                    stable     = [ordered]@{ root = $script:stableRoot; commandPath = $script:stableCmd; alcPath = $script:stableAlc; version = '17.0.34.45391' }
                    prerelease = [ordered]@{ root = $script:preRoot; commandPath = $script:preCmd; alcPath = $script:preAlc; version = '18.0.37.11445-beta' }
                }
            }
            foreach ($k in $Override.Keys) { $s[$k] = $Override[$k] }
            $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $script:alDir 'sentinel.json') -Encoding UTF8
        }
    }
    AfterEach {
        Remove-Item Env:\ALBT_TOOL_CACHE_ROOT -ErrorAction SilentlyContinue
    }

    It 'selects the stable channel for a runtime at or below the stable major' {
        Write-Sentinel
        $info = Get-LatestCompilerInfo -RequiredRuntimeMajor 17
        $info.Channel | Should -Be 'stable'
        $info.Version | Should -Be '17.0.34.45391'
        $info.CommandPath | Should -Be (Get-Item -LiteralPath $script:stableCmd).FullName
        $info.CompilerDir | Should -Be (Get-Item -LiteralPath $script:stableAlcDir).FullName
    }

    It 'selects the prerelease channel for a runtime above the stable major' {
        Write-Sentinel
        $info = Get-LatestCompilerInfo -RequiredRuntimeMajor 18
        $info.Channel | Should -Be 'prerelease'
        $info.Version | Should -Be '18.0.37.11445-beta'
        $info.CommandPath | Should -Be (Get-Item -LiteralPath $script:preCmd).FullName
    }

    It 'defaults to stable when no runtime is required (0)' {
        Write-Sentinel
        (Get-LatestCompilerInfo -RequiredRuntimeMajor 0).Channel | Should -Be 'stable'
    }

    It 'throws when the required runtime exceeds even the prerelease major' {
        Write-Sentinel
        { Get-LatestCompilerInfo -RequiredRuntimeMajor 19 } | Should -Throw -ExpectedMessage '*No installed AL compiler supports runtime major 19*'
    }

    It 'fails loud when the sentinel is missing' {
        { Get-LatestCompilerInfo -RequiredRuntimeMajor 17 } | Should -Throw -ExpectedMessage '*not provisioned*'
    }

    It 'fails loud when the sentinel predates side-by-side channels' {
        # Legacy flat sentinel: no 'channels' key.
        [ordered]@{ compilerVersion = '16.0.0.0'; toolPath = 'x' } | ConvertTo-Json |
            Set-Content -LiteralPath (Join-Path $script:alDir 'sentinel.json') -Encoding UTF8
        { Get-LatestCompilerInfo -RequiredRuntimeMajor 17 } | Should -Throw -ExpectedMessage '*predates side-by-side channels*'
    }

    It 'fails loud when the selected channel command is absent on disk (drift since provision)' {
        Write-Sentinel
        Remove-Item -LiteralPath $script:stableCmd -Force
        { Get-LatestCompilerInfo -RequiredRuntimeMajor 17 } | Should -Throw -ExpectedMessage "*not found at*Run 'provision.ps1'*"
    }

    It 'fails loud when the selected channel alc is absent on disk' {
        Write-Sentinel
        Remove-Item -LiteralPath $script:preAlc -Force
        { Get-LatestCompilerInfo -RequiredRuntimeMajor 18 } | Should -Throw -ExpectedMessage '*alc*not found*'
    }
}

Describe 'Install-ALCompilerChannel' {
    It 'installs into a --tool-path (never --global) and not from prerelease for the stable channel' {
        InModuleScope build-operations {
            Mock Ensure-Directory {}
            Mock Write-BuildMessage {}
            $script:seq = 0
            Mock Get-InstalledCompilerVersion { $script:seq++; if ($script:seq -eq 1) { $null } else { '17.0.34.45391' } }
            Mock Get-LatestCompilerPath { 'X:\stable\alc\alc.exe' }
            Mock Get-ToolCommandPath { 'X:\stable\al.exe' }
            Mock dotnet { $global:LASTEXITCODE = 0 }

            $r = Install-ALCompilerChannel -PackageId 'pkg' -ToolPathRoot 'X:\stable'
            $r.Channel | Should -Be 'stable'
            $r.Version | Should -Be '17.0.34.45391'
            $r.Major   | Should -Be 17
            Should -Invoke dotnet -ParameterFilter { $args -contains 'install' -and $args -contains '--tool-path' -and $args -notcontains '--global' -and $args -notcontains '--prerelease' } -Times 1
        }
    }

    It 'passes --prerelease for the prerelease channel and parses a -beta major' {
        InModuleScope build-operations {
            Mock Ensure-Directory {}
            Mock Write-BuildMessage {}
            Mock Get-InstalledCompilerVersion { '18.0.37.11445-beta' }   # already present -> update path
            Mock Get-LatestCompilerPath { 'X:\pre\alc\alc.exe' }
            Mock Get-ToolCommandPath { 'X:\pre\al.exe' }
            Mock dotnet { $global:LASTEXITCODE = 0 }

            $r = Install-ALCompilerChannel -PackageId 'pkg' -ToolPathRoot 'X:\pre' -Prerelease
            $r.Channel | Should -Be 'prerelease'
            $r.Major   | Should -Be 18
            Should -Invoke dotnet -ParameterFilter { $args -contains 'update' -and $args -contains '--prerelease' } -Times 1
        }
    }

    It 'updates in place when a compiler is already installed' {
        InModuleScope build-operations {
            Mock Ensure-Directory {}
            Mock Write-BuildMessage {}
            Mock Get-InstalledCompilerVersion { '17.0.0.0' }
            Mock Get-LatestCompilerPath { 'X:\s\alc\alc.exe' }
            Mock Get-ToolCommandPath { 'X:\s\al.exe' }
            Mock dotnet { $global:LASTEXITCODE = 0 }

            Install-ALCompilerChannel -PackageId 'pkg' -ToolPathRoot 'X:\s' | Out-Null
            Should -Invoke dotnet -ParameterFilter { $args -contains 'update' } -Times 1
            Should -Invoke dotnet -ParameterFilter { $args -contains 'install' } -Times 0
        }
    }

    It '-Update forces a clean reinstall (uninstall then install) when present' {
        InModuleScope build-operations {
            Mock Ensure-Directory {}
            Mock Write-BuildMessage {}
            Mock Get-InstalledCompilerVersion { '17.0.0.0' }
            Mock Get-LatestCompilerPath { 'X:\s\alc\alc.exe' }
            Mock Get-ToolCommandPath { 'X:\s\al.exe' }
            Mock dotnet { $global:LASTEXITCODE = 0 }

            Install-ALCompilerChannel -PackageId 'pkg' -ToolPathRoot 'X:\s' -Update | Out-Null
            Should -Invoke dotnet -ParameterFilter { $args -contains 'uninstall' } -Times 1
            Should -Invoke dotnet -ParameterFilter { $args -contains 'install' } -Times 1
            Should -Invoke dotnet -ParameterFilter { $args -contains 'update' } -Times 0
        }
    }

    It 'throws when the dotnet install exits non-zero' {
        InModuleScope build-operations {
            Mock Ensure-Directory {}
            Mock Write-BuildMessage {}
            Mock Get-InstalledCompilerVersion { $null }
            Mock Get-LatestCompilerPath { 'X:\s\alc\alc.exe' }
            Mock Get-ToolCommandPath { 'X:\s\al.exe' }
            Mock dotnet { $global:LASTEXITCODE = 1; 'boom' }

            { Install-ALCompilerChannel -PackageId 'pkg' -ToolPathRoot 'X:\s' } |
                Should -Throw -ExpectedMessage '*dotnet tool install (stable) failed*'
        }
    }

    It 'throws when alc cannot be found after a reported-successful install' {
        InModuleScope build-operations {
            Mock Ensure-Directory {}
            Mock Write-BuildMessage {}
            Mock Get-InstalledCompilerVersion { '17.0.0.0' }
            Mock Get-LatestCompilerPath { $null }
            Mock Get-ToolCommandPath { 'X:\s\al.exe' }
            Mock dotnet { $global:LASTEXITCODE = 0 }

            { Install-ALCompilerChannel -PackageId 'pkg' -ToolPathRoot 'X:\s' } |
                Should -Throw -ExpectedMessage '*alc*not found*'
        }
    }
}
