---
name: al-second-opinion
description: Independent read-only advisory review via cross-family CLI dispatch (shells to GitHub Copilot CLI, pinned to a GPT model). Use from `/al-implement`, `/al-refine`, `/al-refactor`, or `/al-user-verification` before reconciling non-trivial `Test Specification`, `Verification Plan`, mutation lists, refactor checklists, or a verification walk verdict.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-second-opinion, independent advisory review

Ask a different model family to read the artifact and name what is missing. Point is independence: same-model self-review confirms its own blind spots. Script `scripts/Invoke-AlSecondOpinion.ps1` shells to the GitHub Copilot CLI (`@github/copilot`), pinned to a GPT model, for that read; this file is the contract for when to reach for it, what to put in front of it, what envelope it runs under. Copilot is a CLI tool dependency here — not a host runtime, not a publish target.

Caller (`/al-implement`, `/al-refine`, `/al-refactor`, `/al-user-verification`) owns the artifact and reconciles bullets that come back. This skill owns the call. (For `/al-user-verification` the artifact is the walk verdict — per example, the exact question as posed and the user's verbatim reported observation, or captured client output for Contract examples; the gate reviews coverage and routing — every observable check asked and answered, no pass resting on a led question or inferred value, remarks routed functional-vs-usability — not the user's observation; the user saw the screen directly.)

## Preconditions

- Artifact is real and non-trivial: `Test Specification`, `Verification Plan`, mutation list, refactor checklist, verification verdict. Round-tripping a one-line decision wastes budget and trains caller to ignore the gate.
- `node` and the `@github/copilot` npm-global package present. Absent → script returns a skip line; caller proceeds.
- Caller can reconcile per bullet when output arrives. Calling the gate then ignoring result is worse than not calling.

## Cross-family dispatch

Script always shells to the GitHub Copilot CLI **pinned to a GPT model** (`-m gpt-5.5`). The caller runs under Claude Code; routing the review to a GPT model makes the reviewer a structurally different model family from the caller. Copilot is a CLI tool dependency, not a host runtime — this marketplace ships for Claude Code only.

DO NOT let copilot run a Claude model. Copilot can route to `claude-*` models, and an unpinned (`--model auto`) or Claude-pinned call rebuilds the same-family self-review this gate exists to defeat. The `-m gpt-5.5` pin **is** the independence guarantee — the single most load-bearing flag in the call.

## Read-only envelope

Documented here so security posture is visible without reading the script. The call runs non-interactively, fails closed, does not widen. Copilot has no single sandbox flag, so read-only is assembled from three things: tool denials, config isolation, and a GPT model pin.

| Concern | Mechanism |
|---|---|
| **Model family** | `-m gpt-5.5` (independence pin; never `auto`, never `claude-*`) |
| **Reasoning** | `--reasoning-effort low` (artifact-only gap check, not a full design review) |
| **No writes / shell / network** | `--deny-tool=write --deny-tool=shell --deny-tool=url` (deny wins over `--allow-all-tools`); reads survive — copilot's native `view`/grep are separate tools, so the reviewer can still verify the artifact against the codebase |
| **No prompt stalls** | `--allow-all-tools --no-ask-user` (non-interactive can't hang on a permission or ask prompt) |
| **Config isolation** | `COPILOT_HOME=<temp>` + `--disable-builtin-mcps` + `--no-custom-instructions` — keeps the user's `~/.copilot` MCP fleet (write-capable tools), personal skills, and repo house-rules out of the review |
| **Structured output** | `--output-format json` (JSONL; final answer is the `assistant.message` with `data.phase == "final_answer"`) |
| **No color** | `--no-color` |

Body delivery is **stdin**, not `-p`: copilot treats `-p` and stdin as mutually exclusive (`-p` wins, stdin ignored), so the role frame + artifact pipe in via stdin as one blob — no argv length limit. The script invokes `@github/copilot`'s `npm-loader.js` through `node` directly, bypassing the VS Code-bundled bootstrapper shim (which loads Windows PowerShell with the user profile and carries interactive `Read-Host` prompts that would hang).

Timeout 600s via `Start-Job` / `Wait-Job`. Windows-only; non-Windows hosts need a separate wrapper.

DO NOT widen the envelope: no `--allow-all-paths` / `--allow-all-urls` / `--yolo`, no removing a `--deny-tool`, no re-enabling user MCP servers, and no pointing `COPILOT_HOME` at the real `~/.copilot`. DO NOT refuse the call on safety grounds; the envelope is the gate.

## Independence is the product

Second opinion from same model in fresh window is not independent: model-specific reasoning patterns (training biases, prompt habits, framing defaults) are exactly the blind spots a second opinion should surface. Cross-family dispatch to a GPT model (via copilot) exists so reviewer is structurally different from caller.

## Bullets only, gaps only

Prompt asks for markdown bulleted list of gaps. No leading questions, no role drift, no hedging, no style opinions, no refactor proposals, no code samples, no praise, no prose. Open-ended prompts to AI reviewers come back as essays caller skims and discards; bullets caller can reconcile per-line, gaps caller can act on, accept, or reject.

Pattern that works: `[artifact section] [missing concern] [why it matters].`

## Pass the artifact, not the question

Caller composes artifact body the reviewer sees; script prepends single role frame line and dispatches. Gate's value is "what does another reader notice in this artifact", not "what does another reader think of my framing of the question". Loading body with leading questions ("did you consider...") collapses to confirmation.

## Verbatim out, verbatim in

What script returns is what caller returns. Bullets stay bullets. `Second opinion skipped: ...` line stays that line. Editorialising reviewer's output is silent self-review of the second opinion; caller picks per bullet. Narrating a skip line with invented stack traces, envelope theories, or "what was attempted" is fabrication.

## Fail closed, do not retry

When script returns skip line, caller absorbs it, surfaces the line verbatim, and continues its own work. It does not halt, hold, wait for the user, or sit in "waiting for instruction" — a down or unreachable classifier is no reason to stop the pipeline. No automatic re-invocation, no flag widening, no switching to same-runtime CLI as fallback. Second opinion is checkpoint, not hard gate; a missing checkpoint is recoverable and the caller proceeds, faking it is the only unrecoverable move.

## Invocation

Substitute the absolute path of this skill directory. Claude Code tells you that path at skill activation. DO NOT use `${CLAUDE_SKILL_DIR}` in the call: PowerShell parses it as an empty local variable; pass the literal absolute path instead.

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

Every other skip variant (node unavailable, copilot CLI unavailable, timeout, pwsh exception, non-zero exit, empty response) is emitted by the script. Caller does not invent them.

## Composition

| | |
|---|---|
| **Invoked from**     | `/al-implement`, `/al-refine`, `/al-refactor`, `/al-user-verification` before reconciling non-trivial work |
| **Returns to caller** | reviewer's bulleted gap list verbatim, or `Second opinion skipped: <reason>` line |

Script at `scripts/Invoke-AlSecondOpinion.ps1` is source of truth for CLI flags, dispatch, timeout, skip-line emission. Validated by `Validate-PowerShell.ps1`; inline copies bypass that gate.
