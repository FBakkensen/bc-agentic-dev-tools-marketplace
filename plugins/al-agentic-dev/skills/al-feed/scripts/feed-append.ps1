#Requires -Version 7.2
<#
.SYNOPSIS
    Append one composed branch-feed card and regenerate feed.html.
.DESCRIPTION
    Thin CLI wrapper over feed.psm1's Add-FeedCard. /al-feed composes the card
    (punchline + layers) and calls this; the module owns append + render.
.EXAMPLE
    pwsh feed-append.ps1 -SpecDir specs/090-prepayment-hold -Skill /al-implement `
        -Kind verdict -Punchline "A test caught a rounding mistake before it shipped." `
        -LayersJson '[{"label":"What surprised me","body":"..."}]' `
        -Branch 090-prepayment-hold -Title "Hold customer prepayments against the order"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SpecDir,
    [Parameter(Mandatory)][string]$Skill,
    [Parameter(Mandatory)][ValidateSet('decision', 'verdict', 'surprise', 'landing')][string]$Kind,
    [Parameter(Mandatory)][string]$Punchline,
    [string]$LayersJson = '[]',
    [string]$Ts = '',
    [string]$Branch = '',
    [string]$Title = '',
    [string]$TemplatePath = ''
)

Import-Module (Join-Path $PSScriptRoot 'feed.psm1') -Force

$layers = @()
if (-not [string]::IsNullOrWhiteSpace($LayersJson)) {
    try {
        $layers = @($LayersJson | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        throw "LayersJson is not valid JSON: $($_.Exception.Message)"
    }
}

$params = @{
    SpecDir   = $SpecDir
    Skill     = $Skill
    Kind      = $Kind
    Punchline = $Punchline
    Layers    = $layers
    Branch    = $Branch
    Title     = $Title
}
if (-not [string]::IsNullOrWhiteSpace($Ts)) { $params.Ts = $Ts }
if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) { $params.TemplatePath = $TemplatePath }

$null = Add-FeedCard @params
Write-Host "feed: appended $Kind card from $Skill -> $(Join-Path $SpecDir 'feed.html')" -ForegroundColor Cyan
