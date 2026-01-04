#requires -Version 7.2

<#
.SYNOPSIS
    Commit BC container to a Docker snapshot image.

.DESCRIPTION
    Commits a stopped BC Docker container to a snapshot image that can be used
    to spawn agent containers. The container must be stopped before committing.

.PARAMETER ContainerName
    Name of the container to commit. Defaults to container.name from al-build.json.

.PARAMETER ImageName
    Name for the snapshot image. Defaults to container.imageName from al-build.json.

.EXAMPLE
    pwsh -File commit-bc-container.ps1

.EXAMPLE
    pwsh -File commit-bc-container.ps1 -ContainerName bctest -ImageName bctest:snapshot
#>

[CmdletBinding()]
param(
    [string]$ContainerName,
    [string]$ImageName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking
Import-Module "$PSScriptRoot/build-operations.psm1" -Force -DisableNameChecking
Import-BCContainerHelper

# Load configuration and apply defaults if parameters not provided
$config = Get-BuildConfig
if (-not $ContainerName) { $ContainerName = $config.GoldenContainerName }
if (-not $ImageName) { $ImageName = $config.ImageName }

Write-BuildHeader 'Commit BC Container'

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "Container Name: $ContainerName"
Write-BuildMessage -Type Detail -Message "Image Name: $ImageName"

# Validate Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "docker command not found. Install Docker Desktop."
}

Write-BuildHeader 'Container Validation'

# Check if container exists
Write-BuildMessage -Type Step -Message "Checking container '$ContainerName' exists..."
$existingContainer = docker ps -a --filter "name=^${ContainerName}$" --format "{{.Names}}" 2>$null
if (-not $existingContainer) {
    throw "Container '$ContainerName' not found. Create it first: pwsh $PSScriptRoot/new-bc-container.ps1"
}
Write-BuildMessage -Type Success -Message "Container found"

# Check if running and stop if needed
$running = docker inspect $ContainerName --format '{{.State.Running}}' 2>$null
if ($running -eq 'true') {
    Write-BuildMessage -Type Warning -Message "Container is running; stopping before commit..."
    Stop-BcContainer -containerName $ContainerName
    Write-BuildMessage -Type Success -Message "Container stopped"
}

Write-BuildHeader 'Creating Snapshot Image'

Write-BuildMessage -Type Step -Message "Committing container to image..."
Write-BuildMessage -Type Detail -Message "This may take a minute..."

docker commit $ContainerName $ImageName

if ($LASTEXITCODE -ne 0) {
    throw "docker commit failed with exit code $LASTEXITCODE"
}

# Get image size
$imageSize = docker images $ImageName --format "{{.Size}}" 2>$null
Write-BuildMessage -Type Success -Message "Snapshot image created: $ImageName ($imageSize)"

Write-BuildMessage -Type Info -Message "Removing source container '$ContainerName'..."
try {
    Remove-BcContainer -containerName $ContainerName -ErrorAction Stop | Out-Null
    Write-BuildMessage -Type Success -Message "Container '$ContainerName' removed"
} catch {
    Write-BuildMessage -Type Warning -Message "Remove-BcContainer failed; using docker rm -f"
    docker rm -f $ContainerName 2>$null | Out-Null
}

Write-BuildHeader 'Commit Complete'
Write-BuildMessage -Type Success -Message "Image '$ImageName' is ready"
Write-BuildMessage -Type Info -Message "Next steps:"
Write-BuildMessage -Type Detail -Message "Spawn agent containers: pwsh $PSScriptRoot/new-agent-container.ps1"
