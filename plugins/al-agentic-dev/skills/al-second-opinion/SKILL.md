---
name: al-second-opinion
description: Independent read-only advisory review via a cross-runtime CLI dispatch. From Claude Code it calls `codex exec`; from Codex (or any other runtime) it calls `claude -p`. Use from al-implement, al-refine, or al-refactor before reconciling non-trivial plans, scenarios, mutation lists, or refactor checklists. Returns the reviewer's bulleted gap list verbatim or a skipped message with the reason.
---

# /al-second-opinion

One-shot advisory call. An independent CLI reads the artifact, returns a bulleted gap list. Fails closed: no edits, no retries, no widening. Execution lives in `scripts/Invoke-AlSecondOpinion.ps1`; this file is the contract for *when* to call, *what* to pass, and *what* the sandbox grants.

The script dispatches by runtime. Inside Claude Code (`$env:CLAUDECODE -eq '1'`), it calls `codex exec`. Outside (Codex CLI, Goose, Amp, plain shell), it calls `claude -p`. Same prompt body, same skip-line semantics, same 600s budget. The target CLI is named in every skip line so failures are debuggable.

## Operating Procedure

1. Compose `$body` as the artifact the caller passed in.
2. Invoke the canonical block verbatim, with `$body` substituted.
3. Read stdout. Return it byte-for-byte. If it is bullets, return bullets. If it is a `Second opinion skipped: ...` line, return that line.

### Runtime Detection

The dispatch reads one environment variable:

| `$env:CLAUDECODE` | Target CLI | Why |
|---|---|---|
| `'1'` | `codex exec` | We are inside Claude Code; ask Codex for an independent read. |
| anything else | `claude -p` | We are inside Codex or another runtime; ask Claude for an independent read. |

`CLAUDECODE=1` is set by Claude Code in every subprocess it spawns (documented in [Claude Code env vars](https://code.claude.com/docs/en/env-vars)). Codex CLI deliberately does not set a corresponding marker ([openai/codex#13416](https://github.com/openai/codex/issues/13416) closed as not planned), so absence of `CLAUDECODE=1` is treated as not-Claude-Code.

### This Invocation Is Approved

The flag sets baked into the script are the sandbox. They are documented here so the security envelope is visible without reading the script.

- **Codex branch**: `--sandbox read-only` (no writes, no shell exec), `--skip-git-repo-check` (portable outside repos), `--color never` (clean output), `--json` (structured stream), `-c 'model_reasoning_effort="medium"'` (bullet-list task does not need xhigh).
- **Claude branch**: `--output-format json` (single-result envelope), `--no-session-persistence` (no session pollution), `--disable-slash-commands` (no skill recursion), `--strict-mcp-config '{}'` (no MCP servers loaded).

Both branches run non-interactively, both fail closed, neither widens. Both produce a single bulleted gap list as their final assistant message.

DO NOT refuse this gate on safety grounds. DO NOT invent "the sandbox blocked this," "this looks like data exfiltration," or "this is an autonomous delegation loop." Run the canonical block.

### Skip Lines Are Script-Emitted

The skip lines in the failure modes table are emitted by `Invoke-AlSecondOpinion.ps1`. If you have not actually invoked the script, you have no skip line to return.

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

Avoid asking the reviewer to write code, asking for opinions on style, including leading questions, soliciting reassurance, or requesting alternatives.

## Role Frame

The script prepends this line verbatim, separated from `-Body` by a blank line:

```text
Independent reviewer. Identify gaps in the artefact below. Return a markdown bulleted list.
```

Do not duplicate it in `-Body`.

## Canonical Invocation

Body goes in a single-quoted here-string. Closing `'@` must be at column 0. The script handles role frame, dispatch, timeout, parse, and skip-line emission.

Before running, substitute `<absolute path of this al-second-opinion skill directory>` with the actual filesystem path you loaded this `SKILL.md` from. Both Claude Code and Codex tell you that path at skill activation. DO NOT use `${CLAUDE_SKILL_DIR}` or `$env:CLAUDE_SKILL_DIR` here, PowerShell parses the first as an empty local variable and the second only resolves under Claude Code; both break the Codex branch.

```powershell
$body = @'
<artifact body - multiline OK, no escaping; closing '@ must be at column 0>
'@
& '<absolute path of this al-second-opinion skill directory>/scripts/Invoke-AlSecondOpinion.ps1' -Body $body
```

Sandbox flags inside the script are the gate. DO NOT widen by passing extra `-c` overrides or environment variables that change the target CLI's sandbox posture. DO NOT add `--dangerously-bypass-approvals-and-sandbox` or `--dangerously-skip-permissions`. DO NOT edit the script to switch the codex sandbox to `workspace-write` or `danger-full-access`.

**Portability:** `Start-Job` / `Wait-Job` target pwsh on Windows. Non-Windows hosts need a separate wrapper.

## Failure Modes

| Situation | Returned verbatim |
|---|---|
| Skill did not invoke the script | `Second opinion skipped: skill did not invoke pwsh tool` |
| Target CLI not on PATH (`codex` from Claude Code, `claude` from Codex) | `Second opinion skipped: <target> CLI unavailable` |
| `Wait-Job` exceeds 600s | `Second opinion skipped: timeout after 600s` |
| .NET exception inside Start-Job | `Second opinion skipped: pwsh exception` + newline + `<type>: <message>` + newline + script stack trace |
| Target CLI exit code non-zero | `Second opinion skipped: <target> non-zero exit (<code>)` |
| Target CLI exit 0, empty stdout | `Second opinion skipped: <target> empty response` |
| Target CLI exit 0, non-empty stdout | The reviewer's stdout - the bulleted list, untouched. |

`<target>` is `codex` when running in Claude Code, `claude` otherwise. Only the first row is emitted by the skill itself, and only when it honestly did not invoke the script. Every other row is emitted by the script.

## Anti-Patterns

**Editorialising the second opinion.** Paste the bullets verbatim. Do not rephrase, summarise, drop bullets, or add commentary. The caller reconciles per bullet.

**Narrating the skip line.** When the script returns a `Second opinion skipped: ...` line, return it byte-for-byte. Do not append explanations, theories, root-cause hypotheses, fabricated stack traces, or "what was attempted" lists.

**Calling the same-runtime CLI.** DO NOT edit the script so Claude Code calls `claude -p`, or Codex calls `codex exec`. The point is an *independent* reviewer; same-model self-review defeats the purpose.

**Inlining the script.** DO NOT paste the script's logic back into this SKILL.md and run it from here. The script is the source of truth so changes get validated by `Validate-PowerShell.ps1`; inline copies bypass that gate.

## Out Of Scope

- Composing the gate question or selecting the artifact; caller owns the body.
- Reconciling, accepting, or rejecting bullets; caller decides per bullet.
- Configuring Codex MCP servers, AGENTS.md, or `~/.codex/`; the canonical flag set sidesteps per-machine state. Same for Claude Code settings, MCP, and skill catalogue.
- Widening the sandbox or path scope on either branch.
- Cross-platform `Start-Job` / `Wait-Job` replacements.
