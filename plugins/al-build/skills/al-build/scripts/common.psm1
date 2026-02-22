#requires -Version 7.2

<#
.SYNOPSIS
    Common helper functions for al-build-remote skill.
    Uses the same provisioned compiler and symbol cache as local al-build.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
# Exit Codes
# =============================================================================

function Get-ExitCode {
    return @{
        Success      = 0
        GeneralError = 1
        Guard        = 2
        Analysis     = 3
        Contract     = 4
        Integration  = 5
        MissingTool  = 6
    }
}

# =============================================================================
# Output Formatting
# =============================================================================

function Write-BuildHeader {
    param([string]$Title)
    $line = '=' * 80
    Write-Host ""
    Write-Host $line
    Write-Host "  $Title"
    Write-Host $line
    Write-Host ""
}

function Write-BuildMessage {
    param(
        [ValidateSet('Info', 'Step', 'Detail', 'Success', 'Warning', 'Error')]
        [string]$Type,
        [string]$Message
    )

    $prefix = switch ($Type) {
        'Info'    { '[INFO]' }
        'Step'    { '[]' }
        'Detail'  { '    ' }
        'Success' { '[V]' }
        'Warning' { '[!]' }
        'Error'   { '[X]' }
    }

    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        default   { $null }
    }

    if ($color) {
        Write-Host "$prefix $Message" -ForegroundColor $color
    } else {
        Write-Host "$prefix $Message"
    }
}

# =============================================================================
# Timing
# =============================================================================

function Save-BuildTimingEntry {
    param(
        [string]$Task,
        [hashtable]$Steps,
        [double]$TotalSeconds
    )

    $repoRoot = Get-RepoRoot
    $logsDir = Join-Path $repoRoot '.output' 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }

    $timingFile = Join-Path $logsDir 'build-timing.jsonl'

    $entry = @{
        timestamp = Get-Date -Format 'yyyy-MM-dd HH.mm.ss'
        task = $Task
        steps = $Steps
        total = '{0:N1}' -f $TotalSeconds -replace ',', '.'
        totalSec = [math]::Round($TotalSeconds, 1)
    }

    $json = $entry | ConvertTo-Json -Compress
    Add-Content -Path $timingFile -Value $json
}

function Show-BuildTimingHistory {
    param([int]$Count = 5)

    $repoRoot = Get-RepoRoot
    $timingFile = Join-Path $repoRoot '.output' 'logs' 'build-timing.jsonl'

    if (-not (Test-Path $timingFile)) { return }

    Write-BuildHeader "Build Timing History (Last $Count Runs)"

    $lines = Get-Content $timingFile -Tail $Count
    foreach ($line in $lines) {
        try {
            $entry = $line | ConvertFrom-Json
            $stepsSummary = ($entry.steps.PSObject.Properties | Sort-Object { $_.Value } -Descending |
                ForEach-Object { "$($_.Name):$($_.Value)s" }) -join ' '
            $total = "0:{0:00}.{1}" -f [math]::Floor($entry.totalSec), [math]::Floor(($entry.totalSec % 1) * 10)
            Write-Host "$($entry.timestamp) | $($entry.task) | $total | $($stepsSummary.Substring(0, [Math]::Min(60, $stepsSummary.Length)))..."
        } catch { }
    }

    Write-Host ""
    Write-Host "Full history: .output/logs/build-timing.jsonl"
}

# =============================================================================
# Path Helpers
# =============================================================================

function Get-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if ($IsWindows) { $root = $root -replace '/', '\' }
    return $root
}

function ConvertTo-SafePathSegment {
    param([string]$Value)
    if (-not $Value) { return '_' }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars() + [char]':'
    $result = $Value
    foreach ($char in $invalid) {
        $pattern = [regex]::Escape([string]$char)
        $result = $result -replace $pattern, '_'
    }
    $result = $result -replace '\s+', '_'
    if ([string]::IsNullOrWhiteSpace($result)) { return '_' }
    return $result
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -ItemType Directory -Path $Path -Force)
    }
}

function New-TemporaryDirectory {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    $base = [System.IO.Path]::GetTempPath()
    $name = 'bc-temp-' + [System.Guid]::NewGuid().ToString('N')
    $path = Join-Path -Path $base -ChildPath $name
    if (-not $PSCmdlet -or $PSCmdlet.ShouldProcess($path, 'Create temporary directory')) {
        Ensure-Directory -Path $path
    }
    return $path
}

function Expand-FullPath {
    param([string]$Path)
    if (-not $Path) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ($expanded.StartsWith('~')) {
        $userHome = $env:HOME
        if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
        if ($userHome) {
            $suffix = $expanded.Substring(1).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            if ([string]::IsNullOrWhiteSpace($suffix)) { $expanded = $userHome }
            else { $expanded = Join-Path -Path $userHome -ChildPath $suffix }
        }
    }
    try { return (Resolve-Path -LiteralPath $expanded -ErrorAction Stop).ProviderPath }
    catch { return [System.IO.Path]::GetFullPath($expanded) }
}

function Get-AppJsonPath {
    param([string]$AppDir)
    $p1 = Join-Path -Path $AppDir -ChildPath 'app.json'
    $p2 = 'app.json'
    if (Test-Path $p1) { return $p1 }
    elseif (Test-Path $p2) { return $p2 }
    else { return $null }
}

function Get-SettingsJsonPath {
    param([string]$AppDir)
    $p1 = Join-Path -Path $AppDir -ChildPath '.vscode/settings.json'
    if (Test-Path $p1) { return $p1 }
    $p2 = '.vscode/settings.json'
    if (Test-Path $p2) { return $p2 }
    return $null
}

function Read-JsonFile {
    param([string]$Path)
    try { return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
    catch { throw "Failed to parse JSON from ${Path}: $($_.Exception.Message)" }
}

function Test-JsonProperty {
    param(
        [Parameter(Mandatory=$true)]$JsonObject,
        [Parameter(Mandatory=$true)][string]$PropertyName
    )
    if ($null -eq $JsonObject) { return $false }
    return $JsonObject.PSObject.Properties.Name -contains $PropertyName
}

# =============================================================================
# Tool Cache (same as local al-build)
# =============================================================================

function Get-ToolCacheRoot {
    $override = $env:ALBT_TOOL_CACHE_ROOT
    if ($override) { return Expand-FullPath -Path $override }

    $userHome = $env:HOME
    if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
    if (-not $userHome) { throw 'Unable to determine home directory for tool cache.' }

    return Join-Path -Path $userHome -ChildPath '.bc-tool-cache'
}

function Get-SymbolCacheRoot {
    $override = $env:ALBT_SYMBOL_CACHE_ROOT
    if ($override) { return $override }

    $userHome = $env:HOME
    if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
    if (-not $userHome) { throw 'Unable to determine home directory for symbol cache.' }

    return Join-Path -Path $userHome -ChildPath '.bc-symbol-cache'
}

function Get-LatestCompilerInfo {
    $toolCacheRoot = Get-ToolCacheRoot
    $alCacheDir = Join-Path -Path $toolCacheRoot -ChildPath 'al'
    $sentinelPath = Join-Path -Path $alCacheDir -ChildPath 'sentinel.json'

    if (-not (Test-Path -LiteralPath $sentinelPath)) {
        throw "Compiler not provisioned. Sentinel not found at: $sentinelPath. Run local al-build provision.ps1 first."
    }

    $sentinel = Get-Content -LiteralPath $sentinelPath -Raw | ConvertFrom-Json
    $compilerVersion = $sentinel.compilerVersion
    $toolPath = $sentinel.toolPath

    if (-not $toolPath -or -not (Test-Path -LiteralPath $toolPath)) {
        throw "AL compiler not found. Run local al-build provision.ps1 first."
    }

    return [pscustomobject]@{
        AlcPath      = $toolPath
        Version      = $compilerVersion
        SentinelPath = $sentinelPath
    }
}

function Get-SymbolCacheInfo {
    param(
        $AppJson
    )

    if (-not $AppJson) {
        throw 'app.json is required to resolve the symbol cache.'
    }

    $cacheRoot = Get-SymbolCacheRoot
    $publisherDir = Join-Path -Path $cacheRoot -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.publisher)
    $appDirPath = Join-Path -Path $publisherDir -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.name)
    $cacheDir = Join-Path -Path $appDirPath -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.id)

    if (-not (Test-Path -LiteralPath $cacheDir)) {
        throw "Symbol cache not found at $cacheDir. Run local al-build provision.ps1 first."
    }

    return [pscustomobject]@{
        CacheDir = (Get-Item -LiteralPath $cacheDir).FullName
    }
}

# =============================================================================
# Configuration
# =============================================================================

function Get-RemoteContainerName {
    <#
    .SYNOPSIS
        Generate container name from repo hash + branch (bc-{hash}-{branch})
    #>

    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $branch) {
        throw "Could not detect git branch. Run from within a git repository."
    }

    $remoteUrl = git remote get-url origin 2>$null
    if (-not $remoteUrl) {
        throw "Could not get git remote URL. Ensure 'origin' remote is configured."
    }

    # Extract org/repo from URL
    $repoPath = $null
    if ($remoteUrl -match 'github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$') {
        $repoPath = $Matches[1]
    } elseif ($remoteUrl -match 'dev\.azure\.com/([^/]+)/([^/]+)/_git/([^/]+)') {
        $repoPath = "$($Matches[1])/$($Matches[3])"
    } else {
        $parts = $remoteUrl -replace '\.git$', '' -split '[:/]'
        if ($parts.Count -ge 2) {
            $repoPath = "$($parts[-2])/$($parts[-1])"
        } else {
            throw "Could not parse repository path from URL: $remoteUrl"
        }
    }

    # Compute 8-character MD5 hash
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($repoPath.ToLower())
    $hash = $md5.ComputeHash($bytes)
    $repoHash = [System.BitConverter]::ToString($hash).Replace('-', '').Substring(0, 8).ToLower()

    # Sanitize branch name
    $sanitizedBranch = $branch -replace '[/\\]', '-' -replace '[^\w-]', ''

    # Format: bc-{hash}-{branch} (max 63 chars for Docker)
    $containerName = "bc-$repoHash-$sanitizedBranch"
    if ($containerName.Length -gt 63) {
        $containerName = $containerName.Substring(0, 63)
    }

    return $containerName
}

function Get-RemoteBuildConfig {
    $repoRoot = Get-RepoRoot
    $configPath = Join-Path $repoRoot 'al-build.json'

    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "al-build.json not found at: $configPath"
    }

    $json = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
    $containerName = Get-RemoteContainerName

    # Resolve paths
    $appDir = $json.appDir ?? 'app'
    $testDir = $json.testDir ?? 'test'
    if (-not [System.IO.Path]::IsPathRooted($appDir)) {
        $appDir = Join-Path $repoRoot $appDir
    }
    if (-not [System.IO.Path]::IsPathRooted($testDir)) {
        $testDir = Join-Path $repoRoot $testDir
    }

    # Remote config
    $remote = $json.remote
    if (-not $remote) {
        throw "al-build.json missing 'remote' section"
    }

    # Container config
    $container = $json.container ?? @{}

    return [PSCustomObject]@{
        RepoRoot          = $repoRoot
        AppDir            = $appDir
        TestDir           = $testDir
        ContainerName     = $containerName
        ContainerUsername = $container.username ?? 'admin'
        ContainerPassword = $container.password ?? 'P@ssw0rd'
        ImageName         = $container.imageName ?? 'acrgtmbcalbuild.azurecr.io/bctest:snapshot'
        Tenant            = $json.tenant ?? 'default'
        WarnAsError       = $json.warnAsError ?? $false
        VmHost            = $remote.vmHost
        VmUser            = $remote.vmUser
        AppStagingPath    = $remote.appStagingPath ?? 'C:/temp/apps'
        SharedBasePath    = $remote.sharedBasePath ?? 'C:/shared'
    }
}

# =============================================================================
# AL Build Functions (using same provisioned compiler as local)
# =============================================================================

function Get-AppJsonObject {
    param([string]$AppDir)
    $appJsonPath = Join-Path $AppDir 'app.json'
    if (-not (Test-Path $appJsonPath)) {
        throw "app.json not found in: $AppDir"
    }
    return Get-Content $appJsonPath -Raw | ConvertFrom-Json
}

function Get-OutputPath {
    param([string]$AppDir)
    $appJson = Get-AppJsonObject $AppDir
    $fileName = "$($appJson.publisher)_$($appJson.name)_$($appJson.version).app"
    return Join-Path $AppDir '.output' $fileName
}

function Copy-ALSymbolToCache {
    param(
        [string]$SourceAppDir,
        [string]$TargetAppDir
    )

    $sourceAppPath = Get-OutputPath $SourceAppDir
    if (-not (Test-Path $sourceAppPath)) {
        throw "Source app not found: $sourceAppPath"
    }

    $targetAppJson = Get-AppJsonObject $TargetAppDir
    if (-not $targetAppJson) {
        throw "Target app.json not found in '$TargetAppDir'"
    }

    $targetCacheInfo = Get-SymbolCacheInfo -AppJson $targetAppJson
    $targetPath = Join-Path $targetCacheInfo.CacheDir (Split-Path -Leaf $sourceAppPath)

    Copy-Item -Path $sourceAppPath -Destination $targetPath -Force

    Write-BuildMessage -Type Success -Message "Symbol provisioned: $(Split-Path -Leaf $sourceAppPath)"
}

# =============================================================================
# SSH/SCP Functions
# =============================================================================

function Invoke-RemoteCommand {
    param(
        [string]$VmHost,
        [string]$VmUser,
        [string]$Command,
        [switch]$ThrowOnError,
        [bool]$StreamOutput = $true
    )

    $sshArgs = @(
        "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes",
        "${VmUser}@${VmHost}",
        $Command
    )

    $outputLines = [System.Collections.Generic.List[string]]::new()
    & ssh @sshArgs 2>&1 | ForEach-Object {
        $line = $_.ToString()
        $outputLines.Add($line)
        if ($StreamOutput) {
            Write-Host $line
        }
    }
    $exitCode = $LASTEXITCODE

    if ($ThrowOnError -and $exitCode -ne 0) {
        throw "SSH command failed with exit code $exitCode : $($outputLines -join "`n")"
    }

    return @{
        Output = $outputLines.ToArray()
        ExitCode = $exitCode
    }
}

function Copy-FileToRemote {
    param(
        [string]$VmHost,
        [string]$VmUser,
        [string]$LocalPath,
        [string]$RemotePath
    )

    $scpResult = & scp -o StrictHostKeyChecking=no -o BatchMode=yes $LocalPath "${VmUser}@${VmHost}:${RemotePath}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SCP failed: $scpResult"
    }
}

function Copy-FileFromRemote {
    param(
        [string]$VmHost,
        [string]$VmUser,
        [string]$RemotePath,
        [string]$LocalPath
    )

    # Normalize path for SCP (Unix scp needs forward slashes)
    $normalizedPath = $RemotePath -replace '\\', '/'

    Write-Host "[DEBUG] SCP command: scp ${VmUser}@${VmHost}:$normalizedPath $LocalPath"

    $scpResult = & scp -o StrictHostKeyChecking=no -o BatchMode=yes "${VmUser}@${VmHost}:$normalizedPath" $LocalPath 2>&1
    $exitCode = $LASTEXITCODE

    Write-Host "[DEBUG] SCP exit code: $exitCode, result: $scpResult"

    return $exitCode -eq 0
}

# =============================================================================
# Business Central Integration
# =============================================================================

function Get-BCAgentContainerName {
    [CmdletBinding()]
    param()
    try {
        $branch = & git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $branch) {
            throw "Could not detect git branch name. Run from within a git repository."
        }
        $containerName = $branch -replace '[/\\]', '-' -replace '[^\w-]', ''
        if (-not $containerName) {
            throw "Derived container name is empty after sanitization (branch: $branch)."
        }
        return $containerName
    } catch {
        throw "Not in a git repository or git command failed: $($_.Exception.Message)"
    }
}

function Import-BCContainerHelper {
    [CmdletBinding()]
    param()
    if (Get-Module -Name BcContainerHelper) {
        Write-Verbose "BcContainerHelper already loaded, skipping import"
        return
    }
    if (Get-Module -Name BcContainerHelper -ListAvailable) {
        Import-Module BcContainerHelper -ArgumentList $true -DisableNameChecking -ErrorAction Stop
        Write-BuildMessage -Type Detail -Message "BcContainerHelper module loaded"
    } else {
        Write-BuildMessage -Type Error -Message "BcContainerHelper PowerShell module not found."
        throw "BcContainerHelper module is required for BC container operations."
    }
}

function Get-BCCredential {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [string]$Password
    )
    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential($Username, $securePassword)
}

function Get-EnabledAnalyzerPath {
    param(
        [string]$AppDir,
        [string]$CompilerDir
    )
    $settingsPath = Get-SettingsJsonPath $AppDir
    $dllMap = @{
        'CodeCop'               = 'Microsoft.Dynamics.Nav.CodeCop.dll'
        'UICop'                 = 'Microsoft.Dynamics.Nav.UICop.dll'
        'AppSourceCop'          = 'Microsoft.Dynamics.Nav.AppSourceCop.dll'
        'PerTenantExtensionCop' = 'Microsoft.Dynamics.Nav.PerTenantExtensionCop.dll'
        'LinterCop'             = 'BusinessCentral.LinterCop.dll'
    }
    $supported = $dllMap.Keys
    $enabled = @()

    if ($settingsPath -and (Test-Path -LiteralPath $settingsPath)) {
        try {
            $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
            if ($json -and ($json.PSObject.Properties.Match('al.codeAnalyzers').Count -gt 0) -and $json.'al.codeAnalyzers') {
                $enabled = @($json.'al.codeAnalyzers')
            }
        } catch { }
    }

    $dllPaths = New-Object System.Collections.Generic.List[string]
    if (-not $enabled -or $enabled.Count -eq 0) { return $dllPaths }

    $analyzersDir = $null
    if ($CompilerDir -and (Test-Path -LiteralPath $CompilerDir)) {
        $candidate = Join-Path -Path $CompilerDir -ChildPath 'Analyzers'
        if (Test-Path -LiteralPath $candidate) {
            $analyzersDir = (Get-Item -LiteralPath $candidate).FullName
        } else {
            $analyzersDir = (Get-Item -LiteralPath $CompilerDir).FullName
        }
    }

    function Add-AnalyzerPath {
        param([string]$Path)
        if (-not $Path) { return }
        if (Test-Path -LiteralPath $Path) {
            $full = (Get-Item -LiteralPath $Path).FullName
            if (-not $dllPaths.Contains($full)) {
                $dllPaths.Add($full) | Out-Null
            }
        }
    }

    foreach ($item in $enabled) {
        $raw = ($item | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }

        $name = $raw
        $varMatch = [regex]::Match($raw, '^\$\{([A-Za-z]+)\}$')
        if ($varMatch.Success) { $name = $varMatch.Groups[1].Value }
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        if ($supported -contains $name) {
            if ($analyzersDir -or $CompilerDir) {
                $dll = $dllMap[$name]
                $searchRoots = @()
                if ($analyzersDir) { $searchRoots += $analyzersDir }
                if ($CompilerDir -and ($searchRoots -notcontains $CompilerDir)) { $searchRoots += $CompilerDir }

                $found = $null
                foreach ($root in $searchRoots) {
                    if (-not (Test-Path -LiteralPath $root)) { continue }
                    $candidate = Get-ChildItem -Path $root -Recurse -Filter $dll -File -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($candidate) { $found = $candidate; break }
                }
                if ($found) { Add-AnalyzerPath -Path $found.FullName }
            }
        }

        # Support VS Code analyzerFolder references (e.g., ${analyzerFolder}BusinessCentral.LinterCop.dll)
        if ($raw -match '\.dll$') {
            $resolvedPath = $raw
            if ($raw -match '^(?i)\$\{analyzerFolder\}(.*)$') {
                if ($analyzersDir) {
                    $suffix = $Matches[1].TrimStart('\', '/')
                    $resolvedPath = if ($suffix) { Join-Path $analyzersDir $suffix } else { $analyzersDir }
                } else {
                    $resolvedPath = $null
                }
            } elseif ($raw -match '(?i)\$\{analyzerFolder\}') {
                if ($analyzersDir) {
                    $resolvedPath = [regex]::Replace(
                        $raw,
                        '\$\{analyzerFolder\}',
                        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $analyzersDir }
                    )
                } else {
                    $resolvedPath = $null
                }
            }
            if ($resolvedPath) {
                if (-not [System.IO.Path]::IsPathRooted($resolvedPath)) {
                    $resolvedPath = Join-Path $AppDir $resolvedPath
                }
                Add-AnalyzerPath -Path $resolvedPath
            }
        }
    }
    return $dllPaths
}

# =============================================================================
# Incremental Publish State Management
# =============================================================================

function Get-ContainerCreatedTime {
    param([string]$ContainerName)
    try {
        $json = docker inspect $ContainerName --format '{{.Created}}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $json) {
            return [DateTimeOffset]::Parse($json)
        }
    } catch { }
    return $null
}

function Get-PublishStatePath {
    param($AppJson, [string]$ContainerName)
    $cacheRoot = Get-SymbolCacheRoot
    $publisherDir = Join-Path -Path $cacheRoot -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.publisher)
    $appDirPath = Join-Path -Path $publisherDir -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.name)
    $cacheDir = Join-Path -Path $appDirPath -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.id)
    Ensure-Directory -Path $cacheDir
    $containerSafe = ConvertTo-SafePathSegment -Value $ContainerName
    return Join-Path -Path $cacheDir -ChildPath "publish-state.$containerSafe.json"
}

function Get-DirectoryHash {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return "" }
    $files = Get-ChildItem -Path $Path -Recurse -File -Include *.al,*.xml,*.json,*.rdlc,*.docx,*.xlsx,*.xlf |
             Where-Object { $_.FullName -notmatch '[\\/](bin|obj|\.git|\.vscode|TestResults)[\\/]' } |
             Sort-Object FullName
    if ($files.Count -eq 0) { return "" }
    $content = $files | ForEach-Object {
        $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
        $relPath = $_.FullName.Substring($Path.Length).TrimStart('\', '/')
        "$relPath=$($hash.Hash)"
    }
    $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes(($content -join "`n")))
    $hash = Get-FileHash -InputStream $stream -Algorithm SHA256
    return $hash.Hash
}

function Test-AppNeedsPublish {
    param([string]$AppDir, $AppJson, [string]$ContainerName, [switch]$Force)
    if ($Force) {
        Write-BuildMessage -Type Detail -Message "Force publish requested"
        return $true
    }
    $statePath = Get-PublishStatePath -AppJson $AppJson -ContainerName $ContainerName
    if (-not (Test-Path -LiteralPath $statePath)) {
        Write-BuildMessage -Type Detail -Message "No previous publish state found"
        return $true
    }
    try {
        $jsonText = Get-Content -LiteralPath $statePath -Raw
        $state = [System.Text.Json.JsonSerializer]::Deserialize[System.Collections.Generic.Dictionary[string,string]]($jsonText)
    } catch {
        Write-BuildMessage -Type Detail -Message "Failed to read publish state: $($_.Exception.Message)"
        return $true
    }
    $containerCreated = Get-ContainerCreatedTime -ContainerName $ContainerName
    if ($containerCreated) {
        $stateContainerTime = if ($state.containerCreated) { [DateTimeOffset]::Parse($state.containerCreated) } else { $null }
        if (-not $stateContainerTime -or $containerCreated -gt $stateContainerTime) {
            Write-BuildMessage -Type Detail -Message "Container recreated since last publish"
            return $true
        }
    }
    $currentHash = Get-DirectoryHash -Path $AppDir
    if (-not $currentHash) {
        Write-BuildMessage -Type Detail -Message "Cannot compute source hash"
        return $true
    }
    if ($state['sourceHash'] -ne $currentHash) {
        Write-BuildMessage -Type Detail -Message "Source files changed"
        return $true
    }
    Write-BuildMessage -Type Detail -Message "Sources unchanged since last publish"
    return $false
}

function Save-PublishState {
    param([string]$AppDir, $AppJson, [string]$ContainerName)
    $statePath = Get-PublishStatePath -AppJson $AppJson -ContainerName $ContainerName
    $containerCreated = Get-ContainerCreatedTime -ContainerName $ContainerName
    $sourceHash = Get-DirectoryHash -Path $AppDir
    $state = [ordered]@{
        sourceHash       = $sourceHash
        containerCreated = if ($containerCreated) { $containerCreated.ToString('o') } else { $null }
        publishedAt      = (Get-Date).ToString('o')
        appVersion       = $AppJson.version
        appName          = $AppJson.name
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
    Write-BuildMessage -Type Detail -Message "Publish state saved to: $statePath"
}

function Clear-PublishState {
    param($AppJson, [string]$ContainerName)
    $statePath = Get-PublishStatePath -AppJson $AppJson -ContainerName $ContainerName
    if (Test-Path -LiteralPath $statePath) {
        Remove-Item -LiteralPath $statePath -Force
        Write-BuildMessage -Type Detail -Message "Publish state cleared"
    }
}

# =============================================================================
# Telemetry Integration
# =============================================================================

function Clear-TestTelemetryLogs {
    [CmdletBinding()]
    param([string]$ContainerName)
    if (-not $ContainerName) {
        try { $ContainerName = Get-BCAgentContainerName } catch { $ContainerName = 'bctest' }
    }
    Write-BuildMessage -Type Step -Message "Clearing test telemetry logs"
    try {
        $result = Invoke-ScriptInBcContainer -containerName $ContainerName -scriptblock {
            $nstBasePath = "C:\ProgramData\Microsoft\Microsoft Dynamics NAV"
            $filesRemoved = 0
            if (Test-Path $nstBasePath) {
                $tempFolders = Get-ChildItem -Path $nstBasePath -Filter "TEMP" -Recurse -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match "\\Server\\.*\\users\\default\\.*\\TEMP$" }
                foreach ($tempFolder in $tempFolders) {
                    $files = Get-ChildItem -Path $tempFolder.FullName -Filter "test-telemetry-*.jsonl" -File -ErrorAction SilentlyContinue
                    foreach ($file in $files) {
                        Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
                        $filesRemoved++
                    }
                }
            }
            @{ FilesRemoved = $filesRemoved }
        }
        Write-BuildMessage -Type Success -Message "Test telemetry logs cleared"
        return [PSCustomObject]$result
    } catch {
        Write-BuildMessage -Type Warning -Message "Failed to clear telemetry logs: $_"
        return [PSCustomObject]@{ FilesRemoved = 0 }
    }
}

function Merge-TestTelemetryLogs {
    [CmdletBinding()]
    param([string]$ContainerName)
    if (-not $ContainerName) {
        try { $ContainerName = Get-BCAgentContainerName } catch { $ContainerName = 'bctest' }
    }
    Write-BuildMessage -Type Step -Message "Consolidating test telemetry logs"
    try {
        $result = Invoke-ScriptInBcContainer -containerName $ContainerName -scriptblock {
            $nstBasePath = "C:\ProgramData\Microsoft\Microsoft Dynamics NAV"
            $allFiles = @()
            if (Test-Path $nstBasePath) {
                $tempFolders = Get-ChildItem -Path $nstBasePath -Filter "TEMP" -Recurse -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match "\\Server\\.*\\users\\default\\.*\\TEMP$" }
                foreach ($tempFolder in $tempFolders) {
                    $files = Get-ChildItem -Path $tempFolder.FullName -Filter "test-telemetry-*.jsonl" -File -ErrorAction SilentlyContinue
                    $allFiles += $files
                }
            }
            if ($allFiles.Count -eq 0) {
                return @{ Success = $false; FileCount = 0; TotalSize = 0; Message = "No telemetry files found" }
            }
            $sortedFiles = $allFiles | Sort-Object Name
            $outputPath = "c:\run\my\test-telemetry.jsonl"
            $totalSize = 0
            foreach ($file in $sortedFiles) {
                Get-Content -Path $file.FullName -Raw | Add-Content -Path $outputPath -NoNewline
                $totalSize += $file.Length
            }
            @{ Success = $true; FileCount = $sortedFiles.Count; TotalSize = $totalSize; OutputPath = $outputPath }
        }
        if ($result.Success) {
            Write-BuildMessage -Type Success -Message "Test telemetry logs consolidated"
        } else {
            Write-BuildMessage -Type Warning -Message $result.Message
        }
        return [PSCustomObject]$result
    } catch {
        Write-BuildMessage -Type Warning -Message "Failed to consolidate telemetry logs: $_"
        return [PSCustomObject]@{ Success = $false; FileCount = 0; TotalSize = 0; Message = $_.ToString() }
    }
}

function Copy-TestTelemetryLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$SharedFolder,
        [Parameter(Mandatory = $true)][string]$LocalResultsPath
    )
    Write-BuildMessage -Type Step -Message "Copying telemetry logs to local folder"
    $sharedFile = Join-Path $SharedFolder "test-telemetry.jsonl"
    $localFile = Join-Path $LocalResultsPath "telemetry.jsonl"
    if (Test-Path -LiteralPath $sharedFile) {
        try {
            Copy-Item -LiteralPath $sharedFile -Destination $localFile -Force
            if (Test-Path -LiteralPath $localFile) {
                Write-BuildMessage -Type Success -Message "Telemetry logs copied successfully"
                Remove-Item -LiteralPath $sharedFile -Force -ErrorAction SilentlyContinue
                return [PSCustomObject]@{ Success = $true; LocalPath = $localFile }
            }
        } catch {
            Write-BuildMessage -Type Warning -Message "Failed to copy telemetry logs: $_"
        }
    } else {
        Write-BuildMessage -Type Warning -Message "Telemetry log file not found in shared location: $sharedFile"
    }
    return [PSCustomObject]@{ Success = $false; LocalPath = $null }
}

# =============================================================================
# Exports
# =============================================================================

Export-ModuleMember -Function @(
    # Exit Codes
    'Get-ExitCode'

    # Output
    'Write-BuildHeader'
    'Write-BuildMessage'

    # Timing
    'Save-BuildTimingEntry'
    'Show-BuildTimingHistory'

    # Path Helpers
    'Get-RepoRoot'
    'ConvertTo-SafePathSegment'
    'Ensure-Directory'
    'New-TemporaryDirectory'
    'Expand-FullPath'
    'Get-AppJsonPath'
    'Get-SettingsJsonPath'
    'Read-JsonFile'
    'Test-JsonProperty'

    # Tool Cache
    'Get-ToolCacheRoot'
    'Get-SymbolCacheRoot'
    'Get-LatestCompilerInfo'
    'Get-SymbolCacheInfo'

    # Remote Configuration
    'Get-RemoteContainerName'
    'Get-RemoteBuildConfig'

    # AL Build
    'Get-AppJsonObject'
    'Get-OutputPath'
    'Copy-ALSymbolToCache'

    # Business Central Integration
    'Get-BCAgentContainerName'
    'Import-BCContainerHelper'
    'Get-BCCredential'
    'Get-EnabledAnalyzerPath'

    # Incremental Publish
    'Get-ContainerCreatedTime'
    'Get-PublishStatePath'
    'Get-DirectoryHash'
    'Test-AppNeedsPublish'
    'Save-PublishState'
    'Clear-PublishState'

    # Telemetry Integration
    'Clear-TestTelemetryLogs'
    'Merge-TestTelemetryLogs'
    'Copy-TestTelemetryLogs'

    # SSH/SCP
    'Invoke-RemoteCommand'
    'Copy-FileToRemote'
    'Copy-FileFromRemote'
)
