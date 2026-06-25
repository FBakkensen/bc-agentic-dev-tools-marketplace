#requires -Version 7.2

<#
.SYNOPSIS
    AL Build Operations Module

.DESCRIPTION
    Core build operations for AL/Business Central projects including:
    - Compiler installation and management
    - Symbol package downloading
    - AL project compilation
    - App publishing to BC containers
    - Test execution

.NOTES
    Import this module alongside common.psm1 for full functionality.
    All functions use Write-BuildMessage for consistent output.
#>

Set-StrictMode -Version Latest

# =============================================================================
# Configuration Loading
# =============================================================================

function Get-BuildConfig {
    <#
    .SYNOPSIS
        Load build configuration with three-tier resolution
    .DESCRIPTION
        Priority: 1. Parameter overrides → 2. Environment variables → 3. Config file defaults
    .PARAMETER Overrides
        Hashtable of parameter overrides
    .OUTPUTS
        PSCustomObject with all configuration values
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Overrides = @{}
    )

    # Find git repo root
    function Get-GitRepoRoot {
        try {
            $root = & git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and $root) {
                if ($IsWindows -or $env:OS -match 'Windows') {
                    $root = $root -replace '/', '\'
                }
                return $root
            }
        } catch { }
        return $null
    }

    # Load config ONLY from project root (plugin config is template only)
    $repoRoot = Get-GitRepoRoot
    $configPath = if ($repoRoot) { Join-Path $repoRoot 'al-build.json' } else { $null }

    $defaults = @{}
    if ($configPath -and (Test-Path -LiteralPath $configPath)) {
        try {
            $defaults = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
            Write-BuildMessage -Type Detail -Message "Loaded config: $configPath"
        } catch {
            Write-BuildMessage -Type Error -Message "Failed to load al-build.json: $($_.Exception.Message)"
            throw
        }
    } else {
        $configLocation = if ($configPath) { $configPath } else { 'repo root (not in git repo)' }
        Write-BuildMessage -Type Error -Message "al-build.json not found at: $configLocation. Run SessionStart or copy from plugin template."
        throw "Config file required. Expected at: $configLocation"
    }

    # Helper function for three-tier resolution
    function Resolve-Value {
        param([string]$Key, [string]$EnvVar, $Default)
        if ($Overrides.ContainsKey($Key) -and $null -ne $Overrides[$Key]) { return $Overrides[$Key] }
        $envVal = [Environment]::GetEnvironmentVariable($EnvVar)
        if ($null -ne $envVal) { return $envVal }
        if ($defaults.ContainsKey($Key) -and $null -ne $defaults[$Key]) { return $defaults[$Key] }
        return $Default
    }

    # Resolve all configuration values
    $appDir = Resolve-Value 'appDir' 'ALBT_APP_DIR' 'app'

    # Resolve testApps array
    $testAppsRaw = if ($defaults.ContainsKey('testApps') -and $defaults['testApps'] -is [System.Collections.IEnumerable] -and $defaults['testApps'] -isnot [string]) {
        @($defaults['testApps'])
    } else {
        @('test')
    }

    # Resolve to absolute paths if relative
    $workspaceRoot = (Get-Location).Path
    if (-not [System.IO.Path]::IsPathRooted($appDir)) {
        $appDir = Join-Path $workspaceRoot $appDir
    }

    $testApps = @()
    foreach ($testAppDir in $testAppsRaw) {
        if (-not [System.IO.Path]::IsPathRooted($testAppDir)) {
            $testApps += Join-Path $workspaceRoot $testAppDir
        } else {
            $testApps += $testAppDir
        }
    }

    # Always derive container name from git branch (no env var caching)
    try {
        $containerName = Get-BCAgentContainerName
    } catch {
        $containerName = 'bctest'
    }

    # Helper for nested container config values
    function Resolve-ContainerValue {
        param([string]$Key, [string]$EnvVar, $Default)
        if ($Overrides.ContainsKey($Key) -and $null -ne $Overrides[$Key]) { return $Overrides[$Key] }
        $envVal = [Environment]::GetEnvironmentVariable($EnvVar)
        if ($null -ne $envVal) { return $envVal }
        if ($defaults.ContainsKey('container') -and $defaults['container'] -is [hashtable]) {
            $container = $defaults['container']
            if ($container.ContainsKey($Key) -and $null -ne $container[$Key]) { return $container[$Key] }
        }
        return $Default
    }

    # Helper for nested breakingChange config values
    function Resolve-BreakingChangeValue {
        param([string]$Key, [string]$EnvVar, $Default)
        if ($Overrides.ContainsKey($Key) -and $null -ne $Overrides[$Key]) { return $Overrides[$Key] }
        $envVal = [Environment]::GetEnvironmentVariable($EnvVar)
        if ($null -ne $envVal) { return $envVal }
        if ($defaults.ContainsKey('breakingChange') -and $defaults['breakingChange'] -is [hashtable]) {
            $breakingChange = $defaults['breakingChange']
            if ($breakingChange.ContainsKey($Key) -and $null -ne $breakingChange[$Key]) { return $breakingChange[$Key] }
        }
        return $Default
    }

    # Resolve unitTestApp (single string, empty = disabled)
    $unitTestAppRaw = Resolve-Value 'unitTestApp' 'ALBT_UNIT_TEST_APP' ''
    $unitTestApp = ''
    if ($unitTestAppRaw -and $unitTestAppRaw -ne '') {
        if (-not [System.IO.Path]::IsPathRooted($unitTestAppRaw)) {
            $unitTestApp = Join-Path $workspaceRoot $unitTestAppRaw
        } else {
            $unitTestApp = $unitTestAppRaw
        }
    }

    $config = [PSCustomObject]@{
        AppDir                              = $appDir
        TestApps                            = $testApps
        UnitTestApp                         = $unitTestApp
        UnitTestInitEvents                  = ConvertTo-Boolean (Resolve-Value 'unitTestInitEvents' 'ALBT_UNIT_TEST_INIT_EVENTS' $false)
        WarnAsError                         = Resolve-Value 'warnAsError' 'WARN_AS_ERROR' $false
        RulesetPath                         = Resolve-Value 'rulesetPath' 'RULESET_PATH' 'al.ruleset.json'
        ServerInstance                      = Resolve-Value 'serverInstance' 'ALBT_BC_SERVER_INSTANCE' 'BC'
        ContainerName                       = $containerName
        ServerUrl                           = "http://$containerName"
        ContainerUsername                   = Resolve-ContainerValue 'username' 'ALBT_BC_CONTAINER_USERNAME' 'admin'
        ContainerPassword                   = Resolve-ContainerValue 'password' 'ALBT_BC_CONTAINER_PASSWORD' 'P@ssw0rd'
        ContainerAuth                       = Resolve-ContainerValue 'auth' 'ALBT_BC_CONTAINER_AUTH' 'UserPassword'
        ArtifactCountry                     = Resolve-ContainerValue 'artifactCountry' 'ALBT_BC_ARTIFACT_COUNTRY' 'w1'
        ArtifactSelect                      = Resolve-ContainerValue 'artifactSelect' 'ALBT_BC_ARTIFACT_SELECT' 'Latest'
        GoldenContainerName                 = Resolve-ContainerValue 'name' 'ALBT_BC_GOLDEN_CONTAINER_NAME' 'bctest'
        ImageName                           = Resolve-ContainerValue 'imageName' 'ALBT_BC_IMAGE_NAME' 'bctest:snapshot'
        MemoryLimit                         = Resolve-ContainerValue 'memoryLimit' 'ALBT_BC_MEMORY_LIMIT' '8g'
        Tenant                              = Resolve-Value 'tenant' 'ALBT_BC_TENANT' 'default'
        ValidateCurrent                     = Resolve-Value 'validateCurrent' 'ALBT_VALIDATE_CURRENT' '1'
        ApplicationInsightsConnectionString = Resolve-Value 'applicationInsightsConnectionString' 'ALBT_APPLICATION_INSIGHTS_CONNECTION_STRING' ''
        BreakingChangeEnabled               = ConvertTo-Boolean (Resolve-BreakingChangeValue 'enabled' 'ALBT_BREAKING_CHANGE_ENABLED' $false)
        BaselinePackageCachePath            = Resolve-BreakingChangeValue 'baselinePackageCachePath' 'ALBT_BASELINE_CACHE_PATH' '.output/baseline-cache'
    }

    return $config
}

function Get-CompileTargets {
    <#
    .SYNOPSIS
        Resolve which apps test.ps1 compiles after the main app, in order.
    .DESCRIPTION
        The main app is compiled separately (test.ps1 Step 1) in every mode, so
        it is not in this list. This returns the secondary compile targets —
        every test app, then the unit-test app — each carrying the Role used to
        name its build step ('test' or 'unit'). Compilation runs the analyzer
        gate (alc /analyzer:) on the host and happens in every mode:
        -UnitTestOnly skips the container publish/run, not the compile. The
        unit-test app is included so its code goes through the analyzer gate (AL
        Runner compiles it internally too, but without /analyzer: args); it is
        omitted here when it is also a test app, to avoid compiling it twice.
    .PARAMETER Config
        Build configuration object from Get-BuildConfig.
    .PARAMETER UnitTestOnly
        Accepted to pin the invariant that the target list is identical in both
        modes — every app compiles through the analyzer gate regardless. The
        return value does not depend on this switch; a test asserts the equality.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [switch]$UnitTestOnly
    )

    $targets = @()
    foreach ($testAppDir in $Config.TestApps) {
        $targets += [ordered]@{ AppDir = $testAppDir; Role = 'test' }
    }
    if ($Config.UnitTestApp -and ($Config.TestApps -notcontains $Config.UnitTestApp)) {
        $targets += [ordered]@{ AppDir = $Config.UnitTestApp; Role = 'unit' }
    }
    return $targets
}

function Set-BuildEnvironment {
    <#
    .SYNOPSIS
        Export build configuration to environment variables
    .PARAMETER Config
        Build configuration object from Get-BuildConfig
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $env:ALBT_APP_DIR = $Config.AppDir
    $env:WARN_AS_ERROR = $Config.WarnAsError
    $env:RULESET_PATH = $Config.RulesetPath
    $env:ALBT_BC_SERVER_URL = $Config.ServerUrl
    $env:ALBT_BC_SERVER_INSTANCE = $Config.ServerInstance
    $env:ALBT_BC_CONTAINER_NAME = $Config.ContainerName
    $env:ALBT_BC_CONTAINER_USERNAME = $Config.ContainerUsername
    $env:ALBT_BC_CONTAINER_PASSWORD = $Config.ContainerPassword
    $env:ALBT_BC_CONTAINER_AUTH = $Config.ContainerAuth
    $env:ALBT_BC_ARTIFACT_COUNTRY = $Config.ArtifactCountry
    $env:ALBT_BC_ARTIFACT_SELECT = $Config.ArtifactSelect
    $env:ALBT_BC_GOLDEN_CONTAINER_NAME = $Config.GoldenContainerName
    $env:ALBT_BC_IMAGE_NAME = $Config.ImageName
    $env:ALBT_BC_MEMORY_LIMIT = $Config.MemoryLimit
    $env:ALBT_BC_TENANT = $Config.Tenant
    $env:ALBT_VALIDATE_CURRENT = $Config.ValidateCurrent
    $env:ALBT_APPLICATION_INSIGHTS_CONNECTION_STRING = $Config.ApplicationInsightsConnectionString
    $env:ALBT_BREAKING_CHANGE_ENABLED = $Config.BreakingChangeEnabled
    $env:ALBT_BASELINE_CACHE_PATH = $Config.BaselinePackageCachePath
}

# =============================================================================
# Compiler Operations
# =============================================================================

function Get-ToolPackageId {
    <#
    .SYNOPSIS
        Get platform-specific AL compiler NuGet package ID
    #>
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
        return 'microsoft.dynamics.businesscentral.development.tools'
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
        return 'microsoft.dynamics.businesscentral.development.tools.linux'
    }
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
        return 'microsoft.dynamics.businesscentral.development.tools.osx'
    }
    return 'microsoft.dynamics.businesscentral.development.tools'
}

function Get-ToolCommandPath {
    <#
    .SYNOPSIS
        Resolve the 'al' command shim inside a --tool-path install root.
    .DESCRIPTION
        A --tool-path install drops the command shim (al.exe on Windows, al on
        unix) at the root, alongside the .store tree. This is the executable the
        build invokes by full path — never the global 'al' on PATH.
    #>
    param([Parameter(Mandatory)][string]$ToolPathRoot)

    foreach ($name in @('al.exe', 'al')) {
        $candidate = Join-Path $ToolPathRoot $name
        if (Test-Path -LiteralPath $candidate) { return (Get-Item -LiteralPath $candidate).FullName }
    }
    return $null
}

function Install-ALCompilerChannel {
    <#
    .SYNOPSIS
        Install or refresh one AL compiler channel as a private --tool-path install.
    .DESCRIPTION
        Installs the compiler into its own tool-path root (never the global slot,
        which is the user's own). Refreshes to latest on every provision: updates an
        existing install, installs when absent. -Update forces a clean reinstall
        (uninstall + install). -Prerelease selects the prerelease NuGet channel.
        Returns the resolved version, major, tool-path root, command (al) path, and
        alc path.
    .PARAMETER PackageId
        Compiler NuGet package id.
    .PARAMETER ToolPathRoot
        Directory for this channel's --tool-path install.
    .PARAMETER Prerelease
        Install from the prerelease channel (dotnet's --prerelease).
    .PARAMETER Update
        Force a clean reinstall instead of an in-place update.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$ToolPathRoot,
        [switch]$Prerelease,
        [switch]$Update
    )

    $channelLabel = if ($Prerelease) { 'prerelease' } else { 'stable' }
    Ensure-Directory -Path $ToolPathRoot

    $existing = Get-InstalledCompilerVersion -PackageId $PackageId -ToolPath $ToolPathRoot
    $commonArgs = @('--tool-path', $ToolPathRoot)
    if ($Prerelease) { $commonArgs += '--prerelease' }

    if ($existing -and $Update) {
        Write-BuildMessage -Type Step -Message "Reinstalling $channelLabel AL compiler (clean)..."
        & dotnet tool uninstall --tool-path $ToolPathRoot $PackageId 2>&1 | Out-Null
        $action = 'install'
        $out = & dotnet tool install @commonArgs $PackageId 2>&1
    } elseif ($existing) {
        Write-BuildMessage -Type Step -Message "Updating $channelLabel AL compiler to latest..."
        $action = 'update'
        $out = & dotnet tool update @commonArgs $PackageId 2>&1
    } else {
        Write-BuildMessage -Type Step -Message "Installing $channelLabel AL compiler..."
        $action = 'install'
        $out = & dotnet tool install @commonArgs $PackageId 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet tool $action ($channelLabel) failed with exit code $LASTEXITCODE. Output: $($out -join [Environment]::NewLine)"
    }

    $version = Get-InstalledCompilerVersion -PackageId $PackageId -ToolPath $ToolPathRoot
    if (-not $version) {
        throw "$channelLabel AL compiler version not found after provisioning at $ToolPathRoot."
    }
    $alcPath = Get-LatestCompilerPath -PackageId $PackageId -ToolRoot $ToolPathRoot
    if (-not $alcPath) {
        throw "$channelLabel compiler executable (alc) not found under $ToolPathRoot after provisioning."
    }
    $commandPath = Get-ToolCommandPath -ToolPathRoot $ToolPathRoot
    if (-not $commandPath) {
        throw "$channelLabel compiler command (al) not found under $ToolPathRoot after provisioning."
    }

    $majorToken = ($version -split '\.')[0]
    $major = 0
    [void][int]::TryParse($majorToken, [ref]$major)

    Write-BuildMessage -Type Success -Message "$channelLabel AL compiler: $version (major $major)"
    return [pscustomobject]@{
        Channel     = $channelLabel
        Version     = $version
        Major       = $major
        Root        = $ToolPathRoot
        CommandPath = $commandPath
        AlcPath     = $alcPath
    }
}

function Get-RequiredRuntimeMajor {
    <#
    .SYNOPSIS
        Highest app.json runtime major across all of a build's apps.
    .DESCRIPTION
        Scans the main app, every test app, and the unit-test app; returns the max
        'runtime' major, or 0 when no app pins a runtime. One compiler compiles them
        all, so it must satisfy the most demanding app — an app at a runtime newer
        than the latest stable pulls the whole build onto the prerelease channel.
    #>
    param([Parameter(Mandatory)]$Config)

    $dirs = New-Object System.Collections.Generic.List[string]
    if ($Config.AppDir) { $dirs.Add([string]$Config.AppDir) }
    foreach ($t in @($Config.TestApps)) { if ($t) { $dirs.Add([string]$t) } }
    if ($Config.UnitTestApp) { $dirs.Add([string]$Config.UnitTestApp) }

    $max = 0
    foreach ($d in $dirs) {
        $m = Get-AppRuntimeMajor -AppDir $d
        if ($null -ne $m -and $m -gt $max) { $max = $m }
    }
    return $max
}

function Install-ALCompiler {
    <#
    .SYNOPSIS
        Provision al-build's two private side-by-side AL compilers.
    .DESCRIPTION
        Installs both the latest stable and the latest prerelease compiler into
        their own --tool-path roots under the tool cache, refreshing both to latest
        on every provision. The global dotnet tool is the user's own (LSP/MCP daily
        driver) and is deliberately NEVER installed, updated, or invoked here — the
        build picks stable vs prerelease per app.json runtime and invokes the chosen
        compiler by full path. ALCops is installed into each channel's Analyzers
        folder so lint coverage is identical whichever channel a build selects.
        A two-channel sentinel records the resolved versions, majors, and paths for
        the offline build-time channel decision (Get-LatestCompilerInfo).
    .PARAMETER Update
        Force a clean reinstall of both channels instead of an in-place update.
    #>
    [CmdletBinding()]
    param(
        [switch]$Update
    )

    Write-BuildHeader 'AL Compiler Provisioning'

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'dotnet CLI not found. Install .NET SDK from https://dotnet.microsoft.com/download'
    }

    $packageId = Get-ToolPackageId
    Write-BuildMessage -Type Detail -Message "Package: $packageId"

    $toolCacheRoot = Get-ToolCacheRoot
    $alCacheDir = Join-Path $toolCacheRoot 'al'
    Ensure-Directory -Path $alCacheDir

    $stableRoot = Join-Path $alCacheDir 'stable'
    $prereleaseRoot = Join-Path $alCacheDir 'prerelease'

    $stable = Install-ALCompilerChannel -PackageId $packageId -ToolPathRoot $stableRoot -Update:$Update
    $prerelease = Install-ALCompilerChannel -PackageId $packageId -ToolPathRoot $prereleaseRoot -Prerelease -Update:$Update

    # ALCops into each channel's Analyzers folder; built-in cops ship inside each compiler.
    Install-ALCops -CompilerDir (Split-Path -Parent $stable.AlcPath)
    Install-ALCops -CompilerDir (Split-Path -Parent $prerelease.AlcPath)

    $sentinel = [ordered]@{
        schemaVersion   = 2
        installedAt     = (Get-Date).ToString('o')
        stableMajor     = $stable.Major
        prereleaseMajor = $prerelease.Major
        channels        = [ordered]@{
            stable     = [ordered]@{
                root        = $stable.Root
                commandPath = $stable.CommandPath
                alcPath     = $stable.AlcPath
                version     = $stable.Version
            }
            prerelease = [ordered]@{
                root        = $prerelease.Root
                commandPath = $prerelease.CommandPath
                alcPath     = $prerelease.AlcPath
                version     = $prerelease.Version
            }
        }
    }
    $sentinelPath = Join-Path $alCacheDir 'sentinel.json'
    $sentinel | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $sentinelPath -Encoding UTF8

    Write-BuildMessage -Type Detail -Message "Sentinel saved: $sentinelPath"
    Write-BuildMessage -Type Success -Message "Stable $($stable.Version) (major $($stable.Major)) + prerelease $($prerelease.Version) (major $($prerelease.Major))"
    Write-BuildMessage -Type Success -Message "Compiler provisioning complete"
}

function Install-ALRunner {
    <#
    .SYNOPSIS
        Ensure the AL Runner tool is available
    .DESCRIPTION
        Installs BusinessCentral.AL.Runner as a global dotnet tool for containerless
        unit testing. Mirrors the Install-ALCompiler pattern.
    .PARAMETER Update
        Force update of an existing global tool.
    #>
    [CmdletBinding()]
    param(
        [switch]$Update
    )

    Write-BuildHeader 'AL Runner Provisioning'

    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'dotnet CLI not found. Install .NET SDK from https://dotnet.microsoft.com/download'
    }

    $packageId = 'MSDyn365BC.AL.Runner'
    $existing = Get-Command al-runner -ErrorAction SilentlyContinue

    if ($existing -and -not $Update) {
        Write-BuildMessage -Type Success -Message "AL Runner already installed: $($existing.Source)"
    } elseif ($existing -and $Update) {
        Write-BuildMessage -Type Step -Message "Updating AL Runner..."
        $updateOutput = & dotnet tool update --global $packageId 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet tool update failed for $packageId with exit code $LASTEXITCODE. Output: $($updateOutput -join [Environment]::NewLine)"
        }
        Write-BuildMessage -Type Success -Message "AL Runner updated"
    } else {
        Write-BuildMessage -Type Step -Message "Installing AL Runner..."
        $installOutput = & dotnet tool install --global $packageId 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet tool install failed for $packageId with exit code $LASTEXITCODE. Output: $($installOutput -join [Environment]::NewLine)"
        }
        Write-BuildMessage -Type Success -Message "AL Runner installed"
    }

    # Verify al-runner is on PATH after install
    $postInstall = Get-Command al-runner -ErrorAction SilentlyContinue
    if (-not $postInstall) {
        $dotnetToolsDir = Join-Path (if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }) '.dotnet' 'tools'
        if (Test-Path $dotnetToolsDir) {
            $env:PATH = "$dotnetToolsDir$([IO.Path]::PathSeparator)$env:PATH"
            Write-BuildMessage -Type Detail -Message "Added $dotnetToolsDir to PATH"
        }
        $postInstall = Get-Command al-runner -ErrorAction SilentlyContinue
        if (-not $postInstall) {
            throw "al-runner not found on PATH after installation. Ensure ~/.dotnet/tools is on your PATH."
        }
    }

    Write-BuildMessage -Type Detail -Message "Path: $($postInstall.Source)"
    Write-BuildMessage -Type Success -Message "AL Runner provisioning complete"
}

function Get-InstalledCompilerVersion {
    <#
    .SYNOPSIS
        Get currently installed AL compiler version from dotnet tools
    .PARAMETER PackageId
        NuGet package id to look up.
    .PARAMETER ToolPath
        When set, query a --tool-path install at this directory instead of the
        global tool store. al-build's compilers are tool-path installs (the global
        slot is the user's own, untouched), so the build path always passes this.
    #>
    param([string]$PackageId, [string]$ToolPath)

    try {
        $listArgs = if ($ToolPath) { @('tool', 'list', '--tool-path', $ToolPath) } else { @('tool', 'list', '--global') }
        $output = & dotnet @listArgs 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { return $null }

        $packageIdLower = $PackageId.ToLowerInvariant()
        $lines = $output -split "`r?`n"
        foreach ($line in $lines) {
            if ($line -match '^Package Id' -or $line -match '^-+$' -or [string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            $parts = $line -split '\s+', 3
            if ($parts.Count -ge 2) {
                $idFromLine = $parts[0].Trim().ToLowerInvariant()
                if ($idFromLine -eq $packageIdLower) {
                    return $parts[1].Trim()
                }
            }
        }
        return $null
    } catch {
        return $null
    }
}

function Get-InstalledRuntimeMajors {
    <#
    .SYNOPSIS
        Major versions of installed Microsoft.NETCore.App runtimes
    #>
    try {
        $runtimes = & dotnet --list-runtimes 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }
        return @($runtimes |
            Where-Object { $_ -match '^Microsoft\.NETCore\.App (\d+)\.' } |
            ForEach-Object { [int]($_ -replace '^Microsoft\.NETCore\.App (\d+)\..*$', '$1') } |
            Sort-Object -Unique)
    } catch {
        return @()
    }
}

function Select-CompilerCandidate {
    <#
    .SYNOPSIS
        Pick the compiler executable among multi-target candidates.
    .DESCRIPTION
        The compiler dotnet tool ships one alc per target framework (tools/net8.0,
        tools/net10.0). Prefer candidates whose target framework has an installed
        .NET runtime, then the highest target framework, then the newest file.
        Deterministic, so the analyzers installed next to the compiler at provision
        time keep matching the compiler directory picked at build time. Runs per
        channel — each side-by-side install (stable / prerelease) has its own .store
        tree, so this picks within one channel's tool-path root, not across them.
    .PARAMETER Candidates
        Objects with FullName and LastWriteTime (FileInfo or equivalent).
    .PARAMETER InstalledRuntimeMajors
        Major versions of installed Microsoft.NETCore.App runtimes. Candidates whose
        path carries no target framework rank as runnable.
    #>
    param(
        [object[]]$Candidates,
        [int[]]$InstalledRuntimeMajors = @()
    )

    if (-not $Candidates -or $Candidates.Count -eq 0) { return $null }

    $ranked = foreach ($item in $Candidates) {
        $tfmMajor = 0
        if ($item.FullName -match '[\\/]tools[\\/]net(\d+)\.\d+[\\/]') {
            $tfmMajor = [int]$matches[1]
        }
        [pscustomobject]@{
            Item       = $item
            TfmMajor   = $tfmMajor
            HasRuntime = ($tfmMajor -eq 0) -or ($InstalledRuntimeMajors -contains $tfmMajor)
        }
    }

    $chosen = $ranked |
        Sort-Object -Property @{Expression = 'HasRuntime'; Descending = $true },
                              @{Expression = 'TfmMajor'; Descending = $true },
                              @{Expression = { $_.Item.LastWriteTime }; Descending = $true } |
        Select-Object -First 1
    return $chosen.Item
}

function Get-LatestCompilerPath {
    <#
    .SYNOPSIS
        Find the AL compiler executable (alc) in a dotnet tool store
    .PARAMETER PackageId
        Compiler NuGet package id.
    .PARAMETER ToolRoot
        Root of a --tool-path install (contains the '.store' tree). When omitted,
        the global ~/.dotnet/tools store is searched. al-build provisions its
        compilers under --tool-path roots, so the install/build paths pass this.
    #>
    param(
        [string]$PackageId,
        [string]$ToolRoot
    )

    if ($ToolRoot) {
        $storeRoot = Join-Path $ToolRoot '.store'
    } else {
        $userHome = $env:HOME
        if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
        $globalToolsRoot = Join-Path $userHome '.dotnet' 'tools'
        $storeRoot = Join-Path $globalToolsRoot '.store'
    }

    if (-not (Test-Path -LiteralPath $storeRoot)) { return $null }

    $packageDirName = $PackageId.ToLower()
    $packageRoot = Join-Path $storeRoot $packageDirName

    if (-not (Test-Path -LiteralPath $packageRoot)) { return $null }

    $toolExecutableNames = @('alc.exe', 'alc')
    $items = Get-ChildItem -Path $packageRoot -Recurse -File -Depth 8 -ErrorAction SilentlyContinue |
        Where-Object { $toolExecutableNames -contains $_.Name }

    $candidate = Select-CompilerCandidate -Candidates @($items) -InstalledRuntimeMajors (Get-InstalledRuntimeMajors)
    if ($candidate) { return $candidate.FullName }
    return $null
}

function Install-ALCops {
    <#
    .SYNOPSIS
        Download and install the ALCops analyzers into the compiler's Analyzers folder.
    .DESCRIPTION
        Uses the official '@alcops/core' CLI to detect the compiler's target framework
        and download the latest ALCops.Analyzers NuGet package (six cops plus the
        shared ALCops.Common.dll). Always installs the latest version and runs on
        every provision, so analyzers track upstream releases without pinning.
        Removes a legacy BusinessCentral.LinterCop.dll when present: ALCops shares
        diagnostic IDs with the discontinued LinterCop, so the two must never load
        together. Fails loudly; a missing analyzer must stop provisioning rather
        than silently degrade the build gate's lint coverage.
    .PARAMETER CompilerDir
        Directory containing alc.exe. DLLs land in '<CompilerDir>\Analyzers' where
        Get-EnabledAnalyzerPath resolves '${analyzerFolder}' entries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CompilerDir
    )

    Write-BuildMessage -Type Step -Message "Installing ALCops analyzers..."

    # Own the native-command error path: with $PSNativeCommandUseErrorActionPreference
    # on, a non-zero npx exit would throw at the call site and discard the captured
    # npm diagnostics. The explicit $LASTEXITCODE check below produces the richer error.
    $PSNativeCommandUseErrorActionPreference = $false

    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        throw "npx not found. ALCops analyzers are installed via the official '@alcops/core' CLI, which requires Node.js. Install Node >= 22 (any source: MSI, Volta, nvm) so 'npx' is on PATH, then re-run provision."
    }

    $analyzersDir = Join-Path $CompilerDir 'Analyzers'
    Ensure-Directory -Path $analyzersDir

    # ALCops shares diagnostic IDs with the discontinued LinterCop; never load both.
    $legacyDll = Join-Path $analyzersDir 'BusinessCentral.LinterCop.dll'
    if (Test-Path -LiteralPath $legacyDll) {
        Remove-Item -LiteralPath $legacyDll -Force
        Write-BuildMessage -Type Detail -Message "Removed legacy BusinessCentral.LinterCop.dll"
    }

    $npxArgs = @(
        '--yes', '@alcops/core@latest', 'download'
        '--output', $analyzersDir
        '--detect-using', $CompilerDir
        '--detect-from', 'compiler-path'
    )
    $output = & npx @npxArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "ALCops download failed (npx exit $LASTEXITCODE): $($output -join [Environment]::NewLine)"
    }

    $expectedDlls = @(
        'ALCops.ApplicationCop.dll'
        'ALCops.Common.dll'
        'ALCops.DocumentationCop.dll'
        'ALCops.FormattingCop.dll'
        'ALCops.LinterCop.dll'
        'ALCops.PlatformCop.dll'
        'ALCops.TestAutomationCop.dll'
    )
    $missing = @($expectedDlls | Where-Object { -not (Test-Path -LiteralPath (Join-Path $analyzersDir $_)) })
    if ($missing.Count -gt 0) {
        throw "ALCops installation incomplete; missing in '$analyzersDir': $($missing -join ', ')"
    }

    Write-BuildMessage -Type Success -Message "ALCops analyzers installed ($($expectedDlls.Count) DLLs)"
    Write-BuildMessage -Type Detail -Message "Folder: $analyzersDir"
}

# =============================================================================
# Symbol Operations
# =============================================================================

function Get-ALSymbols {
    <#
    .SYNOPSIS
        Download required Business Central symbol packages
    .PARAMETER AppDir
        Directory containing app.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppDir
    )

    Write-BuildHeader 'Symbol Package Provisioning'

    $appJsonPath = Get-AppJsonPath $AppDir
    if (-not $appJsonPath) {
        throw "app.json not found in '$AppDir'"
    }

    $appJson = Read-JsonFile -Path $appJsonPath
    Write-BuildMessage -Type Step -Message "Resolving symbols for: $($appJson.name)"
    Write-BuildMessage -Type Detail -Message "Version: $($appJson.version)"

    # Build package map from app.json dependencies
    $packageMap = Build-PackageMap -AppJson $appJson

    if ($packageMap.Count -eq 0) {
        Write-BuildMessage -Type Warning -Message "No dependencies found in app.json"
        return
    }

    Write-BuildMessage -Type Info -Message "$($packageMap.Count) packages to resolve"

    # Resolve cache directory
    $cacheInfo = Get-SymbolCacheInfo -AppJson $appJson -CreateIfMissing
    $cacheDir = $cacheInfo.CacheDir

    # Download each package from NuGet feeds
    $feeds = @(
        'https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/MSSymbols/nuget/v3/index.json',
        'https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/AppSourceSymbols/nuget/v3/index.json'
    )

    $downloaded = 0
    foreach ($packageId in $packageMap.Keys) {
        $minVersion = $packageMap[$packageId]
        $result = Get-SymbolPackage -PackageId $packageId -MinVersion $minVersion -CacheDir $cacheDir -Feeds $feeds
        if ($result) { $downloaded++ }
    }

    Write-BuildMessage -Type Success -Message "$downloaded packages downloaded/verified"
}

function Build-PackageMap {
    <#
    .SYNOPSIS
        Build package ID to version mapping from app.json
    #>
    param($AppJson)

    $map = [ordered]@{}

    if ($AppJson.application) {
        $map['Microsoft.Application.symbols'] = [string]$AppJson.application
    }

    if ($AppJson.dependencies) {
        foreach ($dep in $AppJson.dependencies) {
            if (-not $dep.publisher -or -not $dep.name -or -not $dep.id -or -not $dep.version) { continue }
            $publisher = ($dep.publisher -replace '\s+', '')
            $name = ($dep.name -replace '\s+', '')
            $appId = ($dep.id -replace '\s+', '')
            $packageId = "{0}.{1}.symbols.{2}" -f $publisher, $name, $appId
            $map[$packageId] = [string]$dep.version
        }
    }

    return $map
}

function Get-SymbolPackage {
    <#
    .SYNOPSIS
        Download a symbol package from NuGet feeds
    #>
    param(
        [string]$PackageId,
        [string]$MinVersion,
        [string]$CacheDir,
        [string[]]$Feeds
    )

    $cleanName = $PackageId -replace '\.symbols\.[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', '' -replace '\.symbols$', ''
    Write-BuildMessage -Type Detail -Message "Resolving: $cleanName (>= $MinVersion)"

    # Check if already cached
    $existingFiles = Get-ChildItem -Path $CacheDir -Filter "$($cleanName -replace '\.','-')*.app" -ErrorAction SilentlyContinue
    if ($existingFiles) {
        Write-BuildMessage -Type Detail -Message "  Already cached"
        return $true
    }

    # Try each feed
    foreach ($feed in $Feeds) {
        try {
            # Query NuGet for package versions
            $serviceIndex = Invoke-RestMethod -Uri $feed -UseBasicParsing -ErrorAction Stop
            $searchUrl = ($serviceIndex.resources | Where-Object { $_.'@type' -like '*SearchQueryService*' }).'@id' | Select-Object -First 1

            if (-not $searchUrl) { continue }

            $searchResult = Invoke-RestMethod -Uri "$searchUrl`?q=$PackageId&prerelease=true&take=1" -UseBasicParsing -ErrorAction Stop

            if ($searchResult.data -and $searchResult.data.Count -gt 0) {
                $package = $searchResult.data[0]
                $version = $package.version

                # Download the package
                $packageBaseUrl = ($serviceIndex.resources | Where-Object { $_.'@type' -eq 'PackageBaseAddress/3.0.0' }).'@id'
                $nupkgUrl = "$packageBaseUrl$($PackageId.ToLower())/$version/$($PackageId.ToLower()).$version.nupkg"

                $tempNupkg = Join-Path ([System.IO.Path]::GetTempPath()) "$PackageId.$version.nupkg"
                Invoke-WebRequest -Uri $nupkgUrl -OutFile $tempNupkg -UseBasicParsing -ErrorAction Stop

                # Extract .app file from nupkg
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zip = [System.IO.Compression.ZipFile]::OpenRead($tempNupkg)
                try {
                    $appEntry = $zip.Entries | Where-Object { $_.Name -like '*.app' } | Select-Object -First 1
                    if ($appEntry) {
                        $targetPath = Join-Path $CacheDir "$cleanName.$version.app"
                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($appEntry, $targetPath, $true)
                        Write-BuildMessage -Type Success -Message "  Downloaded: $version"
                        return $true
                    }
                } finally {
                    $zip.Dispose()
                    Remove-Item $tempNupkg -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {
            # Try next feed
            continue
        }
    }

    Write-BuildMessage -Type Warning -Message "  Not found in feeds"
    return $false
}

# =============================================================================
# Build Operations
# =============================================================================

function Invoke-ALBuild {
    <#
    .SYNOPSIS
        Compile an AL project
    .PARAMETER AppDir
        Directory containing app.json and AL source files
    .PARAMETER WarnAsError
        Treat warnings as errors (default: true)
    .PARAMETER RequiredRuntimeMajor
        Max app.json runtime major across the build, driving the stable-vs-prerelease
        compiler channel. Omit (-1) to self-compute from al-build.json; the gate
        (test.ps1) computes it once and passes it to every compile for consistency.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppDir,

        [switch]$WarnAsError = $true,

        [int]$RequiredRuntimeMajor = -1
    )

    Write-BuildHeader "AL Project Compilation"

    $appJson = Get-AppJsonObject $AppDir
    if (-not $appJson) {
        throw "app.json not found or invalid in '$AppDir'"
    }

    Write-BuildMessage -Type Step -Message "Building: $($appJson.name) v$($appJson.version)"

    # Resolve the build's required runtime once; self-compute for callers that don't
    # pass it (the channel is repo-wide, so every app compiles on the same compiler).
    if ($RequiredRuntimeMajor -lt 0) {
        $RequiredRuntimeMajor = Get-RequiredRuntimeMajor -Config (Get-BuildConfig)
    }

    # Pick the stable/prerelease compiler for the required runtime and invoke it by
    # full path — never the global 'al' (the user's own LSP/MCP tool).
    $compilerInfo = Get-LatestCompilerInfo -RequiredRuntimeMajor $RequiredRuntimeMajor
    $compilerRoot = $compilerInfo.CompilerDir

    Write-BuildMessage -Type Detail -Message "Compiler: $($compilerInfo.Version) [$($compilerInfo.Channel)]"

    # Get symbol cache
    $symbolCacheInfo = Get-SymbolCacheInfo -AppJson $appJson
    $packageCachePath = $symbolCacheInfo.CacheDir

    # Get analyzers (Get-EnabledAnalyzerPath throws when a requested analyzer is missing)
    $filteredAnalyzers = @(Get-EnabledAnalyzerPath -AppDir $AppDir -CompilerDir $compilerRoot)

    if ($filteredAnalyzers.Count -gt 0) {
        Write-BuildMessage -Type Detail -Message "Analyzers: $($filteredAnalyzers.Count) configured"
    }

    # Build output path
    $outputFullPath = Get-OutputPath $AppDir
    $outputFile = Split-Path -Path $outputFullPath -Leaf

    # Clean previous build
    if (Test-Path $outputFullPath) {
        Remove-Item $outputFullPath -Force
    }

    # Build compiler arguments (the 'al compile' wrapper from the selected tool-path install)
    $alcArgs = @(
        'compile'
        '/project:' + $AppDir
        '/packagecachepath:' + $packageCachePath
        '/out:' + $outputFullPath
    )

    # Add ruleset if exists
    $rulesetPath = $env:RULESET_PATH
    if ($rulesetPath) {
        $resolvedRuleset = if ([System.IO.Path]::IsPathRooted($rulesetPath)) { $rulesetPath } else { Join-Path (Get-Location).Path $rulesetPath }
        if (Test-Path $resolvedRuleset) {
            $alcArgs += '/ruleset:' + $resolvedRuleset
        }
    }

    # Add analyzers
    foreach ($analyzer in $filteredAnalyzers) {
        $alcArgs += '/analyzer:' + $analyzer
    }

    # Add warning as error
    if ($WarnAsError) {
        $alcArgs += '/warnaserror+'
    }

    Write-BuildMessage -Type Step -Message "Compiling..."

    # Execute the selected channel's compiler by full path (not the global 'al').
    & $compilerInfo.CommandPath @alcArgs

    if ($LASTEXITCODE -ne 0) {
        throw "AL compilation failed with exit code $LASTEXITCODE"
    }

    # Verify output
    if (-not (Test-Path $outputFullPath)) {
        throw "Build completed but output file not found: $outputFullPath"
    }

    $fileInfo = Get-Item $outputFullPath
    $sizeKB = [math]::Round($fileInfo.Length / 1KB, 1)
    Write-BuildMessage -Type Success -Message "Build complete: $outputFile ($sizeKB KB)"
}

# =============================================================================
# Publish Operations
# =============================================================================

function Invoke-ALPublish {
    <#
    .SYNOPSIS
        Publish an AL app to a Business Central container
    .PARAMETER AppDir
        Directory containing the compiled .app file
    .PARAMETER Force
        Force republish even if app is unchanged
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppDir,

        [switch]$Force
    )

    $config = Get-BuildConfig
    $appJson = Get-AppJsonObject $AppDir
    if (-not $appJson) {
        throw "app.json not found in '$AppDir'"
    }

    Write-BuildHeader "App Publishing"
    Write-BuildMessage -Type Step -Message "Publishing: $($appJson.name) v$($appJson.version)"

    # Check if publish needed
    $needsPublish = Test-AppNeedsPublish -AppDir $AppDir -AppJson $appJson -ContainerName $config.ContainerName -Force:$Force
    if (-not $needsPublish) {
        Write-BuildMessage -Type Success -Message "App unchanged, skipping publish"
        return
    }

    # Get app file path
    $appFilePath = Get-OutputPath $AppDir
    if (-not (Test-Path -LiteralPath $appFilePath)) {
        throw "App file not found: $appFilePath. Build first."
    }

    # Import BcContainerHelper
    Import-BCContainerHelper

    # Get credentials
    $credential = Get-BCCredential -Username $config.ContainerUsername -Password $config.ContainerPassword

    try {
        Publish-BcContainerApp `
            -containerName $config.ContainerName `
            -appFile $appFilePath `
            -skipVerification `
            -sync `
            -install `
            -syncMode ForceSync `
            -useDevEndpoint `
            -credential $credential
    } catch {
        throw "Failed to publish app: $_"
    }

    # Save publish state
    Save-PublishState -AppDir $AppDir -AppJson $appJson -ContainerName $config.ContainerName

    Write-BuildMessage -Type Success -Message "App published successfully"
}

# =============================================================================
# Test Operations
# =============================================================================

function Get-XmlAttributeInt {
    param(
        [System.Xml.XmlElement]$Element,
        [string]$Name
    )
    $value = $Element.GetAttribute($Name)
    if ($value) { [int]$value } else { 0 }
}

function Get-JUnitTestCounts {
    <#
    .SYNOPSIS
        Parse test counts from a JUnit XML result file
    .DESCRIPTION
        Both result producers emit the same JUnit schema: the container via
        Run-TestsInBcContainer -JUnitResultFileName and AL Runner via --output-junit.
        One testsuite element per test codeunit; tests=/failures=/errors=/skipped=
        attributes carry the counts.
    .PARAMETER ResultFile
        Path to the JUnit XML result file
    .OUTPUTS
        PSCustomObject with testCodeunits, tests, testsPassed, testsFailed,
        testsSkipped. $null when the file is missing or unparseable — unknown
        counts are never reported as zeros.
    #>
    [CmdletBinding()]
    param(
        [string]$ResultFile
    )

    if (-not $ResultFile -or -not (Test-Path -LiteralPath $ResultFile)) {
        return $null
    }

    try {
        [xml]$doc = Get-Content -LiteralPath $ResultFile -Raw
        $suites = @($doc.SelectNodes('//testsuite'))

        $tests = 0
        $failed = 0
        $skipped = 0
        foreach ($suite in $suites) {
            $tests += Get-XmlAttributeInt -Element $suite -Name 'tests'
            $failed += (Get-XmlAttributeInt -Element $suite -Name 'failures') + (Get-XmlAttributeInt -Element $suite -Name 'errors')
            $skipped += Get-XmlAttributeInt -Element $suite -Name 'skipped'
        }

        return [PSCustomObject]@{
            testCodeunits = $suites.Count
            tests         = $tests
            testsPassed   = $tests - $failed - $skipped
            testsFailed   = $failed
            testsSkipped  = $skipped
        }
    } catch {
        Write-BuildMessage -Type Warning -Message "Could not parse test counts from ${ResultFile}: $_"
        return $null
    }
}

function Format-TestCountSummary {
    <#
    .SYNOPSIS
        Format a counts object as one unambiguous console line fragment
    .DESCRIPTION
        Keeps "tests" and "test codeunits" labeled and adjacent so a reader
        quoting any single line cannot transpose the two numbers.
    #>
    param(
        [Parameter(Mandatory)]
        $Counts
    )
    "$($Counts.tests) tests in $($Counts.testCodeunits) test codeunits - $($Counts.testsPassed) passed, $($Counts.testsFailed) failed, $($Counts.testsSkipped) skipped"
}

function Invoke-ALTest {
    <#
    .SYNOPSIS
        Run AL tests in a Business Central container
    .PARAMETER TestDir
        Directory containing the test app
    .PARAMETER OutputDir
        Directory to write test results (last.xml, telemetry.jsonl)
    .OUTPUTS
        PSCustomObject with Passed, Runner, AppName, TestDir, Counts, ResultFile, TelemetryFile properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TestDir,

        [Parameter(Mandatory)]
        [string]$OutputDir
    )

    $config = Get-BuildConfig

    $appJson = Get-AppJsonObject $TestDir
    if (-not $appJson) {
        throw "app.json not found in '$TestDir'"
    }

    Write-BuildHeader "AL Test Execution"
    Write-BuildMessage -Type Step -Message "Running tests: $($appJson.name)"

    # Setup output directory
    Ensure-Directory -Path $OutputDir

    Write-BuildMessage -Type Step -Message "Cleaning test results in $OutputDir"
    $localResultFiles = @(
        Join-Path $OutputDir 'last.xml'
        Join-Path $OutputDir 'telemetry.jsonl'
    )

    foreach ($localResultFile in $localResultFiles) {
        if (Test-Path -LiteralPath $localResultFile) {
            try {
                Remove-Item -LiteralPath $localResultFile -Force
                Write-BuildMessage -Type Detail -Message "Removed previous result: $localResultFile"
            } catch {
                Write-BuildMessage -Type Warning -Message "Failed to remove previous result: $localResultFile. $_"
            }
        }
    }

    # Import BcContainerHelper
    Import-BCContainerHelper

    # Get shared folder from container
    $sharedFolders = Get-BcContainerSharedFolders -containerName $config.ContainerName
    $sharedBaseFolder = $sharedFolders.Keys | Where-Object { $_ -like "*$($config.ContainerName)*" } | Select-Object -First 1
    if (-not $sharedBaseFolder) {
        $sharedBaseFolder = $sharedFolders.Keys | Where-Object { $_ -like '*ProgramData*' } | Select-Object -First 1
    }
    if (-not $sharedBaseFolder) {
        $sharedBaseFolder = $sharedFolders.Keys | Select-Object -First 1
    }
    if (-not $sharedBaseFolder) {
        throw "No shared folders found for container $($config.ContainerName)"
    }

    $sharedResultsPath = Join-Path $sharedBaseFolder 'TestResults'
    Ensure-Directory -Path $sharedResultsPath
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $sharedResultFile = Join-Path $sharedResultsPath "test-results-$timestamp.xml"

    # Clear telemetry before tests
    try {
        Clear-TestTelemetryLogs -ContainerName $config.ContainerName | Out-Null
    } catch {
        Write-BuildMessage -Type Warning -Message "Pre-test telemetry cleanup failed (non-fatal): $_"
    }

    # Get credentials
    $credential = Get-BCCredential -Username $config.ContainerUsername -Password $config.ContainerPassword

    # Build test parameters — JUnit result format, same schema AL Runner emits (one parser for both)
    $testParams = @{
        containerName         = $config.ContainerName
        tenant                = $config.Tenant
        credential            = $credential
        extensionId           = $appJson.id
        JUnitResultFileName   = $sharedResultFile
        returnTrueIfAllPassed = $true
    }

    # Run tests
    $testsPassed = Run-TestsInBcContainer @testParams

    # Copy results to output dir
    $resultFile = Join-Path $OutputDir 'last.xml'
    if (Test-Path -LiteralPath $sharedResultFile) {
        Copy-Item -LiteralPath $sharedResultFile -Destination $resultFile -Force
        Write-BuildMessage -Type Success -Message "Results saved: $resultFile"
    }

    # Merge and copy telemetry
    $telemetryFile = Join-Path $OutputDir 'telemetry.jsonl'
    try {
        Merge-TestTelemetryLogs -ContainerName $config.ContainerName | Out-Null
    } catch {
        Write-BuildMessage -Type Warning -Message "Telemetry consolidation failed (non-fatal): $_"
    }

    try {
        Copy-TestTelemetryLogs -SharedFolder $sharedBaseFolder -LocalResultsPath $OutputDir | Out-Null
    } catch {
        Write-BuildMessage -Type Warning -Message "Telemetry copy failed (non-fatal): $_"
    }

    # Parse authoritative counts from the JUnit result — never derived from console lines
    $counts = Get-JUnitTestCounts -ResultFile $resultFile

    # Return result object
    $result = [PSCustomObject]@{
        Passed        = [bool]$testsPassed
        Runner        = 'container'
        AppName       = $appJson.name
        TestDir       = $TestDir
        Counts        = $counts
        ResultFile    = $resultFile
        TelemetryFile = $telemetryFile
    }

    if ($testsPassed) {
        if ($counts) {
            Write-BuildMessage -Type Success -Message "container - $($appJson.name): $(Format-TestCountSummary $counts)"
        } else {
            Write-BuildMessage -Type Success -Message "All tests passed: $($appJson.name) (test counts unavailable - result XML missing)"
        }
    } else {
        if ($counts) {
            Write-BuildMessage -Type Error -Message "container - $($appJson.name): $(Format-TestCountSummary $counts). See results in $OutputDir"
        } else {
            Write-BuildMessage -Type Error -Message "Tests failed: $($appJson.name). See results in $OutputDir"
        }
    }

    return $result
}

function Invoke-ALRunnerTest {
    <#
    .SYNOPSIS
        Run AL unit tests using BusinessCentral.AL.Runner (no container required)
    .PARAMETER AppDir
        Directory containing the main app source
    .PARAMETER TestDir
        Directory containing the unit test app source
    .PARAMETER OutputDir
        Directory to write test results (al-runner.xml — last.xml belongs to the
        container run; separate files so neither runner overwrites the other)
    .PARAMETER InitEvents
        Fire BC lifecycle events (OnCompanyInitialize, OnInstallAppPerCompany) at startup
    .OUTPUTS
        PSCustomObject with Passed, Runner, AppName, TestDir, Counts, ResultFile, TelemetryFile properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppDir,

        [Parameter(Mandatory)]
        [string]$TestDir,

        [Parameter(Mandatory)]
        [string]$OutputDir,

        [switch]$InitEvents
    )

    # Guard: al-runner must be available
    $alRunner = Get-Command al-runner -ErrorAction SilentlyContinue
    if (-not $alRunner) {
        throw "al-runner not found on PATH. Run provision.ps1 to install it."
    }

    $appJson = Get-AppJsonObject $TestDir
    if (-not $appJson) {
        throw "app.json not found in '$TestDir'"
    }

    Write-BuildHeader 'AL Runner Unit Test'
    Write-BuildMessage -Type Step -Message "Running unit tests: $($appJson.name)"

    # Setup output directory and clean stale results.
    # AL Runner owns al-runner.xml; the container run owns last.xml in the same
    # directory — separate files so a full gate never overwrites the unit result.
    Ensure-Directory -Path $OutputDir
    $resultFile = Join-Path $OutputDir 'al-runner.xml'
    if (Test-Path -LiteralPath $resultFile) {
        Remove-Item -LiteralPath $resultFile -Force
        Write-BuildMessage -Type Detail -Message "Removed previous result: $resultFile"
    }

    # Resolve symbol package path for the test app
    $packageCachePath = $null
    try {
        $symbolCacheInfo = Get-SymbolCacheInfo -AppJson $appJson
        $packageCachePath = $symbolCacheInfo.CacheDir
    } catch {
        throw "Symbol cache not found for unit test app '$($appJson.name)'. Run provision.ps1 first. Error: $_"
    }

    # Build arguments
    $arguments = @(
        '--output-junit', $resultFile,
        '--strict',
        '--no-telemetry'
    )
    if ($InitEvents) {
        $arguments += '--init-events'
    }
    if ($packageCachePath) {
        $arguments += @('--packages', $packageCachePath)
    }
    $arguments += @($AppDir, $TestDir)

    Write-BuildMessage -Type Detail -Message "Command: al-runner $($arguments -join ' ')"

    # Run al-runner — pipe to Out-Host to avoid polluting the return pipeline
    & $alRunner.Source @arguments | Out-Host
    $exitCode = $LASTEXITCODE

    # Exit codes: 0 = all passed, 1 = test failures, 2 = runner limitations (--strict promotes to 1), 3 = compile error
    $testsPassed = $exitCode -eq 0

    # Parse authoritative counts from the JUnit result — never derived from console lines
    $counts = Get-JUnitTestCounts -ResultFile $resultFile

    $result = [PSCustomObject]@{
        Passed        = $testsPassed
        Runner        = 'al-runner'
        AppName       = $appJson.name
        TestDir       = $TestDir
        Counts        = $counts
        ResultFile    = if (Test-Path -LiteralPath $resultFile) { $resultFile } else { '' }
        TelemetryFile = ''
    }

    if ($testsPassed) {
        if ($counts) {
            Write-BuildMessage -Type Success -Message "al-runner - $($appJson.name): $(Format-TestCountSummary $counts)"
        } else {
            Write-BuildMessage -Type Success -Message "All unit tests passed: $($appJson.name) (test counts unavailable - result XML missing)"
        }
    } else {
        if ($counts) {
            Write-BuildMessage -Type Error -Message "al-runner - $($appJson.name): $(Format-TestCountSummary $counts) (exit $exitCode). See results in $OutputDir"
        } else {
            Write-BuildMessage -Type Error -Message "Unit tests failed (exit $exitCode): $($appJson.name). See results in $OutputDir"
        }
    }

    return $result
}

function Invoke-ALUnpublish {
    <#
    .SYNOPSIS
        Unpublish an AL app from a Business Central container
    .PARAMETER AppName
        Name of the app to unpublish
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppName
    )

    Write-BuildHeader "App Unpublishing"

    $config = Get-BuildConfig

    Import-BCContainerHelper

    # Check if app is installed
    Write-BuildMessage -Type Step -Message "Checking if app is installed: $AppName"
    try {
        $installedApp = Get-BcContainerAppInfo -containerName $config.ContainerName |
            Where-Object { $_.Name -eq $AppName }
    } catch {
        throw "Failed to check app installation: $_"
    }

    if (-not $installedApp) {
        Write-BuildMessage -Type Info -Message "App not installed, skipping unpublish"
        return
    }

    Write-BuildMessage -Type Detail -Message "App found - Version $($installedApp.Version)"

    # Unpublish the app
    Write-BuildMessage -Type Step -Message "Unpublishing: $AppName"
    try {
        Unpublish-BcContainerApp `
            -containerName $config.ContainerName `
            -name $AppName `
            -unInstall `
            -doNotSaveData `
            -doNotSaveSchema `
            -force
    } catch {
        throw "Failed to unpublish app: $_"
    }
    Write-BuildMessage -Type Success -Message "App unpublished"
}

function Copy-ALSymbolToCache {
    <#
    .SYNOPSIS
        Copy a built app to another app's symbol cache
    .PARAMETER SourceAppDir
        Directory containing the built app
    .PARAMETER TargetAppDir
        Directory of the app that needs the symbol
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourceAppDir,

        [Parameter(Mandatory)]
        [string]$TargetAppDir
    )

    Write-BuildHeader 'Local Symbol Provisioning'

    $sourceAppPath = Get-OutputPath $SourceAppDir
    if (-not (Test-Path -LiteralPath $sourceAppPath)) {
        throw "Source app not found: $sourceAppPath. Build first."
    }

    $targetAppJson = Get-AppJsonObject $TargetAppDir
    if (-not $targetAppJson) {
        throw "Target app.json not found in '$TargetAppDir'"
    }

    $targetCacheInfo = Get-SymbolCacheInfo -AppJson $targetAppJson
    $targetPath = Join-Path $targetCacheInfo.CacheDir (Split-Path -Leaf $sourceAppPath)

    Copy-Item -LiteralPath $sourceAppPath -Destination $targetPath -Force
    Write-BuildMessage -Type Success -Message "Symbol provisioned: $(Split-Path -Leaf $sourceAppPath)"
}

# =============================================================================
# Boolean Conversion
# =============================================================================

function ConvertTo-Boolean {
    <#
    .SYNOPSIS
        Convert various value types to boolean
    .DESCRIPTION
        Handles bool, numeric (1/0), and string ('true'/'false') values
    #>
    param($Value)
    if ($Value -is [bool]) { return $Value }
    if ($Value -eq 1 -or $Value -eq '1') { return $true }
    if ($Value -eq 0 -or $Value -eq '0') { return $false }
    if ($Value -is [string]) {
        if ($Value -ieq 'true') { return $true }
        if ($Value -ieq 'false') { return $false }
    }
    return [bool]$Value
}

# =============================================================================
# Breaking-Change Baseline
# =============================================================================

function Get-BaselineVersion {
    <#
    .SYNOPSIS
        Derive the baseline app version for AppSourceCop.
    .DESCRIPTION
        Prefers the trailing token of the .app filename (BcContainerHelper
        convention: <publisher>_<name>_<version>.app), falling back to the
        release tag (leading 'v' stripped). Returns $null when neither yields a
        valid 2- to 4-part version — the caller fails loud rather than write a
        bad baseline.
    .PARAMETER AppFileName
        The baseline .app file name (with or without the .app extension).
    .PARAMETER ReleaseTag
        The release tag to fall back to.
    #>
    param(
        [Parameter(Mandatory)][string]$AppFileName,
        [string]$ReleaseTag
    )
    $baseName = $AppFileName -replace '\.app$', ''
    $token = ($baseName -split '_')[-1]
    if ($token -match '^\d+(\.\d+){1,3}$') { return $token }
    $tag = $ReleaseTag -replace '^v', ''
    if ($tag -match '^\d+(\.\d+){1,3}$') { return $tag }
    return $null
}

function Set-AppSourceCopBaseline {
    <#
    .SYNOPSIS
        Point an AppSourceCop.json object at a baseline (version + cache path).
    .DESCRIPTION
        Mutates the PSCustomObject in place, preserving existing key order and
        single-element arrays (PSCustomObject + ConvertTo-Json round-trips both).
        Existing version/baselinePackageCachePath values are updated, not
        duplicated. Returns the object for chaining.
    .PARAMETER Object
        The AppSourceCop.json object (from ConvertFrom-Json).
    .PARAMETER Version
        Baseline version string.
    .PARAMETER CachePath
        baselinePackageCachePath value (relative to the app folder).
    #>
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$CachePath
    )
    foreach ($pair in @(@{ n = 'version'; v = $Version }, @{ n = 'baselinePackageCachePath'; v = $CachePath })) {
        if ($Object.PSObject.Properties[$pair.n]) { $Object.$($pair.n) = $pair.v }
        else { $Object | Add-Member -NotePropertyName $pair.n -NotePropertyValue $pair.v }
    }
    return $Object
}

function Clear-AppSourceCopBaseline {
    <#
    .SYNOPSIS
        Remove the baseline version so AppSourceCop stops breaking-change checks.
    .DESCRIPTION
        Drops the 'version' property (the switch that activates breaking-change
        detection per AS0003 docs), leaving affixes/countries/cache path intact.
        Used when no release exists — detection stays cleanly off, never a false
        green. Returns the object for chaining.
    .PARAMETER Object
        The AppSourceCop.json object (from ConvertFrom-Json).
    #>
    param([Parameter(Mandatory)]$Object)
    if ($Object.PSObject.Properties['version']) { $Object.PSObject.Properties.Remove('version') }
    return $Object
}

function Get-AlValidationVerdict {
    <#
    .SYNOPSIS
        Classify Run-AlValidation's returned result lines into a verdict.
    .DESCRIPTION
        Run-AlValidation (without -throwOnError) returns its accumulated
        $validationResult strings: AppSourceCop findings from Run-AlCops plus
        environment errors its internal catch tags with the prefix
        "Unexpected error while validating app". The two demand different
        responses — a finding stops for a human, an environment failure is
        fix-and-re-run — so the verdict splits them. Any finding outranks
        environment errors: a run that both found a break and hit an
        environment error is still a detected break.
    .PARAMETER ValidationResult
        The lines Run-AlValidation returned. Empty/blank lines are noise
        (Run-AlCops appends separators) and are ignored.
    #>
    param(
        [AllowEmptyCollection()][string[]]$ValidationResult = @()
    )
    $envErrorPattern = '^Unexpected error while validating app'
    $lines = @($ValidationResult | Where-Object { $_ -and $_.Trim() })
    $environmentErrors = @($lines | Where-Object { $_ -match $envErrorPattern })
    $findings = @($lines | Where-Object { $_ -notmatch $envErrorPattern })
    $verdict = if ($findings.Count -gt 0) { 'BreakingChange' }
    elseif ($environmentErrors.Count -gt 0) { 'EnvironmentError' }
    else { 'Passed' }
    return [PSCustomObject]@{
        Verdict           = $verdict
        Findings          = $findings
        EnvironmentErrors = $environmentErrors
    }
}

# =============================================================================
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    # Configuration
    'Get-BuildConfig'
    'Get-CompileTargets'
    'Set-BuildEnvironment'
    'ConvertTo-Boolean'

    # Breaking-change baseline
    'Get-BaselineVersion'
    'Set-AppSourceCopBaseline'
    'Clear-AppSourceCopBaseline'
    'Get-AlValidationVerdict'

    # Compiler
    'Get-ToolPackageId'
    'Install-ALCompiler'
    'Install-ALCompilerChannel'
    'Get-ToolCommandPath'
    'Get-RequiredRuntimeMajor'
    'Get-InstalledCompilerVersion'
    'Get-LatestCompilerPath'
    'Select-CompilerCandidate'
    'Install-ALCops'

    # Symbols
    'Get-ALSymbols'
    'Build-PackageMap'
    'Get-SymbolPackage'

    # Build
    'Invoke-ALBuild'

    # Publish
    'Invoke-ALPublish'
    'Invoke-ALUnpublish'

    # Test
    'Invoke-ALTest'
    'Invoke-ALRunnerTest'
    'Get-JUnitTestCounts'
    'Format-TestCountSummary'

    # AL Runner
    'Install-ALRunner'

    # Local Symbols
    'Copy-ALSymbolToCache'
)
