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

# Require Volta + Node 22-25.
# Volta is the project's only supported Node version manager — its shims route node/npm/npx
# through the `volta.node` pin in pagescripts/package.json. The script uses `volta pin` to
# write that pin on first setup.
# Node 22-25 is the empirically-tested working range for bc-replay's bundled Playwright
# (@playwright/test 1.55.1 officially supports 20/22/24). Node 26+ hangs in Playwright's
# browser-install per upstream microsoft/playwright#40724.
if (-not (Get-Command volta -ErrorAction SilentlyContinue)) {
    Write-BuildMessage -Type Error -Message "Volta not found. Install Volta from https://volta.sh, then 'volta install node@22'."
    exit 1
}
$nodeVersion = $null
try { $nodeVersion = & node --version 2>$null } catch {}
$nodeMajor = if ($nodeVersion) {
    [int](($nodeVersion -replace '^v','') -split '\.')[0]
} else { 0 }
if ($nodeMajor -lt 22 -or $nodeMajor -gt 25) {
    $observed = if ($nodeVersion) { $nodeVersion } else { 'not found' }
    Write-BuildMessage -Type Error -Message "Node $observed is not supported (need 22-25). Run 'volta install node@22' to make Volta's default a compatible version."
    exit 1
}
Write-BuildMessage -Type Detail -Message "Node: $nodeVersion (via Volta)"

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
        # Treat as first-time-setup if package.json is missing OR lacks a volta.node pin.
        # A bare package.json with no volta pin can arise from a prior partial run
        # (volta pin failed after the file was written) — re-running the setup self-heals.
        $needsFirstTimeSetup = $true
        if (Test-Path -LiteralPath $packageJsonPath) {
            try {
                $existingPkg = Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json
                if ($existingPkg.PSObject.Properties.Name -contains 'volta' -and $existingPkg.volta.PSObject.Properties.Name -contains 'node' -and $existingPkg.volta.node) {
                    $needsFirstTimeSetup = $false
                }
            } catch {
                # Malformed JSON — treat as first-time-setup to rewrite cleanly.
                $needsFirstTimeSetup = $true
            }
        }
        if ($needsFirstTimeSetup) {
            # First-time setup: write minimal package.json, then let Volta pin the exact
            # Node version into the `volta.node` field. Volta requires a parseable semver
            # in package.json (Volta 2.0.2 rejects the bare major form "22"); `volta pin
            # node@22` lets Volta resolve to the latest 22.x it knows about and write that
            # exact version. Volta's shim routes any node/npm/npx call inside this
            # directory tree through the pinned version on every clone.
            $pkg = [ordered]@{
                name    = 'pagescripts'
                version = '1.0.0'
                private = $true
            } | ConvertTo-Json -Depth 5
            Set-Content -LiteralPath $packageJsonPath -Value $pkg -Encoding utf8
            & volta pin node@22 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-BuildMessage -Type Error -Message "volta pin node@22 failed"
                exit $LASTEXITCODE
            }
            & npm install '@microsoft/bc-replay@latest' | Out-Null
        } else {
            # package.json + volta pin already in place: install from existing version (no modification)
            & npm install | Out-Null
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
