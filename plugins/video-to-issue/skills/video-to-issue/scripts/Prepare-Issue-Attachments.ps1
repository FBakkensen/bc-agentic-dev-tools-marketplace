<#
.SYNOPSIS
    Prepare extracted frames for manual attachment to an issue.

.DESCRIPTION
    Reads a video processing result JSON file, downloads selected frames
    from the API via Download-Frame.ps1, and prints a list of files to attach manually.

.PARAMETER ResultJson
    Path to video processing result JSON file.

.PARAMETER FrameIndices
    Array of frame indices to extract (0-based). Default: first, middle, last.

.PARAMETER ScreenshotIds
    Array of screenshot IDs to download (e.g., "f_0001", "f_0010"). Mutually exclusive with FrameIndices.

.PARAMETER OutDir
    Optional output folder. If omitted, uses the skill data folder under the session.

.EXAMPLE
    .\Prepare-Issue-Attachments.ps1 -ResultJson "$env:TEMP\video-result.json"

.EXAMPLE
    .\Prepare-Issue-Attachments.ps1 -ResultJson "$env:TEMP\video-result.json" -FrameIndices 0,5,10

.EXAMPLE
    .\Prepare-Issue-Attachments.ps1 -ResultJson "$env:TEMP\video-result.json" -ScreenshotIds "f_0003","f_0015","f_0042"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResultJson,

    [Parameter()]
    [int[]]$FrameIndices,

    [Parameter()]
    [string[]]$ScreenshotIds,

    [Parameter()]
    [string]$OutDir
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ResultJson -PathType Leaf)) {
    Write-Error "Result JSON not found: $ResultJson"
}

$json = Get-Content $ResultJson -Raw | ConvertFrom-Json
$frames = $json.frames
$sessionId = $json.session_id

if (-not $frames -or $frames.Count -eq 0) {
    Write-Warning "No frames found in result JSON"
    exit 0
}

if (-not $sessionId) {
    Write-Error "No session_id found in result JSON. Cannot download frames from API."
}

# Resolve which frames to download
$selectedFrames = @()

if ($ScreenshotIds) {
    foreach ($sid in $ScreenshotIds) {
        $match = $frames | Where-Object { $_.screenshot_id -eq $sid -or $_.name -eq $sid -or $_.name -eq "$sid.png" }
        if ($match) {
            $selectedFrames += $match
        } else {
            Write-Warning "Screenshot ID '$sid' not found in result JSON, skipping"
        }
    }
} else {
    # Use FrameIndices - default: first, middle, last (deduplicated)
    if (-not $FrameIndices) {
        $FrameIndices = @(0, [math]::Floor($frames.Count / 2), $frames.Count - 1) | Sort-Object -Unique
    }

    foreach ($idx in $FrameIndices) {
        if ($idx -lt 0 -or $idx -ge $frames.Count) {
            Write-Warning "Frame index $idx out of range (0-$($frames.Count - 1)), skipping"
            continue
        }
        $selectedFrames += $frames[$idx]
    }
}

if ($selectedFrames.Count -eq 0) {
    Write-Warning "No frames selected for download"
    exit 0
}

# Determine output directory
if (-not $OutDir) {
    $dataRoot = Join-Path $PSScriptRoot "..\data"
    $OutDir = Join-Path $dataRoot ("sessions\" + $sessionId + "\issue-attachments")
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$downloadScript = Join-Path $PSScriptRoot "Download-Frame.ps1"
$output = @()

Write-Host "Downloading $($selectedFrames.Count) frame(s) from $($frames.Count) total..." -ForegroundColor Cyan

foreach ($frame in $selectedFrames) {
    $timestamp = $frame.timestamp_formatted
    if (-not $timestamp) {
        $timestamp = $frame.screenshot_id
    }

    $fileName = "frame_$($timestamp -replace ':', '-').png"
    $filePath = Join-Path $OutDir $fileName

    & $downloadScript -SessionId $sessionId -ScreenshotId $frame.screenshot_id -OutPath $filePath | Out-Null

    $transcriptSnippet = $frame.transcription
    if ($transcriptSnippet -and $transcriptSnippet.Length -gt 100) {
        $transcriptSnippet = $transcriptSnippet.Substring(0, 97) + "..."
    }

    $output += [PSCustomObject]@{
        ScreenshotId = $frame.screenshot_id
        Timestamp    = $frame.timestamp_formatted
        Path         = $filePath
        Transcript   = $transcriptSnippet
    }

    Write-Host "  [$timestamp] $fileName" -ForegroundColor Gray
}

Write-Host "`nAttach these files manually to the issue:" -ForegroundColor Cyan
foreach ($item in $output) {
    $line = "  - $($item.Path)"
    if ($item.Timestamp) {
        $line += " ($($item.Timestamp))"
    }
    Write-Host $line -ForegroundColor Gray
}

# Return the list for pipeline use
$output
