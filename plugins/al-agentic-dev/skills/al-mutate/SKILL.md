---
name: al-mutate
description: Validate AL/Business Central test rigor by mutation testing. Inject one mutation, run /al-build, classify the survivor, revert. Use mandatorily inside /al-implement for non-trivial tasks, or standalone on legacy code to audit coverage before /al-refactor. Dispatches the al-agentic-dev:al-mutate agent for the mutate-build-revert cycle.
---

# /al-mutate — Test-rigor gate

Dispatch the `al-agentic-dev:al-mutate` agent. The agent owns the cycle. The skill resolves the task and hands off — nothing else.

**Resolve `tasks.md`:** Branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise standalone — no `tasks.md` write, agent reports only.

## Flow

1. Resolve `tasks.md` per the rule above. Standalone if no match.
2. Spawn `Agent(subagent_type: 'al-agentic-dev:al-mutate', prompt: <body>)`.
3. Pass through what the agent needs:
   - Inside `/al-implement` — calling task ID + the `**Mutations**` block from that task.
   - Standalone — target file or area; agent builds the plan from the code.
4. Relay the agent's report to the caller. Do not summarise away survivors.

## Composition

- `/al-build` runs every iteration — agent owns it.
- `/al-research` when a survivor needs BaseApp behaviour verified.
- `/al-refactor` consumes the standalone report — gaps drive new tests before any shape change.
- `/grill-me` when a survivor's classification needs the user.

## Out of scope

- No code changes outside the agent's mutate-revert cycle.
- No `tasks.md` restructuring — gaps surface as Notes lines on the calling task.
- No mutating test code, generated `.rdlc`, generated `.xlf`, or captions.
- No skipping preflight. Stop. Run `/al-build` until green, then retry.
