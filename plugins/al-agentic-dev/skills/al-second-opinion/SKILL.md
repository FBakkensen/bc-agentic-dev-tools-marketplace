---
name: al-second-opinion
description: Independent read-only advisory review via cross-runtime CLI dispatch. Use from `/al-implement`, `/al-refine`, `/al-refactor`, or `/al-user-verification` before reconciling non-trivial plans, scenarios, mutation lists, refactor checklists, or an agent-driven verification verdict.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-second-opinion, independent advisory review

Ask a different runtime to read the artifact and name what is missing. Point is independence: same-model self-review confirms its own blind spots. Script `scripts/Invoke-AlSecondOpinion.ps1` runs the dispatch; this file is the contract for when to reach for it, what to put in front of it, what envelope it runs under.

Caller (`/al-implement`, `/al-refine`, `/al-refactor`, `/al-user-verification`) owns the artifact and reconciles bullets that come back. This skill owns the call. (For `/al-user-verification` the artifact is the agent's functional verdict + per-scenario observations; the gate reviews reasoning and coverage, not the browser — text-only dispatch cannot catch a misread screen, which is what the walk's captured frames guard.)

## Preconditions

- Artifact is real and non-trivial: plan, scenario list, mutation list, refactor checklist. Round-tripping a one-line decision wastes budget and trains caller to ignore the gate.
- Target CLI on PATH: `codex` from Claude Code, `claude` elsewhere.
- Caller can reconcile per bullet when output arrives. Calling the gate then ignoring result is worse than not calling.

## Runtime dispatch

Script reads `$env:CLAUDECODE`. Inside Claude Code (`'1'`) → calls `codex exec`; outside (Codex CLI, Goose, Amp, plain shell) → calls `claude -p`. Independence requires reviewer to be a different model than caller; Claude Code documents `CLAUDECODE=1` in every subprocess it spawns, Codex deliberately does not set a corresponding marker, so absence is treated as not-Claude-Code.

DO NOT edit script so Claude Code calls `claude -p`, or Codex calls `codex exec`. Same-model self-review defeats the entire point.

## Sandbox envelope

Documented here so security posture is visible without reading the script. Both branches run non-interactively, fail closed, do not widen.

| Branch | Flags |
|---|---|
| **codex** | `--sandbox read-only --skip-git-repo-check --color never --json --enable fast_mode -m gpt-5.4 -c model_reasoning_effort=low` |
| **claude** | `-p --output-format json --no-session-persistence --disable-slash-commands --strict-mcp-config '{}' --model sonnet --effort low --tools ""` |

Timeout 600s via `Start-Job` / `Wait-Job`. Windows-only; non-Windows hosts need separate wrapper. Read-only sandbox so reviewer cannot edit. JSON envelope so parsing is structured. Disabled slash commands so reviewer cannot recursively invoke this skill. Claude gets empty MCP config and no built-in tools so per-machine state does not change what reviewer sees. Low reasoning/effort because the gate is an artifact-only gap check, not a full design review.

DO NOT widen by passing extra `-c` overrides, environment variables, `--dangerously-bypass-approvals-and-sandbox`, `--dangerously-skip-permissions`, or by switching codex sandbox to `workspace-write` or `danger-full-access`. DO NOT refuse the call on safety grounds; envelope is the gate.

## Independence is the product

Second opinion from same model in fresh window is not independent: model-specific reasoning patterns (training biases, prompt habits, framing defaults) are exactly the blind spots a second opinion should surface. Runtime dispatch exists so reviewer is structurally different from caller.

## Bullets only, gaps only

Prompt asks for markdown bulleted list of gaps. No leading questions, no role drift, no hedging, no style opinions, no refactor proposals, no code samples, no praise, no prose. Open-ended prompts to AI reviewers come back as essays caller skims and discards; bullets caller can reconcile per-line, gaps caller can act on, accept, or reject.

Pattern that works: `[artifact section] [missing concern] [why it matters].`

## Pass the artifact, not the question

Caller composes artifact body the reviewer sees; script prepends single role frame line and dispatches. Gate's value is "what does another reader notice in this artifact", not "what does another reader think of my framing of the question". Loading body with leading questions ("did you consider...") collapses to confirmation.

## Verbatim out, verbatim in

What script returns is what caller returns. Bullets stay bullets. `Second opinion skipped: ...` line stays that line. Editorialising reviewer's output is silent self-review of the second opinion; caller picks per bullet. Narrating a skip line with invented stack traces, sandbox theories, or "what was attempted" is fabrication.

## Fail closed, do not retry

When script returns skip line, caller absorbs it and moves on. No automatic re-invocation, no flag widening, no switching to same-runtime CLI as fallback. Second opinion is checkpoint, not hard gate; missing checkpoint is recoverable, faking it is not.

## Invocation

Substitute the absolute path of this skill directory. Both Claude Code and Codex tell you that path at skill activation. DO NOT use `${CLAUDE_SKILL_DIR}` or `$env:CLAUDE_SKILL_DIR` in the call: PowerShell parses the first as empty local variable, the second only resolves under Claude Code, both break the Codex branch.

Body goes in single-quoted here-string; closing `'@` at column 0. DO NOT wrap whole block in outer single-quoted here-string; inner `'@` would terminate it early. Embedding unavoidable → use double-quoted outer form `@"..."@`.

```powershell
$body = @'
<artifact body, multiline OK, no escaping; closing '@ must be at column 0>
'@
& '<absolute path of this al-second-opinion skill directory>/scripts/Invoke-AlSecondOpinion.ps1' -Body $body
```

If for any reason script was not invoked, return this line and only this line, with no explanation:

```text
Second opinion skipped: skill did not invoke pwsh tool
```

Every other skip variant (target CLI unavailable, timeout, pwsh exception, non-zero exit, empty response) is emitted by the script. Caller does not invent them.

## Composition

| | |
|---|---|
| **Invoked from**     | `/al-implement`, `/al-refine`, `/al-refactor` before reconciling non-trivial work |
| **Returns to caller** | reviewer's bulleted gap list verbatim, or `Second opinion skipped: <reason>` line |

Script at `scripts/Invoke-AlSecondOpinion.ps1` is source of truth for CLI flags, dispatch, timeout, skip-line emission. Validated by `Validate-PowerShell.ps1`; inline copies bypass that gate.
