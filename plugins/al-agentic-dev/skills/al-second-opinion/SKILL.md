---
name: al-second-opinion
description: Independent read-only advisory review via cross-family CLI dispatch (shells to GitHub Copilot CLI, pinned to a GPT model). Use from `/al-implement`, `/al-refine`, `/al-refactor`, `/al-user-verification`, or `/al-code-review` before reconciling non-trivial `Test Specification`, `Verification Plan`, mutation lists, refactor checklists, a verification walk verdict, or a review fix-queue.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-second-opinion, independent advisory review

Ask a different model family to read the artifact and name what is missing. Same-model self-review confirms its own blind spots; cross-family is the point. Script `scripts/Invoke-AlSecondOpinion.ps1` shells to the GitHub Copilot CLI (`@github/copilot`), pinned to a GPT model, for that read. Copilot is a CLI tool dependency here — not a host runtime, not a publish target.

Caller (`/al-implement`, `/al-refine`, `/al-refactor`, `/al-user-verification`, `/al-code-review`) owns the artifact and reconciles bullets that come back; this skill owns the call. For `/al-user-verification` the artifact is the walk verdict — per example, the exact question as posed and the user's verbatim observation (or captured client output for Contract examples); the review checks coverage and routing, not the observation itself. For `/al-code-review` the artifact is the round's must-fix survivor list, and the caller treats a refutation as a **veto on autonomous action** — the refuted finding drops out of the fix queue and escalates rather than being auto-fixed on cross-family doubt.

## Preconditions

- Artifact is real and non-trivial: `Test Specification`, `Verification Plan`, mutation list, refactor checklist, verification verdict. Round-tripping a one-line decision trains the caller to ignore the gate.
- `node` and the `@github/copilot` npm-global package present. Absent → script returns a skip line; caller proceeds.
- Caller can reconcile per bullet when output arrives. Calling the gate then ignoring the result is worse than not calling.

## Cross-family dispatch

Script always shells to the GitHub Copilot CLI **pinned to a GPT model** (`-m gpt-5.5`). The caller runs under Claude Code, so a GPT reviewer is a structurally different family.

DO NOT let copilot run a Claude model. Copilot can route to `claude-*`, and an unpinned (`--model auto`) or Claude-pinned call rebuilds the same-family self-review this gate exists to defeat. The `-m gpt-5.5` pin **is** the independence guarantee — the most load-bearing flag in the call.

## Read-only envelope

Documented here so the security posture is visible without reading the script. Copilot has no single sandbox flag, so read-only is assembled from tool denials, config isolation, and the GPT pin.

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

## Bullets only, gaps only

Prompt asks for a markdown bulleted list of gaps, shape `[artifact section] [missing concern] [why it matters].` Bullets the caller reconciles per-line; gaps it can act on, accept, or reject.

## Pass the artifact, not the question

Caller composes the artifact body the reviewer sees; script prepends a single role-frame line and dispatches. The value is "what does another reader notice in this artifact", not a verdict on the caller's framing — leading questions ("did you consider...") collapse to confirmation.

## Verbatim out, verbatim in

What the script returns is what the caller returns. Bullets stay bullets; the `Second opinion skipped: ...` line stays that line. Editorialising the output is silent self-review of the second opinion; narrating a skip line with invented stack traces or "what was attempted" is fabrication.

## Fail closed, do not retry

On a skip line the caller surfaces it verbatim and continues its own work — it does not halt, wait, re-invoke, widen flags, or fall back to a same-runtime CLI. Second opinion is a checkpoint, not a hard gate: a missing one is recoverable, faking it is the only unrecoverable move.

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
| **Invoked from**     | `/al-implement`, `/al-refine`, `/al-refactor`, `/al-user-verification` before reconciling non-trivial work; `/al-code-review` every round on the must-fix survivor list (return treated as a veto on autonomous fixing) |
| **Returns to caller** | reviewer's bulleted gap list verbatim, or `Second opinion skipped: <reason>` line |

Script at `scripts/Invoke-AlSecondOpinion.ps1` is source of truth for CLI flags, dispatch, timeout, skip-line emission. Validated by `Validate-PowerShell.ps1`; inline copies bypass that gate.
