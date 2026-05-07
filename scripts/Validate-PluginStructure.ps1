#Requires -Version 7.2
<#
.SYNOPSIS
    Validates the Claude and Codex marketplaces, manifests, and instructions.
.DESCRIPTION
    Checks that every plugin listed in the Claude marketplace has a folder
    under plugins/, both Claude and Codex per-plugin manifests, and a matching
    Codex marketplace entry. Also checks that every CLAUDE.md instruction file
    has a colocated AGENTS.md bridge for Codex.
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

    if ((Test-Path $claudePluginJson) -and (Test-Path $codexPluginJson)) {
        try {
            $claudeManifest = Get-Content -Path $claudePluginJson -Raw | ConvertFrom-Json
            $codexManifest = Get-Content -Path $codexPluginJson -Raw | ConvertFrom-Json

            if ($claudeManifest.version -ne $codexManifest.version) {
                $errors += "Version mismatch in $pluginName manifests: Claude=$($claudeManifest.version), Codex=$($codexManifest.version)"
                Write-Host "FAIL: $pluginName manifest versions differ: Claude=$($claudeManifest.version), Codex=$($codexManifest.version)" -ForegroundColor Red
            } else {
                Write-Host "OK: $pluginName manifest versions match ($($claudeManifest.version))" -ForegroundColor Green
            }
        } catch {
            $errors += "Invalid JSON while comparing manifest versions in $pluginName"
            Write-Host "FAIL: cannot compare manifest versions in $pluginName" -ForegroundColor Red
        }
    }
}

$pluginAgentDirs = @(Get-ChildItem -Path $pluginsPath -Recurse -Directory -Filter "agents" -ErrorAction SilentlyContinue)
foreach ($pluginAgentDir in $pluginAgentDirs) {
    $relativeAgentDir = Resolve-Path -Path $pluginAgentDir.FullName -Relative
    $errors += "Plugin agents directory is not portable across Claude and Codex: $relativeAgentDir"
    Write-Host "FAIL: plugin agents directory is not portable: $relativeAgentDir" -ForegroundColor Red
}

$runtimeSkillFiles = @(Get-ChildItem -Path $pluginsPath -Recurse -File -Filter "SKILL.md" -ErrorAction SilentlyContinue)
foreach ($runtimeSkillFile in $runtimeSkillFiles) {
    $content = Get-Content -Path $runtimeSkillFile.FullName -Raw
    $relativeRuntimePath = Resolve-Path -Path $runtimeSkillFile.FullName -Relative

    if ($content -match "Agent\(" -or
        $content -match "Skill\(" -or
        $content -match "mcp__" -or
        $content -match "subagent_type" -or
        $content -match "al-agentic-dev:al-") {
        $errors += "Runtime skill contains host-specific tool invocation syntax or namespaced plugin-agent reference: $relativeRuntimePath"
        Write-Host "FAIL: runtime skill contains host-specific tool syntax: $relativeRuntimePath" -ForegroundColor Red
    }
}

$claudeInstructionFiles = @(Get-ChildItem -Path $repoRoot -Recurse -Filter "CLAUDE.md")
foreach ($claudeInstructionFile in $claudeInstructionFiles) {
    $agentsInstructionPath = Join-Path $claudeInstructionFile.Directory.FullName "AGENTS.md"
    $relativeClaudePath = Resolve-Path -Path $claudeInstructionFile.FullName -Relative
    $relativeAgentsPath = Resolve-Path -Path $agentsInstructionPath -Relative -ErrorAction SilentlyContinue

    if (Test-Path $agentsInstructionPath) {
        Write-Host "OK: $relativeAgentsPath exists" -ForegroundColor Green
    } else {
        $errors += "Missing AGENTS.md next to $relativeClaudePath"
        Write-Host "FAIL: missing AGENTS.md next to $relativeClaudePath" -ForegroundColor Red
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "`nAll plugins have valid Claude and Codex structure." -ForegroundColor Cyan
