#requires -Version 7.2

<#
.SYNOPSIS
    Remove orphaned or stale agent containers.

.DESCRIPTION
    Finds and removes BC agent containers that are:
    - Orphaned: branch no longer exists locally
    - Stale: unused for more than 7 days

.PARAMETER Preview
    Show what would be removed without making changes.

.EXAMPLE
    pwsh -File prune.ps1
    # Remove orphaned containers

.EXAMPLE
    pwsh -File prune.ps1 -Preview
    # Preview only (dry run)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Preview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Import modules
Import-Module "$PSScriptRoot/common.psm1" -Force -DisableNameChecking

Write-BuildHeader 'Prune: Orphaned Container Cleanup'

Remove-OrphanedAgentContainers -WhatIf:$Preview
