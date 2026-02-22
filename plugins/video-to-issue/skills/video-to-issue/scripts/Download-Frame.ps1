<#
.SYNOPSIS
    Download a frame image by session id and screenshot id.

.DESCRIPTION
    Fetches a single PNG frame from the Video Processing API using
    session id + screenshot id and saves it locally.

.PARAMETER SessionId
    Session id returned by the Video Processing API.

.PARAMETER ScreenshotId
    Screenshot id from the frames list (e.g., "f_0001" or "f_0001.png").

.PARAMETER ApiUrl
    Base URL of the Video Processing API.
    Default: https://func-gtm-video-to-workitem.azurewebsites.net
    For local testing: http://localhost:8000

.PARAMETER FunctionKey
    Azure Function key used for authentication when calling the hosted API.
    If not provided, the script will load it from secret.json in the skill folder.

.PARAMETER OutPath
    Optional file path for saving the image. If omitted, saves to:
    .agents\skills\video-to-issue\data\sessions\<session_id>\frames\<screenshot_id>.png
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SessionId,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ScreenshotId,

    [Parameter()]
    [string]$ApiUrl = "https://func-gtm-video-to-workitem.azurewebsites.net",

    [Parameter()]
    [string]$FunctionKey = "",

    [Parameter()]
    [string]$OutPath
)

$ErrorActionPreference = "Stop"

function Normalize-ScreenshotId {
    param([string]$Id)
    if ($Id.ToLower().EndsWith(".png")) {
        return $Id.Substring(0, $Id.Length - 4)
    }
    return $Id
}

$ScreenshotId = Normalize-ScreenshotId -Id $ScreenshotId

# Load Function key (required for non-local calls)
$isLocal = $ApiUrl -match "localhost|127\.0\.0\.1"
if (-not $isLocal -and -not $FunctionKey) {
    $secretPath = Join-Path $PSScriptRoot "..\secret.json"
    $resolvedSecret = Resolve-Path $secretPath -ErrorAction SilentlyContinue
    if ($resolvedSecret) {
        try {
            $secret = Get-Content $resolvedSecret | ConvertFrom-Json
            if ($secret.functionKey) {
                $FunctionKey = $secret.functionKey
            }
        }
        catch {
            Write-Error "Failed to read function key from $resolvedSecret. Ensure secret.json contains a 'functionKey' value."
        }
    }
}

if (-not $isLocal -and -not $FunctionKey) {
    Write-Error "Function key missing. Add it to .agents\skills\video-to-issue\secret.json or pass -FunctionKey."
}

# Build output path
if (-not $OutPath) {
    $dataRoot = Join-Path $PSScriptRoot "..\data"
    $sessionDir = Join-Path $dataRoot ("sessions\" + $SessionId)
    $framesDir = Join-Path $sessionDir "frames"
    New-Item -ItemType Directory -Path $framesDir -Force | Out-Null
    $OutPath = Join-Path $framesDir ("$ScreenshotId.png")
}
else {
    $outDir = Split-Path -Parent $OutPath
    if ($outDir) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
}

$endpoint = "$($ApiUrl.TrimEnd('/'))/sessions/$SessionId/frames/$ScreenshotId"
$headers = @{}
if (-not $isLocal) {
    $headers["x-functions-key"] = $FunctionKey
}

Write-Host "Downloading frame $ScreenshotId for session $SessionId..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $endpoint -Headers $headers -OutFile $OutPath | Out-Null
Write-Host "Saved to: $OutPath" -ForegroundColor Green

# Return file info for pipeline use
Get-Item $OutPath
