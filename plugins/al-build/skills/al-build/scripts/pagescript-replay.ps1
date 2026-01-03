#requires -Version 7.2

<#
.SYNOPSIS
    Run Business Central Page Script YAML recordings.

.DESCRIPTION
    Invokes bc-replay against all YAML scripts in pagescripts/recordings/*.yml.
    Requires published main app in the BC container.

.PARAMETER Force
    Force republish even if app is unchanged.

.EXAMPLE
    pwsh -File pagescript-replay.ps1
    # Run all page scripts

.EXAMPLE
    pwsh -File pagescript-replay.ps1 -Force
    # Force republish and run page scripts
#>

[CmdletBinding()]
param(
    [switch]$Force
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

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

# Load configuration
$config = Get-BuildConfig
Set-BuildEnvironment -Config $config

Write-BuildHeader 'Page Script Replay'

# Step 1: Build main app
Start-Step 'build'
Write-BuildMessage -Type Step -Message "Building main app..."
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:($config.WarnAsError -eq '1')
Stop-Step 'build'

# Step 2: Ensure agent container is running
Start-Step 'ensure-container'
Ensure-BCAgentContainer -ContainerName $config.ContainerName
Stop-Step 'ensure-container'

# Step 3: Publish main app (with smart detection)
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force:$Force
Stop-Step 'publish'

# Now run page scripts
$workspaceRoot = (Get-Location).Path
$pagescriptDir = Join-Path $workspaceRoot 'pagescripts'

if (-not (Test-Path -LiteralPath $pagescriptDir)) {
    Write-BuildMessage -Type Warning -Message "pagescripts directory not found: $pagescriptDir"
    exit 0
}

# Validate Node.js
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-BuildMessage -Type Error -Message "npm not found. Install Node.js first."
    exit 1
}

# Build start address
$startAddress = "$($config.ServerUrl)/$($config.ServerInstance)/"

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "Start Address: $startAddress"
Write-BuildMessage -Type Detail -Message "Scripts Directory: $pagescriptDir"

# Ensure results directory exists
$resultsDir = Join-Path $pagescriptDir 'results'
Ensure-Directory -Path $resultsDir

Push-Location $pagescriptDir
try {
    # Install bc-replay if not present
    $modulePath = Join-Path $pagescriptDir 'node_modules\@microsoft\bc-replay'
    if (-not (Test-Path -LiteralPath $modulePath)) {
        Write-BuildMessage -Type Step -Message "Installing @microsoft/bc-replay..."
        $packageJsonPath = Join-Path $pagescriptDir 'package.json'
        if (-not (Test-Path -LiteralPath $packageJsonPath)) {
            # First-time setup: initialize and install latest
            & npm init -y | Out-Null
            & npm install @microsoft/bc-replay@latest | Out-Null
        } else {
            # package.json exists: install from existing version (no modification)
            & npm install | Out-Null
        }
        if ($LASTEXITCODE -ne 0) {
            Write-BuildMessage -Type Error -Message "npm install failed"
            exit $LASTEXITCODE
        }
    }

    # Step 4: Run bc-replay with glob pattern (bc-replay handles file discovery internally)
    Start-Step 'replay'
    $replayExe = Join-Path $pagescriptDir 'node_modules\.bin\replay.cmd'
    if (-not (Test-Path -LiteralPath $replayExe)) {
        $replayExe = Join-Path $pagescriptDir 'node_modules\.bin\replay'
    }

    # Use glob pattern - bc-replay handles multiple files internally
    $glob = 'recordings/*.yml'

    Write-BuildMessage -Type Step -Message "Running bc-replay on $glob"
    & $replayExe -Tests $glob -StartAddress $startAddress -Authentication UserPassword -UserNameKey ALBT_BC_CONTAINER_USERNAME -PasswordKey ALBT_BC_CONTAINER_PASSWORD -ResultDir $resultsDir

    if ($LASTEXITCODE -ne 0) {
        Write-BuildMessage -Type Error -Message "Page script replay failed (exit code $LASTEXITCODE)"
        Stop-Step 'replay'
        exit $LASTEXITCODE
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

    Save-BuildTimingEntry -Task 'pagescript-replay' -Steps $steps -TotalSeconds $totalSeconds
    Show-BuildTimingHistory -Count 5

    Write-BuildHeader 'Page Script Replay Complete'

} finally {
    Pop-Location
}
