#requires -Version 7.2

<#
.SYNOPSIS
    Publish all configured AL apps to the current branch's agent container — clean republish.

.DESCRIPTION
    Clean-republish primitive. Unconditionally unpublishes every app present in
    the container (test apps → unitTestApp → main app, dependency-reversed),
    then force-publishes them in dependency order (main → test apps → unitTestApp)
    per al-build.json.

    No build, no tests, no replay — caller is responsible for having compiled
    .app artifacts present. Invoke-ALUnpublish internally skips when an app is
    not installed, so the unconditional unpublish is safe on a fresh container.
    Invoke-ALPublish is called with -Force to bypass Test-AppNeedsPublish's
    source-hash cache (stale after unpublish).

    Used by /al-user-verification's spawn #2 (publish to a fresh container
    before the human walk) and any other consumer that needs a deterministic
    publish without test or replay side effects.

.EXAMPLE
    pwsh -File publish-apps.ps1
    # Clean republish of main + test apps to the agent container
#>

[CmdletBinding()]
param()

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

Write-BuildHeader 'Publish Apps'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Apps: $($config.TestApps -join ', ')"
if ($config.UnitTestApp) {
    Write-BuildMessage -Type Detail -Message "Unit Test App: $($config.UnitTestApp)"
}
Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"

# Step 1: Ensure agent container is running
Start-Step 'ensure-container'
Ensure-BCAgentContainer -ContainerName $config.ContainerName
Stop-Step 'ensure-container'

# Step 2: Unpublish all apps in dependency-reverse order
# Invoke-ALUnpublish internally skips when app is not installed → safe on fresh container.
Start-Step 'unpublish'
foreach ($testAppDir in @($config.TestApps | Sort-Object -Descending)) {
    $testAppJson = Get-AppJsonObject $testAppDir
    if ($testAppJson) {
        Invoke-ALUnpublish -AppName $testAppJson.name
    }
}
if ($config.UnitTestApp -and ($config.UnitTestApp -notin $config.TestApps)) {
    $unitAppJson = Get-AppJsonObject $config.UnitTestApp
    if ($unitAppJson) {
        Invoke-ALUnpublish -AppName $unitAppJson.name
    }
}
$mainAppJson = Get-AppJsonObject $config.AppDir
if ($mainAppJson) {
    Invoke-ALUnpublish -AppName $mainAppJson.name
}
Stop-Step 'unpublish'

# Step 3: Publish main app
# -Force bypasses Test-AppNeedsPublish's source-hash cache, which is stale after unpublish.
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force
Stop-Step 'publish'

# Step 4: Publish each test app
foreach ($testAppDir in $config.TestApps) {
    $dirName = Split-Path $testAppDir -Leaf
    Start-Step "publish-test-$dirName"
    Invoke-ALPublish -AppDir $testAppDir -Force
    Stop-Step "publish-test-$dirName"
}

# Step 5: Publish unit test app when configured and not already in TestApps
if ($config.UnitTestApp -and ($config.UnitTestApp -notin $config.TestApps)) {
    $unitDirName = Split-Path $config.UnitTestApp -Leaf
    Start-Step "publish-unit-$unitDirName"
    Invoke-ALPublish -AppDir $config.UnitTestApp -Force
    Stop-Step "publish-unit-$unitDirName"
}

# Show timing summary
$script:BuildStartTime.Stop()
$totalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

$steps = @{}
foreach ($name in $script:StepTimings.Keys) {
    $steps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
}

Save-BuildTimingEntry -Task 'publish-apps' -Steps $steps -TotalSeconds $totalSeconds
Show-BuildTimingHistory -Count 5

Write-BuildHeader 'Publish Complete'
Write-BuildMessage -Type Success -Message "All apps published"
