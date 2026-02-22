<#
.SYNOPSIS
    Upload a video to the Video Processing API and retrieve frames + transcription.

.DESCRIPTION
    Sends a video file to the Azure-hosted Video Processing API.
    Returns JSON with extracted frames (base64 PNG), timestamps, and transcription.

    The API extracts key frames and transcribes audio using Azure OpenAI Whisper.
    Use the output to create a GitHub issue with your preferred tooling.

.PARAMETER VideoPath
    Path to the video file to process.

.PARAMETER ApiUrl
    Base URL of the Video Processing API.
    Default: https://func-gtm-video-to-workitem.azurewebsites.net
    For local testing: http://localhost:8000

.PARAMETER FunctionKey
    Azure Function key used for authentication when calling the hosted API.
    If not provided, the script will load it from secret.json in the skill folder.

.PARAMETER Interval
    Seconds between frame extractions. Default: 2.0

.PARAMETER MaxFrames
    Maximum number of frames to extract. Default: 100

.PARAMETER Language
    Language code for transcription (e.g., 'en-US', 'da-DK').
    Leave empty for auto-detection.

.PARAMETER SkipTranscription
    Skip audio transcription (faster, frames only).

.PARAMETER OutputPath
    Path to save output JSON. If not specified, outputs to console.

.EXAMPLE
    # Process video and output to console
    .\Invoke-VideoProcessing.ps1 -VideoPath "C:\Videos\demo.mp4"

.EXAMPLE
    # Process with specific settings and save to file
    .\Invoke-VideoProcessing.ps1 -VideoPath "C:\Videos\demo.mp4" -Interval 3.0 -MaxFrames 10 -OutputPath ".\result.json"

.EXAMPLE
    # Use local API for testing
    .\Invoke-VideoProcessing.ps1 -VideoPath "C:\Videos\demo.mp4" -ApiUrl "http://localhost:8000"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$VideoPath,

    [Parameter()]
    [string]$ApiUrl = "https://func-gtm-video-to-workitem.azurewebsites.net",

    [Parameter()]
    [double]$Interval = 2.0,

    [Parameter()]
    [int]$MaxFrames = 100,

    [Parameter()]
    [string]$FunctionKey = "",

    [Parameter()]
    [string]$Language = "",

    [Parameter()]
    [switch]$SkipTranscription,

    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

# Resolve full path
$VideoPath = Resolve-Path $VideoPath

# Validate video file
$videoInfo = Get-Item $VideoPath
$validExtensions = @('.mp4', '.mkv', '.avi', '.mov', '.webm', '.wmv')
if ($videoInfo.Extension -notin $validExtensions) {
    Write-Error "Unsupported video format: $($videoInfo.Extension). Supported: $($validExtensions -join ', ')"
}

Write-Host "Processing: $($videoInfo.Name) ($([math]::Round($videoInfo.Length / 1MB, 2)) MB)" -ForegroundColor Cyan

# Build API URL
$endpoint = "$($ApiUrl.TrimEnd('/'))/process-video"

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

# Build form data
$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"

# Read video file
$videoBytes = [System.IO.File]::ReadAllBytes($VideoPath)
$videoBase64 = [Convert]::ToBase64String($videoBytes)

# Build multipart form body
$bodyLines = @(
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=`"$($videoInfo.Name)`"",
    "Content-Type: video/$($videoInfo.Extension.TrimStart('.'))",
    "",
    ""
)

$bodyEnd = @(
    "",
    "--$boundary",
    "Content-Disposition: form-data; name=`"interval`"",
    "",
    $Interval.ToString(),
    "--$boundary",
    "Content-Disposition: form-data; name=`"max_frames`"",
    "",
    $MaxFrames.ToString(),
    "--$boundary",
    "Content-Disposition: form-data; name=`"skip_transcription`"",
    "",
    $SkipTranscription.ToString().ToLower()
)

if ($Language) {
    $bodyEnd += @(
        "--$boundary",
        "Content-Disposition: form-data; name=`"language`"",
        "",
        $Language
    )
}

$bodyEnd += "--$boundary--"

# Combine body parts
$bodyStart = ($bodyLines -join $LF)
$bodyEndStr = ($bodyEnd -join $LF)

$encoding = [System.Text.Encoding]::UTF8
$bodyStartBytes = $encoding.GetBytes($bodyStart)
$bodyEndBytes = $encoding.GetBytes($bodyEndStr)

# Create final body with video bytes in the middle
$body = New-Object byte[] ($bodyStartBytes.Length + $videoBytes.Length + $bodyEndBytes.Length)
[System.Buffer]::BlockCopy($bodyStartBytes, 0, $body, 0, $bodyStartBytes.Length)
[System.Buffer]::BlockCopy($videoBytes, 0, $body, $bodyStartBytes.Length, $videoBytes.Length)
[System.Buffer]::BlockCopy($bodyEndBytes, 0, $body, $bodyStartBytes.Length + $videoBytes.Length, $bodyEndBytes.Length)

# Make request
Write-Host "Uploading to API..." -ForegroundColor Yellow
$headers = @{
    "Content-Type" = "multipart/form-data; boundary=$boundary"
}
if (-not $isLocal) {
    if (-not $FunctionKey) {
        Write-Error "Function key missing. Add it to .agents\skills\video-to-issue\secret.json or pass -FunctionKey."
    }
    $headers["x-functions-key"] = $FunctionKey
}

try {
    $response = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $headers -Body $body -TimeoutSec 300

    Write-Host "Processing complete!" -ForegroundColor Green
    Write-Host "  Duration: $($response.video_duration)s" -ForegroundColor Gray
    Write-Host "  Frames: $($response.frame_count)" -ForegroundColor Gray

    if ($response.transcription -and $response.transcription.has_speech) {
        Write-Host "  Transcription: $($response.transcription.language)" -ForegroundColor Gray
        Write-Host "  Text: $($response.transcription.text.Substring(0, [Math]::Min(100, $response.transcription.text.Length)))..." -ForegroundColor Gray
    }

    if ($OutputPath) {
        $response | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "Output saved to: $OutputPath" -ForegroundColor Green
    }
    else {
        # Return as object (for pipeline use)
        $response
    }

    # Always save to skill data folder
    if ($response.session_id) {
        $dataRoot = Join-Path $PSScriptRoot "..\data"
        $sessionDir = Join-Path $dataRoot ("sessions\" + $response.session_id)
        New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
        $skillOutput = Join-Path $sessionDir "result.json"
        $response | ConvertTo-Json -Depth 10 | Set-Content -Path $skillOutput -Encoding UTF8
        Write-Host "Output saved to: $skillOutput" -ForegroundColor Green
    }
}
catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) {
        Write-Error "Details: $($_.ErrorDetails.Message)"
    }
}
