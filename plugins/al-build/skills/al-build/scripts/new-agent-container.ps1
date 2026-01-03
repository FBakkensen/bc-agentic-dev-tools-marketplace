#requires -Version 7.2

<#
.SYNOPSIS
    Create a new BC agent container from a snapshot image.

.DESCRIPTION
    Spawns a new container from a committed BC Docker image (default: bctest:snapshot).
    If AgentName is not provided, uses the current Git branch name (sanitized).

.PARAMETER AgentName
    Name for the agent container. If not provided, uses current git branch.

.PARAMETER ImageName
    Docker image to use (default: bctest:snapshot).

.PARAMETER MemoryLimit
    Memory limit for the container (default: 8g).

.EXAMPLE
    pwsh -File new-agent-container.ps1
    # Uses current branch name

.EXAMPLE
    pwsh -File new-agent-container.ps1 -AgentName my-agent -MemoryLimit 4g
#>

[CmdletBinding()]
param(
    [string]$AgentName,
    [string]$ImageName = 'bctest:snapshot',
    [string]$MemoryLimit = '8g'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking

$Exit = Get-ExitCode

Write-BuildHeader 'New Agent Container'

# Validate Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-BuildMessage -Type Error -Message "docker command not found"
    exit $Exit.MissingTool
}

# Import BcContainerHelper
Import-BCContainerHelper

# Auto-detect agent name from git branch if not provided
$OriginalBranch = $null
if (-not $AgentName) {
    Write-BuildMessage -Type Step -Message "Detecting agent name from git branch..."
    try {
        $OriginalBranch = git rev-parse --abbrev-ref HEAD 2>$null
        $AgentName = Get-BCAgentContainerName
        Write-BuildMessage -Type Success -Message "Agent name: $AgentName"
    } catch {
        Write-BuildMessage -Type Error -Message "Not in a git repository"
        Write-BuildMessage -Type Detail -Message "Provide -AgentName explicitly"
        exit $Exit.Contract
    }
}

# Prune orphaned containers first (skip in CI)
if (-not $env:CI) {
    Write-BuildHeader 'Orphaned Container Cleanup'
    Remove-OrphanedAgentContainers
}

Write-BuildMessage -Type Info -Message "Configuration:"
Write-BuildMessage -Type Detail -Message "Agent Name: $AgentName"
Write-BuildMessage -Type Detail -Message "Image: $ImageName"
Write-BuildMessage -Type Detail -Message "Memory: $MemoryLimit"

Write-BuildHeader 'Image Validation'

# Check if image exists
Write-BuildMessage -Type Step -Message "Checking for image '$ImageName'..."
$imageExists = docker images -q $ImageName 2>$null
if (-not $imageExists) {
    Write-BuildMessage -Type Error -Message "Image '$ImageName' not found"
    Write-BuildMessage -Type Info -Message "Create it by running:"
    Write-BuildMessage -Type Detail -Message "1. pwsh $PSScriptRoot/new-bc-container.ps1"
    Write-BuildMessage -Type Detail -Message "2. docker stop bctest"
    Write-BuildMessage -Type Detail -Message "3. pwsh $PSScriptRoot/commit-bc-container.ps1"
    exit $Exit.Contract
}
Write-BuildMessage -Type Success -Message "Snapshot image found"

Write-BuildHeader 'Container Lifecycle'

# Remove existing container if present
$existingContainer = docker ps -a --filter "name=^${AgentName}$" --format "{{.Names}}" 2>$null
if ($existingContainer) {
    Write-BuildMessage -Type Warning -Message "Container '$AgentName' already exists; removing..."
    try {
        Remove-BcContainer -containerName $AgentName -ErrorAction Stop | Out-Null
    } catch {
        Write-BuildMessage -Type Warning -Message "Remove-BcContainer failed; using docker rm -f"
        docker rm -f $AgentName 2>$null | Out-Null
    }
    # Remove stale hosts entry
    try {
        Remove-HostsEntry -Hostname $AgentName
    } catch {
        Write-BuildMessage -Type Warning -Message "Could not remove hosts entry"
    }
    Write-BuildMessage -Type Success -Message "Previous container removed"
}

Write-BuildHeader 'Creating Agent Container'

Write-BuildMessage -Type Step -Message "Creating container '$AgentName' from snapshot..."

# Get extensions path for BcContainerHelper
$bcHelperPath = 'C:\ProgramData\BcContainerHelper'
$extensionsPath = Join-Path $bcHelperPath 'Extensions'
$agentExtPath = Join-Path $extensionsPath $AgentName

# Create extensions folder
if (-not (Test-Path $agentExtPath)) {
    New-Item -ItemType Directory -Path $agentExtPath -Force | Out-Null
}

# Create my folder for container scripts
$myPath = Join-Path $agentExtPath 'my'
if (-not (Test-Path $myPath)) {
    New-Item -ItemType Directory -Path $myPath -Force | Out-Null
}

# Run container from snapshot
$runArgs = @(
    'run', '-d',
    '--name', $AgentName,
    '--hostname', $AgentName,
    '--memory', $MemoryLimit,
    '--restart', 'unless-stopped',
    '--network', 'nat',
    '--dns', '8.8.8.8',
    '--isolation', 'process',
    '-v', 'c:\windows\system32\drivers\etc:C:\driversetc',
    '-v', 'c:\bcartifacts.cache:c:\dl',
    '-v', "${bcHelperPath}:${bcHelperPath}",
    '-v', "${myPath}:c:\run\my",
    $ImageName
)

docker @runArgs

if ($LASTEXITCODE -ne 0) {
    Write-BuildMessage -Type Error -Message "docker run failed with exit code $LASTEXITCODE"
    exit $Exit.Integration
}

Write-BuildMessage -Type Success -Message "Container started"

Write-BuildHeader 'Container Configuration'

# Wait for container to be healthy with log streaming
Write-BuildMessage -Type Step -Message "Waiting for container to become healthy..."
Write-BuildMessage -Type Info -Message "Streaming container logs while waiting..."

$logJob = Start-Job -ScriptBlock {
    param($containerName)
    docker logs -f $containerName 2>&1
} -ArgumentList $AgentName

$ready = $false
$pollDelaySeconds = 2
$unhealthyCount = 0
$unhealthyThreshold = 15  # 15 consecutive polls × 2s = 30 second grace period for BC startup retries

try {
    while ($true) {
        # Drain log output
        Receive-Job $logJob -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_ -ne $null) {
                Write-BuildMessage -Type Info -Message "  $_"
            }
        }

        $running = docker inspect $AgentName --format '{{.State.Running}}' 2>$null
        $health = docker inspect $AgentName --format '{{.State.Health.Status}}' 2>$null

        if ($running -ne 'true') {
            # Container stopped - drain remaining logs before exiting
            $exitCode = docker inspect $AgentName --format '{{.State.ExitCode}}' 2>$null
            Write-BuildMessage -Type Error -Message "Container exited before becoming healthy (exit code $exitCode)"

            Start-Sleep -Milliseconds 500
            Receive-Job $logJob -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_ -ne $null) {
                    Write-BuildMessage -Type Info -Message "  $_"
                }
            }
            exit $Exit.Integration
        }

        if ($health -eq 'healthy') {
            $ready = $true
            break
        }

        if ($health -eq 'unhealthy') {
            $unhealthyCount++
            if ($unhealthyCount -ge $unhealthyThreshold) {
                Write-BuildMessage -Type Error -Message "Container health check reported 'unhealthy' ($unhealthyCount consecutive checks)"

                Start-Sleep -Milliseconds 500
                Receive-Job $logJob -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_ -ne $null) {
                        Write-BuildMessage -Type Info -Message "  $_"
                    }
                }
                exit $Exit.Integration
            }
            Write-BuildMessage -Type Warning -Message "Container health check reported 'unhealthy' (attempt $unhealthyCount of $unhealthyThreshold, waiting...)"
        }
        else {
            $unhealthyCount = 0  # Reset on any non-unhealthy status (starting, healthy)
        }

        Start-Sleep -Seconds $pollDelaySeconds
    }
}
finally {
    Stop-Job $logJob -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $logJob -ErrorAction SilentlyContinue | Out-Null
}

if (-not $ready) {
    Write-BuildMessage -Type Error -Message "Container did not become healthy"
    exit $Exit.Integration
}

Write-BuildMessage -Type Success -Message "Container is healthy"

# Get container IP and update hosts
Write-BuildMessage -Type Step -Message "Configuring network..."
$containerIP = docker inspect $AgentName --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>$null
if ($containerIP) {
    Add-HostsEntry -Hostname $AgentName -IPAddress $containerIP
    Write-BuildMessage -Type Detail -Message "Hosts entry added: $AgentName -> $containerIP"
}

# Update PublicWebBaseUrl
Write-BuildMessage -Type Step -Message "Updating PublicWebBaseUrl..."
try {
    Update-BCPublicWebBaseUrl -ContainerName $AgentName -NewHostname $AgentName | Out-Null
    Write-BuildMessage -Type Success -Message "PublicWebBaseUrl updated"
} catch {
    Write-BuildMessage -Type Warning -Message "Could not update PublicWebBaseUrl: $_"
}

# Register container
$branch = if ($OriginalBranch) { $OriginalBranch } else { $AgentName }
Register-AgentContainer -ContainerName $AgentName -Branch $branch

Write-BuildHeader 'Agent Container Ready'
Write-BuildMessage -Type Success -Message "Container '$AgentName' is ready for use"
Write-BuildMessage -Type Detail -Message "Server URL: http://$AgentName"
