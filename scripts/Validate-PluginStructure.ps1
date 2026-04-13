#Requires -Version 7.2
<#
.SYNOPSIS
    Validates that Claude and Codex marketplaces stay in sync and that each
    listed plugin has both manifest formats.
.DESCRIPTION
    Checks that every plugin listed in the Claude marketplace also appears in
    the Codex marketplace, that every listed plugin folder exists, and that
    each listed plugin has both .claude-plugin/plugin.json and
    .codex-plugin/plugin.json.
.EXAMPLE
    pwsh scripts/Validate-PluginStructure.ps1
#>
[CmdletBinding()]
param()

$errors = @()

function Get-MarketplacePluginNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path $Path)) {
        $script:errors += "Missing $Label marketplace: $Path"
        Write-Host "FAIL: $Label marketplace missing at $Path" -ForegroundColor Red
        return @()
    }

    try {
        $marketplace = Get-Content -Path $Path -Raw | ConvertFrom-Json
    } catch {
        $script:errors += "Invalid JSON in $Label marketplace: $Path"
        Write-Host "FAIL: $Label marketplace JSON invalid at $Path" -ForegroundColor Red
        return @()
    }

    $pluginNames = @()
    foreach ($plugin in @($marketplace.plugins)) {
        if ($null -ne $plugin.name -and $plugin.name.ToString().Trim().Length -gt 0) {
            $pluginNames += $plugin.name.ToString()
        }
    }

    Write-Host "OK: $Label marketplace loaded with $($pluginNames.Count) plugins" -ForegroundColor Green
    return $pluginNames
}

$repoRoot = Join-Path $PSScriptRoot ".."
$claudeMarketplacePath = Join-Path $repoRoot ".claude-plugin\marketplace.json"
$codexMarketplacePath = Join-Path $repoRoot ".agents\plugins\marketplace.json"
$pluginsPath = Join-Path $repoRoot "plugins"

$claudePlugins = @(Get-MarketplacePluginNames -Path $claudeMarketplacePath -Label "Claude")
$codexPlugins = @(Get-MarketplacePluginNames -Path $codexMarketplacePath -Label "Codex")

if ($claudePlugins.Count -gt 0 -and $codexPlugins.Count -gt 0) {
    $claudeSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$claudePlugins)
    $codexSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$codexPlugins)

    $missingInCodex = @($claudePlugins | Where-Object { -not $codexSet.Contains($_) })
    $extraInCodex = @($codexPlugins | Where-Object { -not $claudeSet.Contains($_) })

    if ($missingInCodex.Count -gt 0) {
        $errors += "Claude marketplace plugins missing from Codex marketplace: $($missingInCodex -join ', ')"
        Write-Host "FAIL: Claude plugins missing in Codex marketplace: $($missingInCodex -join ', ')" -ForegroundColor Red
    }

    if ($extraInCodex.Count -gt 0) {
        $errors += "Codex marketplace has extra plugins not in Claude marketplace: $($extraInCodex -join ', ')"
        Write-Host "FAIL: Codex marketplace has extra plugins: $($extraInCodex -join ', ')" -ForegroundColor Red
    }

    if (($claudePlugins -join '|') -ne ($codexPlugins -join '|')) {
        $errors += "Claude and Codex marketplace plugin order differs."
        Write-Host "FAIL: Claude and Codex marketplace plugin order differs" -ForegroundColor Red
    }
}

if ($claudePlugins.Count -eq 0 -and $codexPlugins.Count -eq 0) {
    Write-Host "WARN: No plugins found in either marketplace." -ForegroundColor Yellow
}

$allPlugins = @($claudePlugins + $codexPlugins | Sort-Object -Unique)
foreach ($pluginName in $allPlugins) {
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
