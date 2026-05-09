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
        Tenant                              = Resolve-Value 'tenant' 'ALBT_BC_TENANT' 'default'
        ValidateCurrent                     = Resolve-Value 'validateCurrent' 'ALBT_VALIDATE_CURRENT' '1'
        ApplicationInsightsConnectionString = Resolve-Value 'applicationInsightsConnectionString' 'ALBT_APPLICATION_INSIGHTS_CONNECTION_STRING' ''
    }

    return $config
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
    $env:ALBT_BC_TENANT = $Config.Tenant
    $env:ALBT_VALIDATE_CURRENT = $Config.ValidateCurrent
    $env:ALBT_APPLICATION_INSIGHTS_CONNECTION_STRING = $Config.ApplicationInsightsConnectionString
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

function Install-ALCompiler {
    <#
    .SYNOPSIS
        Ensure the AL compiler is available
    .DESCRIPTION
        Reuses an existing AL compiler by default. Installs the compiler when missing,
        or updates it only when explicitly requested.
        Also downloads and installs LinterCop analyzer.
    .PARAMETER Update
        Force update of an existing global compiler tool.
    #>
    [CmdletBinding()]
    param(
        [switch]$Update
    )

    Write-BuildHeader 'AL Compiler Provisioning'

    # Validate dotnet availability
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw 'dotnet CLI not found. Install .NET SDK from https://dotnet.microsoft.com/download'
    }

    $packageId = Get-ToolPackageId
    Write-BuildMessage -Type Detail -Message "Package: $packageId"

    $version = Get-InstalledCompilerVersion -PackageId $packageId
    $alcPath = $null
    if ($version) {
        $alcPath = Get-LatestCompilerPath -PackageId $packageId
    }

    if ($version -and $alcPath -and -not $Update) {
        Write-BuildMessage -Type Success -Message "AL compiler already installed: $version"
        Write-BuildMessage -Type Detail -Message "Path: $alcPath"
    } elseif ($version -and $Update) {
        Write-BuildMessage -Type Step -Message "Updating AL compiler from NuGet..."
        $updateArgs = @('tool', 'update', '--global', $packageId, '--prerelease')
        $updateOutput = & dotnet @updateArgs 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "dotnet tool update failed with exit code $LASTEXITCODE. Output: $($updateOutput -join [Environment]::NewLine)"
        }

        $version = Get-InstalledCompilerVersion -PackageId $packageId
        $alcPath = Get-LatestCompilerPath -PackageId $packageId
        Write-BuildMessage -Type Success -Message "AL compiler updated: $version"
    } elseif (-not $version) {
        Write-BuildMessage -Type Step -Message "Installing AL compiler from NuGet..."
        $installArgs = @('tool', 'install', '--global', $packageId, '--prerelease')
        $installOutput = & dotnet @installArgs 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "dotnet tool install failed with exit code $LASTEXITCODE. Output: $($installOutput -join [Environment]::NewLine)"
        }

        $version = Get-InstalledCompilerVersion -PackageId $packageId
        $alcPath = Get-LatestCompilerPath -PackageId $packageId
        Write-BuildMessage -Type Success -Message "AL compiler installed: $version"
    }

    if (-not $version) {
        throw "AL compiler version not found after provisioning"
    }
    if (-not $alcPath) {
        throw "Compiler executable not found after provisioning. Run `provision.ps1 -UpdateCompiler` to repair the global tool installation."
    }

    # Save sentinel file
    $toolCacheRoot = Get-ToolCacheRoot
    $alCacheDir = Join-Path $toolCacheRoot 'al'
    Ensure-Directory -Path $alCacheDir

    $sentinel = @{
        compilerVersion  = $version
        toolPath         = $alcPath
        installationType = 'global-tool'
        installedAt      = (Get-Date).ToString('o')
    }
    $sentinelPath = Join-Path $alCacheDir 'sentinel.json'
    $sentinel | ConvertTo-Json | Set-Content -LiteralPath $sentinelPath -Encoding UTF8

    Write-BuildMessage -Type Detail -Message "Sentinel saved: $sentinelPath"

    # Install LinterCop
    Install-LinterCop -CompilerVersion $version -CompilerDir (Split-Path -Parent $alcPath)

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
    #>
    param([string]$PackageId)

    try {
        $output = & dotnet tool list --global 2>&1 | Out-String
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

function Get-LatestCompilerPath {
    <#
    .SYNOPSIS
        Find the AL compiler executable in global dotnet tools
    #>
    param([string]$PackageId)

    $userHome = $env:HOME
    if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
    $globalToolsRoot = Join-Path $userHome '.dotnet' 'tools'
    $storeRoot = Join-Path $globalToolsRoot '.store'

    if (-not (Test-Path -LiteralPath $storeRoot)) { return $null }

    $packageDirName = $PackageId.ToLower()
    $packageRoot = Join-Path $storeRoot $packageDirName

    if (-not (Test-Path -LiteralPath $packageRoot)) { return $null }

    $toolExecutableNames = @('alc.exe', 'alc')
    $items = Get-ChildItem -Path $packageRoot -Recurse -File -Depth 6 -ErrorAction SilentlyContinue |
        Where-Object { $toolExecutableNames -contains $_.Name }

    $candidate = $items | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
    if ($candidate) { return $candidate.FullName }
    return $null
}

function Get-LinterCopDownloadUrl {
    <#
    .SYNOPSIS
        Find the best matching LinterCop asset for the given compiler version.
    .DESCRIPTION
        Uses multi-tier fallback: exact version → major.minor → prerelease → stable.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CompilerVersion
    )

    $apiUrl = "https://api.github.com/repos/StefanMaron/BusinessCentral.LinterCop/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -ErrorAction Stop
    $assets = $release.assets

    # Parse version: 17.0.30.30339 or 17.0.1998613
    $versionParts = $CompilerVersion -split '\.'
    $major = $versionParts[0]
    $minor = $versionParts[1]
    $majorMinor = "$major.$minor"

    # Tier 1: Exact version match (e.g., BusinessCentral.LinterCop.AL-17.0.1998613.dll)
    $exactMatch = $assets | Where-Object { $_.name -eq "BusinessCentral.LinterCop.AL-$CompilerVersion.dll" } | Select-Object -First 1
    if ($exactMatch) {
        Write-BuildMessage -Type Detail -Message "LinterCop: Exact version match found"
        return $exactMatch.browser_download_url
    }

    # Tier 2: Major.minor match - find highest patch version for this major.minor
    # Pattern: BusinessCentral.LinterCop.AL-17.0.NNNNNN.dll (stable patch)
    $majorMinorPattern = "^BusinessCentral\.LinterCop\.AL-$major\.$minor\.(\d+)\.dll$"
    $majorMinorMatches = $assets | Where-Object { $_.name -match $majorMinorPattern } | Sort-Object {
        if ($_.name -match $majorMinorPattern) { [int]$matches[1] } else { 0 }
    } -Descending
    $bestMajorMinor = $majorMinorMatches | Select-Object -First 1
    if ($bestMajorMinor) {
        Write-BuildMessage -Type Detail -Message "LinterCop: Major.minor match found: $($bestMajorMinor.name)"
        return $bestMajorMinor.browser_download_url
    }

    # Tier 3: Beta/prerelease for this major.minor (e.g., 17.0.30.30339-beta)
    $betaPattern = "^BusinessCentral\.LinterCop\.AL-$major\.$minor\.\d+\.\d+(-beta)?\.dll$"
    $betaMatches = $assets | Where-Object { $_.name -match $betaPattern }
    $bestBeta = $betaMatches | Select-Object -First 1
    if ($bestBeta) {
        Write-BuildMessage -Type Detail -Message "LinterCop: Beta match found: $($bestBeta.name)"
        return $bestBeta.browser_download_url
    }

    # Tier 4: Generic prerelease (AL-PreRelease.dll)
    $preRelease = $assets | Where-Object { $_.name -eq "BusinessCentral.LinterCop.AL-PreRelease.dll" } | Select-Object -First 1
    if ($preRelease) {
        Write-BuildMessage -Type Detail -Message "LinterCop: Using prerelease version"
        return $preRelease.browser_download_url
    }

    # Tier 5: Stable fallback (BusinessCentral.LinterCop.dll)
    $stable = $assets | Where-Object { $_.name -eq "BusinessCentral.LinterCop.dll" } | Select-Object -First 1
    if ($stable) {
        Write-BuildMessage -Type Detail -Message "LinterCop: Using stable fallback"
        return $stable.browser_download_url
    }

    return $null
}

function Install-LinterCop {
    <#
    .SYNOPSIS
        Download and install LinterCop analyzer matching compiler version.
    .DESCRIPTION
        Downloads to Analyzers subfolder as BusinessCentral.LinterCop.dll so it's
        discovered by Get-EnabledAnalyzerPath when "LinterCop" is in al.codeAnalyzers.
    #>
    param(
        [string]$CompilerVersion,
        [string]$CompilerDir
    )

    Write-BuildMessage -Type Step -Message "Installing LinterCop analyzer..."

    # Target path: always use standard name for discovery
    $analyzersDir = Join-Path $CompilerDir 'Analyzers'
    Ensure-Directory -Path $analyzersDir
    $targetPath = Join-Path $analyzersDir 'BusinessCentral.LinterCop.dll'

    # Check if already installed
    if (Test-Path $targetPath) {
        Write-BuildMessage -Type Success -Message "LinterCop already installed"
        return
    }

    try {
        $downloadUrl = Get-LinterCopDownloadUrl -CompilerVersion $CompilerVersion
        if (-not $downloadUrl) {
            Write-BuildMessage -Type Warning -Message "No matching LinterCop version found for $CompilerVersion"
            return
        }

        # Download to temp file first, then move (atomic operation)
        $tempPath = Join-Path $analyzersDir "LinterCop.tmp.$([guid]::NewGuid().ToString('N')).dll"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing
            Move-Item -Path $tempPath -Destination $targetPath -Force
            Write-BuildMessage -Type Success -Message "LinterCop installed for compiler v$CompilerVersion"
        } finally {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force -ErrorAction SilentlyContinue }
        }
    } catch {
        Write-BuildMessage -Type Warning -Message "LinterCop installation failed: $($_.Exception.Message)"
    }
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
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppDir,

        [switch]$WarnAsError = $true
    )

    Write-BuildHeader "AL Project Compilation"

    $appJson = Get-AppJsonObject $AppDir
    if (-not $appJson) {
        throw "app.json not found or invalid in '$AppDir'"
    }

    Write-BuildMessage -Type Step -Message "Building: $($appJson.name) v$($appJson.version)"

    # Get compiler info (needed for version and analyzer paths)
    $compilerInfo = Get-LatestCompilerInfo
    $compilerRoot = Split-Path -Parent $compilerInfo.AlcPath

    Write-BuildMessage -Type Detail -Message "Compiler: $($compilerInfo.Version)"

    # Get symbol cache
    $symbolCacheInfo = Get-SymbolCacheInfo -AppJson $appJson
    $packageCachePath = $symbolCacheInfo.CacheDir

    # Get analyzers
    $analyzerPaths = Get-EnabledAnalyzerPath -AppDir $AppDir -CompilerDir $compilerRoot
    $filteredAnalyzers = @($analyzerPaths | Where-Object { $_ -and (Test-Path $_ -PathType Leaf) })

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

    # Build compiler arguments (using 'al compile' wrapper from dotnet global tool)
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

    # Execute compiler via 'al' dotnet global tool
    & al @alcArgs

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

function Invoke-ALTest {
    <#
    .SYNOPSIS
        Run AL tests in a Business Central container
    .PARAMETER TestDir
        Directory containing the test app
    .PARAMETER OutputDir
        Directory to write test results (last.xml, telemetry.jsonl)
    .OUTPUTS
        PSCustomObject with Passed, AppName, ResultFile, TelemetryFile properties
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

    # Build test parameters
    $testParams = @{
        containerName         = $config.ContainerName
        tenant                = $config.Tenant
        credential            = $credential
        extensionId           = $appJson.id
        XUnitResultFileName   = $sharedResultFile
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

    # Return result object
    $result = [PSCustomObject]@{
        Passed        = [bool]$testsPassed
        AppName       = $appJson.name
        TestDir       = $TestDir
        ResultFile    = $resultFile
        TelemetryFile = $telemetryFile
    }

    if ($testsPassed) {
        Write-BuildMessage -Type Success -Message "All tests passed: $($appJson.name)"
    } else {
        Write-BuildMessage -Type Error -Message "Tests failed: $($appJson.name). See results in $OutputDir"
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
        Directory to write test results (last.xml)
    .PARAMETER InitEvents
        Fire BC lifecycle events (OnCompanyInitialize, OnInstallAppPerCompany) at startup
    .OUTPUTS
        PSCustomObject with Passed, AppName, TestDir, ResultFile, TelemetryFile properties
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

    # Setup output directory and clean stale results
    Ensure-Directory -Path $OutputDir
    $resultFile = Join-Path $OutputDir 'last.xml'
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

    $result = [PSCustomObject]@{
        Passed        = $testsPassed
        AppName       = $appJson.name
        TestDir       = $TestDir
        ResultFile    = if (Test-Path -LiteralPath $resultFile) { $resultFile } else { '' }
        TelemetryFile = ''
    }

    if ($testsPassed) {
        Write-BuildMessage -Type Success -Message "All unit tests passed: $($appJson.name)"
    } else {
        Write-BuildMessage -Type Error -Message "Unit tests failed (exit $exitCode): $($appJson.name). See results in $OutputDir"
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
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    # Configuration
    'Get-BuildConfig'
    'Set-BuildEnvironment'
    'ConvertTo-Boolean'

    # Compiler
    'Get-ToolPackageId'
    'Install-ALCompiler'
    'Get-InstalledCompilerVersion'
    'Get-LatestCompilerPath'
    'Install-LinterCop'

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

    # AL Runner
    'Install-ALRunner'

    # Local Symbols
    'Copy-ALSymbolToCache'
)
