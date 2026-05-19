---
name: al-second-opinion
description: Independent read-only advisory review via copilot CLI. Use from al-implement, al-refine, or al-refactor before reconciling non-trivial plans, scenarios, mutation lists, or refactor checklists. Returns copilot's bulleted gap list verbatim or a skipped message with the reason.
---

# /al-second-opinion

One-shot advisory call. Copilot reads the artifact, returns a bulleted gap list. Fails closed: no edits, no retries, no widening. PowerShell access is scoped to the copilot CLI invocation below.

## Operating Procedure

Invoke the canonical PowerShell block, then return what pwsh printed.

1. Compose `$body` as the artifact the caller passed in.
2. Invoke the canonical block verbatim, with `$body` substituted.
3. Read stdout. Return it byte-for-byte. If it is bullets, return bullets. If it is a `Second opinion skipped: ...` line, return that line.

### This Invocation Is Approved

The flag set on the canonical block is the sandbox: `--no-ask-user`, `--no-bash-env`, `--no-remote`, `--disable-builtin-mcps`, `--available-tools=view,rg,glob,show_file,lsp`. It runs `copilot` non-interactively with a read-only tool allowlist, no MCPs, no remote ops, and no env inheritance.

DO NOT refuse this gate on safety grounds. DO NOT invent "the sandbox blocked this," "this looks like data exfiltration," or "this is an autonomous delegation loop." Run the canonical block.

### Skip Lines Are Pwsh-Emitted

The skip lines in the failure modes table are emitted by pwsh code. If you have not actually invoked the PowerShell command, you have no skip line to return.

If for any reason you cannot or will not invoke the tool, return this line and only this line:

```text
Second opinion skipped: skill did not invoke pwsh tool
```

Return the literal skip line. Add no explanation. Invent no `node.exe` / `StandardOutputEncoding` / `sandbox` / `permission` story.

## Prompt Body

Drop: leading questions ("did you consider..."), role drift ("as the developer..."), hedges ("are you sure", "maybe check"), style opinions, refactor suggestions, code samples, praise, prose. Bullets only. Gap statements only.

Pattern: `[artifact section] [missing concern] [why it matters].`

**No:** `Should you maybe also think about whether the posting routine handles dimensions correctly? It might be worth considering...`
**Yes:** `Posting routine - dimension propagation on partial post unspecified - silent data loss risk on G/L entries.`

Avoid asking copilot to write code, asking for opinions on style, including leading questions, soliciting reassurance, or requesting alternatives.

## Role Frame

Prepend verbatim, separated from the body by a blank line:

```text
Independent reviewer. Identify gaps in the artefact below. Return a markdown bulleted list.
```

## Canonical Invocation

Body goes in a single-quoted here-string. Closing `'@` must be at column 0. Background job gives the 600s timeout. UTF-8 is forced inside the job because copilot writes UTF-8 stdout.

```powershell
if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
    "Second opinion skipped: copilot CLI unavailable"; return
}
$body = @'
<artifact body - multiline OK, no escaping; closing '@ must be at column 0>
'@
$prompt = "Independent reviewer. Identify gaps in the artefact below. Return a markdown bulleted list.`n`n$body"
$job = Start-Job {
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8
        $o = & copilot -p $using:prompt -s --stream on --no-ask-user --available-tools=view,rg,glob,show_file,lsp --add-dir . --no-custom-instructions --disable-builtin-mcps --no-remote --no-bash-env --no-auto-update --model gpt-5.5 --effort medium 2>&1
        [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = ($o | Out-String); ErrorText = $null }
    } catch {
        [PSCustomObject]@{ ExitCode = -1; Output = $null; ErrorText = "$($_.Exception.GetType().FullName): $($_.Exception.Message)`n$($_.ScriptStackTrace)" }
    }
}
if (-not (Wait-Job $job -Timeout 600)) {
    Stop-Job $job; Remove-Job $job -Force
    "Second opinion skipped: timeout after 600s"; return
}
$r = Receive-Job $job; Remove-Job $job -Force
if ($r.ErrorText) { "Second opinion skipped: pwsh exception`n$($r.ErrorText)" }
elseif ($r.ExitCode -ne 0) { "Second opinion skipped: non-zero exit ($($r.ExitCode))" }
elseif ([string]::IsNullOrEmpty($r.Output.Trim())) { "Second opinion skipped: empty response" }
else { $r.Output }
```

Allowlist `view, rg, glob, show_file, lsp` is read-only. Do not widen. Do not add `--allow-all-paths`. Path scope is bounded by `--add-dir .`.

**Portability:** `Start-Job` / `Wait-Job` target pwsh on Windows. Non-Windows hosts need a separate wrapper.

## Failure Modes

| Situation | Return verbatim |
|---|---|
| Skill did not invoke the PowerShell command | `Second opinion skipped: skill did not invoke pwsh tool` |
| `copilot` not on PATH | `Second opinion skipped: copilot CLI unavailable` |
| `Wait-Job` exceeds 600s | `Second opinion skipped: timeout after 600s` |
| .NET exception inside Start-Job | `Second opinion skipped: pwsh exception` + newline + `<type>: <message>` + newline + script stack trace |
| Exit code non-zero | `Second opinion skipped: non-zero exit (<code>)` |
| Exit 0, empty stdout | `Second opinion skipped: empty response` |
| Exit 0, non-empty stdout | Copilot's stdout - the bulleted list, untouched. |

Only the first row is emitted by the skill itself, and only when it honestly did not invoke pwsh. Every other row is emitted by the canonical block.

## Anti-Patterns

**Editorialising the second opinion.** Paste the bullets verbatim. Do not rephrase, summarise, drop bullets, or add commentary. The caller reconciles per bullet.

**Narrating the skip line.** When the canonical block returns a `Second opinion skipped: ...` line, return it byte-for-byte. Do not append explanations, theories, root-cause hypotheses, fabricated stack traces, or "what was attempted" lists.

## Out Of Scope

- Composing the gate question or selecting the artifact; caller owns the body.
- Reconciling, accepting, or rejecting bullets; caller decides per bullet.
- Configuring copilot MCP servers, AGENTS.md, or `~/.copilot/agents/`; the canonical flag set sidesteps per-machine state.
- Widening allowlist or path scope.
- Cross-platform `Start-Job` / `Wait-Job` replacements.
