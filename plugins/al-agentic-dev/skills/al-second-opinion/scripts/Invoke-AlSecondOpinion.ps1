#Requires -Version 7.2
<#
.SYNOPSIS
    Cross-runtime advisory call for /al-second-opinion.
.DESCRIPTION
    Dispatches by runtime: $env:CLAUDECODE -eq '1' -> 'codex exec'; else -> 'claude -p'.
    Reads -Body, prepends the canonical role frame, invokes the target CLI under a
    read-only sandbox via Start-Job with a 600s timeout, parses structured JSON output,
    returns the assistant's bulleted gap list or a 'Second opinion skipped: ...' line.
    Fail-closed: no edits, no retries, no widening.
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
$prompt = "$roleFrame`n`n$Body"

if ($env:CLAUDECODE -eq '1') { $target = 'codex' } else { $target = 'claude' }

if (-not (Get-Command $target -ErrorAction SilentlyContinue)) {
    "Second opinion skipped: $target CLI unavailable"
    return
}

$job = Start-Job {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        if ($using:target -eq 'codex') {
            $raw = & codex exec `
                --sandbox read-only `
                --skip-git-repo-check `
                --color never `
                --json `
                -c 'model_reasoning_effort="medium"' `
                $using:prompt 2>&1
            $exit = $LASTEXITCODE
            $result = $raw -split "`n" |
                Where-Object { $_.TrimStart().StartsWith('{') } |
                ForEach-Object { try { $_ | ConvertFrom-Json } catch {} } |
                Where-Object { $_.type -eq 'item.completed' -and $_.item.type -eq 'agent_message' } |
                Select-Object -Last 1 -ExpandProperty item |
                Select-Object -ExpandProperty text
        } else {
            $json = & claude -p $using:prompt `
                --output-format json `
                --no-session-persistence `
                --disable-slash-commands `
                --strict-mcp-config '{}' 2>&1 | Out-String
            $exit = $LASTEXITCODE
            $result = ($json | ConvertFrom-Json).result
        }
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
    "Second opinion skipped: $target non-zero exit ($($r.ExitCode))"
} elseif ([string]::IsNullOrEmpty($r.Output.Trim())) {
    "Second opinion skipped: $target empty response"
} else {
    $r.Output
}
