#Requires -Version 7.2
<#
.SYNOPSIS
    Cross-family advisory call for /al-second-opinion.
.DESCRIPTION
    Shells out to the GitHub Copilot CLI ('@github/copilot') for an independent, different-model-family
    read of the artifact. Reads -Body, prepends the canonical role frame, pipes the combined prompt via
    stdin (no argv length limit), invokes copilot under a read-only envelope via Start-Job with a 600s
    timeout, parses the JSONL output, returns the assistant's bulleted gap list or a 'Second opinion
    skipped: ...' line. Fail-closed: no edits, no retries, no widening. Copilot is a CLI tool dependency
    here, not a host runtime.

    Independence guarantee is the '-m gpt-5.5' pin: copilot can run Claude models, so an unpinned call
    would rebuild the same-family self-review this gate exists to defeat. Read-only is assembled from
    --deny-tool (write/shell/url) plus COPILOT_HOME isolation, because copilot has no single sandbox flag.
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
# Role frame + body pipe via stdin as one blob (copilot reads stdin as the prompt).
# -p and stdin are mutually exclusive in copilot (-p wins, stdin ignored), so the body goes on stdin
# only; this also dodges the ~32 KB Windows command-line limit that an argv -p would impose.

# Resolve the real @github/copilot entrypoint via node, bypassing the VS Code bootstrapper shim
# (which launches Windows PowerShell with the user profile and carries interactive Read-Host prompts
# that would hang a non-interactive call).
if (-not (Get-Command 'node' -ErrorAction SilentlyContinue)) {
    "Second opinion skipped: node unavailable"
    return
}
$npmRoot = try { (& npm root -g 2>$null).Trim() } catch { $null }
$loader = if ($npmRoot) { Join-Path $npmRoot '@github/copilot/npm-loader.js' } else { $null }
if (-not $loader -or -not (Test-Path $loader)) {
    "Second opinion skipped: copilot CLI unavailable"
    return
}

# Isolated config home: keeps the user's ~/.copilot MCP fleet (write-capable tools) out of the
# read-only envelope. Stable reused dir, holds no user config; auth survives via the OS credential store.
$copilotHome = Join-Path ([System.IO.Path]::GetTempPath()) 'al-second-opinion-copilot-home'

$prompt = $roleFrame + "`n" + $Body

$job = Start-Job {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        New-Item -ItemType Directory -Force -Path $using:copilotHome | Out-Null
        $env:COPILOT_HOME = $using:copilotHome
        $raw = $using:prompt | & node $using:loader `
            --model gpt-5.5 `
            --reasoning-effort low `
            --allow-all-tools `
            --deny-tool=write `
            --deny-tool=shell `
            --deny-tool=url `
            --no-ask-user `
            --disable-builtin-mcps `
            --no-custom-instructions `
            --no-color `
            --output-format json 2>&1
        $exit = $LASTEXITCODE
        $result = $raw -split "`n" |
            Where-Object { "$_".TrimStart().StartsWith('{') } |
            ForEach-Object { try { $_ | ConvertFrom-Json } catch {} } |
            Where-Object { $_.type -eq 'assistant.message' -and $_.data.phase -eq 'final_answer' } |
            Select-Object -Last 1 -ExpandProperty data |
            Select-Object -ExpandProperty content
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
    "Second opinion skipped: copilot non-zero exit ($($r.ExitCode))"
} elseif ([string]::IsNullOrEmpty($r.Output.Trim())) {
    "Second opinion skipped: copilot empty response"
} else {
    $r.Output
}
