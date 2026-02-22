---
name: video-to-issue
description: Create GitHub issues from Business Central screen recordings. Extracts BC-specific context (Pages, Actions, Fields, processes), transcribes narration, searches workspace/W1 for related code, and creates structured issues. Works with any video but optimized for BC workflows.
---

# Video to GitHub Issue

Transform screen recordings into well-structured GitHub issues by extracting BC-specific context that makes issues actionable.

## Architecture

```
User Video -> Azure Video Processing API -> frames stored server-side + transcription returned
     -> Agent reviews transcription -> selectively downloads key frames -> GitHub issues
```

**Two components:**
1. **Video Processing API (Azure Function)** - Extracts frames (stored server-side in Azure Storage) and transcribes audio
2. **GitHub Issue Creation** - Creates and updates issues using the agent's GitHub tooling

**Key design:** The API does NOT return frame images in the response. It returns metadata (timestamps, screenshot IDs, transcription per frame) and stores the actual images server-side. Frames are downloaded on demand via `Download-Frame.ps1`. This allows processing long videos (10-20+ minutes) with many frames without payload size issues.

**Authentication:**
The Azure Function is protected with a function key. The skill bundles the key in
`.agents\skills\video-to-issue\secret.json`, so users do not need to provide credentials.

## What Makes a Good BC Issue

A quality BC issue captures context a developer needs without re-watching the video:

| Element | Why It Matters |
|---------|----------------|
| **Page/Component** | Identifies where in BC the issue/feature lives |
| **Navigation path** | How to reproduce or locate the feature |
| **Field names** | Enables code search for validation/logic |
| **Process context** | Posting, validation, calculation--guides where to look |
| **User intent** | What they're trying to accomplish (from narration) |

Generic "the button doesn't work" is useless. "Post action on Sales Order Card fails after adding custom discount field" is actionable.

## Video Analysis Goals

When reviewing extracted frames and transcription, identify:

1. **BC UI patterns**: Page type (Card, List, Worksheet), visible FactBoxes, action menus
2. **Navigation breadcrumbs**: Search terms used, menu paths, page transitions
3. **Error indicators**: Dialogs, notification bars, validation messages, red fields
4. **Process stage**: Pre-posting, during posting, released documents, etc.
5. **User narration intent**: What they expect vs what happens

See [bc-terminology.md](./references/bc-terminology.md) for extraction patterns.

## When NOT to Use

- Audio-only recordings without screen content
- Videos that don't show the actual bug/feature (e.g., talking head explanations)
- Issues already documented elsewhere--link to existing issue instead

## Workflow

### 1. Process Video via the Skill Script

```powershell
# Process video - uploads to service, returns metadata + transcription
$result = & ".agents\skills\video-to-issue\scripts\Invoke-VideoProcessing.ps1" -VideoPath "C:\path\to\video.mp4"

# Or save to file for review
& ".agents\skills\video-to-issue\scripts\Invoke-VideoProcessing.ps1" -VideoPath "C:\path\to\video.mp4" -OutputPath ".\video-result.json"
```

**Output data folder (auto-saved):**
Every run saves a copy of the JSON response in the skill data folder:

```
.agents\skills\video-to-issue\data\sessions\<session_id>\result.json
```

**Parameters:**
- `-VideoPath` (required): Path to video file
- `-Interval`: Seconds between frames (default: 2.0)
- `-MaxFrames`: Max frames to extract (default: 100, server limit: 100)
- `-Language`: Language code (e.g., 'en-US', 'da-DK') or leave empty for auto-detect
- `-SkipTranscription`: Skip audio transcription (faster)
- `-ApiUrl`: Override API URL (default: `https://func-gtm-video-to-workitem.azurewebsites.net`, use `http://localhost:8000` for local testing)
- `-FunctionKey`: Optional override for the function key (normally loaded from `secret.json`)

**Output JSON structure:**

The response contains frame **metadata only** — no image data. Frame images are stored server-side and fetched on demand.

```json
{
  "session_id": "uuid",
  "expires_at": "2026-02-10T07:30:00+00:00",
  "video_duration": 600.0,
  "frame_count": 100,
  "actual_interval": 6.0,
  "transcription": {
    "text": "Full transcription text...",
    "has_speech": true,
    "language": "en-US",
    "segments": [{"start": 0.0, "end": 2.5, "text": "..."}]
  },
  "frames": [
    {
      "name": "f_0001.png",
      "screenshot_id": "f_0001",
      "timestamp": 0.0,
      "timestamp_formatted": "0:00",
      "transcription": "What was said at this frame"
    }
  ]
}
```

### 2. Analyze Transcription and Select Key Frames

**IMPORTANT: Do NOT download all frames. Use the transcription to decide which frames matter.**

The API may return many frames (up to 100). Downloading all of them wastes time and tokens. Instead:

1. **Review the frame metadata list** — scan `frames[].timestamp_formatted` and `frames[].transcription` for every frame. This is text-only and already in the response.
2. **Identify important moments from the transcription:**
   - Frames where the user describes a **problem or error** ("this doesn't work", "I get an error", "it should show...")
   - Frames near **page transitions** or **navigation changes** (different page names mentioned)
   - Frames where **key actions** are performed (posting, validating, configuring)
   - The **first frame** (starting context) and **last frame** (end state)
   - Frames near **topic transitions** in the narration
3. **Download only those key frames** using `Download-Frame.ps1`:

```powershell
& ".agents\skills\video-to-issue\scripts\Download-Frame.ps1" `
  -SessionId "<session_id>" `
  -ScreenshotId "f_0001"
```

4. **Review the downloaded frames** for BC UI context (page names, field values, error dialogs).
5. **Download additional frames if needed** — if a downloaded frame raises questions or you need more context around a specific moment, download neighboring frames.

Frames are saved under:

```
.agents\skills\video-to-issue\data\sessions\<session_id>\frames\<screenshot_id>.png
```

The `screenshot_id` can be provided with or without `.png`.

**Typical selection:** For a 10-minute video with 100 frames, you might download 8-15 key frames rather than all 100.

### 3. Discover Related Code

Search the workspace for code related to what's visible:
- Page names and their source tables
- Field names and validation logic
- Process handlers (posting routines, event subscribers)

If standard BC pages are shown, consult W1 reference sources to confirm canonical implementations.

### 4. Clarify with User

Before asking the user, determine the target repository and any existing issue metadata using your GitHub tooling.

Then resolve ambiguities:
- **Issue type**: Bug, User Story, Task, Feature, or Epic (present as options)
- **Expected behavior**: If not clear from video
- **Priority**: If not indicated (present as options: Critical, High, Medium, Low)

### 5. Create Issue

Populate the issue using the templates in [issue-template.md](./references/issue-template.md). Include:
- **Title** with concise problem statement
- **Summary** describing the video context and intent
- **Reproduction steps** derived from navigation breadcrumbs
- **Expected vs actual behavior**
- **Screenshots section** with suggested attachments

### 6. Prepare Attachments (Manual Upload)

Download key frames for manual attachment to the GitHub issue:

```powershell
# Download first, middle, and last frames (default)
& ".agents\skills\video-to-issue\scripts\Prepare-Issue-Attachments.ps1" `
    -ResultJson ".agents\skills\video-to-issue\data\sessions\<session_id>\result.json"

# Or specify exact frame indices
& ".agents\skills\video-to-issue\scripts\Prepare-Issue-Attachments.ps1" `
    -ResultJson ".agents\skills\video-to-issue\data\sessions\<session_id>\result.json" `
    -FrameIndices 0,5,10

# Or specify exact screenshot IDs (preferred when you know which frames matter)
& ".agents\skills\video-to-issue\scripts\Prepare-Issue-Attachments.ps1" `
    -ResultJson ".agents\skills\video-to-issue\data\sessions\<session_id>\result.json" `
    -ScreenshotIds "f_0003","f_0015","f_0042"
```

The script downloads the frames from the API and prints a list of local files to attach manually.

## Local Development

If you run a local processing service, pass its endpoint using `-ApiUrl` when calling `Invoke-VideoProcessing.ps1`.

## Error Handling

See [error-handling.md](./references/error-handling.md) for more scenarios.
