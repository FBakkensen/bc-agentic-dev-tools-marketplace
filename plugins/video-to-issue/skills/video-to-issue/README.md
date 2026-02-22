# Video to GitHub Issue

Convert screen recordings into well-structured GitHub issues with extracted screenshots and transcribed audio.

## Architecture

```
User Video -> Azure Video Processing API -> Copilot analysis -> GitHub issues
```

Components:
- **Video Processing API (Azure Function)**: Extracts frames and transcribes audio
- **Skill workflow**: Interprets frames + transcription and creates GitHub issues

## Default Processing Endpoint

The script uses this default processing endpoint:
`https://func-gtm-video-to-workitem.azurewebsites.net`

Override it with `-ApiUrl` for local or alternate deployments.

## Authentication

The Azure Function is protected with a function key. The skill bundles the key in:
`.agents\skills\video-to-issue\secret.json`

No user setup is required. If the key is rotated, update this file in the skill bundle.

## Usage

Process a video and return frames + transcription:

```powershell
$result = & ".agents\skills\video-to-issue\scripts\Invoke-VideoProcessing.ps1" `
  -VideoPath "C:\Videos\demo.mp4"
```

Each run also saves a local copy of the JSON result in:

```
.agents\skills\video-to-issue\data\sessions\<session_id>\result.json
```

Override the processing endpoint (local or alternate deployment):

```powershell
& ".agents\skills\video-to-issue\scripts\Invoke-VideoProcessing.ps1" `
  -VideoPath "C:\Videos\demo.mp4" `
  -ApiUrl "http://localhost:8000"
```

Download a specific frame by session id and screenshot id:

```powershell
& ".agents\skills\video-to-issue\scripts\Download-Frame.ps1" `
  -SessionId "<session_id>" `
  -ScreenshotId "f_0001"
```

Frames are saved under:

```
.agents\skills\video-to-issue\data\sessions\<session_id>\frames\<screenshot_id>.png
```

Prepare extracted frames for manual attachment to an issue:

```powershell
& ".agents\skills\video-to-issue\scripts\Prepare-Issue-Attachments.ps1" `
  -ResultJson "$env:TEMP\video-result.json"
```

Full workflow instructions live in `SKILL.md`.

## Troubleshooting

Common fixes:
- Reduce workload: `-MaxFrames 10`
- Skip audio: `-SkipTranscription`
- Large file errors: trim or compress the video

See `references/error-handling.md` for more.
