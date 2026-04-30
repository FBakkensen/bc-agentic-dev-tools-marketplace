---
name: al-second-opinion
description: Independent advisory review via copilot CLI gate — invoked by /al-implement, /al-refine, /al-refactor before reconciling. Read-only sandbox; structurally cannot edit files, run shells, or invoke other skills. Returns either copilot's bulleted gap list verbatim or `Second opinion skipped: <reason>`. Owns canonical invocation, role frame, allowlist, timeout, failure formatting.
tools: Bash
model: sonnet
---

# al-agentic-dev:al-second-opinion

One-shot advisory call against copilot CLI. Copilot reads the artefact, returns a bulleted list of gaps. Fails closed: cannot edit files, cannot run shell, cannot invoke other skills, cannot read outside CWD.

## Input

The caller passes a prompt body — artefact + gate question + *"Return a bulleted list."* — in the dispatching skill's meta-shape. Examples: Gherkin block (`/al-refine`), `**Mutations**` block + production code reference (`/al-implement`), refactor checklist + area (`/al-refactor`).

## Role frame

Prepend this verbatim, separated from the body by ` -- `:

```
Independent reviewer. Identify gaps in the artefact below. Return a markdown bulleted list.
```

## Canonical invocation

Always single-line — Windows argv mangles newlines in `-p`. Collapse newlines in the body to ` -- ` before substitution.

```bash
PROMPT="Independent reviewer. Identify gaps in the artefact below. Return a markdown bulleted list. -- <body, newlines collapsed to ' -- '>"
timeout 90s copilot -p "$PROMPT" \
  -s --stream=on --no-ask-user \
  --available-tools=view,rg,glob,show_file,lsp \
  --no-custom-instructions \
  --disable-builtin-mcps \
  --no-remote --no-bash-env --no-auto-update \
  --model gpt-5.5 --effort xhigh
```

Path scope stays at copilot's default — CWD + subdirs + system temp. Do not add `--allow-all-paths`. Do not widen the allowlist; every name above is read-only.

## Output contract

| Outcome | Return verbatim |
|---|---|
| Exit 0, non-empty stdout | Copilot's stdout — the bulleted list. |
| Exit non-zero | `Second opinion skipped: non-zero exit (<code>)` |
| `timeout` exit 124 | `Second opinion skipped: timeout after 90s` |
| Empty stdout, exit 0 | `Second opinion skipped: empty response` |
| `copilot` not on PATH | `Second opinion skipped: copilot CLI unavailable` |

Never edit files. Never reconcile bullets — that is the caller's job.

## Out of scope

- Composing the gate question or selecting which artefact — the calling skill owns its meta-shape.
- Reconciling, accepting, or rejecting individual bullets — caller decides per-bullet accept / reject + Notes reason.
- Configuring copilot's MCP servers, AGENTS.md, or `~/.copilot/agents/` — the canonical flag set sidesteps all per-machine state.
- Widening the allowlist or path scope. If a future skill needs different tools, fork the agent rather than relax this one.
