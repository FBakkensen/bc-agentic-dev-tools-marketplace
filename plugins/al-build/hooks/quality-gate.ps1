$data = $input | Out-String | ConvertFrom-Json

# Prevent infinite loops
if ($data.stop_hook_active -eq $true) { exit 0 }

$codeModifyingTools = @('Write', 'Edit', 'NotebookEdit')

$transcriptPath = $data.transcript_path
# Normalize MSYS-style /c/... paths to C:\... (Git Bash on Windows)
if ($transcriptPath -match '^/([a-zA-Z])/(.*)$') {
    $transcriptPath = "$($Matches[1].ToUpper()):\$($Matches[2] -replace '/', '\')"
}
if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) { exit 0 }

# Scope state file to transcript path to avoid cross-session bleed
$pathHash = [System.BitConverter]::ToString(
    [System.Security.Cryptography.SHA256]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($transcriptPath)
    )
).Replace('-', '').Substring(0, 12)
$stateFile = Join-Path ([System.IO.Path]::GetTempPath()) "quality-gate-$pathHash"
$lastCheckedLine = 0
$raw = Get-Content $stateFile -ErrorAction SilentlyContinue
if ($raw -and -not [int]::TryParse($raw, [ref]$lastCheckedLine)) { $lastCheckedLine = 0 }

# Stream only unprocessed lines, pre-filter by string match before JSON parsing
# Always count all lines (no early break) so state file reflects full transcript length
$lineCount = 0
$codeToolUsed = $false
foreach ($line in [System.IO.File]::ReadLines($transcriptPath)) {
    $lineCount++
    if ($lineCount -le $lastCheckedLine) { continue }
    if ($codeToolUsed) { continue }
    if ($line -notmatch '"tool_use"') { continue }
    $parsed = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $parsed.message.content) { continue }
    foreach ($block in $parsed.message.content) {
        if ($block.type -eq 'tool_use' -and $block.name -in $codeModifyingTools) {
            $codeToolUsed = $true
            break
        }
    }
}

$lineCount | Set-Content $stateFile

if ($codeToolUsed) {
    $reason = "Code was written or modified this turn. Before responding to the user, launch a subagent to perform a quality review of your work. The subagent should check: (1) Task completion - were all requested tasks finished? Any TODO items or planned steps left undone? (2) Verification - did you verify changes work (ran tests, built the project, confirmed correctness)? Unverified code is a gap. (3) Test quality - if tests were written or modified, do they assert meaningful behavior or are they vague/trivial? Do they cover edge cases and failure paths? (4) Code quality - is the code clean, following project conventions? Any obvious simplifications, dead code, or unnecessary complexity? (5) Loose ends - any unresolved issues, skipped error handling, or temporary workarounds? Act on the subagent findings before responding to the user."
    @{ decision = "block"; reason = $reason } | ConvertTo-Json -Compress
}
