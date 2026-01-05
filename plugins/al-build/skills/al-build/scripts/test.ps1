#requires -Version 7.2

<#
.SYNOPSIS
    Build, publish, and run AL tests.

.DESCRIPTION
    The canonical build-test gate. Performs the full workflow:
    1. Build main app
    2. Provision main app as local symbol for test app
    3. Build test app
    4. Ensure agent container is running
    5. Unpublish test app (if main app changed)
    6. Publish main app
    7. Publish test app
    8. Run tests

.PARAMETER TestCodeunit
    Optional: Run only a specific test codeunit (by ID or name, wildcards supported).

.PARAMETER Force
    Force republish even if apps are unchanged.

.EXAMPLE
    pwsh -File test.ps1
    # Run all tests

.EXAMPLE
    pwsh -File test.ps1 -TestCodeunit 50123
    # Run specific test codeunit

.EXAMPLE
    pwsh -File test.ps1 -Force
    # Force republish and run all tests
#>

[CmdletBinding()]
param(
    [string]$TestCodeunit,
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

Write-BuildHeader 'Test: Build & Test Gate'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "App Directory: $($config.AppDir)"
Write-BuildMessage -Type Detail -Message "Test Directory: $($config.TestDir)"
Write-BuildMessage -Type Detail -Message "Container: $($config.ContainerName)"
if ($TestCodeunit) {
    Write-BuildMessage -Type Detail -Message "Test Filter: $TestCodeunit"
}

# Step 1: Build main app
Start-Step 'build'
Invoke-ALBuild -AppDir $config.AppDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
Stop-Step 'build'

# Step 2: Provision main app as local symbol for test app
Start-Step 'provision-symbols'
Copy-ALSymbolToCache -SourceAppDir $config.AppDir -TargetAppDir $config.TestDir
Stop-Step 'provision-symbols'

# Step 3: Build test app
Start-Step 'build-test'
Invoke-ALBuild -AppDir $config.TestDir -WarnAsError:(ConvertTo-Boolean $config.WarnAsError)
Stop-Step 'build-test'

# Step 4: Ensure agent container is running
Start-Step 'ensure-container'
Ensure-BCAgentContainer -ContainerName $config.ContainerName
Stop-Step 'ensure-container'

# Step 5: Check if main app needs publish
$appJson = Get-AppJsonObject $config.AppDir
$mainAppNeedsPublish = Test-AppNeedsPublish -AppDir $config.AppDir -AppJson $appJson -ContainerName $config.ContainerName -Force:$Force

# Step 6: Unpublish test app if main app changed (to allow main app republish)
if ($mainAppNeedsPublish) {
    Start-Step 'unpublish-test'
    Invoke-ALUnpublish -AppName $config.TestAppName
    Stop-Step 'unpublish-test'
}

# Step 7: Publish main app
Start-Step 'publish'
Invoke-ALPublish -AppDir $config.AppDir -Force:$Force
Stop-Step 'publish'

# Step 8: Publish test app
Start-Step 'publish-test'
$testForcePublish = $Force -or $mainAppNeedsPublish
Invoke-ALPublish -AppDir $config.TestDir -Force:$testForcePublish
Stop-Step 'publish-test'

# Step 9: Run tests
Start-Step 'test'
$testParams = @{
    TestDir = $config.TestDir
}
if ($TestCodeunit) {
    $testParams['TestCodeunit'] = $TestCodeunit
}
Invoke-ALTest @testParams
Stop-Step 'test'

# Show timing summary
$script:BuildStartTime.Stop()
$totalSeconds = $script:BuildStartTime.Elapsed.TotalSeconds

$steps = @{}
foreach ($name in $script:StepTimings.Keys) {
    $steps[$name] = $script:StepTimings[$name].Elapsed.TotalSeconds
}

Save-BuildTimingEntry -Task 'test' -Steps $steps -TotalSeconds $totalSeconds
Show-BuildTimingHistory -Count 5

Write-BuildHeader 'Test Complete'
Write-BuildMessage -Type Success -Message "All tests passed with zero warnings and zero errors"
