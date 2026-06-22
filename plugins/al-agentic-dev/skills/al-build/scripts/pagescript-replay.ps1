#requires -Version 7.2

<#
.SYNOPSIS
    Run Business Central Page Script YAML recordings.

.DESCRIPTION
    Default (batch mode): invokes bc-replay against all YAML scripts in
    pagescripts/recordings/*.yml.
    Single-file mode (-File <path>): replays one specific .yml file. Used by
    /al-page-script to replay one user-recorded scenario at a time, on a
    freshly spawned container (re-runnability gate).
    Requires published main app in the BC container.

.PARAMETER Force
    Force republish even if app is unchanged.

.PARAMETER File
    Path to a single .yml recording to replay instead of the glob. Path may be
    absolute or relative to the consumer repo root. Overrides batch mode.

.EXAMPLE
    pwsh -File pagescript-replay.ps1
    # Batch mode: replay every .yml under pagescripts/recordings/

.EXAMPLE
    pwsh -File pagescript-replay.ps1 -Force
    # Force republish, then batch replay

.EXAMPLE
    pwsh -File pagescript-replay.ps1 -File pagescripts/recordings/007-sales-charge-validation__post-validates-allocation__02.yml
    # Single-file mode: replay one per-scenario recording only
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [string]$File
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Track timing
$script:BuildStartTime = [Diagnostics.Stopwatch]::StartNew()
$script:StepTimings = @{}

function Start-Step {
    param([string]$Name)
    $script:StepTimings[$Name] = [Diagnostics.Stopwatch]::StartNew()
}

function Stop-Step {
    param([string]$Name)
    if ($script:StepTimings.ContainsKey($Name)) {
        $script:StepTimings[$Name].Stop()
    }
}

function Invoke-SerialPageScriptBatch {
    param(
        [Parameter(Mandatory)][string]$PageScriptDir,
        [Parameter(Mandatory)][string]$ModulePath,
        [Parameter(Mandatory)][string]$Tests,
        [Parameter(Mandatory)][string]$StartAddress,
        [Parameter(Mandatory)][string]$ResultDir
    )

    $script:LastPageScriptReplayExitCode = 0
    $envNames = @(
        'bc_player_testDir',
        'bc_player_workingDir',
        'bc_player_tests',
        'bc_player_resultDir',
        'bc_player_startAddress',
        'bc_player_auth',
        'bc_player_username_key',
        'bc_player_password_key'
    )
    $savedEnv = @{}
    foreach ($name in $envNames) {
        $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }

    try {
        foreach ($credentialName in @('ALBT_BC_CONTAINER_USERNAME', 'ALBT_BC_CONTAINER_PASSWORD')) {
            if (-not (Get-Item "env:$credentialName" -ErrorAction Ignore).Value) {
                Write-BuildMessage -Type Error -Message "The required $credentialName environment variable has not been set."
                $script:LastPageScriptReplayExitCode = 1
                return
            }
        }

        $resolvedPageScriptDir = (Resolve-Path -LiteralPath $PageScriptDir).Path
        $resolvedResultDir = (Resolve-Path -LiteralPath $ResultDir).Path
        $playerSpec = (Join-Path $ModulePath 'player\dist\player.spec.js').Replace('\', '/')
        $configFile = (Join-Path $ModulePath 'player\dist\playwright.config.js').Replace('\', '/')
        $outputDir = Join-Path $resolvedPageScriptDir 'test-results'

        $env:bc_player_testDir = Join-Path $ModulePath 'player'
        $env:bc_player_workingDir = $resolvedPageScriptDir
        $env:bc_player_tests = $Tests
        $env:bc_player_resultDir = $resolvedResultDir
        $env:bc_player_startAddress = $StartAddress
        $env:bc_player_auth = 'UserPassword'
        $env:bc_player_username_key = 'ALBT_BC_CONTAINER_USERNAME'
        $env:bc_player_password_key = 'ALBT_BC_CONTAINER_PASSWORD'

        Write-BuildMessage -Type Step -Message "Installing Playwright browsers..."
        & npx playwright install
        $script:LastPageScriptReplayExitCode = $LASTEXITCODE
        if ($script:LastPageScriptReplayExitCode -ne 0) {
            return
        }

        Write-BuildMessage -Type Step -Message "Running serial Playwright batch on $Tests (--workers=1 --retries=0)"
        & npx playwright test $playerSpec --config $configFile --output $outputDir --workers=1 --retries=0
        $script:LastPageScriptReplayExitCode = $LASTEXITCODE
    } finally {
        foreach ($name in $envNames) {
            [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process')
        }
    }
}

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

# Anchor CWD to the consumer repo root BEFORE loading configuration. Get-BuildConfig
# resolves relative `appDir` / `testApps` paths against Get-Location at call time, so
# invoking the script from any non-root CWD (subdirectory, IDE terminal, CI runner cwd)
# would bake the wrong base path into $config.AppDir. Fall back to current CWD when not
# inside a git repo (mirrors test.ps1's anchor pattern).
$workspaceRoot = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $workspaceRoot) {
    $workspaceRoot = (Get-Location).Path
}
if ($IsWindows -or $env:OS -match 'Windows') {
    $workspaceRoot = $workspaceRoot -replace '/', '\'
}
Set-Location $workspaceRoot

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

Write-BuildHeader 'Page Script Replay'

# Resolve Node from PATH — no version manager required.
# This script formerly hard-required Volta + Node 22-25. Hosts have since moved to
# Company Portal / MSI-managed Node (e.g. C:\Program Files\nodejs, v26.3.1, resolved via
# PATH with no version manager). Node 26 runs the replay harness fine once
# @microsoft/bc-replay + @playwright/test browsers are cached; the known Node-26 hang
# (upstream microsoft/playwright#40724) is in a *fresh* `playwright install`
# browser-download, not the test run. So: hard-floor at 22 (bc-replay's bundled Playwright
# is unsupported below — @playwright/test 1.55.1 officially supports 20/22/24), warn at 26+
# (a fresh `playwright install` may hang), stay silent in the proven 22-25 band. Volta boxes
# keep working unchanged — their shims put node/npm/npx on PATH like any other source.
$MinNode = 22       # below this: hard error (bc-replay's bundled Playwright unsupported)
$KnownGoodMax = 26  # replay run proven good through here (v26.3.1); fresh install may hang at/above
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-BuildMessage -Type Error -Message "Node not found on PATH. Install Node >= $MinNode (any source: MSI, Volta, nvm) and re-run."
    exit 1
}
$nodeVersion = $null
try { $nodeVersion = & node --version 2>$null } catch {}
$nodeMajor = if ($nodeVersion) {
    [int](($nodeVersion -replace '^v','') -split '\.')[0]
} else { 0 }
if ($nodeMajor -lt $MinNode) {
    $observed = if ($nodeVersion) { $nodeVersion } else { 'not found' }
    Write-BuildMessage -Type Error -Message "Node $observed is below the minimum supported major $MinNode. Install Node >= $MinNode and re-run."
    exit 1
}
if ($nodeMajor -ge $KnownGoodMax) {
    Write-BuildMessage -Type Warning -Message "Node $nodeVersion is at/above $KnownGoodMax; the replay run is known-good but a *fresh* 'playwright install' browser-download may hang (microsoft/playwright#40724). Ensure Playwright browsers are already cached."
}
$nodeDir = Split-Path -Parent $node.Source
Write-BuildMessage -Type Detail -Message "Node: $nodeVersion ($nodeDir)"

# Step 1: Build main app
Start-Step 'build'
Write-BuildMessage -Type Step -Message "Building main app..."
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
Stop-Step 'build'

# Step 2: Ensure agent container is running
Start-Step 'ensure-container'
Ensure-BCAgentContainer -ContainerName $config.ContainerName
Stop-Step 'ensure-container'

# Step 3: Publish main app (with smart detection)
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force:$Force
Stop-Step 'publish'

$pagescriptDir = Join-Path $workspaceRoot 'pagescripts'

if (-not (Test-Path -LiteralPath $pagescriptDir)) {
    Write-BuildMessage -Type Warning -Message "pagescripts directory not found: $pagescriptDir"
    exit 0
}

# Build start address
$startAddress = "$($config.ServerUrl)/$($config.ServerInstance)/"

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "Start Address: $startAddress"
Write-BuildMessage -Type Detail -Message "Scripts Directory: $pagescriptDir"

# Clean and re-create results directory.
# Mirrors test.ps1's per-run clean discipline so accumulated artifacts (playwright-report/,
# results.xml, video.webm) don't bleed across runs — stale red from a prior run would
# confuse log readers and any CI consumer parsing results.xml.
$resultsDir = Join-Path $pagescriptDir 'results'
if (Test-Path -LiteralPath $resultsDir) {
    Write-BuildMessage -Type Step -Message "Cleaning prior results in $resultsDir"
    Remove-Item -LiteralPath $resultsDir -Recurse -Force
}
Ensure-Directory -Path $resultsDir

Push-Location $pagescriptDir
try {
    # Install bc-replay if not present
    $modulePath = Join-Path $pagescriptDir 'node_modules\@microsoft\bc-replay'
    if (-not (Test-Path -LiteralPath $modulePath)) {
        Write-BuildMessage -Type Step -Message "Installing @microsoft/bc-replay..."
        $packageJsonPath = Join-Path $pagescriptDir 'package.json'
        # Discriminate on whether package.json already DECLARES @microsoft/bc-replay as a
        # dependency, not on file presence. A committed-but-depless package.json (or one
        # carrying only a vestigial `volta` key) would otherwise read as "already set up" and
        # a plain `npm install` would install nothing, leaving bc-replay missing. node/npm
        # resolve from PATH (no version manager required); any existing `volta` key is left
        # untouched but never depended on.
        $hasReplayDep = $false
        if (Test-Path -LiteralPath $packageJsonPath) {
            try {
                $existingPkg = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
                if ($existingPkg.PSObject.Properties.Name -contains 'dependencies' -and
                    $existingPkg.dependencies.PSObject.Properties.Name -contains '@microsoft/bc-replay') {
                    $hasReplayDep = $true
                }
            } catch {
                # Malformed JSON — treat as first-time setup to rewrite cleanly.
                $hasReplayDep = $false
            }
        }
        if ($hasReplayDep) {
            # Dependency already declared: restore the pinned/ranged version, no modification.
            & npm install | Out-Null
        } else {
            # First-time setup: ensure a minimal package.json exists (create only if absent,
            # so any existing `volta` key survives), then install bc-replay. The install also
            # records the dependency, so subsequent runs take the restore path above.
            if (-not (Test-Path -LiteralPath $packageJsonPath)) {
                $pkg = [ordered]@{
                    name    = 'pagescripts'
                    version = '1.0.0'
                    private = $true
                } | ConvertTo-Json -Depth 5
                Set-Content -LiteralPath $packageJsonPath -Value $pkg -Encoding utf8
            }
            & npm install '@microsoft/bc-replay@latest' | Out-Null
        }
        if ($LASTEXITCODE -ne 0) {
            Write-BuildMessage -Type Error -Message "npm install failed"
            exit $LASTEXITCODE
        }
    }

    # Step 4: Run page-script replay
    Start-Step 'replay'
    $replayExe = Join-Path $pagescriptDir 'node_modules\.bin\replay.cmd'
    if (-not (Test-Path -LiteralPath $replayExe)) {
        $replayExe = Join-Path $pagescriptDir 'node_modules\.bin\replay'
    }

    # Single-file mode (-File) overrides glob; relative paths resolve against the consumer repo root,
    # then convert to a path relative to $pagescriptDir for bc-replay's -Tests argument.
    if ($File) {
        if ([IO.Path]::IsPathRooted($File)) {
            $resolvedFile = $File
        } else {
            $resolvedFile = Join-Path $workspaceRoot $File
        }
        if (-not (Test-Path -LiteralPath $resolvedFile)) {
            Write-BuildMessage -Type Error -Message "File not found: $resolvedFile"
            Stop-Step 'replay'
            exit 1
        }
        # bc-replay's -Tests resolves against its CWD ($pagescriptDir after Push-Location); pass relative.
        $testsArg = [IO.Path]::GetRelativePath($pagescriptDir, $resolvedFile)
        Write-BuildMessage -Type Step -Message "Running bc-replay on $testsArg (single-file mode)"
        & $replayExe -Tests $testsArg -StartAddress $startAddress -Authentication UserPassword -UserNameKey ALBT_BC_CONTAINER_USERNAME -PasswordKey ALBT_BC_CONTAINER_PASSWORD -ResultDir $resultsDir
        $replayExitCode = $LASTEXITCODE
    } else {
        # Batch mode: run the bc-replay Playwright player directly and force
        # serial execution. Microsoft bc-replay's local config is fully parallel
        # unless worker count is explicit, which can race BC company initialization.
        $testsArg = 'recordings/*.yml'
        Invoke-SerialPageScriptBatch -PageScriptDir $pagescriptDir -ModulePath $modulePath -Tests $testsArg -StartAddress $startAddress -ResultDir $resultsDir
        $replayExitCode = $script:LastPageScriptReplayExitCode
    }

    if ($replayExitCode -ne 0) {
        Write-BuildMessage -Type Error -Message "Page script replay failed (exit code $replayExitCode)"
        Stop-Step 'replay'
        exit $replayExitCode
    }

    Write-BuildMessage -Type Success -Message "All recordings passed"
    Stop-Step 'replay'

    # Show timing summary
    $script:BuildStartTime.Stop()
    $totalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

    $steps = @{}
    foreach ($name in $script:StepTimings.Keys) {
        $steps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
    }

    $timingTask = if ($File) { 'pagescript-replay-file' } else { 'pagescript-replay' }
    Save-BuildTimingEntry -Task $timingTask -Steps $steps -TotalSeconds $totalSeconds
    Show-BuildTimingHistory -Count 5

    Write-BuildHeader 'Page Script Replay Complete'

} finally {
    Pop-Location
}
