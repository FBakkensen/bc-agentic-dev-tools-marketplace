#Requires -Version 7.2
<#
.SYNOPSIS
    Validates the Claude marketplace and per-plugin manifests.
.DESCRIPTION
    Checks that every plugin listed in the Claude marketplace has a folder
    under plugins/ and a .claude-plugin/plugin.json manifest.
.EXAMPLE
    pwsh scripts/Validate-PluginStructure.ps1
#>
[CmdletBinding()]
param()

$errors = @()

function Get-MarketplacePluginNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        $script:errors += "Missing Claude marketplace: $Path"
        Write-Host "FAIL: Claude marketplace missing at $Path" -ForegroundColor Red
        return @()
    }

    try {
        $marketplace = Get-Content -Path $Path -Raw | ConvertFrom-Json
    } catch {
        $script:errors += "Invalid JSON in Claude marketplace: $Path"
        Write-Host "FAIL: Claude marketplace JSON invalid at $Path" -ForegroundColor Red
        return @()
    }

    $pluginNames = @()
    foreach ($plugin in @($marketplace.plugins)) {
        if ($null -ne $plugin.name -and $plugin.name.ToString().Trim().Length -gt 0) {
            $pluginNames += $plugin.name.ToString()
        }
    }

    Write-Host "OK: Claude marketplace loaded with $($pluginNames.Count) plugins" -ForegroundColor Green
    return $pluginNames
}

$repoRoot = Join-Path $PSScriptRoot ".."
$claudeMarketplacePath = Join-Path $repoRoot ".claude-plugin\marketplace.json"
$pluginsPath = Join-Path $repoRoot "plugins"

$claudePlugins = @(Get-MarketplacePluginNames -Path $claudeMarketplacePath)

if ($claudePlugins.Count -eq 0) {
    Write-Host "WARN: No plugins found in marketplace." -ForegroundColor Yellow
}

foreach ($pluginName in $claudePlugins) {
    $pluginPath = Join-Path $pluginsPath $pluginName
    if (-not (Test-Path $pluginPath)) {
        $errors += "Missing plugin folder for marketplace entry: $pluginName"
        Write-Host "FAIL: plugin folder missing for $pluginName" -ForegroundColor Red
        continue
    }

    $claudePluginJson = Join-Path $pluginPath ".claude-plugin\plugin.json"
    if (Test-Path $claudePluginJson) {
        Write-Host "OK: $pluginName/.claude-plugin/plugin.json exists" -ForegroundColor Green
    } else {
        $errors += "Missing .claude-plugin/plugin.json in $pluginName"
        Write-Host "FAIL: $pluginName/.claude-plugin/plugin.json missing" -ForegroundColor Red
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`nAll plugins have valid Claude structure." -ForegroundColor Cyan
