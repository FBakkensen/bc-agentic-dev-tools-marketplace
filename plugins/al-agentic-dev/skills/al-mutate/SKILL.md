---
name: al-mutate
description: Validate AL/Business Central test rigor via mutation testing. Use mandatorily inside /al-implement for non-trivial tasks, or standalone on legacy code to audit coverage before /al-refactor. Dispatches the al-agentic-dev:al-mutate agent for the mutate-build-revert cycle.
---

# /al-mutate — Validate test rigor

Dispatch the `al-agentic-dev:al-mutate` agent. The agent owns preflight (clean tree + baseline green + production-only + plan ready), the per-mutation flow, classification, BC-specific safety, and output. Standalone or inside `/al-implement`.

**Resolve `tasks.md`:** Branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise standalone — no `tasks.md` write, report only.

## Invocation

Spawn `Agent(subagent_type: 'al-agentic-dev:al-mutate', prompt: <task context or standalone target>)`. Pass the calling task ID and the `**Mutations**` block when invoked from `/al-implement`; pass the target file or area when standalone.

The agent's full contract — preflight, canonical `**Mutations**` block format, flow, mutation classes, survivor classification, BC safety, output — lives in `agents/al-mutate.md`.

## Composition

- `/al-build` every iteration — the agent inherits this dependency.
- `/al-research` when a survivor requires verifying BaseApp behaviour.
- `/al-refactor` consumes the report when run standalone — gaps drive new tests before shape changes.
- `/grill-me` when survivor classification needs the user.

## Out of scope

- No code changes outside the mutation/revert cycle.
- No `tasks.md` restructuring — gaps surface as Notes lines.
- No mutating test code, generated files, or captions.
- No skipping preflight.
