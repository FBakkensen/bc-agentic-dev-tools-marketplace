#requires -Version 7.2

<#
.SYNOPSIS
    Shared utilities for AL Build System

.DESCRIPTION
    Common helper functions used across build, test, and provisioning scripts.
    This module eliminates code duplication and provides a single source of truth
    for path resolution, JSON parsing, formatting, and configuration management.

.NOTES
    This module is dot-sourced by al.build.ps1 and imported by task scripts.
    Functions are organized by category for maintainability.
#>

Set-StrictMode -Version Latest

# =============================================================================
# Exit Codes
# =============================================================================

function Get-ExitCode {
    <#
    .SYNOPSIS
        Standard exit codes for build scripts
    #>
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
# Path Utilities
# =============================================================================

function Expand-FullPath {
    <#
    .SYNOPSIS
        Expand environment variables and resolve full path
    .PARAMETER Path
        Path to expand (supports ~, environment variables)
    #>
    param([string]$Path)

    if (-not $Path) { return $null }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)

    if ($expanded.StartsWith('~')) {
        $userHome = $env:HOME
        if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
        if ($userHome) {
            $suffix = $expanded.Substring(1).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            if ([string]::IsNullOrWhiteSpace($suffix)) {
                $expanded = $userHome
            } else {
                $expanded = Join-Path -Path $userHome -ChildPath $suffix
            }
        }
    }

    try {
        return (Resolve-Path -LiteralPath $expanded -ErrorAction Stop).ProviderPath
    } catch {
        return [System.IO.Path]::GetFullPath($expanded)
    }
}

function ConvertTo-SafePathSegment {
    <#
    .SYNOPSIS
        Convert string to safe filesystem path segment
    .PARAMETER Value
        String to sanitize
    #>
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
    <#
    .SYNOPSIS
        Ensure directory exists (create if missing)
    .PARAMETER Path
        Directory path to ensure exists
    #>
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        [void](New-Item -ItemType Directory -Path $Path -Force)
    }
}

function New-TemporaryDirectory {
    <#
    .SYNOPSIS
        Create a new temporary directory with unique GUID-based name
    .DESCRIPTION
        Creates a uniquely named temporary directory in the system temp location.
        Useful for isolating temporary file operations across scripts.
    .OUTPUTS
        String path to the created temporary directory
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()

    $base = [System.IO.Path]::GetTempPath()
    $name = 'bc-temp-' + [System.Guid]::NewGuid().ToString('N')
    $path = Join-Path -Path $base -ChildPath $name
    $action = 'Create temporary directory'

    if (-not $PSCmdlet -or $PSCmdlet.ShouldProcess($path, $action)) {
        Ensure-Directory -Path $path
    }

    return $path
}

# =============================================================================
# JSON and App Configuration
# =============================================================================

function Get-AppJsonPath {
    <#
    .SYNOPSIS
        Locate app.json in project directory
    .PARAMETER AppDir
        Directory to search (defaults to current directory)
    #>
    param([string]$AppDir)
    $p1 = Join-Path -Path $AppDir -ChildPath 'app.json'
    $p2 = 'app.json'
    if (Test-Path $p1) { return $p1 }
    elseif (Test-Path $p2) { return $p2 }
    else { return $null }
}

function Get-SettingsJsonPath {
    <#
    .SYNOPSIS
        Locate .vscode/settings.json in project directory
    .PARAMETER AppDir
        Directory to search
    #>
    param([string]$AppDir)
    $p1 = Join-Path -Path $AppDir -ChildPath '.vscode/settings.json'
    if (Test-Path $p1) { return $p1 }
    $p2 = '.vscode/settings.json'
    if (Test-Path $p2) { return $p2 }
    return $null
}

function Get-AppJsonObject {
    <#
    .SYNOPSIS
        Parse app.json as PowerShell object
    .PARAMETER AppDir
        Directory containing app.json
    #>
    param([string]$AppDir)
    $appJson = Get-AppJsonPath $AppDir
    if (-not $appJson) { return $null }
    try { Get-Content $appJson -Raw | ConvertFrom-Json } catch { $null }
}

function Get-SettingsJsonObject {
    <#
    .SYNOPSIS
        Parse .vscode/settings.json as PowerShell object
    .PARAMETER AppDir
        Directory containing .vscode
    #>
    param([string]$AppDir)
    $path = Get-SettingsJsonPath $AppDir
    if (-not $path) { return $null }
    try { Get-Content $path -Raw | ConvertFrom-Json } catch { $null }
}

function Get-OutputPath {
    <#
    .SYNOPSIS
        Compute expected output .app file path from app.json
    .PARAMETER AppDir
        Directory containing app.json
    #>
    param([string]$AppDir)
    $appJson = Get-AppJsonPath $AppDir
    if (-not $appJson) { return $null }
    try {
        $json = Get-Content $appJson -Raw | ConvertFrom-Json
        if (-not $json.name -or -not $json.version -or -not $json.publisher) {
            return $null
        }
        $name = $json.name
        $version = $json.version
        $publisher = $json.publisher
        $file = "${publisher}_${name}_${version}.app"
        return Join-Path -Path $AppDir -ChildPath $file
    } catch { return $null }
}

function Read-JsonFile {
    <#
    .SYNOPSIS
        Read and parse JSON file with error handling
    .PARAMETER Path
        Path to JSON file
    #>
    param([string]$Path)
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse JSON from ${Path}: $($_.Exception.Message)"
    }
}

function Test-JsonProperty {
    <#
    .SYNOPSIS
        Check if a JSON object has a specific property
    .PARAMETER JsonObject
        The JSON object to test
    .PARAMETER PropertyName
        The property name to check
    .DESCRIPTION
        Safely checks if a property exists on a PSCustomObject without throwing exceptions.
        Returns $true if the property exists, $false otherwise.
    .EXAMPLE
        if (Test-JsonProperty $appJson 'application') { ... }
    #>
    param(
        [Parameter(Mandatory=$true)]
        $JsonObject,
        [Parameter(Mandatory=$true)]
        [string]$PropertyName
    )

    if ($null -eq $JsonObject) { return $false }
    return $JsonObject.PSObject.Properties.Name -contains $PropertyName
}

function Resolve-AppJsonPath {
    <#
    .SYNOPSIS
        Resolve absolute path to app.json with validation
    .PARAMETER AppDirectory
        Directory to search
    #>
    param([string]$AppDirectory)

    if ($AppDirectory) {
        $candidate = Join-Path -Path $AppDirectory -ChildPath 'app.json'
        if (Test-Path -LiteralPath $candidate) {
            return (Get-Item -LiteralPath $candidate).FullName
        }
    }
    if (Test-Path -LiteralPath 'app.json') {
        return (Get-Item -LiteralPath 'app.json').FullName
    }
    throw "app.json not found. Provide -AppDir or run from project root."
}

# =============================================================================
# Cache Management
# =============================================================================

function Get-ToolCacheRoot {
    <#
    .SYNOPSIS
        Get root directory for AL compiler tool cache
    #>
    $override = $env:ALBT_TOOL_CACHE_ROOT
    if ($override) { return Expand-FullPath -Path $override }

    $userHome = $env:HOME
    if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
    if (-not $userHome) { throw 'Unable to determine home directory for tool cache.' }

    return Join-Path -Path $userHome -ChildPath '.bc-tool-cache'
}

function Get-SymbolCacheRoot {
    <#
    .SYNOPSIS
        Get root directory for BC symbol package cache
    #>
    $userHome = $env:HOME
    if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
    if (-not $userHome) {
        throw 'Unable to determine home directory for symbol cache. Ensure HOME or USERPROFILE environment variable is set.'
    }
    return Join-Path -Path $userHome -ChildPath '.bc-symbol-cache'
}

function Get-LatestCompilerInfo {
    <#
    .SYNOPSIS
        Get AL compiler information from latest-only sentinel (no runtime-specific versions)
    .DESCRIPTION
        Uses the new "latest compiler only" principle - single compiler version for all projects.
        No runtime-specific caching, no version selection.
    .OUTPUTS
        PSCustomObject with AlcPath, Version, SentinelPath, IsLocalTool
    #>
    [CmdletBinding()]
    param()

    $toolCacheRoot = Get-ToolCacheRoot
    $alCacheDir = Join-Path -Path $toolCacheRoot -ChildPath 'al'
    $sentinelPath = Join-Path -Path $alCacheDir -ChildPath 'sentinel.json'

    if (-not (Test-Path -LiteralPath $sentinelPath)) {
        throw "Compiler not provisioned. Sentinel not found at: $sentinelPath. Run 'provision.ps1' first."
    }

    try {
        $sentinel = Get-Content -LiteralPath $sentinelPath -Raw | ConvertFrom-Json
    } catch {
        throw "Failed to parse compiler sentinel at ${sentinelPath}: $($_.Exception.Message)"
    }

    $compilerVersion = if ($sentinel.PSObject.Properties.Match('compilerVersion').Count -gt 0) { [string]$sentinel.compilerVersion } else { $null }
    $toolPath = [string]$sentinel.toolPath

    if (-not $toolPath) {
        throw "Compiler sentinel at $sentinelPath is missing 'toolPath' property."
    }

    if (-not (Test-Path -LiteralPath $toolPath)) {
        throw "AL compiler executable not found at: $toolPath. Run 'provision.ps1' to reinstall."
    }

    $toolItem = Get-Item -LiteralPath $toolPath

    return [pscustomobject]@{
        AlcPath      = $toolItem.FullName
        Version      = $compilerVersion
        SentinelPath = $sentinelPath
        IsLocalTool  = ($sentinel.installationType -eq 'local-tool')
    }
}

function Get-SymbolCacheInfo {
    <#
    .SYNOPSIS
        Get symbol cache directory and manifest information
    .PARAMETER AppJson
        Parsed app.json object
    #>
    param($AppJson)

    if (-not $AppJson) {
        throw 'app.json is required to resolve the symbol cache. Ensure app.json exists and run `provision.ps1`.'
    }

    if (-not $AppJson.publisher) {
    throw 'app.json missing "publisher". Update the manifest and rerun `provision.ps1`.'
    }
    if (-not $AppJson.name) {
    throw 'app.json missing "name". Update the manifest and rerun `provision.ps1`.'
    }
    if (-not $AppJson.id) {
    throw 'app.json missing "id". Update the manifest and rerun `provision.ps1`.'
    }

    $cacheRoot = Get-SymbolCacheRoot

    $publisherDir = Join-Path -Path $cacheRoot -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.publisher)
    $appDirPath = Join-Path -Path $publisherDir -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.name)
    $cacheDir = Join-Path -Path $appDirPath -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.id)

    if (-not (Test-Path -LiteralPath $cacheDir)) {
    throw "Symbol cache directory not found at $cacheDir. Run `provision.ps1` before building."
    }

    $manifestPath = Join-Path -Path $cacheDir -ChildPath 'symbols.lock.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Symbol manifest missing at $manifestPath. Run `provision.ps1` before building."
    }

    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    } catch {
    throw "Failed to parse symbol manifest at ${manifestPath}: $($_.Exception.Message). Run `provision.ps1` before building."
    }

    return [pscustomobject]@{
        CacheDir     = (Get-Item -LiteralPath $cacheDir).FullName
        ManifestPath = $manifestPath
        Manifest     = $manifest
    }
}

# =============================================================================
# Standardized Output System (enforces consistent formatting)
# =============================================================================

function Write-BuildMessage {
    <#
    .SYNOPSIS
        Standardized output for all build scripts (enforces consistent formatting)
    .DESCRIPTION
        Central output function that ensures all build scripts use consistent message formatting.
        This is the ONLY function scripts should use for console output (except Write-BuildHeader).

        Detail is verbose-gated by design (Write-Verbose): diagnostics for humans
        re-running with -Verbose, invisible in default runs so agent-driven gates
        stay lean. Never put verdict payload (findings, error evidence, the reason
        a script exits non-zero or skips) in Detail — use Error or Info.
    .PARAMETER Type
        Message type: Info, Success, Warning, Error, Step, Detail
    .PARAMETER Message
        The message text
    .EXAMPLE
        Write-BuildMessage -Type Step -Message "Downloading compiler..."
        Write-BuildMessage -Type Success -Message "Build completed"
        Write-BuildMessage -Type Error -Message "Compilation failed"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Step', 'Detail')]
        [string]$Type = 'Info',

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    switch ($Type) {
        'Detail' {
            if (-not [string]::IsNullOrEmpty($Message)) {
                Write-Verbose "    • $Message"
            } else {
                Write-Verbose ''
            }
        }
        'Info' {
            Write-Host "[INFO] " -NoNewline -ForegroundColor Cyan
            Write-Host $Message
        }
        'Success' {
            Write-Host "[✓] " -NoNewline -ForegroundColor Green
            Write-Host $Message
        }
        'Warning' {
            Write-Host "[!] " -NoNewline -ForegroundColor Yellow
            Write-Host $Message
        }
        'Error' {
            Write-Host "[✗] " -NoNewline -ForegroundColor Red
            Write-Host $Message
        }
        'Step' {
            Write-Host "[→] " -NoNewline -ForegroundColor Magenta
            Write-Host $Message
        }
    }
}

function Write-BuildHeader {
    <#
    .SYNOPSIS
        Standardized section header for build scripts
    .DESCRIPTION
        Displays a consistent section header across all build scripts.
    .PARAMETER Title
        Section title
    .EXAMPLE
        Write-BuildHeader "AL Compiler Provisioning"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor DarkGray
    Write-Host "  $Title" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor DarkGray
    Write-Host ""
}

function Write-TaskHeader {
    <#
    .SYNOPSIS
        Standardized task header for AL build scripts
    .DESCRIPTION
        Displays the colored "🔧 AL-BUILD | TASK | Description" header used by tasks.
    .PARAMETER TaskName
        Name of the task (e.g., "BUILD", "HELP", "DOWNLOAD-COMPILER")
    .PARAMETER Description
        Brief description of the task
    .EXAMPLE
        Write-TaskHeader "BUILD" "AL Project Compilation"
        Write-TaskHeader "HELP" "AL Project Build System"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName,

        [Parameter(Mandatory=$true)]
        [string]$Description
    )

    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host "🔧 AL-BUILD | $TaskName | $Description" -ForegroundColor Yellow
    Write-Host ("=" * 80) -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# Legacy Formatting Helpers (deprecated - use Write-BuildMessage instead)
# =============================================================================

function Write-Section {
    <#
    .SYNOPSIS
        Write formatted section header
    .PARAMETER Title
        Section title
    .PARAMETER SubInfo
        Optional subtitle
    .NOTES
        DEPRECATED: Use Write-BuildHeader instead
    #>
    param([string]$Title, [string]$SubInfo = '')
    $line = ''.PadLeft(80, '=')
    Write-Information "" # blank spacer
    Write-Information $line -InformationAction Continue
    $header = "🔧 BUILD | {0}" -f $Title
    if ($SubInfo) { $header += " | {0}" -f $SubInfo }
    Write-Information $header -InformationAction Continue
    Write-Information $line -InformationAction Continue
}

function Write-InfoLine {
    <#
    .SYNOPSIS
        Write formatted information line with label and value
    .PARAMETER Label
        Label text
    .PARAMETER Value
        Value text
    .PARAMETER Icon
        Icon character (defaults to •)
    .NOTES
        DEPRECATED: Use Write-BuildMessage -Type Detail instead
    #>
    param(
        [string]$Label,
        [string]$Value,
        [string]$Icon = '•'
    )
    $labelPadded = ($Label).PadRight(14)
    Write-Information ("  {0}{1}: {2}" -f $Icon, $labelPadded, $Value) -InformationAction Continue
}

function Write-StatusLine {
    <#
    .SYNOPSIS
        Write formatted status message
    .PARAMETER Message
        Status message
    .PARAMETER Icon
        Icon character (defaults to ⚠️)
    .NOTES
        DEPRECATED: Use Write-BuildMessage -Type Info/Warning instead
    #>
    param([string]$Message, [string]$Icon = '⚠️')
    Write-Information ("  {0} {1}" -f $Icon, $Message) -InformationAction Continue
}

function Write-ListItem {
    <#
    .SYNOPSIS
        Write formatted list item
    .PARAMETER Item
        Item text
    .PARAMETER Icon
        Icon character (defaults to →)
    .NOTES
        DEPRECATED: Use Write-BuildMessage -Type Detail instead
    #>
    param([string]$Item, [string]$Icon = '→')
    Write-Information ("    {0} {1}" -f $Icon, $Item) -InformationAction Continue
}

# =============================================================================
# Analyzer Utilities
# =============================================================================

function Test-AnalyzerDependencies {
    <#
    .SYNOPSIS
        Test if an analyzer has all required dependencies available
    .PARAMETER AnalyzerPath
        Path to the analyzer DLL to test
    #>
    param([string]$AnalyzerPath)

    if (-not (Test-Path -LiteralPath $AnalyzerPath)) {
        return $false
    }

    try {
        # Try to load the analyzer assembly to check for missing dependencies
        $bytes = [System.IO.File]::ReadAllBytes($AnalyzerPath)
        $assembly = [System.Reflection.Assembly]::Load($bytes)

        # Check if we can get the types (this will fail if dependencies are missing)
        $types = $assembly.GetTypes()
        return $true
    } catch {
        Write-Information "[albt] Analyzer dependency check failed for $(Split-Path -Leaf $AnalyzerPath): $($_.Exception.Message)" -InformationAction Continue
        return $false
    }
}

function Get-EnabledAnalyzerPath {
    <#
    .SYNOPSIS
        Get list of enabled analyzer DLL paths based on VS Code settings
    .DESCRIPTION
        Resolves al.codeAnalyzers entries in the official AL notation: '${CodeCop}'
        style tokens for the Microsoft analyzers and '${analyzerFolder}ALCops.*.dll'
        path entries for the ALCops cops. When any ALCops cop is enabled, the shared
        ALCops.Common.dll is appended automatically, plus
        Microsoft.Dynamics.Nav.Analyzers.Common.dll when no Microsoft analyzer is
        enabled to bring it in. Throws when a requested analyzer cannot be resolved;
        the build gate must never silently compile with less lint coverage than the
        settings ask for.
    .PARAMETER AppDir
        Application directory
    .PARAMETER CompilerDir
        Compiler directory (for resolving analyzer paths)
    #>
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
    }
    $supported = $dllMap.Keys
    $enabled = @()

    if ($settingsPath -and (Test-Path -LiteralPath $settingsPath)) {
        # An empty settings.json requests nothing — only a non-empty file that fails to
        # parse is a misconfiguration. ConvertFrom-Json tolerates JSONC comments and
        # trailing commas, so files shared with VS Code parse fine.
        $settingsRaw = Get-Content $settingsPath -Raw
        if (-not [string]::IsNullOrWhiteSpace($settingsRaw)) {
            try {
                $json = $settingsRaw | ConvertFrom-Json
                if ($json -and ($json.PSObject.Properties.Match('al.codeAnalyzers').Count -gt 0) -and $json.'al.codeAnalyzers') {
                    $enabled = @($json.'al.codeAnalyzers')
                } elseif ($json) {
                    if ($json.PSObject.Properties.Match('enableCodeCop').Count -gt 0 -and $json.enableCodeCop) { $enabled += 'CodeCop' }
                    if ($json.PSObject.Properties.Match('enableUICop').Count -gt 0 -and $json.enableUICop) { $enabled += 'UICop' }
                    if ($json.PSObject.Properties.Match('enableAppSourceCop').Count -gt 0 -and $json.enableAppSourceCop) { $enabled += 'AppSourceCop' }
                    if ($json.PSObject.Properties.Match('enablePerTenantExtensionCop').Count -gt 0 -and $json.enablePerTenantExtensionCop) { $enabled += 'PerTenantExtensionCop' }
                }
            } catch {
                # A settings.json that exists but will not parse is a misconfiguration,
                # not an absent-file default. Guessing "no analyzers" here would silently
                # strip lint coverage — the failure mode the unresolved-analyzer throw closes.
                throw "settings.json at '$settingsPath' could not be parsed: $($_.Exception.Message)"
            }
        }
    }

    $dllPaths = New-Object System.Collections.Generic.List[string]
    if (-not $enabled -or $enabled.Count -eq 0) { return $dllPaths }

    $workspaceRoot = (Get-Location).Path
    $appFull = try { (Resolve-Path $AppDir -ErrorAction Stop).Path } catch { Join-Path $workspaceRoot $AppDir }

    # Find analyzers directory - check compiler directory only (no runtime-specific caches)
    $analyzersDir = $null

    if ($CompilerDir -and (Test-Path -LiteralPath $CompilerDir)) {
        $candidate = Join-Path -Path $CompilerDir -ChildPath 'Analyzers'
        if (Test-Path -LiteralPath $candidate) {
            $analyzersDir = (Get-Item -LiteralPath $candidate).FullName
        } else {
            $analyzersDir = (Get-Item -LiteralPath $CompilerDir).FullName
        }
    }

    function Resolve-AnalyzerEntry {
        param([string]$Entry)

        $val = $Entry
        if ($null -eq $val) { return @() }

        if ($val -match '^\$\{analyzerFolder\}(.*)$' -and $analyzersDir) {
            $tail = $matches[1]
            if ($tail -and $tail[0] -notin @('\\','/')) { $val = Join-Path $analyzersDir $tail } else { $val = "$analyzersDir$tail" }
        }
        if ($val -match '^\$\{alExtensionPath\}(.*)$' -and $CompilerDir) {
            $tail2 = $matches[1]
            if ($tail2 -and $tail2[0] -notin @('\\','/')) { $val = Join-Path $CompilerDir $tail2 } else { $val = "$CompilerDir$tail2" }
        }
        if ($val -match '^\$\{compilerRoot\}(.*)$' -and $CompilerDir) {
            $tail3 = $matches[1]
            if ($tail3 -and $tail3[0] -notin @('\\','/')) { $val = Join-Path $CompilerDir $tail3 } else { $val = "$CompilerDir$tail3" }
        }

        if ($CompilerDir) {
            $val = $val.Replace('${alExtensionPath}', $CompilerDir)
            $val = $val.Replace('${compilerRoot}', $CompilerDir)
        }
        if ($analyzersDir) {
            $val = $val.Replace('${analyzerFolder}', $analyzersDir)
        }

        $val = $val.Replace('${workspaceFolder}', $workspaceRoot).Replace('${workspaceRoot}', $workspaceRoot).Replace('${appDir}', $appFull)
        $val = [regex]::Replace($val, '\$\{([^}]+)\}', '$1')

        $expanded = [Environment]::ExpandEnvironmentVariables($val)
        if ($expanded.StartsWith('~')) {
            $userHome = $env:HOME
            if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
            if ($userHome) {
                $suffix = $expanded.Substring(1).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
                if ([string]::IsNullOrWhiteSpace($suffix)) {
                    $expanded = $userHome
                } else {
                    $expanded = Join-Path -Path $userHome -ChildPath $suffix
                }
            }
        }

        if (-not [IO.Path]::IsPathRooted($expanded)) {
            $expanded = Join-Path $workspaceRoot $expanded
        }

        if (Test-Path $expanded -PathType Container) {
            return Get-ChildItem -Path $expanded -Filter '*.dll' -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
        }

        if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($expanded)) {
            return Get-ChildItem -Path $expanded -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
        }

        if (Test-Path $expanded -PathType Leaf) { return @($expanded) }

        return @()
    }

    $searchRoots = @()
    if ($analyzersDir) { $searchRoots += $analyzersDir }
    if ($CompilerDir -and ($searchRoots -notcontains $CompilerDir)) { $searchRoots += $CompilerDir }

    function Find-AnalyzerDll {
        param([string]$DllName)

        foreach ($root in $searchRoots) {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            $candidate = Get-ChildItem -Path $root -Recurse -Filter $DllName -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($candidate) { return $candidate.FullName }
        }
        return $null
    }

    $unresolved = New-Object System.Collections.Generic.List[string]

    foreach ($item in $enabled) {
        $name = ($item | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -match '^\$\{([A-Za-z]+)\}$') { $name = $matches[1] }

        if ($supported -contains $name) {
            $dll = $dllMap[$name]
            $found = Find-AnalyzerDll -DllName $dll
            if ($found) {
                if (-not $dllPaths.Contains($found)) { $dllPaths.Add($found) | Out-Null }
            } else {
                $unresolved.Add("$name ($dll)") | Out-Null
            }
        } else {
            $resolved = @(Resolve-AnalyzerEntry -Entry $name)
            if ($resolved.Count -eq 0) {
                $unresolved.Add($name) | Out-Null
            } else {
                $resolved | ForEach-Object {
                    if ($_ -and -not $dllPaths.Contains($_)) { $dllPaths.Add($_) | Out-Null }
                }
            }
        }
    }

    # ALCops cops need companion DLLs loaded alongside (per alcops.dev command-line
    # docs): ALCops.Common.dll always, and Microsoft.Dynamics.Nav.Analyzers.Common.dll
    # when no Microsoft analyzer is enabled to bring it in.
    $leafNames = @($dllPaths | ForEach-Object { Split-Path -Leaf $_ })
    $hasALCopsCop = [bool]($leafNames | Where-Object { $_ -like 'ALCops.*.dll' -and $_ -ne 'ALCops.Common.dll' })
    if ($hasALCopsCop) {
        $companions = @('ALCops.Common.dll')
        if (-not ($leafNames | Where-Object { $_ -like 'Microsoft.Dynamics.Nav.*.dll' })) {
            $companions += 'Microsoft.Dynamics.Nav.Analyzers.Common.dll'
        }
        foreach ($companion in $companions) {
            if ($leafNames -contains $companion) { continue }
            $found = Find-AnalyzerDll -DllName $companion
            if ($found) { $dllPaths.Add($found) | Out-Null } else { $unresolved.Add($companion) | Out-Null }
        }
    }

    if ($unresolved.Count -gt 0) {
        throw "Analyzer(s) requested in '$settingsPath' but not resolvable: $($unresolved -join ', '). Run provision.ps1 to install analyzers, then retry."
    }

    return $dllPaths
}

# =============================================================================
# Business Central Integration
# =============================================================================

function Add-HostsEntry {
    <#
    .SYNOPSIS
        Add or update an entry in the Windows hosts file
    .DESCRIPTION
        Safely updates C:\Windows\System32\drivers\etc\hosts with file locking,
        retry logic, duplicate removal, and ASCII encoding. Assumes write
        permissions are pre-granted on the hosts file.
    .PARAMETER Hostname
        The hostname to add (e.g., 'bctest', 'my-container')
    .PARAMETER IPAddress
        The IP address to map to the hostname
    .EXAMPLE
        Add-HostsEntry -Hostname 'bctest' -IPAddress '172.28.0.5'
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hostname,

        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )

    $hostsFile = 'C:\Windows\System32\drivers\etc\hosts'
    $file = $null
    $maxRetries = 10
    $attempt = 0

    while ($null -eq $file -and $attempt -lt $maxRetries) {
        try {
            $file = [System.IO.File]::Open(
                $hostsFile,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::Read
            )
        }
        catch [System.IO.IOException] {
            $attempt++
            Start-Sleep -Milliseconds 500
        }
    }

    if ($null -eq $file) {
        throw "Failed to open hosts file after $maxRetries attempts"
    }

    try {
        # Read existing content
        $content = New-Object System.Byte[] ($file.Length)
        $file.Read($content, 0, $file.Length) | Out-Null
        $hostsContent = [System.Text.Encoding]::ASCII.GetString($content)

        # Parse lines and remove any existing entry for this hostname
        $lines = $hostsContent.Replace("`r`n", "`n").Split("`n")
        $escapedHostname = [Regex]::Escape($Hostname)
        $lines = $lines | Where-Object {
            -not ($_ -match "^\s*\S+\s+$escapedHostname(\s|#|$)")
        }

        # Add new entry
        $lines += "$IPAddress`t$Hostname"

        # Write back with ASCII encoding
        $newContent = [System.Text.Encoding]::ASCII.GetBytes(($lines -join "`r`n") + "`r`n")
        $file.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $file.Write($newContent, 0, $newContent.Length)
        $file.SetLength($newContent.Length)
        $file.Flush()
    }
    finally {
        if ($file) {
            $file.Dispose()
        }
    }
}

function Remove-HostsEntry {
    <#
    .SYNOPSIS
        Remove an entry from the Windows hosts file
    .DESCRIPTION
        Safely removes a hostname entry from C:\Windows\System32\drivers\etc\hosts
        with file locking, retry logic, and ASCII encoding. Assumes write
        permissions are pre-granted on the hosts file.
    .PARAMETER Hostname
        The hostname to remove
    .EXAMPLE
        Remove-HostsEntry -Hostname 'bctest'
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hostname
    )

    $hostsFile = 'C:\Windows\System32\drivers\etc\hosts'
    $file = $null
    $maxRetries = 10
    $attempt = 0

    while ($null -eq $file -and $attempt -lt $maxRetries) {
        try {
            $file = [System.IO.File]::Open(
                $hostsFile,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::Read
            )
        }
        catch [System.IO.IOException] {
            $attempt++
            Start-Sleep -Milliseconds 500
        }
    }

    if ($null -eq $file) {
        throw "Failed to open hosts file after $maxRetries attempts"
    }

    try {
        # Read existing content
        $content = New-Object System.Byte[] ($file.Length)
        $file.Read($content, 0, $file.Length) | Out-Null
        $hostsContent = [System.Text.Encoding]::ASCII.GetString($content)

        # Parse lines and remove entries for this hostname
        $lines = $hostsContent.Replace("`r`n", "`n").Split("`n")
        $escapedHostname = [Regex]::Escape($Hostname)
        $lines = $lines | Where-Object {
            -not ($_ -match "^\s*\S+\s+$escapedHostname(\s|#|$)")
        }

        # Write back with ASCII encoding
        $newContent = [System.Text.Encoding]::ASCII.GetBytes(($lines -join "`r`n") + "`r`n")
        $file.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $file.Write($newContent, 0, $newContent.Length)
        $file.SetLength($newContent.Length)
        $file.Flush()
    }
    finally {
        if ($file) {
            $file.Dispose()
        }
    }
}

function Update-BCPublicWebBaseUrl {
    <#
    .SYNOPSIS
        Update PublicWebBaseUrl in a BC container, replacing only the hostname
    .DESCRIPTION
        Reads the current PublicWebBaseUrl from the container's service tier,
        replaces only the hostname portion (preserving scheme, port, and path),
        then updates the configuration and restarts the service tier.
    .PARAMETER ContainerName
        Name of the BC container
    .PARAMETER NewHostname
        The new hostname to use in the URL
    .EXAMPLE
        Update-BCPublicWebBaseUrl -ContainerName 'my-agent' -NewHostname 'my-agent'
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName,

        [Parameter(Mandatory = $true)]
        [string]$NewHostname
    )

    # Get current PublicWebBaseUrl from container
    $config = Get-BcContainerServerConfiguration -containerName $ContainerName
    $currentUrl = $config.PublicWebBaseUrl

    if (-not $currentUrl) {
        throw "PublicWebBaseUrl not found in container '$ContainerName' configuration"
    }

    # Parse and replace hostname only
    # URL format: scheme://hostname:port/path or scheme://hostname/path
    if ($currentUrl -match '^(https?://)([^:/]+)(:\d+)?(.*)$') {
        $scheme = $matches[1]
        $port = $matches[3]    # may be empty
        $path = $matches[4]    # includes leading /
        $newUrl = "${scheme}${NewHostname}${port}${path}"
    }
    else {
        throw "Could not parse PublicWebBaseUrl: $currentUrl"
    }

    # Update the configuration
    Set-BcContainerServerConfiguration `
        -containerName $ContainerName `
        -keyName 'PublicWebBaseUrl' `
        -keyValue $newUrl

    # Restart service tier to apply
    Restart-BcContainerServiceTier -containerName $ContainerName

    return $newUrl
}

function New-BCLaunchConfig {
    <#
    .SYNOPSIS
        Create minimal launch configuration for non-interactive BC operations
    .DESCRIPTION
        Creates a simplified launch configuration for publishing and testing.
        Removes interactive debugging settings (startupObjectId, breakpoints, browser launch).
    .PARAMETER ServerUrl
        Business Central server URL (e.g., http://bctest)
    .PARAMETER ServerInstance
        Business Central server instance name (e.g., BC)
    .PARAMETER Tenant
        BC tenant name (defaults to 'default')
    .OUTPUTS
        Hashtable with launch configuration for non-interactive operations
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerUrl,

        [Parameter(Mandatory=$true)]
        [string]$ServerInstance,

        [string]$Tenant = 'default'
    )

    return @{
        name = "Publish: $ServerUrl"
        type = 'al'
        request = 'launch'
        environmentType = 'OnPrem'
        server = $ServerUrl
        serverInstance = $ServerInstance
        authentication = 'UserPassword'
        tenant = $Tenant
        usePublicURLFromServer = $true
    }
}

function Get-BCCredential {
    <#
    .SYNOPSIS
        Create PSCredential object for BC authentication
    .PARAMETER Username
        BC username (typically 'admin' for local containers)
    .PARAMETER Password
        BC password (plain text - non-secret for local dev environments)
    .OUTPUTS
        PSCredential object
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$true)]
        [string]$Password
    )

    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential($Username, $securePassword)
}

function Get-BCContainerName {
    <#
    .SYNOPSIS
        Resolve BC container name from launch config or environment
    .PARAMETER LaunchConfig
        Launch configuration object (optional)
    .OUTPUTS
        Container name string
    #>
    param(
        [object]$LaunchConfig = $null
    )

    # Try to extract from launch config server URL
    if ($LaunchConfig -and $LaunchConfig.server) {
        $serverUrl = $LaunchConfig.server
        # Extract hostname from URL (e.g., http://bctest -> bctest)
        if ($serverUrl -match '://([^:/]+)') {
            return $matches[1]
        }
    }

    # Fallback to git branch name, or bctest if not in a repo
    try {
        return Get-BCAgentContainerName
    } catch {
        return 'bctest'
    }
}

function Get-BCAgentContainerName {
    <#
    .SYNOPSIS
        Derive BC agent container name from current git branch
    .DESCRIPTION
        Resolves container name from the current git branch, sanitizing for Docker compatibility.
        Replaces / and \ with -, strips invalid characters.
        Fails if not in a git repository (forces explicit branch context for agents).
    .OUTPUTS
        Sanitized container name string derived from branch name
    .EXAMPLE
        Get-BCAgentContainerName
        # Returns 'chore-refactortestsetup' for branch 'chore/refactortestsetup'
    #>
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

function Test-BCAgentContainerHealthy {
    <#
    .SYNOPSIS
        Check if a BC agent container exists and is healthy
    .PARAMETER ContainerName
        Name of the container to check
    .OUTPUTS
        $true if container exists and is healthy, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName
    )

    # Check if container exists
    $existingContainer = docker ps -a --filter "name=^${ContainerName}$" --format "{{.Names}}" 2>$null
    if (-not $existingContainer) {
        Write-BuildMessage -Type Detail -Message "Container '$ContainerName' does not exist"
        return $false
    }

    # Check if running
    $running = docker inspect $ContainerName --format '{{.State.Running}}' 2>$null
    if ($running -ne 'true') {
        Write-BuildMessage -Type Detail -Message "Container '$ContainerName' exists but is not running"
        return $false
    }

    # Check health status
    $health = docker inspect $ContainerName --format '{{.State.Health.Status}}' 2>$null
    if ($health -eq 'healthy') {
        return $true
    }

    Write-BuildMessage -Type Detail -Message "Container '$ContainerName' health status: $health"
    return $false
}

# =============================================================================
# Agent Container Registry
# =============================================================================

function Get-AgentContainerRegistryPath {
    <#
    .SYNOPSIS
        Get path to the agent container registry file
    .OUTPUTS
        Path to ~/.bc-agent-containers/registry.json
    #>
    $userHome = $env:HOME
    if (-not $userHome -and $env:USERPROFILE) { $userHome = $env:USERPROFILE }
    if (-not $userHome) {
        throw 'Unable to determine home directory. Ensure HOME or USERPROFILE environment variable is set.'
    }
    $registryDir = Join-Path -Path $userHome -ChildPath '.bc-agent-containers'
    return Join-Path -Path $registryDir -ChildPath 'registry.json'
}

function Get-RegisteredAgentContainers {
    <#
    .SYNOPSIS
        Get all registered agent containers
    .OUTPUTS
        Hashtable of container entries, or empty hashtable if no registry exists
    #>
    [CmdletBinding()]
    param()

    $registryPath = Get-AgentContainerRegistryPath
    if (-not (Test-Path -LiteralPath $registryPath)) {
        return @{}
    }

    try {
        $content = Get-Content -LiteralPath $registryPath -Raw
        if (-not $content -or $content.Trim() -eq '') {
            return @{}
        }
        $registry = $content | ConvertFrom-Json -AsHashtable
        return $registry ?? @{}
    } catch {
        Write-BuildMessage -Type Warning -Message "Failed to read container registry: $($_.Exception.Message)"
        return @{}
    }
}

function Register-AgentContainer {
    <#
    .SYNOPSIS
        Register an agent container in the registry
    .PARAMETER ContainerName
        Sanitized container name (e.g., 'chore-refactortestsetup')
    .PARAMETER Branch
        Original git branch name (e.g., 'chore/refactortestsetup')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [string]$Branch
    )

    $registryPath = Get-AgentContainerRegistryPath
    $registryDir = Split-Path -Parent $registryPath
    Ensure-Directory -Path $registryDir

    $registry = Get-RegisteredAgentContainers
    $now = (Get-Date).ToString('o')

    $registry[$ContainerName] = @{
        branch      = $Branch
        repoPath    = Get-GitRepoIdentifier
        createdAt   = $now
        lastUsedAt  = $now
    }

    $registry | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $registryPath -Encoding UTF8
    Write-BuildMessage -Type Detail -Message "Registered container '$ContainerName' for branch '$Branch'"
}

function Update-AgentContainerUsage {
    <#
    .SYNOPSIS
        Update the lastUsedAt timestamp for a container
    .PARAMETER ContainerName
        Container name to update
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName
    )

    $registryPath = Get-AgentContainerRegistryPath
    if (-not (Test-Path -LiteralPath $registryPath)) {
        return  # No registry, nothing to update
    }

    $registry = Get-RegisteredAgentContainers
    if (-not $registry.ContainsKey($ContainerName)) {
        return  # Container not registered (e.g., bctest)
    }

    $registry[$ContainerName].lastUsedAt = (Get-Date).ToString('o')
    $registry | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $registryPath -Encoding UTF8
    Write-BuildMessage -Type Detail -Message "Updated usage timestamp for container '$ContainerName'"
}

function Unregister-AgentContainer {
    <#
    .SYNOPSIS
        Remove a container from the registry
    .PARAMETER ContainerName
        Container name to remove
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName
    )

    $registryPath = Get-AgentContainerRegistryPath
    if (-not (Test-Path -LiteralPath $registryPath)) {
        return
    }

    $registry = Get-RegisteredAgentContainers
    if ($registry.ContainsKey($ContainerName)) {
        $registry.Remove($ContainerName)
        $registry | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $registryPath -Encoding UTF8
        Write-BuildMessage -Type Detail -Message "Unregistered container '$ContainerName'"
    }
}

function Get-GitRepoIdentifier {
    <#
    .SYNOPSIS
        Get a unique identifier for the current git clone
    .DESCRIPTION
        Returns the resolved path to the clone's common git directory, prefixed
        with 'local:'. Consistent across linked worktrees of one clone (they
        share the same .git/), distinct across separate clones of the same
        remote (each has its own .git/). Returns $null when not in a git repo.
    .OUTPUTS
        'local:<resolved-common-dir>' or $null
    #>
    [CmdletBinding()]
    param()

    $commonDir = git rev-parse --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $commonDir) {
        return $null
    }

    $resolved = Resolve-Path -LiteralPath $commonDir -ErrorAction SilentlyContinue
    if ($resolved) {
        return "local:$($resolved.Path.Replace('\', '/'))"
    }
    return "local:$($commonDir.Replace('\', '/'))"
}

function Test-GitBranchExists {
    <#
    .SYNOPSIS
        Check if a git branch exists locally
    .PARAMETER BranchName
        Branch name to check
    .OUTPUTS
        $true if branch exists, $false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BranchName
    )

    $result = git rev-parse --verify "refs/heads/$BranchName" 2>$null
    return $LASTEXITCODE -eq 0
}

function Get-OrphanedAgentContainers {
    <#
    .SYNOPSIS
        Get list of agent containers that should be pruned
    .DESCRIPTION
        Returns containers where:
        - Branch no longer exists locally (orphaned), OR
        - Branch exists but container unused for more than 7 days (stale)
    .PARAMETER StaleThresholdDays
        Number of days after which an unused container is considered stale (default: 7)
    .OUTPUTS
        Array of objects with ContainerName, Branch, Reason, LastUsedAt
    #>
    [CmdletBinding()]
    param(
        [int]$StaleThresholdDays = 7
    )

    $registry = Get-RegisteredAgentContainers
    $orphaned = @()
    $staleThreshold = (Get-Date).AddDays(-$StaleThresholdDays)
    $currentRepoPath = Get-GitRepoIdentifier

    foreach ($containerName in $registry.Keys) {
        $entry = $registry[$containerName]
        $branch = $entry.branch

        # Skip containers from other repos (only process containers belonging to current repo)
        if ($entry.repoPath -and $entry.repoPath -ne $currentRepoPath) {
            continue
        }

        if (-not (Test-GitBranchExists -BranchName $branch)) {
            $orphaned += [PSCustomObject]@{
                ContainerName = $containerName
                Branch        = $branch
                Reason        = 'orphaned'
                LastUsedAt    = $entry.lastUsedAt
            }
        } elseif ($entry.lastUsedAt) {
            # Handle both DateTime objects (from ConvertFrom-Json auto-conversion) and strings
            $lastUsed = if ($entry.lastUsedAt -is [DateTime]) {
                [DateTimeOffset]::new($entry.lastUsedAt)
            } else {
                [DateTimeOffset]::Parse($entry.lastUsedAt)
            }
            if ($lastUsed -lt $staleThreshold) {
                $orphaned += [PSCustomObject]@{
                    ContainerName = $containerName
                    Branch        = $branch
                    Reason        = 'stale'
                    LastUsedAt    = $entry.lastUsedAt
                }
            }
        }
    }

    return $orphaned
}

function Remove-OrphanedAgentContainers {
    <#
    .SYNOPSIS
        Remove orphaned and stale agent containers
    .DESCRIPTION
        Removes containers that are orphaned (branch deleted) or stale (unused > 7 days).
        Also removes associated publish-state files and registry entries.
    .PARAMETER WhatIf
        Preview what would be removed without making changes
    .PARAMETER StaleThresholdDays
        Number of days after which an unused container is considered stale (default: 7)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [int]$StaleThresholdDays = 7
    )

    $orphaned = @(Get-OrphanedAgentContainers -StaleThresholdDays $StaleThresholdDays)

    if ($orphaned.Count -eq 0) {
        Write-BuildMessage -Type Info -Message "No orphaned or stale containers found"
        return
    }

    Write-BuildMessage -Type Info -Message "Found $($orphaned.Count) container(s) to prune"

    foreach ($container in $orphaned) {
        $action = if ($container.Reason -eq 'orphaned') { "Removing orphaned" } else { "Removing stale" }
        $detail = if ($container.Reason -eq 'orphaned') {
            "branch '$($container.Branch)' no longer exists"
        } else {
            "last used: $($container.LastUsedAt)"
        }

        if ($PSCmdlet.ShouldProcess("$($container.ContainerName) ($detail)", $action)) {
            Write-BuildMessage -Type Step -Message "$action container '$($container.ContainerName)'"
            Write-BuildMessage -Type Detail -Message $detail

            # Remove docker container
            $existingContainer = docker ps -a --filter "name=^$($container.ContainerName)$" --format "{{.Names}}" 2>$null
            if ($existingContainer) {
                try {
                    Remove-BcContainer -containerName $container.ContainerName -ErrorAction Stop | Out-Null
                    Write-BuildMessage -Type Success -Message "Container removed"
                } catch {
                    Write-BuildMessage -Type Warning -Message "Remove-BcContainer failed; using docker rm -f"
                    docker rm -f $container.ContainerName 2>$null | Out-Null
                }

                # Remove hosts entry
                try {
                    Remove-HostsEntry -Hostname $container.ContainerName
                } catch {
                    Write-BuildMessage -Type Warning -Message "Could not remove hosts entry: $($_.Exception.Message)"
                }
            } else {
                Write-BuildMessage -Type Detail -Message "Container not running (already removed)"
            }

            # Remove publish-state files for this container
            $cacheRoot = Get-SymbolCacheRoot
            if (Test-Path -LiteralPath $cacheRoot) {
                $stateFiles = Get-ChildItem -Path $cacheRoot -Recurse -Filter "publish-state.$($container.ContainerName).json" -ErrorAction SilentlyContinue
                foreach ($stateFile in $stateFiles) {
                    Remove-Item -LiteralPath $stateFile.FullName -Force
                    Write-BuildMessage -Type Detail -Message "Removed publish state: $($stateFile.Name)"
                }
            }

            # Unregister from registry
            Unregister-AgentContainer -ContainerName $container.ContainerName
        }
    }
}

function Ensure-BCAgentContainer {
    <#
    .SYNOPSIS
        Ensure BC agent container exists and is healthy, creating if needed
    .DESCRIPTION
        Checks if the container exists and is healthy. If unhealthy, waits and retries.
        If container is missing or persistently unhealthy, invokes new-agent-container.ps1
        to create or recreate it.
    .PARAMETER ContainerName
        Name of the container to ensure
    .PARAMETER MaxHealthRetries
        Maximum retries waiting for unhealthy container to recover (default: 5)
    .PARAMETER RetryDelaySeconds
        Delay between health check retries (default: 2)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [int]$MaxHealthRetries = 5,

        [int]$RetryDelaySeconds = 2
    )

    Write-BuildHeader "Agent Container Check"
    Write-BuildMessage -Type Info -Message "Target Container: $ContainerName"

    # Quick check: container exists and healthy?
    if (Test-BCAgentContainerHealthy -ContainerName $ContainerName) {
        Write-BuildMessage -Type Success -Message "Container is running and healthy"
        return
    }

    # Container exists but not healthy? Wait and retry
    $existingContainer = docker ps -a --filter "name=^${ContainerName}$" --format "{{.Names}}" 2>$null
    if ($existingContainer) {
        Write-BuildMessage -Type Warning -Message "Container '$ContainerName' exists but is not healthy, waiting..."

        for ($i = 1; $i -le $MaxHealthRetries; $i++) {
            Start-Sleep -Seconds $RetryDelaySeconds

            if (Test-BCAgentContainerHealthy -ContainerName $ContainerName) {
                Write-BuildMessage -Type Success -Message "Container '$ContainerName' became healthy after $i retries"
                return
            }

            $health = docker inspect $ContainerName --format '{{.State.Health.Status}}' 2>$null
            Write-BuildMessage -Type Detail -Message "Health check $i/$MaxHealthRetries : $health"
        }

        Write-BuildMessage -Type Warning -Message "Container '$ContainerName' did not recover, will recreate"
    }

    # Container missing or persistently unhealthy - create via new-agent-container.ps1
    Write-BuildMessage -Type Step -Message "Creating container '$ContainerName' via new-agent-container.ps1"

    $scriptPath = Join-Path $PSScriptRoot 'new-agent-container.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "new-agent-container.ps1 not found at: $scriptPath"
    }

    try {
        & $scriptPath -AgentName $ContainerName
        if ($LASTEXITCODE -ne 0) {
            throw "new-agent-container.ps1 failed with exit code $LASTEXITCODE"
        }
    } finally {
        # No guard cleanup needed - command scripts don't use guards
    }

    # Verify container is now healthy
    if (-not (Test-BCAgentContainerHealthy -ContainerName $ContainerName)) {
        throw "Container '$ContainerName' is not healthy after creation"
    }

    Write-BuildMessage -Type Success -Message "Container '$ContainerName' is ready"
}

function Clear-TestTelemetryLogs {
    <#
    .SYNOPSIS
        Clear test telemetry log files from container
    .DESCRIPTION
        Removes all test-telemetry-*.jsonl files from container temporary paths
        and consolidated test-telemetry.jsonl from shared folder.
        Non-fatal operation; warnings logged if cleanup fails.
    .PARAMETER ContainerName
        Name of the BC container. If not specified, uses ALBT_BC_CONTAINER_NAME
        environment variable or 'bcserver' as default.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ContainerName
    )

    # Resolve from parameter, git branch, or fallback to bctest
    if (-not $ContainerName) {
        try {
            $ContainerName = Get-BCAgentContainerName
        } catch {
            $ContainerName = 'bctest'
        }
    }

    Write-BuildMessage -Type Step -Message "Clearing test telemetry logs"
    Write-BuildMessage -Type Detail -Message "Container: $ContainerName"

    try {
        $result = Invoke-ScriptInBcContainer -containerName $ContainerName -scriptblock {
            # Dynamically find NST service temp path (where TemporaryPath() actually points)
            # Search pattern: C:\ProgramData\Microsoft\Microsoft Dynamics NAV\{version}\Server\{instance}\users\default\*\TEMP\
            $nstBasePath = "C:\ProgramData\Microsoft\Microsoft Dynamics NAV"
            $filesRemoved = 0

            if (Test-Path $nstBasePath) {
                # Find all TEMP folders under NST service user directories
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

            @{
                FilesRemoved = $filesRemoved
            }
        }

        Write-BuildMessage -Type Detail -Message "Sequential files removed: $($result.FilesRemoved)"
        Write-BuildMessage -Type Success -Message "Test telemetry logs cleared"

        return [PSCustomObject]$result

    } catch {
        Write-BuildMessage -Type Warning -Message "Failed to clear telemetry logs: $_"
        return [PSCustomObject]@{
            FilesRemoved = 0
        }
    }
}

function Merge-TestTelemetryLogs {
    <#
    .SYNOPSIS
        Consolidate test telemetry log files into single file
    .DESCRIPTION
        Finds all test-telemetry-*.jsonl files in container temporary paths,
        sorts by name (preserving sequential order), and concatenates into
        test-telemetry.jsonl in shared folder.
        Non-fatal operation; warnings logged if no files found or merge fails.
    .PARAMETER ContainerName
        Name of the BC container. If not specified, uses ALBT_BC_CONTAINER_NAME
        environment variable or 'bcserver' as default.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ContainerName
    )

    # Resolve from parameter, git branch, or fallback to bctest
    if (-not $ContainerName) {
        try {
            $ContainerName = Get-BCAgentContainerName
        } catch {
            $ContainerName = 'bctest'
        }
    }

    Write-BuildMessage -Type Step -Message "Consolidating test telemetry logs"
    Write-BuildMessage -Type Detail -Message "Container: $ContainerName"

    try {
        $result = Invoke-ScriptInBcContainer -containerName $ContainerName -scriptblock {
            # Dynamically find NST service temp path (where TemporaryPath() actually points)
            # Search pattern: C:\ProgramData\Microsoft\Microsoft Dynamics NAV\{version}\Server\{instance}\users\default\*\TEMP\
            $nstBasePath = "C:\ProgramData\Microsoft\Microsoft Dynamics NAV"

            # Find all telemetry files
            $allFiles = @()
            if (Test-Path $nstBasePath) {
                # Find all TEMP folders under NST service user directories
                $tempFolders = Get-ChildItem -Path $nstBasePath -Filter "TEMP" -Recurse -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match "\\Server\\.*\\users\\default\\.*\\TEMP$" }

                foreach ($tempFolder in $tempFolders) {
                    $files = Get-ChildItem -Path $tempFolder.FullName -Filter "test-telemetry-*.jsonl" -File -ErrorAction SilentlyContinue
                    $allFiles += $files
                }
            }

            if ($allFiles.Count -eq 0) {
                return @{
                    Success = $false
                    FileCount = 0
                    TotalSize = 0
                    Message = "No telemetry files found"
                }
            }

            # Sort by name to preserve sequential order
            $sortedFiles = $allFiles | Sort-Object Name

            # Concatenate to shared folder
            $outputPath = "c:\run\my\test-telemetry.jsonl"
            $totalSize = 0

            foreach ($file in $sortedFiles) {
                Get-Content -Path $file.FullName -Raw | Add-Content -Path $outputPath -NoNewline
                $totalSize += $file.Length
            }

            @{
                Success = $true
                FileCount = $sortedFiles.Count
                TotalSize = $totalSize
                OutputPath = $outputPath
            }
        }

        if ($result.Success) {
            Write-BuildMessage -Type Detail -Message "Files consolidated: $($result.FileCount)"
            Write-BuildMessage -Type Detail -Message "Total size: $([math]::Round($result.TotalSize / 1KB, 2)) KB"
            Write-BuildMessage -Type Success -Message "Test telemetry logs consolidated"
        } else {
            Write-BuildMessage -Type Warning -Message $result.Message
        }

        return [PSCustomObject]$result

    } catch {
        Write-BuildMessage -Type Warning -Message "Failed to consolidate telemetry logs: $_"
        return [PSCustomObject]@{
            Success = $false
            FileCount = 0
            TotalSize = 0
            Message = $_.ToString()
        }
    }
}

function Copy-TestTelemetryLogs {
    <#
    .SYNOPSIS
        Copy consolidated telemetry logs to local test results folder
    .DESCRIPTION
        Copies test-telemetry.jsonl from shared folder to local .output/TestResults/telemetry.jsonl.
        Cleans up shared file after successful copy.
        Non-fatal operation; warnings logged if file not found or copy fails.
    .PARAMETER SharedFolder
        Path to shared folder containing test-telemetry.jsonl (mandatory).
    .PARAMETER LocalResultsPath
        Path to local .output/TestResults folder where telemetry.jsonl will be saved (mandatory).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SharedFolder,

        [Parameter(Mandatory = $true)]
        [string]$LocalResultsPath
    )

    Write-BuildMessage -Type Step -Message "Copying telemetry logs to local folder"

    $sharedFile = Join-Path $SharedFolder "test-telemetry.jsonl"
    $localFile = Join-Path $LocalResultsPath "telemetry.jsonl"

    if (Test-Path -LiteralPath $sharedFile) {
        Write-BuildMessage -Type Detail -Message "Source: $sharedFile"
        Write-BuildMessage -Type Detail -Message "Target: $localFile"

        try {
            Copy-Item -LiteralPath $sharedFile -Destination $localFile -Force

            if (Test-Path -LiteralPath $localFile) {
                Write-BuildMessage -Type Success -Message "Telemetry logs copied successfully"

                # Clean up shared location
                Remove-Item -LiteralPath $sharedFile -Force -ErrorAction SilentlyContinue

                return [PSCustomObject]@{
                    Success = $true
                    LocalPath = $localFile
                }
            } else {
                Write-BuildMessage -Type Warning -Message "Failed to copy telemetry logs to local location"
                return [PSCustomObject]@{
                    Success = $false
                    LocalPath = $null
                }
            }
        } catch {
            Write-BuildMessage -Type Warning -Message "Failed to copy telemetry logs: $_"
            return [PSCustomObject]@{
                Success = $false
                LocalPath = $null
            }
        }
    } else {
        Write-BuildMessage -Type Warning -Message "Telemetry log file not found in shared location: $sharedFile"
        Write-BuildMessage -Type Detail -Message "Logs may not have been generated or consolidation failed"
        return [PSCustomObject]@{
            Success = $false
            LocalPath = $null
        }
    }
}

function Import-BCContainerHelper {
    <#
    .SYNOPSIS
        Import BcContainerHelper PowerShell module (idempotent)
    .DESCRIPTION
        Centralized import of BcContainerHelper with error handling and validation.
        Skips import if module is already loaded to avoid repeated initialization overhead.
        Provides helpful error messages if the module is not installed.
    #>
    [CmdletBinding()]
    param()

    # Skip if already loaded - avoids ~22s reload overhead per call
    if (Get-Module -Name BcContainerHelper) {
        Write-Verbose "BcContainerHelper already loaded, skipping import"
        return
    }

    if (Get-Module -Name BcContainerHelper -ListAvailable) {
        # Use -ArgumentList $true for silent import to avoid false permission warning
        # when PowerShell is spawned from bash (Claude Code, WSL, Git Bash)
        # See: https://github.com/microsoft/navcontainerhelper/issues/4078
        Import-Module BcContainerHelper -ArgumentList $true -DisableNameChecking -ErrorAction Stop
        Write-BuildMessage -Type Detail -Message "BcContainerHelper module loaded"
    } else {
        Write-BuildMessage -Type Error -Message "BcContainerHelper PowerShell module not found."
        Write-BuildMessage -Type Detail -Message "Install from: Install-Module BcContainerHelper -Scope CurrentUser"
        Write-BuildMessage -Type Detail -Message "Or see: https://github.com/microsoft/navcontainerhelper"
        throw "BcContainerHelper module is required for BC container operations."
    }
}

# =============================================================================
# GitHub CLI Integration
# =============================================================================

function Test-GhAuthentication {
    <#
    .SYNOPSIS
        Check if GitHub CLI (gh) is authenticated
    .OUTPUTS
        $true if authenticated, $false otherwise
    #>
    try {
        $null = gh auth status 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-GhHostAuthentication {
    <#
    .SYNOPSIS
        Check if GitHub CLI (gh) is authenticated to a specific host.
    .PARAMETER HostName
        Host to check (e.g. github.com, mytenant.ghe.com).
    .OUTPUTS
        $true if authenticated to that host, $false otherwise.
    #>
    param([Parameter(Mandatory)][string]$HostName)
    try {
        $null = gh auth status --hostname $HostName 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Get-RepoFromUrl {
    <#
    .SYNOPSIS
        Parse a Git repository URL into a structured spec.
    .DESCRIPTION
        Accepts HTTPS (github.com, *.ghe.com, custom hosts), SSH (git@host:owner/repo),
        and bare owner/repo forms. A trailing .git is stripped. Bare form is treated as
        github.com. Throws on unparseable input.
    .PARAMETER Url
        Repository URL or owner/repo slug.
    .OUTPUTS
        [pscustomobject] with HostName, Owner, Repo properties.
    .EXAMPLE
        Get-RepoFromUrl 'https://mytenant.ghe.com/acme/widget.git'
        # HostName=mytenant.ghe.com  Owner=acme  Repo=widget
    #>
    param([Parameter(Mandatory)][string]$Url)

    # SSH: git@HOST:OWNER/REPO[.git]
    if ($Url -match '^git@([^:]+):([^/]+)/([^/]+?)(?:\.git)?$') {
        return [pscustomobject]@{ HostName = $Matches[1]; Owner = $Matches[2]; Repo = $Matches[3] }
    }

    # HTTPS: https?://HOST/OWNER/REPO[.git]
    if ($Url -match '^https?://([^/]+)/([^/]+)/([^/]+?)(?:\.git)?$') {
        return [pscustomobject]@{ HostName = $Matches[1]; Owner = $Matches[2]; Repo = $Matches[3] }
    }

    # Bare: OWNER/REPO[.git] -> assume github.com. Segments may contain dots (e.g. vscode.dev).
    if ($Url -match '^([^/:@\s]+)/([^/:@\s]+?)(?:\.git)?$') {
        return [pscustomobject]@{ HostName = 'github.com'; Owner = $Matches[1]; Repo = $Matches[2] }
    }

    throw "Unrecognized repository URL format: '$Url'"
}

function Get-ReleaseAppFiles {
    <#
    .SYNOPSIS
        Download and extract .app files from a GitHub release
    .DESCRIPTION
        Downloads *Apps*.zip assets from a release, extracts them, and returns
        paths to the .app files found inside. Excludes TestApps archives by default.
    .PARAMETER ReleaseTag
        Release tag to download (e.g., "27.4.0" or "latest")
    .PARAMETER Repo
        Repository slug passed to `gh release download --repo`. Accepts both
        two-segment "owner/repo" (assumed github.com) and three-segment
        "host/owner/repo" (e.g. "mytenant.ghe.com/acme/widget") forms.
        Optional; if omitted, gh uses the current repository.
    .PARAMETER OutputDir
        Directory to extract files to
    .PARAMETER ExcludeTest
        Exclude test app files (default: $true)
    .OUTPUTS
        Array of FileInfo objects for .app files
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ReleaseTag,

        [string]$Repo,

        [Parameter(Mandatory)]
        [string]$OutputDir,

        [bool]$ExcludeTest = $true
    )

    # Build gh arguments
    $ghArgs = @('release', 'download', '--pattern', '*Apps*.zip', '--dir', $OutputDir)
    if ($Repo) {
        $ghArgs += @('--repo', $Repo)
    }
    if ($ReleaseTag -ne 'latest') {
        $ghArgs += $ReleaseTag
    }

    $ghOutput = & gh @ghArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-BuildMessage -Type Warning -Message "Failed to download release: $ghOutput"
        return ,@()
    }

    # Find downloaded zip files (exclude TestApps if requested)
    $zipFilter = if ($ExcludeTest) {
        { $_.Name -notlike '*TestApps*' }
    } else {
        { $true }
    }

    $zipFiles = @(Get-ChildItem -Path $OutputDir -Filter '*.zip' -ErrorAction SilentlyContinue |
                  Where-Object $zipFilter)

    if ($zipFiles.Count -eq 0) {
        Write-BuildMessage -Type Warning -Message "No *Apps*.zip assets found in release"
        return ,@()
    }

    $appFiles = @()

    foreach ($zipFile in $zipFiles) {
        Write-BuildMessage -Type Detail -Message "Extracting: $($zipFile.Name)"
        $extractDir = Join-Path $OutputDir ($zipFile.BaseName)
        Expand-Archive -Path $zipFile.FullName -DestinationPath $extractDir -Force

        # Find .app files (exclude test apps if requested)
        $appFilter = if ($ExcludeTest) {
            { $_.Name -notlike '*Test*' }
        } else {
            { $true }
        }

        $foundApps = @(Get-ChildItem -Path $extractDir -Filter '*.app' -Recurse -ErrorAction SilentlyContinue |
                       Where-Object $appFilter)
        $appFiles += $foundApps
    }

    return ,$appFiles
}

# =============================================================================
# AL-Go Integration
# =============================================================================

function Get-AlGoSettingsPath {
    <#
    .SYNOPSIS
        Locate .AL-Go/settings.json in workspace
    .PARAMETER WorkspaceRoot
        Root directory of the workspace (defaults to current directory)
    .OUTPUTS
        Path to settings.json or $null if not found
    #>
    param([string]$WorkspaceRoot = '.')

    $settingsPath = Join-Path $WorkspaceRoot '.AL-Go/settings.json'
    if (Test-Path $settingsPath) {
        return $settingsPath
    }
    return $null
}

function Get-AlGoDependencyProbingPaths {
    <#
    .SYNOPSIS
        Read appDependencyProbingPaths from .AL-Go/settings.json
    .PARAMETER WorkspaceRoot
        Root directory of the workspace (defaults to current directory)
    .OUTPUTS
        Array of dependency objects, or empty array if none found
    #>
    param([string]$WorkspaceRoot = '.')

    $settingsPath = Get-AlGoSettingsPath -WorkspaceRoot $WorkspaceRoot
    if (-not $settingsPath) {
        return ,@()
    }

    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($settings.PSObject.Properties.Match('appDependencyProbingPaths').Count -gt 0 -and $settings.appDependencyProbingPaths) {
            return ,@($settings.appDependencyProbingPaths)
        }
    } catch {
        Write-BuildMessage -Type Warning -Message "Failed to parse .AL-Go/settings.json: $_"
    }

    return ,@()
}

function Install-AlGoDependencies {
    <#
    .SYNOPSIS
        Download and install dependencies from AL-Go settings to BC container
    .DESCRIPTION
        Reads appDependencyProbingPaths from .AL-Go/settings.json, downloads release
        artifacts using GitHub CLI (gh), extracts .app files, and publishes them
        to the specified BC container. Supports github.com and *.ghe.com (and other
        custom-host) probing paths in the same settings.json. Authentication is
        checked per host so a gap on one host does not block the others.
    .PARAMETER ContainerName
        Name of the BC container
    .PARAMETER Credential
        Credential for BC container authentication
    .PARAMETER WorkspaceRoot
        Root directory of the workspace (defaults to current directory)
    .OUTPUTS
        [pscustomobject] with Installed (apps published), Failed (probing paths
        that failed at any stage), and ProbingPaths (total configured).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ContainerName,

        [Parameter(Mandatory)]
        [pscredential]$Credential,

        [string]$WorkspaceRoot = '.'
    )

    $probingPaths = Get-AlGoDependencyProbingPaths -WorkspaceRoot $WorkspaceRoot
    if (-not $probingPaths -or $probingPaths.Count -eq 0) {
        Write-BuildMessage -Type Detail -Message "No dependency probing paths configured"
        return [pscustomobject]@{ Installed = 0; Failed = 0; ProbingPaths = 0 }
    }

    $installedCount = 0
    $failedCount = 0
    $tempDir = New-TemporaryDirectory

    try {
        foreach ($dependency in $probingPaths) {
            try {
                $spec = Get-RepoFromUrl $dependency.repo
            } catch {
                Write-BuildMessage -Type Warning -Message "Unparseable repo URL '$($dependency.repo)': $_"
                $failedCount++
                continue
            }

            $repoDisplay = "$($spec.Owner)/$($spec.Repo)"
            Write-BuildMessage -Type Step -Message "Processing dependency: $repoDisplay ($($spec.HostName))"

            if (-not (Test-GhHostAuthentication -HostName $spec.HostName)) {
                Write-BuildMessage -Type Warning -Message "Not authenticated to $($spec.HostName). Run: gh auth login --hostname $($spec.HostName) — skipping $repoDisplay"
                $failedCount++
                continue
            }

            # Determine release tag based on version
            $releaseTag = if ($dependency.version -eq 'latest' -or -not $dependency.version) { 'latest' } else { $dependency.version }

            # Windows-safe download dir: host dots collapsed to underscores
            $downloadDir = Join-Path $tempDir ("{0}_{1}_{2}" -f $spec.HostName.Replace('.', '_'), $spec.Owner, $spec.Repo)
            New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

            try {
                Write-BuildMessage -Type Detail -Message "Downloading release '$releaseTag' from $repoDisplay"

                # Three-segment --repo routes gh to the named host (github.com, *.ghe.com, custom).
                $repoArg = "$($spec.HostName)/$($spec.Owner)/$($spec.Repo)"
                $ghArgs = @('release', 'download', '--repo', $repoArg, '--pattern', '*Apps*.zip', '--dir', $downloadDir)
                if ($releaseTag -ne 'latest') {
                    $ghArgs += $releaseTag
                }

                $ghOutput = & gh @ghArgs 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $firstLine = ($ghOutput | Select-Object -First 1) -as [string]
                    Write-BuildMessage -Type Warning -Message "gh release download failed for $repoDisplay on $($spec.HostName) (exit $LASTEXITCODE): $firstLine"
                    $failedCount++
                    continue
                }

                # Find downloaded zip files (exclude TestApps)
                $zipFiles = @(Get-ChildItem -Path $downloadDir -Filter '*.zip' -ErrorAction SilentlyContinue |
                              Where-Object { $_.Name -notlike '*TestApps*' })
                if ($zipFiles.Count -eq 0) {
                    Write-BuildMessage -Type Warning -Message "No *Apps*.zip assets found in release from $repoDisplay"
                    $failedCount++
                    continue
                }

                $publishSucceeded = $false
                $publishFailed = $false

                # Extract and publish each zip
                foreach ($zipFile in $zipFiles) {
                    Write-BuildMessage -Type Detail -Message "Extracting: $($zipFile.Name)"
                    $extractDir = Join-Path $downloadDir ($zipFile.BaseName)
                    Expand-Archive -Path $zipFile.FullName -DestinationPath $extractDir -Force

                    # Find all .app files
                    $appFiles = @(Get-ChildItem -Path $extractDir -Filter '*.app' -Recurse -ErrorAction SilentlyContinue)
                    foreach ($appFile in $appFiles) {
                        Write-BuildMessage -Type Detail -Message "Publishing: $($appFile.Name)"
                        try {
                            Publish-BcContainerApp -containerName $ContainerName `
                                                   -appFile $appFile.FullName `
                                                   -skipVerification `
                                                   -sync `
                                                   -install `
                                                   -credential $Credential

                            Write-BuildMessage -Type Success -Message "Installed: $($appFile.Name)"
                            $installedCount++
                            $publishSucceeded = $true
                        } catch {
                            Write-BuildMessage -Type Warning -Message "Failed to publish $($appFile.Name) from $repoDisplay : $_"
                            $publishFailed = $true
                        }
                    }
                }

                # Count probing path as failed if any publish failed or nothing was installed.
                if ($publishFailed -or -not $publishSucceeded) {
                    $failedCount++
                }
            } catch {
                Write-BuildMessage -Type Warning -Message "Error processing dependency $repoDisplay : $_"
                $failedCount++
            }
        }
    } finally {
        # Clean up temp directory
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    return [pscustomobject]@{
        Installed    = $installedCount
        Failed       = $failedCount
        ProbingPaths = $probingPaths.Count
    }
}

# =============================================================================
# Incremental Publish State Management
# =============================================================================

function Get-ContainerCreatedTime {
    <#
    .SYNOPSIS
        Get the creation timestamp of a BC Docker container
    .PARAMETER ContainerName
        Name of the container to check
    .OUTPUTS
        DateTimeOffset or $null if container doesn't exist
    #>
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
    <#
    .SYNOPSIS
        Get path to publish state file for an app
    .PARAMETER AppJson
        Parsed app.json object
    .PARAMETER ContainerName
        BC container name (used to isolate state per container)
    #>
    param(
        $AppJson,
        [string]$ContainerName
    )

    $cacheRoot = Get-SymbolCacheRoot
    $publisherDir = Join-Path -Path $cacheRoot -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.publisher)
    $appDirPath = Join-Path -Path $publisherDir -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.name)
    $cacheDir = Join-Path -Path $appDirPath -ChildPath (ConvertTo-SafePathSegment -Value $AppJson.id)

    # Create directory if needed
    Ensure-Directory -Path $cacheDir

    $containerSafe = ConvertTo-SafePathSegment -Value $ContainerName
    return Join-Path -Path $cacheDir -ChildPath "publish-state.$containerSafe.json"
}

function Get-AppFileHash {
    <#
    .SYNOPSIS
        Calculate SHA256 hash of an .app file
    .PARAMETER AppFilePath
        Path to the .app file
    #>
    param([string]$AppFilePath)

    if (-not (Test-Path -LiteralPath $AppFilePath)) { return $null }
    return (Get-FileHash -LiteralPath $AppFilePath -Algorithm SHA256).Hash
}

function Get-DirectoryHash {
    <#
    .SYNOPSIS
        Calculate a hash of a directory's source files
    .PARAMETER Path
        Directory to hash
    #>
    param([string]$Path)

    if (-not (Test-Path $Path)) { return "" }

    # Include relevant source files, exclude build artifacts
    $files = Get-ChildItem -Path $Path -Recurse -File -Include *.al,*.xml,*.json,*.rdlc,*.docx,*.xlsx,*.xlf |
             Where-Object { $_.FullName -notmatch '[\\/](bin|obj|\.git|\.vscode|TestResults)[\\/]' } |
             Sort-Object FullName

    if ($files.Count -eq 0) { return "" }

    $content = $files | ForEach-Object {
        $hash = Get-FileHash -Path $_.FullName -Algorithm SHA256
        # Use relative path to be location-agnostic
        $relPath = $_.FullName.Substring($Path.Length).TrimStart('\', '/')
        "$relPath=$($hash.Hash)"
    }

    # Hash the combined string of file paths and hashes
    $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes(($content -join "`n")))
    $hash = Get-FileHash -InputStream $stream -Algorithm SHA256
    return $hash.Hash
}

function Test-AppNeedsPublish {
    <#
    .SYNOPSIS
        Check if an app needs to be republished
    .DESCRIPTION
        Compares current source directory hash and container creation time against stored state.
        Returns $true if publish is needed, $false if sources are unchanged.
    .PARAMETER AppDir
        Path to the app source directory
    .PARAMETER AppJson
        Parsed app.json object
    .PARAMETER ContainerName
        BC container name
    .PARAMETER Force
        Force republish even if unchanged
    #>
    param(
        [string]$AppDir,
        $AppJson,
        [string]$ContainerName,
        [switch]$Force
    )

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
        # Use System.Text.Json to preserve ISO date strings (ConvertFrom-Json auto-converts to DateTime)
        $jsonText = Get-Content -LiteralPath $statePath -Raw
        $state = [System.Text.Json.JsonSerializer]::Deserialize[System.Collections.Generic.Dictionary[string,string]]($jsonText)
    } catch {
        Write-BuildMessage -Type Detail -Message "Failed to read publish state: $($_.Exception.Message)"
        return $true
    }

    # Check container recreation
    $containerCreated = Get-ContainerCreatedTime -ContainerName $ContainerName
    if ($containerCreated) {
        $stateContainerTime = if ($state.containerCreated) { [DateTimeOffset]::Parse($state.containerCreated) } else { $null }
        if (-not $stateContainerTime -or $containerCreated -gt $stateContainerTime) {
            Write-BuildMessage -Type Detail -Message "Container recreated since last publish"
            return $true
        }
    }

    # Check source hash
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
    <#
    .SYNOPSIS
        Save publish state after successful publish
    .PARAMETER AppDir
        Path to the app source directory
    .PARAMETER AppJson
        Parsed app.json object
    .PARAMETER ContainerName
        BC container name
    #>
    param(
        [string]$AppDir,
        $AppJson,
        [string]$ContainerName
    )

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
    <#
    .SYNOPSIS
        Clear publish state for an app (forces republish next time)
    .PARAMETER AppJson
        Parsed app.json object
    .PARAMETER ContainerName
        BC container name
    #>
    param(
        $AppJson,
        [string]$ContainerName
    )

    $statePath = Get-PublishStatePath -AppJson $AppJson -ContainerName $ContainerName
    if (Test-Path -LiteralPath $statePath) {
        Remove-Item -LiteralPath $statePath -Force
        Write-BuildMessage -Type Detail -Message "Publish state cleared"
    }
}

# =============================================================================
# Build Timing History
# =============================================================================

function Get-GitBranchName {
    try {
        $branch = & git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $branch) { return ([string]$branch).Trim() }
    } catch {
        # git missing or not a repo — branch stays unrecorded
    }
    return $null
}

function Get-GitRepoRoot {
    try {
        $root = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $root) { return [IO.Path]::GetFullPath(([string]$root).Trim()) }
    } catch {
        # git missing or not a repo — fall back to cwd
    }
    return (Get-Location).Path
}

function Get-GateMetricsGlobalPath {
    if ($env:ALBT_GATE_METRICS_GLOBAL_PATH) { return $env:ALBT_GATE_METRICS_GLOBAL_PATH }
    return Join-Path ([Environment]::GetFolderPath('UserProfile')) '.al-build' 'gate-metrics.jsonl'
}

function Get-DirtyFileCounts {
    <#
    .SYNOPSIS
        Buckets dirty workspace files into app / tests / other counts.
    .DESCRIPTION
        Reads `git status --porcelain` (or the supplied lines) and counts
        changed files — modified, added, deleted, renamed, and untracked —
        by location: under the main app dir, under any test app dir, or
        elsewhere. This is the workspace evidence gate metrics record at gate
        time; phase attribution is derived from it at report time instead of
        trusting a caller-supplied tag.
    .PARAMETER AppDir
        Main app directory (repo-relative, e.g. 'app').
    .PARAMETER TestDirs
        Test app directories (repo-relative), including the unit test app.
    .PARAMETER StatusLines
        Porcelain lines to classify (for tests). Omit to run git.
    .OUTPUTS
        Hashtable @{ app; tests; other } or $null when git is unavailable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDir,

        [string[]]$TestDirs = @(),

        [string[]]$StatusLines
    )

    if (-not $PSBoundParameters.ContainsKey('StatusLines')) {
        try {
            $StatusLines = @(& git status --porcelain 2>$null)
            if ($LASTEXITCODE -ne 0) { return $null }
        } catch {
            return $null
        }
    }

    # Porcelain paths are repo-root-relative; config dirs arrive absolute
    # (Get-BuildConfig resolves them). Strip the repo root so prefixes match.
    $repoRoot = [IO.Path]::GetFullPath((Get-GitRepoRoot))
    $normalizePrefix = {
        param([string]$Dir)
        $clean = $Dir.Trim()
        if (-not $clean) { return $null }
        if ([IO.Path]::IsPathRooted($clean)) {
            $full = [IO.Path]::GetFullPath($clean)
            if (-not $full.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) { return $null }
            $clean = $full.Substring($repoRoot.Length)
        }
        $clean = ($clean.Replace('\', '/') -replace '^(\./)+', '').Trim('/')
        if ($clean) { return "$clean/" }
        return $null
    }

    $appPrefix = & $normalizePrefix $AppDir
    $testPrefixes = @($TestDirs | ForEach-Object { & $normalizePrefix $_ } | Where-Object { $_ })

    $counts = @{ app = 0; tests = 0; other = 0 }
    foreach ($line in $StatusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -le 3) { continue }
        $path = $line.Substring(3)
        # Rename lines read 'old -> new'; the new location is the live file
        if ($path -match '\s->\s') { $path = ($path -split '\s->\s')[-1] }
        $path = $path.Trim().Trim('"').Replace('\', '/')
        if (-not $path) { continue }
        # Compiled artifacts are build output, not source evidence — a repo
        # that does not gitignore them must not look dirty after a compile
        if ($path.EndsWith('.app', [StringComparison]::OrdinalIgnoreCase)) { continue }

        if ($appPrefix -and $path.StartsWith($appPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            $counts.app++
        } elseif (@($testPrefixes | Where-Object { $path.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) {
            $counts.tests++
        } else {
            $counts.other++
        }
    }
    return $counts
}

function Save-BuildTimingEntry {
    <#
    .SYNOPSIS
        Saves a build timing entry to the history log
    .DESCRIPTION
        Appends one JSONL entry to the repo-local timing log, and mirrors the
        same entry (plus repo identity) to the user-level gate-metrics log so
        history survives .output wipes and aggregates across consumer repos.
        Gate/Outcome/Tests/Dirty/HeadSha are optional telemetry fields; entries
        written without them stay valid (legacy shape). Phase attribution is
        derived at report time from the recorded workspace evidence (Dirty),
        never from a caller-supplied tag.
    .PARAMETER Task
        The top-level task name (e.g., "test", "build")
    .PARAMETER Steps
        Hashtable of step names to elapsed seconds
    .PARAMETER TotalSeconds
        Optional total elapsed seconds (if not provided, calculated from steps)
    .PARAMETER Gate
        Optional gate scope: unit or full.
    .PARAMETER Outcome
        Optional run outcome: passed, failed, or error.
    .PARAMETER Tests
        Optional per-runner executed-test totals (runner name -> test count).
    .PARAMETER Dirty
        Optional dirty-workspace fingerprint captured at gate start
        (@{ app; tests; other } from Get-DirtyFileCounts).
    .PARAMETER HeadSha
        Optional short HEAD sha at gate time.
    .PARAMETER LogPath
        Path to the timing log file (default: .output/logs/build-timing.jsonl)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Task,

        [Parameter(Mandatory = $true)]
        [hashtable]$Steps,

        [double]$TotalSeconds = 0,

        [string]$Gate,

        [ValidateSet('passed', 'failed', 'error')]
        [string]$Outcome,

        [hashtable]$Tests,

        [hashtable]$Dirty,

        [string]$HeadSha,

        [string]$LogPath = ".output/logs/build-timing.jsonl"
    )

    # Ensure logs directory exists
    $logDir = Split-Path -Path $LogPath -Parent
    if ($logDir -and -not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Use provided total or calculate from steps
    $totalSeconds = if ($TotalSeconds -gt 0) { $TotalSeconds } else { ($Steps.Values | Measure-Object -Sum).Sum }

    # Format total time as mm:ss.f
    $totalFormatted = "{0}:{1:00}.{2}" -f [math]::Floor($totalSeconds / 60), [math]::Floor($totalSeconds % 60), [math]::Floor(($totalSeconds % 1) * 10)

    # Create entry object. Timestamp is culture-invariant: ':' in a format
    # string is the culture time separator (da-DK renders '.'), which breaks
    # round-tripping.
    $entry = [ordered]@{
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
        task      = $Task
    }
    if ($Gate) { $entry.gate = $Gate }
    if ($Outcome) { $entry.outcome = $Outcome }

    $branch = Get-GitBranchName
    if ($branch) { $entry.branch = $branch }
    if ($HeadSha) { $entry.headSha = $HeadSha }

    if ($Dirty) {
        $entry.dirty = [ordered]@{
            app   = [int]$Dirty.app
            tests = [int]$Dirty.tests
            other = [int]$Dirty.other
        }
    }

    if ($Tests -and $Tests.Count -gt 0) {
        $testsOrdered = [ordered]@{}
        foreach ($runner in ($Tests.Keys | Sort-Object)) {
            $testsOrdered[$runner] = $Tests[$runner]
        }
        $entry.tests = $testsOrdered
    }

    $entry.steps = [ordered]@{}
    $entry.total = $totalFormatted
    $entry.totalSec = [math]::Round($totalSeconds, 1)

    # Add steps sorted by execution order (alphabetically as fallback)
    foreach ($stepName in ($Steps.Keys | Sort-Object)) {
        $stepSeconds = $Steps[$stepName]
        $entry.steps[$stepName] = [math]::Round($stepSeconds, 1)
    }

    # Append to JSONL file
    $json = $entry | ConvertTo-Json -Compress -Depth 5
    Add-Content -Path $LogPath -Value $json -Encoding UTF8

    # Mirror to the user-level gate-metrics log. Never fail the build over
    # telemetry: warn and continue.
    try {
        $globalPath = Get-GateMetricsGlobalPath
        $globalDir = Split-Path -Path $globalPath -Parent
        if ($globalDir -and -not (Test-Path $globalDir)) {
            New-Item -ItemType Directory -Path $globalDir -Force -ErrorAction Stop | Out-Null
        }

        $repoRoot = Get-GitRepoRoot
        $mirrorEntry = [ordered]@{}
        foreach ($key in $entry.Keys) { $mirrorEntry[$key] = $entry[$key] }
        $mirrorEntry.repo = Split-Path -Path $repoRoot -Leaf
        $mirrorEntry.repoPath = $repoRoot

        $mirrorJson = $mirrorEntry | ConvertTo-Json -Compress -Depth 5
        Add-Content -Path $globalPath -Value $mirrorJson -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-BuildMessage -Type Warning -Message "Gate-metrics mirror write failed: $($_.Exception.Message)"
    }
}

function Show-BuildTimingHistory {
    <#
    .SYNOPSIS
        Displays recent build timing history
    .PARAMETER Count
        Number of recent entries to display (default: 5)
    .PARAMETER LogPath
        Path to the timing log file (default: .output/logs/build-timing.jsonl)
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 5,

        [string]$LogPath = ".output/logs/build-timing.jsonl"
    )

    if (-not (Test-Path $LogPath)) {
        return
    }

    # Read last N lines from the log
    $lines = @(Get-Content -Path $LogPath -Tail $Count -ErrorAction SilentlyContinue)
    if ($lines.Count -eq 0) {
        return
    }

    # Display header
    Write-BuildHeader "Build Timing History (Last $Count Runs)"

    # Parse and display entries (most recent first)
    $entries = @()
    foreach ($lineContent in $lines) {
        try {
            $entry = $lineContent | ConvertFrom-Json
            $entries += $entry
        } catch {
            continue
        }
    }

    # Reverse to show most recent first
    [array]::Reverse($entries)

    foreach ($entry in $entries) {
        # Format steps summary (show key steps, truncate if too long)
        $stepParts = @()
        $stepOrder = @('test-build', 'unpublish-test-app', 'test-publish', 'test-publish-test', 'test', 'build', 'publish')

        # Get step names from the entry - handle JSON object properties
        $stepNames = @()
        if ($null -ne $entry.steps) {
            try {
                $stepNames = @($entry.steps.PSObject.Properties | ForEach-Object { $_.Name })
            } catch {
                $stepNames = @()
            }
        }

        foreach ($stepName in $stepOrder) {
            if ($stepName -in $stepNames) {
                $sec = $entry.steps.$stepName
                $shortName = $stepName -replace '^test-', '' -replace '-test$', ''
                $stepParts += "{0}:{1}s" -f $shortName, $sec
            }
        }

        # Add any remaining steps not in the predefined order
        foreach ($stepName in $stepNames) {
            if ($stepName -notin $stepOrder) {
                $stepParts += "{0}:{1}s" -f $stepName, $entry.steps.$stepName
            }
        }

        $stepsSummary = $stepParts -join " "
        if ($stepsSummary.Length -gt 60) {
            $stepsSummary = $stepsSummary.Substring(0, 57) + "..."
        }

        # Display entry (use Write-Host directly as this is user-facing summary, not verbose logging)
        $outputLine = "{0} | {1,-11} | {2,7} | {3}" -f $entry.timestamp, $entry.task, $entry.total, $stepsSummary
        Write-Host $outputLine
    }

    # Show log file location
    Write-Host ""
    Write-Host "Full history: " -NoNewline -ForegroundColor DarkGray
    Write-Host $LogPath -ForegroundColor DarkGray
}

function Get-GateMetricsSummary {
    <#
    .SYNOPSIS
        Aggregates gate timing entries by workspace signature and gate.
    .DESCRIPTION
        Reads a build-timing / gate-metrics JSONL log and returns one row per
        signature × gate combination: run count, outcome counts, total minutes,
        median and p95 duration.

        The signature is derived from the dirty-workspace evidence recorded at
        gate time, never from a caller-supplied tag:
          prod-only — app files dirty, test apps clean. Mutation gates have
                      exactly this shape (/al-mutate proves a committed clean
                      baseline, then applies one production mutant).
          test-only — test app files dirty, app clean. RED-first runs.
          mixed     — both dirty. TDD inner-loop runs after the first GREEN.
          clean     — no app/test changes. Closeout and baseline runs.
          unknown   — entry predates evidence capture.

        Gate falls back from the task name for legacy entries ('unit-test' →
        unit, 'test' → full, anything else → '-'). Malformed lines are skipped.
    .PARAMETER LogPath
        JSONL log to read.
    .PARAMETER SinceDays
        Only include entries newer than N days. 0 = no filter.
    .PARAMETER Task
        Only include entries whose task is in this list. Empty = all tasks.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [int]$SinceDays = 0,

        [string[]]$Task
    )

    if (-not (Test-Path $LogPath)) { return @() }

    $cutoff = if ($SinceDays -gt 0) { (Get-Date).AddDays(-$SinceDays) } else { $null }

    function Get-EntryProperty {
        param($Object, [string]$Name)
        $prop = $Object.PSObject.Properties[$Name]
        if ($prop) { return $prop.Value }
        return $null
    }

    $entries = @()
    foreach ($line in @(Get-Content -Path $LogPath -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $e = $line | ConvertFrom-Json } catch { continue }
        if ($null -eq (Get-EntryProperty $e 'totalSec') -or $null -eq (Get-EntryProperty $e 'task')) { continue }
        if ($Task -and (Get-EntryProperty $e 'task') -notin $Task) { continue }
        if ($cutoff) {
            # Two accepted shapes: invariant ':' and legacy culture-written '.'
            # time separators (entries logged before the invariant fix).
            [datetime]$ts = [datetime]::MinValue
            $timestampFormats = [string[]]@('yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH.mm.ss')
            if (-not [datetime]::TryParseExact([string](Get-EntryProperty $e 'timestamp'), $timestampFormats, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$ts)) { continue }
            if ($ts -lt $cutoff) { continue }
        }
        $entries += $e
    }

    $groups = $entries | Group-Object -Property {
        $dirty = Get-EntryProperty $_ 'dirty'
        if ($null -eq $dirty) {
            $signature = 'unknown'
        } else {
            $appDirty = [int](Get-EntryProperty $dirty 'app')
            $testsDirty = [int](Get-EntryProperty $dirty 'tests')
            $signature = if ($appDirty -gt 0 -and $testsDirty -gt 0) { 'mixed' }
            elseif ($appDirty -gt 0) { 'prod-only' }
            elseif ($testsDirty -gt 0) { 'test-only' }
            else { 'clean' }
        }
        $gate = Get-EntryProperty $_ 'gate'
        if (-not $gate) {
            $gate = switch (Get-EntryProperty $_ 'task') {
                'unit-test' { 'unit' }
                'test' { 'full' }
                default { '-' }
            }
        }
        "$signature|$gate"
    }

    $rows = foreach ($group in $groups) {
        $signature, $gate = $group.Name -split '\|', 2
        $durations = @($group.Group | ForEach-Object { [double](Get-EntryProperty $_ 'totalSec') } | Sort-Object)
        $outcomes = @($group.Group | ForEach-Object { Get-EntryProperty $_ 'outcome' })
        $timestamps = @($group.Group | ForEach-Object { [string](Get-EntryProperty $_ 'timestamp') } | Sort-Object)

        # Nearest-rank percentile on the sorted durations
        $p50Index = [int][Math]::Max(0, [Math]::Ceiling(0.50 * $durations.Count) - 1)
        $p95Index = [int][Math]::Max(0, [Math]::Ceiling(0.95 * $durations.Count) - 1)

        [pscustomobject]@{
            Signature = $signature
            Gate      = $gate
            Runs      = $group.Count
            Passed    = @($outcomes | Where-Object { $_ -eq 'passed' }).Count
            Failed    = @($outcomes | Where-Object { $_ -eq 'failed' }).Count
            Errors    = @($outcomes | Where-Object { $_ -eq 'error' }).Count
            Untagged  = @($outcomes | Where-Object { -not $_ }).Count
            TotalMin  = [math]::Round((($durations | Measure-Object -Sum).Sum) / 60, 1)
            MedianSec = [math]::Round($durations[$p50Index], 1)
            P95Sec    = [math]::Round($durations[$p95Index], 1)
            FirstSeen = $timestamps[0]
            LastSeen  = $timestamps[-1]
        }
    }

    return @($rows | Sort-Object -Property TotalMin -Descending)
}

# =============================================================================
# Module Exports
# =============================================================================

Export-ModuleMember -Function @(
    # Exit Codes
    'Get-ExitCode'

    # Path Utilities
    'Expand-FullPath'
    'ConvertTo-SafePathSegment'
    'Ensure-Directory'
    'New-TemporaryDirectory'

    # JSON and App Configuration
    'Get-AppJsonPath'
    'Get-SettingsJsonPath'
    'Get-AppJsonObject'
    'Get-SettingsJsonObject'
    'Get-OutputPath'
    'Read-JsonFile'
    'Resolve-AppJsonPath'
    'Test-JsonProperty'

    # Cache Management
    'Get-ToolCacheRoot'
    'Get-SymbolCacheRoot'
    'Get-LatestCompilerInfo'
    'Get-SymbolCacheInfo'

    # Standardized Output (recommended for all scripts)
    'Write-BuildMessage'
    'Write-BuildHeader'
    'Write-TaskHeader'

    # Legacy Formatting Helpers (deprecated - use Write-BuildMessage instead)
    'Write-Section'
    'Write-InfoLine'
    'Write-StatusLine'
    'Write-ListItem'

    # Analyzer Utilities
    'Test-AnalyzerDependencies'
    'Get-EnabledAnalyzerPath'

    # Business Central Integration
    'Add-HostsEntry'
    'Remove-HostsEntry'
    'Update-BCPublicWebBaseUrl'
    'New-BCLaunchConfig'
    'Get-BCCredential'
    'Get-BCContainerName'
    'Get-BCAgentContainerName'
    'Test-BCAgentContainerHealthy'
    'Ensure-BCAgentContainer'
    'Import-BCContainerHelper'

    # Agent Container Registry
    'Get-AgentContainerRegistryPath'
    'Get-RegisteredAgentContainers'
    'Register-AgentContainer'
    'Update-AgentContainerUsage'
    'Unregister-AgentContainer'
    'Get-OrphanedAgentContainers'
    'Remove-OrphanedAgentContainers'

    # GitHub CLI Integration
    'Test-GhAuthentication'
    'Test-GhHostAuthentication'
    'Get-RepoFromUrl'
    'Get-ReleaseAppFiles'

    # AL-Go Integration
    'Get-AlGoSettingsPath'
    'Get-AlGoDependencyProbingPaths'
    'Install-AlGoDependencies'

    # Telemetry Integration
    'Clear-TestTelemetryLogs'
    'Merge-TestTelemetryLogs'
    'Copy-TestTelemetryLogs'

    # Build Timing History
    'Save-BuildTimingEntry'
    'Show-BuildTimingHistory'
    'Get-GateMetricsSummary'
    'Get-GateMetricsGlobalPath'
    'Get-DirtyFileCounts'

    # Incremental Publish
    'Get-ContainerCreatedTime'
    'Get-PublishStatePath'
    'Get-AppFileHash'
    'Get-DirectoryHash'
    'Test-AppNeedsPublish'
    'Save-PublishState'
    'Clear-PublishState'
)
