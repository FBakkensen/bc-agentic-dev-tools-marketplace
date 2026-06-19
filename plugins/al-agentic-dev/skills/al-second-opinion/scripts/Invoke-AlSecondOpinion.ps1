#Requires -Version 7.2
<#
.SYNOPSIS
    Cross-family advisory call for /al-second-opinion.
.DESCRIPTION
    Shells out to the Codex CLI ('codex exec') for an independent, different-model-family
    read of the artifact. Reads -Body, prepends the canonical role frame, invokes codex
    under a read-only sandbox via Start-Job with a 600s timeout, parses structured JSON
    output, returns the assistant's bulleted gap list or a 'Second opinion skipped: ...' line.
    Fail-closed: no edits, no retries, no widening. Codex is a CLI tool dependency here,
    not a host runtime.
.PARAMETER Body
    The artifact body to review. Multiline OK. The skill caller composes it; this script
    only frames and dispatches.
.OUTPUTS
    System.String. Either the reviewer's bulleted list (verbatim) or a 'Second opinion
    skipped: ...' line. Caller returns stdout byte-for-byte.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string] $Body
)

$ErrorActionPreference = 'Stop'

$roleFrame = 'Independent reviewer. Identify gaps in the artefact below. Return a markdown bulleted list.'
# $Body pipes via stdin (Codex appends it as an <stdin> block).
# Concatenating into one positional arg silently truncates at the first newline on Windows native-arg passing.

if (-not (Get-Command 'codex' -ErrorAction SilentlyContinue)) {
    "Second opinion skipped: codex CLI unavailable"
    return
}

$job = Start-Job {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = $using:Body | & codex exec `
            --sandbox read-only `
            --skip-git-repo-check `
            --color never `
            --json `
            --enable fast_mode `
            -m gpt-5.4 `
            -c 'model_reasoning_effort="low"' `
            $using:roleFrame 2>&1
        $exit = $LASTEXITCODE
        $result = $raw -split "`n" |
            Where-Object { $_.TrimStart().StartsWith('{') } |
            ForEach-Object { try { $_ | ConvertFrom-Json } catch {} } |
            Where-Object { $_.type -eq 'item.completed' -and $_.item.type -eq 'agent_message' } |
            Select-Object -Last 1 -ExpandProperty item |
            Select-Object -ExpandProperty text
        [PSCustomObject]@{ ExitCode = $exit; Output = $result; ErrorText = $null }
    } catch {
        [PSCustomObject]@{ ExitCode = -1; Output = $null; ErrorText = "$($_.Exception.GetType().FullName): $($_.Exception.Message)`n$($_.ScriptStackTrace)" }
    }
}

if (-not (Wait-Job $job -Timeout 600)) {
    Stop-Job $job; Remove-Job $job -Force
    'Second opinion skipped: timeout after 600s'
    return
}

$r = Receive-Job $job; Remove-Job $job -Force

if ($r.ErrorText) {
    "Second opinion skipped: pwsh exception`n$($r.ErrorText)"
} elseif ($r.ExitCode -ne 0) {
    "Second opinion skipped: codex non-zero exit ($($r.ExitCode))"
} elseif ([string]::IsNullOrEmpty($r.Output.Trim())) {
    "Second opinion skipped: codex empty response"
} else {
    $r.Output
}
