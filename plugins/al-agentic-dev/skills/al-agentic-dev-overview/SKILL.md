---
name: al-agentic-dev-overview
description: User-facing orientation for the al-agentic-dev plugin — pipeline diagram, 17-skill catalogue, persistence layers, and cold-start guidance. Use when the user asks "what is al-agentic-dev", "what skills are in here", "show me the pipeline", "where do I start from scratch", or wants a tour. Pure static emit; does not inspect repo state. For state-aware navigation mid-feature ("what should I do next"), the dispatcher should prefer /al-steer.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-agentic-dev-overview, Plugin tour

Read `${CLAUDE_SKILL_DIR}/../../references/overview.md` and emit verbatim. No framing, no preamble, no prompt-echo header, no section selection. The whole file goes to the user as the response body.

## Power model

Read `references/overview.md`. Write nothing. Inspect no repo state — not `tasks.md`, not the branch, not recent commits, not the codebase. Pure static emit is the design rationale: this skill answers "what does the plugin contain", `/al-steer` answers "what should I do right now". Mixing the two collapses the seam.

## When NOT to fire

`/al-agentic-dev-overview` is the tour. It does not navigate, advise, or replan. If the user prompt is:

- "What should I do next?" / "Where are we?" → that is `/al-steer`. Stop and route.
- "What does `/al-mutate` do?" → answer from the dispatcher's own description of that skill, or invoke it. Do not dump the whole tour.
- "Help me design X" / "I want to implement Y" → that is the named work skill (`/al-design`, `/al-implement`). Do not dump the tour.

The tour fires on plugin-orientation intent only.

## Composition

| | |
|---|---|
| **Invoked by** | user typing "what is al-agentic-dev", "show me the pipeline", "what skills are in here", "where do I start", or similar tour-shaped prompt |
| **Reads** | `${CLAUDE_SKILL_DIR}/../../references/overview.md` |
| **Routes to** | `/al-steer` if the user actually wanted state-aware navigation |
