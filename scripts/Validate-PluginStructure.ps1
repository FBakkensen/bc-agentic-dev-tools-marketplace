#Requires -Version 7.2
<#
.SYNOPSIS
    Validates the Claude and Codex marketplaces and per-plugin manifests.
.DESCRIPTION
    Checks that every plugin listed in the Claude marketplace has a folder
    under plugins/, both Claude and Codex per-plugin manifests, and a matching
    Codex marketplace entry.
.EXAMPLE
    pwsh scripts/Validate-PluginStructure.ps1
#>
[CmdletBinding()]
param()

$errors = @()

function Get-ClaudeMarketplacePluginNames {
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

function Get-CodexMarketplacePluginNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        $script:errors += "Missing Codex marketplace: $Path"
        Write-Host "FAIL: Codex marketplace missing at $Path" -ForegroundColor Red
        return @()
    }

    try {
        $marketplace = Get-Content -Path $Path -Raw | ConvertFrom-Json
    } catch {
        $script:errors += "Invalid JSON in Codex marketplace: $Path"
        Write-Host "FAIL: Codex marketplace JSON invalid at $Path" -ForegroundColor Red
        return @()
    }

    $pluginNames = @()
    foreach ($plugin in @($marketplace.plugins)) {
        if ($null -ne $plugin.name -and $plugin.name.ToString().Trim().Length -gt 0) {
            $pluginNames += $plugin.name.ToString()
        }

        if ($null -eq $plugin.policy -or
            $null -eq $plugin.policy.installation -or
            $null -eq $plugin.policy.authentication -or
            $null -eq $plugin.category) {
            $script:errors += "Codex marketplace entry missing policy/category fields: $($plugin.name)"
            Write-Host "FAIL: Codex marketplace entry missing policy/category fields: $($plugin.name)" -ForegroundColor Red
        }
    }

    Write-Host "OK: Codex marketplace loaded with $($pluginNames.Count) plugins" -ForegroundColor Green
    return $pluginNames
}

$repoRoot = Join-Path $PSScriptRoot ".."
$claudeMarketplacePath = Join-Path $repoRoot ".claude-plugin\marketplace.json"
$codexMarketplacePath = Join-Path $repoRoot ".agents\plugins\marketplace.json"
$pluginsPath = Join-Path $repoRoot "plugins"

$claudePlugins = @(Get-ClaudeMarketplacePluginNames -Path $claudeMarketplacePath)
$codexPlugins = @(Get-CodexMarketplacePluginNames -Path $codexMarketplacePath)

if ($claudePlugins.Count -eq 0) {
    Write-Host "WARN: No plugins found in Claude marketplace." -ForegroundColor Yellow
}

if ($codexPlugins.Count -eq 0) {
    Write-Host "WARN: No plugins found in Codex marketplace." -ForegroundColor Yellow
}

$missingFromCodex = @($claudePlugins | Where-Object { $_ -notin $codexPlugins })
$extraInCodex = @($codexPlugins | Where-Object { $_ -notin $claudePlugins })

foreach ($pluginName in $missingFromCodex) {
    $errors += "Plugin listed in Claude marketplace but missing from Codex marketplace: $pluginName"
    Write-Host "FAIL: $pluginName missing from Codex marketplace" -ForegroundColor Red
}

foreach ($pluginName in $extraInCodex) {
    $errors += "Plugin listed in Codex marketplace but missing from Claude marketplace: $pluginName"
    Write-Host "FAIL: $pluginName missing from Claude marketplace" -ForegroundColor Red
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

    $codexPluginJson = Join-Path $pluginPath ".codex-plugin\plugin.json"
    if (Test-Path $codexPluginJson) {
        Write-Host "OK: $pluginName/.codex-plugin/plugin.json exists" -ForegroundColor Green
    } else {
        $errors += "Missing .codex-plugin/plugin.json in $pluginName"
        Write-Host "FAIL: $pluginName/.codex-plugin/plugin.json missing" -ForegroundColor Red
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`nAll plugins have valid Claude and Codex structure." -ForegroundColor Cyan
