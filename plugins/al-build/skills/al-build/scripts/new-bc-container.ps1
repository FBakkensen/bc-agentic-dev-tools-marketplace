#requires -Version 7.2

<#
.SYNOPSIS
    Create and configure a BC Docker container.

.DESCRIPTION
    Sets up a new Business Central Docker container using BcContainerHelper.
    This is the "golden" container that can be committed to a snapshot image
    for spawning agent containers.

.PARAMETER ApplicationInsightsConnectionString
    Optional: Azure Application Insights connection string for telemetry.

.EXAMPLE
    pwsh -File new-bc-container.ps1

.EXAMPLE
    pwsh -File new-bc-container.ps1 -ApplicationInsightsConnectionString "InstrumentationKey=..."
#>

[CmdletBinding()]
param(
    [string]$ApplicationInsightsConnectionString
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking

# Load configuration
$overrides = @{}
if ($ApplicationInsightsConnectionString) {
    $overrides['ApplicationInsightsConnectionString'] = $ApplicationInsightsConnectionString
}
$config = Get-BuildConfig -Overrides $overrides
Set-BuildEnvironment -Config $config
$containerName = $config.GoldenContainerName

Write-BuildHeader 'New BC Container: Golden Container Setup'

Write-BuildMessage -Type Info -Message "Container Configuration:"
Write-BuildMessage -Type Detail -Message "Container Name: $containerName"
Write-BuildMessage -Type Detail -Message "Username: $($config.ContainerUsername)"
Write-BuildMessage -Type Detail -Message "Authentication: $($config.ContainerAuth)"
Write-BuildMessage -Type Detail -Message "Artifact Country: $($config.ArtifactCountry)"
Write-BuildMessage -Type Detail -Message "Artifact Selection: $($config.ArtifactSelect)"
if ($config.ApplicationInsightsConnectionString) {
    Write-BuildMessage -Type Detail -Message "Application Insights: Enabled"
} else {
    Write-BuildMessage -Type Detail -Message "Application Insights: Disabled"
}

# Import BcContainerHelper
Import-BCContainerHelper

Write-BuildHeader 'Retrieving BC Artifact'

Write-BuildMessage -Type Step -Message "Getting BC artifact URL..."
$artifactUrl = Get-BcArtifactUrl -type 'OnPrem' -country $config.ArtifactCountry -select $config.ArtifactSelect
Write-BuildMessage -Type Success -Message "Artifact URL retrieved"
Write-BuildMessage -Type Detail -Message "URL: $artifactUrl"

Write-BuildHeader 'Creating BC Container'

$credential = Get-BCCredential -Username $config.ContainerUsername -Password $config.ContainerPassword

Write-BuildMessage -Type Step -Message "Creating container '$containerName'..."
Write-BuildMessage -Type Detail -Message "This may take several minutes..."

$containerParams = @{
    accept_eula           = $true
    containerName         = $containerName
    credential            = $credential
    auth                  = $config.ContainerAuth
    artifactUrl           = $artifactUrl
    includeTestToolkit    = $true
    includeTestLibrariesOnly = $true
    dns                   = '8.8.8.8'
    useBestContainerOS    = $true
    memoryLimit           = '8g'
    isolation             = 'process'
    updateHosts           = $true
}

New-BcContainer @containerParams

Write-BuildMessage -Type Success -Message "Container created successfully"

# Configure Application Insights if provided
if ($config.ApplicationInsightsConnectionString) {
    Write-BuildHeader 'Configuring Application Insights'
    Write-BuildMessage -Type Step -Message "Setting Application Insights connection string..."

    Set-BcContainerServerConfiguration `
        -containerName $containerName `
        -keyName "ApplicationInsightsConnectionString" `
        -keyValue $config.ApplicationInsightsConnectionString

    Write-BuildMessage -Type Success -Message "Application Insights configured"
}

Write-BuildHeader 'Configuring Development Settings'

Write-BuildMessage -Type Step -Message "Enabling symbol loading at startup..."
Set-BcContainerServerConfiguration `
    -containerName $containerName `
    -keyName "EnableSymbolLoadingAtServerStartup" `
    -keyValue "true"

Write-BuildMessage -Type Step -Message "Enabling debugging..."
Set-BcContainerServerConfiguration `
    -containerName $containerName `
    -keyName "EnableDebugging" `
    -keyValue "true"

Write-BuildMessage -Type Step -Message "Configuring data cache size..."
Set-BcContainerServerConfiguration `
    -containerName $containerName `
    -keyName "DataCacheSize" `
    -keyValue "11"

Write-BuildMessage -Type Step -Message "Restarting BC service to apply development settings..."
Restart-BcContainerServiceTier -containerName $containerName

Write-BuildMessage -Type Success -Message "Development settings configured successfully"

Write-BuildHeader 'Installing AL Test Runner Service'

Write-BuildMessage -Type Step -Message "Downloading AL Test Runner Service app..."
$tempDir = New-TemporaryDirectory
$testRunnerUrl = 'https://github.com/jimmymcp/test-runner-service/raw/master/James%20Pearson_Test%20Runner%20Service.app'
$testRunnerAppPath = Join-Path $tempDir 'Test Runner Service.app'

Write-BuildMessage -Type Detail -Message "URL: $testRunnerUrl"
Write-BuildMessage -Type Detail -Message "Temp directory: $tempDir"

try {
    Invoke-WebRequest -Uri $testRunnerUrl -OutFile $testRunnerAppPath -UseBasicParsing
    Write-BuildMessage -Type Success -Message "Downloaded Test Runner Service app"
    Write-BuildMessage -Type Detail -Message "File: $testRunnerAppPath"

    Write-BuildMessage -Type Step -Message "Publishing Test Runner Service to container..."
    Write-BuildMessage -Type Detail -Message "This may take a minute..."

    Publish-BcContainerApp -containerName $containerName `
                           -appFile $testRunnerAppPath `
                           -skipVerification `
                           -sync `
                           -install `
                           -credential $credential

    Write-BuildMessage -Type Success -Message "Test Runner Service installed successfully"
} catch {
    Write-BuildMessage -Type Error -Message "Failed to install Test Runner Service: $_"
    throw
} finally {
    # Clean up temp directory
    if (Test-Path $tempDir) {
        Write-BuildMessage -Type Detail -Message "Cleaning up temporary files"
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-BuildHeader 'Installing AL-Go Dependencies'

Write-BuildMessage -Type Step -Message "Checking for AL-Go dependencies..."
$workspaceRoot = (Get-Location).Path
$installedCount = Install-AlGoDependencies -ContainerName $containerName -Credential $credential -WorkspaceRoot $workspaceRoot
if ($installedCount -gt 0) {
    Write-BuildMessage -Type Success -Message "Installed $installedCount dependency app(s)"
} else {
    Write-BuildMessage -Type Detail -Message "No dependencies installed"
}

Write-BuildHeader 'Summary'

Write-BuildMessage -Type Success -Message "BC container '$containerName' is ready!"
Write-BuildMessage -Type Detail -Message "Container Name: $containerName"
Write-BuildMessage -Type Detail -Message "Authentication: $($config.ContainerAuth)"
Write-BuildMessage -Type Detail -Message "Credentials: $($config.ContainerUsername) / $($config.ContainerPassword)"
Write-BuildMessage -Type Detail -Message "AL Test Runner Service: Installed"
Write-BuildMessage -Type Detail -Message "AL-Go Dependencies: $installedCount app(s) installed"
Write-BuildMessage -Type Detail -Message "Development Settings: Enabled (symbols, debugging, cache size 11)"
if ($config.ApplicationInsightsConnectionString) {
    Write-BuildMessage -Type Detail -Message "Application Insights: Enabled (telemetry active)"
} else {
    Write-BuildMessage -Type Detail -Message "Application Insights: Disabled"
}
Write-BuildMessage -Type Info -Message "Use this container for publishing and testing AL apps."

Write-BuildHeader 'Preparing Container For Commit'

# Stop IIS and delete web client folder before commit to prevent file locks when restarting with different hostname.
# When a committed container starts with a new hostname, the BC startup script:
#   1. Starts IIS
#   2. Tries to delete C:\inetpub\wwwroot\BC to reconfigure it
#   3. Fails because IIS has files locked
# By stopping IIS and deleting the folder before commit, there's nothing for IIS to lock,
# and the startup script recreates the folder fresh.
Write-BuildMessage -Type Step -Message "Stopping IIS service inside container..."
try {
    docker exec $containerName powershell -Command "Stop-Service W3SVC -Force -ErrorAction SilentlyContinue"
    Write-BuildMessage -Type Success -Message "IIS service stopped"
} catch {
    Write-BuildMessage -Type Warning -Message "Could not stop IIS service: $($_.Exception.Message)"
}

Write-BuildMessage -Type Step -Message "Removing web client folder for clean hostname reconfiguration..."
try {
    docker exec $containerName powershell -Command "Remove-Item 'C:\inetpub\wwwroot\BC' -Recurse -Force -ErrorAction SilentlyContinue"
    Write-BuildMessage -Type Success -Message "Web client folder removed"
} catch {
    Write-BuildMessage -Type Warning -Message "Could not remove web client folder: $($_.Exception.Message)"
}

Write-BuildHeader 'Stopping Container'

Write-BuildMessage -Type Step -Message "Stopping container to prepare for commit..."
try {
    Stop-BcContainer -containerName $containerName
    Write-BuildMessage -Type Success -Message "Container '$containerName' stopped"
} catch {
    Write-BuildMessage -Type Error -Message "Failed to stop container: $($_.Exception.Message)"
    throw
}

Write-BuildHeader 'Next Steps'

Write-BuildMessage -Type Warning -Message "RESTART YOUR COMPUTER before committing!"
Write-BuildMessage -Type Detail -Message "A restart is required to release locked files held by the container."
Write-BuildMessage -Type Info -Message "After restart, create a snapshot image:"
Write-BuildMessage -Type Info -Message "  pwsh $PSScriptRoot/commit-bc-container.ps1"
Write-BuildMessage -Type Info -Message "Then spawn agent containers with:"
Write-BuildMessage -Type Info -Message "  pwsh $PSScriptRoot/new-agent-container.ps1"
