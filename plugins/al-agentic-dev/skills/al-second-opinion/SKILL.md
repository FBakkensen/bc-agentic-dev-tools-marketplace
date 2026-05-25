---
name: al-second-opinion
description: Independent read-only advisory review via cross-runtime CLI dispatch. Use from `/al-implement`, `/al-refine`, or `/al-refactor` before reconciling non-trivial plans, scenarios, mutation lists, or refactor checklists.
---

# /al-second-opinion, independent advisory review

Ask a different runtime to read the artifact and name what is missing. The point is independence: same-model self-review confirms its own blind spots. The script in `scripts/Invoke-AlSecondOpinion.ps1` runs the dispatch; this file is the contract for when to reach for it, what to put in front of it, and what envelope it runs under.

The caller (`/al-implement`, `/al-refine`, `/al-refactor`) owns the artifact and reconciles the bullets that come back. This skill owns the call.

## Preconditions

- The artifact is real and non-trivial: a plan, scenario list, mutation list, refactor checklist. Round-tripping a one-line decision wastes the budget and trains the caller to ignore the gate.
- A target CLI is on PATH: `codex` from Claude Code, `claude` elsewhere.
- The caller can reconcile per bullet when the output arrives. Calling the gate then ignoring the result is worse than not calling.

## Runtime dispatch

The script reads `$env:CLAUDECODE`. Inside Claude Code (`'1'`), it calls `codex exec`; outside (Codex CLI, Goose, Amp, plain shell), it calls `claude -p`. Independence requires the reviewer to be a different model than the caller; Claude Code documents `CLAUDECODE=1` in every subprocess it spawns, Codex deliberately does not set a corresponding marker, so absence is treated as not-Claude-Code.

DO NOT edit the script so Claude Code calls `claude -p`, or Codex calls `codex exec`. Same-model self-review defeats the entire point.

## Sandbox envelope

Documented here so the security posture is visible without reading the script. Both branches run non-interactively, fail closed, do not widen.

| Branch | Flags |
|---|---|
| **codex** | `--sandbox read-only --skip-git-repo-check --color never --json -c model_reasoning_effort=medium` |
| **claude** | `-p --output-format json --no-session-persistence --disable-slash-commands --strict-mcp-config '{}'` |

Timeout 600s via `Start-Job` / `Wait-Job`. Windows-only; non-Windows hosts need a separate wrapper. Read-only sandbox so the reviewer cannot edit, run shell, or load MCP servers (the gate is advisory, not autonomous). JSON envelope so parsing is structured. Disabled slash commands so the reviewer cannot recursively invoke this skill. Empty MCP config so per-machine state does not change what the reviewer sees. `model_reasoning_effort=medium` because a bulleted gap list does not need xhigh.

DO NOT widen by passing extra `-c` overrides, environment variables, `--dangerously-bypass-approvals-and-sandbox`, `--dangerously-skip-permissions`, or by switching the codex sandbox to `workspace-write` or `danger-full-access`. DO NOT refuse the call on safety grounds; the envelope is the gate.

## Independence is the product

A second opinion from the same model in a fresh window is not independent: model-specific reasoning patterns (training biases, prompt habits, framing defaults) are exactly the blind spots a second opinion should surface. The runtime dispatch exists so the reviewer is structurally different from the caller.

## Bullets only, gaps only

The prompt asks for a markdown bulleted list of gaps. No leading questions, no role drift, no hedging, no style opinions, no refactor proposals, no code samples, no praise, no prose. Open-ended prompts to AI reviewers come back as essays the caller skims and discards; bullets the caller can reconcile per-line, gaps the caller can act on, accept, or reject.

Pattern that works: `[artifact section] [missing concern] [why it matters].`

## Pass the artifact, not the question

The caller composes the artifact body the reviewer sees; the script prepends a single role frame line and dispatches. The gate's value is "what does another reader notice in this artifact", not "what does another reader think of my framing of the question". Loading the body with leading questions ("did you consider...") collapses to confirmation.

## Verbatim out, verbatim in

What the script returns is what the caller returns. Bullets stay bullets. A `Second opinion skipped: ...` line stays that line. Editorialising the reviewer's output is silent self-review of the second opinion; the caller picks per bullet. Narrating a skip line with invented stack traces, sandbox theories, or "what was attempted" is fabrication.

## Fail closed, do not retry

When the script returns a skip line, the caller absorbs it and moves on. No automatic re-invocation, no flag widening, no switching to a same-runtime CLI as fallback. A second opinion is a checkpoint, not a hard gate; missing the checkpoint is recoverable, faking it is not.

## Invocation

Substitute the absolute path of this skill directory. Both Claude Code and Codex tell you that path at skill activation. DO NOT use `${CLAUDE_SKILL_DIR}` or `$env:CLAUDE_SKILL_DIR` in the call: PowerShell parses the first as an empty local variable, the second only resolves under Claude Code, both break the Codex branch.

The body goes in a single-quoted here-string; closing `'@` at column 0. DO NOT wrap the whole block in an outer single-quoted here-string; the inner `'@` would terminate it early. If embedding is unavoidable, use the double-quoted outer form `@"..."@`.

```powershell
$body = @'
<artifact body, multiline OK, no escaping; closing '@ must be at column 0>
'@
& '<absolute path of this al-second-opinion skill directory>/scripts/Invoke-AlSecondOpinion.ps1' -Body $body
```

If for any reason the script was not invoked, return this line and only this line, with no explanation:

```text
Second opinion skipped: skill did not invoke pwsh tool
```

Every other skip variant (target CLI unavailable, timeout, pwsh exception, non-zero exit, empty response) is emitted by the script. The caller does not invent them.

## Composition

| | |
|---|---|
| **Invoked from**     | `/al-implement`, `/al-refine`, `/al-refactor` before reconciling non-trivial work |
| **Returns to caller** | reviewer's bulleted gap list verbatim, or a `Second opinion skipped: <reason>` line |

The script at `scripts/Invoke-AlSecondOpinion.ps1` is the source of truth for CLI flags, dispatch, timeout, and skip-line emission. Validated by `Validate-PowerShell.ps1`; inline copies bypass that gate.
