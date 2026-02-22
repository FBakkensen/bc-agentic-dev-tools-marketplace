# Error Handling

## Video Processing Errors

| Scenario | Behavior |
|----------|----------|
| Video has no audio track | Skips transcription, continues with frames only |
| No speech detected in audio | Reports "no speech", continues with frames only |
| Transcription engine unavailable | Reports error, continues with frames only |
| Transcription fails | Reports error, continues with frames only |

## GitHub Issue Creation Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Not authenticated | GitHub authentication is missing or expired | Authenticate with the preferred GitHub tooling and retry |
| Repository not found or access denied | Wrong repo or insufficient permissions | Verify repository name and access rights |
| Issue creation failed | Required fields missing or repository has constraints | Ensure required fields are filled and retry |
| Attachment too large | Frame file exceeds GitHub size limits | Compress image or attach fewer frames |

## Error Recovery

If processing fails:

1. **Processing runtime missing**: Ensure the local processing service dependencies are installed
2. **Video file not found**: Verify the path is correct and the file exists
3. **No frames extracted**: Check if the video is corrupted or in an unsupported format (mp4 preferred)
4. **Script not found**: Ensure you're running from the repository root directory

If the script produces no usable output, ask the user to:
- Provide a different video format (mp4 preferred)
- Trim the video to the relevant section
- Describe the issue manually instead
