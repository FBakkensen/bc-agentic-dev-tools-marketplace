<#
.SYNOPSIS
    Generates a comprehensive release analysis document for AI-assisted release note generation.

.DESCRIPTION
    This script analyzes all changes between the last release and HEAD, organizing the data
    by Pull Request. It generates a structured JSONL document that can be queried with jq
    and fed to an AI agent for release note generation.

    The output includes:
    - Release boundary information (summary record)
    - Complete PR inventory with descriptions and diffs (one record per PR)
    - File change categorization
    - Breaking change indicators

.PARAMETER OutputPath
    Path where the analysis document will be saved. Defaults to '.output/releases/release-analysis.jsonl'

.PARAMETER Tag
    Specific release tag to compare against. If not specified, uses the latest release.

.PARAMETER PreviousTag
    Previous release tag to compare from. When specified, the analysis covers changes between
    PreviousTag and Tag (i.e., what went into the Tag release). When omitted, compares Tag to HEAD.

.PARAMETER IncludeFullDiff
    If specified, includes full file diffs in the output. Otherwise, includes only key AL changes.

.EXAMPLE
    .\Get-ReleaseAnalysis.ps1
    Generates analysis comparing latest release to HEAD.

.EXAMPLE
    .\Get-ReleaseAnalysis.ps1 -Tag "v26.0.0" -IncludeFullDiff
    Generates analysis comparing v26.0.0 to HEAD with full diffs.

.EXAMPLE
    .\Get-ReleaseAnalysis.ps1 -Tag "27.7.0" -PreviousTag "27.6.0"
    Generates analysis for the 27.7.0 release, showing changes between 27.6.0 and 27.7.0.

.NOTES
    Output format is JSONL (JSON Lines) - one JSON object per line.
    Use jq to query the output:

    # Get summary
    jq 'select(.type == "summary")' .output/releases/release-analysis.jsonl

    # List all PR titles
    jq -r 'select(.type == "pr") | "#\(.number): \(.title)"' .output/releases/release-analysis.jsonl

    # Get PRs with breaking changes
    jq 'select(.type == "pr" and .breakingChangeIndicators | length > 0)' .output/releases/release-analysis.jsonl

    # Get PRs that modified Pages
    jq 'select(.type == "pr" and .filesByCategory.Page)' .output/releases/release-analysis.jsonl
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = ".output/releases/release-analysis.jsonl",

    [Parameter()]
    [string]$Tag,

    [Parameter()]
    [string]$PreviousTag,

    [Parameter()]
    [switch]$IncludeFullDiff
)

$ErrorActionPreference = 'Stop'

# === Helper Functions ===

function Get-LatestReleaseTag {
    $releases = gh release list --limit 1 --json tagName | ConvertFrom-Json
    if (-not $releases -or $releases.Count -eq 0) {
        throw "No releases found in repository"
    }
    return $releases[0].tagName
}

function Get-ReleaseInfo {
    param([string]$TagName)

    $info = gh release view $TagName --json tagName,publishedAt,name | ConvertFrom-Json
    return $info
}

function Get-ReleaseDateForSearch {
    param($ReleaseInfo)

    # The publishedAt from gh comes as a DateTime object after ConvertFrom-Json
    # We need YYYY-MM-DD format for GitHub search
    $published = $ReleaseInfo.publishedAt

    if ($published -is [DateTime]) {
        return $published.ToString("yyyy-MM-dd")
    }

    # If it's a string (ISO 8601 format like 2025-09-18T06:13:45Z)
    if ($published -is [string]) {
        if ($published -match '^(\d{4}-\d{2}-\d{2})') {
            return $Matches[1]
        }
        # Try parsing
        $parsedDate = [DateTime]::Parse($published)
        return $parsedDate.ToString("yyyy-MM-dd")
    }

    throw "Could not extract date from release info: $published"
}

function Get-PreviousReleaseTag {
    param([string]$CurrentTag)

    $allTags = git tag --sort=-v:refname
    $found = $false
    foreach ($t in $allTags) {
        if ($found) {
            return $t
        }
        if ($t -eq $CurrentTag) {
            $found = $true
        }
    }
    throw "No previous release tag found before '$CurrentTag'"
}

function Get-PRNumbersFromGitLog {
    param([string]$Range)

    # Extract PR numbers from merge commit messages like "Some title (#123)"
    $logLines = git log $Range --oneline --first-parent
    $prNumbers = @()
    foreach ($line in $logLines) {
        if ($line -match '\(#(\d+)\)\s*$') {
            $prNumbers += [int]$Matches[1]
        }
    }
    return $prNumbers
}

function Get-MergedPRsByNumbers {
    param([int[]]$PRNumbers)

    $prs = @()
    foreach ($num in $PRNumbers) {
        Write-Host "  Fetching PR #$num..." -ForegroundColor Gray
        $pr = gh pr view $num --json number,title,body,mergedAt,labels,author 2>$null | ConvertFrom-Json
        if ($pr) {
            $prs += $pr
        }
    }
    return $prs | Sort-Object mergedAt
}

function Get-PRFiles {
    param([int]$PRNumber)

    $files = gh pr view $PRNumber --json files --jq '.files[].path' 2>$null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    return $files
}

function Get-PRDiff {
    param([int]$PRNumber)

    $diff = gh pr diff $PRNumber 2>$null
    return $diff
}

function Get-PRCommits {
    param([int]$PRNumber)

    $commits = gh pr view $PRNumber --json commits --jq '.commits[] | "\(.oid[0:7]) \(.messageHeadline)"' 2>$null
    return $commits
}

function Get-FileCategory {
    param([string]$FilePath)

    if ($FilePath -match '\.Table\.al$') { return 'Table' }
    if ($FilePath -match '\.TableExt\.al$') { return 'TableExtension' }
    if ($FilePath -match '\.Page\.al$') { return 'Page' }
    if ($FilePath -match '\.PageExt\.al$') { return 'PageExtension' }
    if ($FilePath -match '\.Codeunit\.al$') { return 'Codeunit' }
    if ($FilePath -match '\.Report\.al$') { return 'Report' }
    if ($FilePath -match '\.ReportExt\.al$') { return 'ReportExtension' }
    if ($FilePath -match '\.Enum\.al$') { return 'Enum' }
    if ($FilePath -match '\.EnumExt\.al$') { return 'EnumExtension' }
    if ($FilePath -match '\.Interface\.al$') { return 'Interface' }
    if ($FilePath -match '\.PermissionSet\.al$') { return 'PermissionSet' }
    if ($FilePath -match '\.PermissionSetExt\.al$') { return 'PermissionSetExtension' }
    if ($FilePath -match '\.Query\.al$') { return 'Query' }
    if ($FilePath -match '\.Entitlement\.al$') { return 'Entitlement' }
    if ($FilePath -match '\.ControlAddin\.al$') { return 'ControlAddin' }
    if ($FilePath -match '\.al$') { return 'Other AL' }
    if ($FilePath -match '\.(js|css|html)$') { return 'Web Resources' }
    if ($FilePath -match '\.xlf$') { return 'Translations' }
    if ($FilePath -match 'app\.json$') { return 'App Manifest' }
    if ($FilePath -match '\.(md|txt)$') { return 'Documentation' }
    if ($FilePath -match '\.(ps1|psm1)$') { return 'Scripts' }
    return 'Other'
}

function Find-BreakingChangeIndicators {
    param([string]$Diff)

    $indicators = @()

    # Removed procedures
    if ($Diff -match '^\-\s*(local\s+)?procedure\s+\w+') {
        $indicators += "Potentially removed procedure(s)"
    }

    # ObsoleteState changes
    if ($Diff -match 'ObsoleteState\s*=\s*Removed') {
        $indicators += "Obsolete items marked as Removed"
    }

    # Removed fields
    if ($Diff -match '^\-\s*field\(\d+;') {
        $indicators += "Potentially removed field(s)"
    }

    # Changed Access modifiers
    if ($Diff -match '^\-.*Access\s*=\s*Public' -and $Diff -match '^\+.*Access\s*=\s*Internal') {
        $indicators += "Public API changed to Internal"
    }

    return $indicators
}

function Format-PRBody {
    param([string]$Body)

    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $null
    }

    # Clean up the body - remove excessive whitespace but preserve structure
    return $Body.Trim()
}

# === Main Script ===

Write-Host "🔍 Starting Release Analysis..." -ForegroundColor Cyan

# Step 1: Determine release boundary
if (-not $Tag) {
    Write-Host "  Finding latest release tag..." -ForegroundColor Gray
    $Tag = Get-LatestReleaseTag
}

Write-Host "  Comparing against: $Tag" -ForegroundColor Green

$releaseInfo = Get-ReleaseInfo -TagName $Tag
$releaseDate = $releaseInfo.publishedAt
$releaseDateForSearch = Get-ReleaseDateForSearch -ReleaseInfo $releaseInfo

Write-Host "  Release date: $releaseDate (search: $releaseDateForSearch)" -ForegroundColor Gray

# Step 2: Determine comparison target (HEAD or the release tag itself)
if ($PreviousTag) {
    $previousReleaseInfo = Get-ReleaseInfo -TagName $PreviousTag
    $previousReleaseDateForSearch = Get-ReleaseDateForSearch -ReleaseInfo $previousReleaseInfo
    $compareTarget = $Tag
    Write-Host "  Previous release: $PreviousTag (date: $previousReleaseDateForSearch)" -ForegroundColor Gray
} else {
    $compareTarget = "HEAD"
}

$diffRange = if ($PreviousTag) { "$PreviousTag..$Tag" } else { "$Tag..HEAD" }

# Step 3: Get all merged PRs (from git log, not date-based search)
Write-Host "📋 Fetching merged PRs..." -ForegroundColor Cyan
$prNumbers = Get-PRNumbersFromGitLog -Range $diffRange
Write-Host "  Found PR numbers from git log: $($prNumbers -join ', ')" -ForegroundColor Gray
$prs = Get-MergedPRsByNumbers -PRNumbers $prNumbers

Write-Host "  Found $($prs.Count) merged PR(s)" -ForegroundColor Green

if ($prs.Count -eq 0) {
    Write-Host "⚠️ No PRs found. Checking for direct commits..." -ForegroundColor Yellow
}

# Step 4: Get overall diff statistics
Write-Host "📊 Calculating diff statistics..." -ForegroundColor Cyan
$changedFiles = git diff $diffRange --name-only
$commitCount = git rev-list --count $diffRange
$allCommits = git log $diffRange --oneline --no-merges

# Get app.json diff for version info
$appJsonDiff = git diff $diffRange -- "app/app.json" 2>$null

# Step 5: Build the JSONL output
Write-Host "📝 Generating JSONL analysis document..." -ForegroundColor Cyan

$outputLines = [System.Collections.ArrayList]::new()

# === Summary Record ===
$categoryStats = @{}
$changedFiles | ForEach-Object {
    $cat = Get-FileCategory $_
    if ($categoryStats.ContainsKey($cat)) {
        $categoryStats[$cat]++
    } else {
        $categoryStats[$cat] = 1
    }
}

$summaryRecord = [ordered]@{
    type = "summary"
    generated = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
    compareFrom = if ($PreviousTag) { $PreviousTag } else { $Tag }
    compareTo = $compareTarget
    releaseDate = $releaseDateForSearch
    totalCommits = [int]$commitCount
    totalPRs = $prs.Count
    totalFilesChanged = $changedFiles.Count
    filesByCategory = $categoryStats
    appJsonDiff = $appJsonDiff
    allCommits = @($allCommits)
}

[void]$outputLines.Add(($summaryRecord | ConvertTo-Json -Compress -Depth 10))

# === PR Records ===
foreach ($pr in $prs) {
    Write-Host "  Analyzing PR #$($pr.number): $($pr.title)" -ForegroundColor Gray

    # Get PR files
    $prFiles = Get-PRFiles -PRNumber $pr.number

    # Group files by category
    $filesByCategory = @{}
    if ($prFiles) {
        $prFiles | ForEach-Object {
            $cat = Get-FileCategory $_
            if (-not $filesByCategory.ContainsKey($cat)) {
                $filesByCategory[$cat] = @()
            }
            $filesByCategory[$cat] += $_
        }
    }

    # Get commits
    $prCommits = Get-PRCommits -PRNumber $pr.number

    # Get diff and analyze
    $prDiff = Get-PRDiff -PRNumber $pr.number
    $breakingIndicators = @()
    $keyAlChanges = $null

    if ($prDiff) {
        $breakingIndicators = Find-BreakingChangeIndicators -Diff $prDiff

        if ($IncludeFullDiff) {
            $keyAlChanges = $prDiff
        } else {
            # Extract key AL changes
            $alDiffLines = $prDiff -split "`n" | Where-Object {
                $_ -match '^diff --git.*\.al$' -or
                $_ -match '^\+\+\+' -or
                $_ -match '^@@' -or
                $_ -match '^\+\s*(local\s+)?procedure' -or
                $_ -match '^\-\s*(local\s+)?procedure' -or
                $_ -match '^\+\s*field\(' -or
                $_ -match '^\-\s*field\(' -or
                $_ -match '^\+\s*action\(' -or
                $_ -match '^\-\s*action\(' -or
                $_ -match 'ObsoleteState' -or
                $_ -match 'ObsoleteReason'
            }
            if ($alDiffLines) {
                $keyAlChanges = $alDiffLines -join "`n"
            }
        }
    }

    $prRecord = [ordered]@{
        type = "pr"
        number = $pr.number
        title = $pr.title
        author = $pr.author.login
        mergedAt = $pr.mergedAt.ToString("yyyy-MM-ddTHH:mm:ssZ")
        labels = @($pr.labels | ForEach-Object { $_.name })
        description = (Format-PRBody -Body $pr.body)
        filesChanged = if ($prFiles) { $prFiles.Count } else { 0 }
        filesByCategory = $filesByCategory
        commits = @($prCommits)
        breakingChangeIndicators = @($breakingIndicators)
        keyAlChanges = $keyAlChanges
    }

    [void]$outputLines.Add(($prRecord | ConvertTo-Json -Compress -Depth 10))
}

# Write output file
$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$outputLines -join "`n" | Out-File -FilePath $OutputPath -Encoding utf8 -NoNewline

Write-Host ""
Write-Host "✅ Analysis complete!" -ForegroundColor Green
Write-Host "   Output: $OutputPath" -ForegroundColor Cyan
Write-Host "   PRs analyzed: $($prs.Count)" -ForegroundColor Gray
Write-Host "   Files changed: $($changedFiles.Count)" -ForegroundColor Gray
Write-Host ""
Write-Host "Query examples with jq:" -ForegroundColor Yellow
Write-Host "  jq 'select(.type == ""summary"")' $OutputPath" -ForegroundColor Gray
Write-Host "  jq -r 'select(.type == ""pr"") | ""#\(.number): \(.title)""' $OutputPath" -ForegroundColor Gray
Write-Host "  jq 'select(.type == ""pr"" and .breakingChangeIndicators | length > 0)' $OutputPath" -ForegroundColor Gray
