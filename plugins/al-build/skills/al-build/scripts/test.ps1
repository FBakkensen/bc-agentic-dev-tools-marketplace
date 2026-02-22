#requires -Version 7.2

<#
.SYNOPSIS
    Build locally and run AL tests on remote Azure VM.

.DESCRIPTION
    Remote test execution workflow:
    1. Build main app locally using al (dotnet tool)
    2. Provision main app as local symbol for test app
    3. Build test app locally
    4. Connect via SSH to remote VM
    5. Copy .app files to remote staging via SCP
    6. Ensure remote container exists and is healthy
    7. Publish main app on remote
    8. Publish test app on remote
    9. Run tests on remote
    10. Copy results back to local via SCP

.PARAMETER TestCodeunit
    Optional: Run only a specific test codeunit (by ID or name).

.PARAMETER Force
    Force republish even if apps are unchanged.

.EXAMPLE
    pwsh -File test.ps1
    # Run all tests on remote VM

.EXAMPLE
    pwsh -File test.ps1 -TestCodeunit 50123
    # Run specific test codeunit
#>

[CmdletBinding()]
param(
    [string]$TestCodeunit,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import shared helpers and build operations
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'build-operations.psm1') -Force -DisableNameChecking

# =============================================================================
# Timing
# =============================================================================

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

function ConvertTo-RemoteArgs {
    <#
    .SYNOPSIS
        Converts a hashtable to a PowerShell argument string for remote execution.
    #>
    param([hashtable]$Arguments)

    $parts = @()
    foreach ($key in $Arguments.Keys) {
        $value = $Arguments[$key]
        if ($null -eq $value) { continue }
        if ($value -is [bool]) {
            if ($value) { $parts += "-$key" }
        } else {
            $escaped = "$value" -replace "'", "''"
            $parts += "-$key '$escaped'"
        }
    }
    return $parts -join ' '
}

function Invoke-RemoteScript {
    <#
    .SYNOPSIS
        Executes a pre-deployed script at C:/scripts/ on the remote VM.
    #>
    param(
        [string]$VmHost,
        [string]$VmUser,
        [string]$ScriptName,
        [hashtable]$Arguments = @{},
        [bool]$StreamOutput = $true
    )

    $argString = ConvertTo-RemoteArgs $Arguments
    $command = "pwsh -NoProfile -File 'C:/scripts/$ScriptName' $argString"
    return Invoke-RemoteCommand -VmHost $VmHost -VmUser $VmUser -Command $command -StreamOutput $StreamOutput
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-BuildHeader 'Remote Test: Build & Test on Azure VM'

# Load configuration
$config = Get-RemoteBuildConfig

# Ensure ruleset path is available for local compilation
$rulesetPath = $null
$configPath = Join-Path $config.RepoRoot 'al-build.json'
if (Test-Path $configPath) {
    try {
        $rulesetPath = (Get-Content $configPath -Raw | ConvertFrom-Json).rulesetPath
    } catch { }
}
if (-not $rulesetPath) { $rulesetPath = 'al.ruleset.json' }
if (-not [System.IO.Path]::IsPathRooted($rulesetPath)) {
    $rulesetPath = Join-Path $config.RepoRoot $rulesetPath
}
$env:RULESET_PATH = $rulesetPath

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Directory: $($config.TestDir)"
Write-BuildMessage -Type Detail -Message "Remote VM: $($config.VmHost)"
Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"
if ($TestCodeunit) {
    Write-BuildMessage -Type Detail -Message "Test Filter: $TestCodeunit"
}

# =============================================================================
# PHASE 1: LOCAL COMPILATION
# =============================================================================

# Build main app
Start-Step 'build'
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:$config.WarnAsError
Stop-Step 'build'

# Provision symbol
Start-Step 'provision-symbols'
common\Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $config.TestDir
Stop-Step 'provision-symbols'

# Build test app
Start-Step 'build-test'
Invoke-ALBuild -AppDir $config.TestDir -WarnAsError:$config.WarnAsError
Stop-Step 'build-test'

# Get paths
$mainAppPath = Get-OutputPath $config.AppDir
$testAppPath = Get-OutputPath $config.TestDir
$testAppJson = Get-AppJsonObject $config.TestDir

Write-BuildMessage -Type Success -Message "Local compilation complete"
Write-BuildMessage -Type Detail -Message "Main app: $(Split-Path -Leaf $mainAppPath)"
Write-BuildMessage -Type Detail -Message "Test app: $(Split-Path -Leaf $testAppPath)"

# =============================================================================
# PHASE 2: SSH CONNECTION
# =============================================================================

Write-BuildHeader 'SSH Connection'
Start-Step 'ssh-connect'

Write-BuildMessage -Type Step -Message "Testing SSH connection to $($config.VmHost)..."
$sshTest = Invoke-RemoteCommand -VmHost $config.VmHost -VmUser $config.VmUser -Command "hostname" -StreamOutput $false
if ($sshTest.ExitCode -ne 0) {
    throw "SSH connection failed: $($sshTest.Output)"
}
Write-BuildMessage -Type Success -Message "Connected to $($sshTest.Output)"
Stop-Step 'ssh-connect'

# =============================================================================
# PHASE 3: COPY APPS TO REMOTE
# =============================================================================

Write-BuildHeader 'Copy Apps to Remote'
Start-Step 'copy-apps'

$remoteStagingPath = "$($config.AppStagingPath)/$($config.ContainerName)"

Write-BuildMessage -Type Step -Message "Creating staging directory..."
Invoke-RemoteCommand -VmHost $config.VmHost -VmUser $config.VmUser `
    -Command "New-Item -Path '$remoteStagingPath' -ItemType Directory -Force | Out-Null" -ThrowOnError -StreamOutput $false

Write-BuildMessage -Type Step -Message "Copying main app..."
Copy-FileToRemote -VmHost $config.VmHost -VmUser $config.VmUser `
    -LocalPath $mainAppPath -RemotePath "$remoteStagingPath/"

Write-BuildMessage -Type Step -Message "Copying test app..."
Copy-FileToRemote -VmHost $config.VmHost -VmUser $config.VmUser `
    -LocalPath $testAppPath -RemotePath "$remoteStagingPath/"

$remoteMainAppPath = "$remoteStagingPath/$(Split-Path -Leaf $mainAppPath)"
$remoteTestAppPath = "$remoteStagingPath/$(Split-Path -Leaf $testAppPath)"

Write-BuildMessage -Type Success -Message "Apps copied to remote staging"
Stop-Step 'copy-apps'

# =============================================================================
# PHASE 4: ENSURE REMOTE CONTAINER
# =============================================================================

Write-BuildHeader 'Ensure Remote Container'
Start-Step 'ensure-container'

Write-BuildMessage -Type Step -Message "Ensuring container is running..."
$containerResult = Invoke-RemoteScript -VmHost $config.VmHost -VmUser $config.VmUser `
    -ScriptName 'ensure-container.ps1' `
    -Arguments @{
        ContainerName = $config.ContainerName
    }

if ($containerResult.ExitCode -ne 0) {
    Write-BuildMessage -Type Error -Message "Container creation failed"
    throw "Failed to ensure container"
}

Write-BuildMessage -Type Success -Message "Container is ready on remote VM"
Stop-Step 'ensure-container'

# =============================================================================
# PHASE 5: PUBLISH APPS
# =============================================================================

Write-BuildHeader 'Publish Apps'

# Publish main app
Start-Step 'publish'
Write-BuildMessage -Type Step -Message "Publishing main app..."

$publishResult = Invoke-RemoteScript -VmHost $config.VmHost -VmUser $config.VmUser `
    -ScriptName 'publish-app.ps1' `
    -Arguments @{
        ContainerName = $config.ContainerName
        AppFile       = $remoteMainAppPath
    }

if ($publishResult.ExitCode -ne 0) {
    Write-BuildMessage -Type Error -Message "Main app publish failed"
    throw "Failed to publish main app"
}
Write-BuildMessage -Type Success -Message "Main app published"
Stop-Step 'publish'

# Publish test app
Start-Step 'publish-test'
Write-BuildMessage -Type Step -Message "Publishing test app..."

$publishResult = Invoke-RemoteScript -VmHost $config.VmHost -VmUser $config.VmUser `
    -ScriptName 'publish-app.ps1' `
    -Arguments @{
        ContainerName = $config.ContainerName
        AppFile       = $remoteTestAppPath
    }

if ($publishResult.ExitCode -ne 0) {
    Write-BuildMessage -Type Error -Message "Test app publish failed"
    throw "Failed to publish test app"
}
Write-BuildMessage -Type Success -Message "Test app published"
Stop-Step 'publish-test'

# =============================================================================
# PHASE 6: RUN TESTS
# =============================================================================

Write-BuildHeader 'Run Tests'
Start-Step 'test'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Write-BuildMessage -Type Step -Message "Running tests on remote container..."

$testArgs = @{
    ContainerName = $config.ContainerName
    ExtensionId   = $testAppJson.id
    Tenant        = $config.Tenant
    ResultsPath   = "test-results-$timestamp.xml"
}
if ($TestCodeunit) {
    $testArgs['TestCodeunit'] = $TestCodeunit
}

$testResult = Invoke-RemoteScript -VmHost $config.VmHost -VmUser $config.VmUser `
    -ScriptName 'run-tests.ps1' `
    -Arguments $testArgs

$testOutput = $testResult.Output -join "`n"
$testsPassed = $testOutput -match 'TESTS_PASSED'

Stop-Step 'test'

# =============================================================================
# PHASE 7: COPY RESULTS BACK
# =============================================================================

Write-BuildHeader 'Copy Results'
Start-Step 'copy-results'

$localResultsPath = Join-Path $config.RepoRoot '.output' 'TestResults'
if (-not (Test-Path $localResultsPath)) {
    New-Item -Path $localResultsPath -ItemType Directory -Force | Out-Null
}

# Parse RESULT_FILE from remote test output (dynamically discovered path)
$remoteResultPath = $null
if ($testOutput -match 'RESULT_FILE:(.+\.xml)') {
    $remoteResultPath = $Matches[1].Trim()
    Write-BuildMessage -Type Step -Message "Result file from remote: $remoteResultPath"
}

if ($remoteResultPath) {
    Write-BuildMessage -Type Step -Message "Copying test results..."
    $lastXmlPath = Join-Path $localResultsPath 'last.xml'

    $copied = Copy-FileFromRemote -VmHost $config.VmHost -VmUser $config.VmUser `
        -RemotePath $remoteResultPath -LocalPath $lastXmlPath

    if ($copied -and (Test-Path $lastXmlPath)) {
        Write-BuildMessage -Type Success -Message "Results saved: $lastXmlPath"
    } else {
        Write-BuildMessage -Type Warning -Message "Could not copy test result file"
    }
} else {
    Write-BuildMessage -Type Warning -Message "No RESULT_FILE marker found in remote output"
}

# Copy telemetry logs - derive shared folder from result path
$remoteSharedDir = if ($remoteResultPath) { Split-Path -Parent (Split-Path -Parent $remoteResultPath) } else { $null }

if ($remoteSharedDir) {
    Write-BuildMessage -Type Step -Message "Copying debug logs from: $remoteSharedDir"

    $findTelemetryCmd = "Get-ChildItem '$remoteSharedDir' -Filter '*.jsonl' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName"
    $telemetryResult = Invoke-RemoteCommand -VmHost $config.VmHost -VmUser $config.VmUser -Command $findTelemetryCmd -StreamOutput $false
    $telemetryFiles = $telemetryResult.Output | Where-Object { $_ -match '\.jsonl$' }

    foreach ($remoteTelemetryPath in $telemetryFiles) {
        if ($remoteTelemetryPath) {
            $remoteTelemetryPath = $remoteTelemetryPath.Trim()
            $fileName = Split-Path -Leaf $remoteTelemetryPath
            $localTelemetryPath = Join-Path $localResultsPath $fileName

            $telemetryCopied = Copy-FileFromRemote -VmHost $config.VmHost -VmUser $config.VmUser `
                -RemotePath $remoteTelemetryPath -LocalPath $localTelemetryPath

            if ($telemetryCopied) {
                Write-BuildMessage -Type Detail -Message "Copied: $fileName"
            }
        }
    }
} else {
    Write-BuildMessage -Type Warning -Message "Skipping telemetry copy - no shared folder path available"
}

Stop-Step 'copy-results'

# =============================================================================
# PHASE 8: RESULTS
# =============================================================================

Write-BuildHeader 'Test Results'

$script:BuildStartTime.Stop()
$totalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

$steps = @{}
foreach ($name in $script:StepTimings.Keys) {
    $steps[$name] = [math]::Round($script:StepTimings[$name].Elapsed.TotalSeconds, 1)
}

Save-BuildTimingEntry -Task 'test-remote' -Steps $steps -TotalSeconds $totalSeconds
Show-BuildTimingHistory -Count 5

if ($testsPassed) {
    Write-Host ""
    Write-Host "[OK] All tests passed" -ForegroundColor Green
    Write-Host "    Results: $localResultsPath\last.xml"
} else {
    Write-Host ""
    Write-Host "[FAIL] Tests failed" -ForegroundColor Red
    Write-Host "    Output: $testOutput"
    Write-Host "    Results: $localResultsPath\last.xml"
    throw "Tests failed. See results in $localResultsPath"
}

Write-BuildHeader 'Remote Test Complete'
Write-BuildMessage -Type Success -Message "All tests passed with zero warnings and zero errors"
