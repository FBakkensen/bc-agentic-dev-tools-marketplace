#requires -Version 7.2

<#
.SYNOPSIS
    Provision the breaking-change baseline: cache the previous release + its
    dependencies and point AppSourceCop at them.

.DESCRIPTION
    Sole owner of the baseline fetch. When breakingChange.enabled is set:
    1. Resolves the latest GitHub release of the app's own repo (gh uses the
       repo's remote host automatically — works on github.com and *.ghe.com).
    2. Downloads the previous .app plus every AL-Go dependency-probing-path
       dependency into the flat baseline package cache.
    3. Writes `version` and `baselinePackageCachePath` into app/AppSourceCop.json
       so AppSourceCop reports breaking changes (AS00xx) at compile time.

    version and the cached .app come from the same fetch, so AS0003
    (baseline-version-not-in-cache) is structurally impossible.

    No release exists -> removes `version` from AppSourceCop.json and clears the
    cache so breaking-change detection stays cleanly off (never a false green).

    Both provision.ps1 (warms the cache) and validate-breaking-changes.ps1
    (reads it) depend on this; the cache is the single source of truth for the
    baseline.

.EXAMPLE
    pwsh -File download-baseline.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

$Exit = Get-ExitCode

Write-BuildHeader 'Breaking-Change Baseline'

if (-not $config.BreakingChangeEnabled) {
    Write-BuildMessage -Type Detail -Message "breakingChange.enabled is false - skipping baseline."
    exit 0
}

# Resolve app directory + AppSourceCop.json
$absoluteAppDir = (Resolve-Path -Path $config.AppDir).Path
$appSourceCopPath = Join-Path $absoluteAppDir "AppSourceCop.json"
if (-not (Test-Path $appSourceCopPath)) {
    Write-BuildMessage -Type Error -Message "AppSourceCop.json not found at $appSourceCopPath"
    exit $Exit.Contract
}

# Resolve repo root + absolute cache directory
$repoRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRoot) {
    $repoRoot = (Get-Location).Path
}
if ($IsWindows -or $env:OS -match 'Windows') {
    $repoRoot = $repoRoot -replace '/', '\'
}
$cacheDir = if ([System.IO.Path]::IsPathRooted($config.BaselinePackageCachePath)) {
    $config.BaselinePackageCachePath
} else {
    Join-Path $repoRoot $config.BaselinePackageCachePath
}

# AppSourceCop.json is written via a PSCustomObject round-trip (preserves key
# order + single-element arrays -> stable diffs). Mutators live in the module.
function Save-Asc {
    param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Path)
    $Object | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Force
}

$appSourceCop = Get-Content $appSourceCopPath -Raw | ConvertFrom-Json

Write-BuildHeader 'Previous Release'

# Check gh CLI + auth (app's own repo -> gh resolves the remote host automatically)
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-BuildMessage -Type Error -Message "GitHub CLI (gh) not found"
    exit $Exit.MissingTool
}
if (-not (Test-GhAuthentication)) {
    Write-BuildMessage -Type Error -Message "GitHub CLI not authenticated. Run 'gh auth login'"
    exit $Exit.Contract
}

Write-BuildMessage -Type Step -Message "Fetching latest release..."
$releaseInfo = gh release view --json tagName,assets 2>$null | ConvertFrom-Json

if (-not $releaseInfo) {
    # No baseline exists yet -> detection stays off, honestly. Never a false green.
    Write-BuildMessage -Type Warning -Message "No releases found - breaking-change detection stays off (no baseline)."
    Clear-AppSourceCopBaseline -Object $appSourceCop | Out-Null
    Save-Asc -Object $appSourceCop -Path $appSourceCopPath
    if (Test-Path $cacheDir) { Remove-Item -Path $cacheDir -Recurse -Force -ErrorAction SilentlyContinue }
    Write-BuildMessage -Type Detail -Message "Removed 'version' from AppSourceCop.json; cleared cache."
    exit 0
}

Write-BuildMessage -Type Detail -Message "Latest release: $($releaseInfo.tagName)"

# Recreate the cache fresh so stale baseline versions never mix
if (Test-Path $cacheDir) { Remove-Item -Path $cacheDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

$tempDir = New-TemporaryDirectory
try {
    Write-BuildMessage -Type Step -Message "Downloading previous release..."

    $appFiles = @(Get-ReleaseAppFiles -ReleaseTag $releaseInfo.tagName -OutputDir $tempDir -ExcludeTest $true)
    if (-not $appFiles -or $appFiles.Count -eq 0) {
        Write-BuildMessage -Type Error -Message "Release '$($releaseInfo.tagName)' has no production .app asset - cannot establish a baseline."
        exit $Exit.Contract
    }

    # Cache every production app from the release (AppSourceCop matches the baseline
    # by the current project's identity; extra apps are harmless symbols).
    foreach ($app in $appFiles) { Copy-Item -Path $app.FullName -Destination $cacheDir -Force }

    # The baseline for version derivation is the app matching the current project name.
    $appJson = Get-AppJsonObject $config.AppDir
    $previousApp = @($appFiles | Where-Object { $appJson -and $_.Name -like "*$($appJson.name)*" })[0]
    if (-not $previousApp) { $previousApp = $appFiles[0] }
    Write-BuildMessage -Type Success -Message "Baseline: $($previousApp.Name)"

    # Derive the baseline version (filename token, then release tag). Mismatch
    # against the cached .app -> AppSourceCop fires AS0003, loud.
    $version = Get-BaselineVersion -AppFileName $previousApp.Name -ReleaseTag $releaseInfo.tagName
    if (-not $version) {
        Write-BuildMessage -Type Error -Message "Could not derive a baseline version from '$($previousApp.Name)' or tag '$($releaseInfo.tagName)'."
        exit $Exit.Contract
    }
    Write-BuildMessage -Type Detail -Message "Baseline version: $version"

    # Dependencies (AL-Go probing paths) -> same flat cache
    Write-BuildHeader 'Dependencies'
    $probingPaths = Get-AlGoDependencyProbingPaths -WorkspaceRoot (Get-Location)

    foreach ($dependency in $probingPaths) {
        try {
            $spec = Get-RepoFromUrl $dependency.repo
        } catch {
            Write-BuildMessage -Type Error -Message "Unparseable repo URL '$($dependency.repo)': $_"
            exit $Exit.Contract
        }

        if (-not (Test-GhHostAuthentication -HostName $spec.HostName)) {
            Write-BuildMessage -Type Error -Message "Not authenticated to $($spec.HostName). Run: gh auth login --hostname $($spec.HostName)"
            exit $Exit.Contract
        }

        $releaseTag = if ($dependency.version -eq 'latest' -or -not $dependency.version) { 'latest' } else { $dependency.version }
        $repoDisplay = "$($spec.Owner)/$($spec.Repo)"
        Write-BuildMessage -Type Step -Message "Downloading dependency: $repoDisplay ($releaseTag) from $($spec.HostName)"

        $depDir = Join-Path $tempDir ("deps_{0}_{1}_{2}" -f $spec.HostName.Replace('.', '_'), $spec.Owner, $spec.Repo)
        New-Item -ItemType Directory -Path $depDir -Force | Out-Null

        $repoArg = "$($spec.HostName)/$($spec.Owner)/$($spec.Repo)"
        $depApps = @(Get-ReleaseAppFiles -ReleaseTag $releaseTag -Repo $repoArg -OutputDir $depDir -ExcludeTest $true)
        if ($depApps.Count -eq 0) {
            Write-BuildMessage -Type Error -Message "No apps found in $repoDisplay on $($spec.HostName)"
            exit $Exit.Contract
        }

        foreach ($app in $depApps) {
            Copy-Item -Path $app.FullName -Destination $cacheDir -Force
            Write-BuildMessage -Type Success -Message "Dependency: $($app.Name)"
        }
    }

    # Point AppSourceCop at the baseline. Path is relative to the app folder
    # (where AppSourceCop.json lives), forward-slashed for portability.
    $relCache = [System.IO.Path]::GetRelativePath($absoluteAppDir, $cacheDir) -replace '\\', '/'
    Set-AppSourceCopBaseline -Object $appSourceCop -Version $version -CachePath $relCache | Out-Null
    Save-Asc -Object $appSourceCop -Path $appSourceCopPath

    Write-BuildHeader 'Baseline Ready'
    Write-BuildMessage -Type Success -Message "AppSourceCop baseline set to $version at $relCache"
} finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
