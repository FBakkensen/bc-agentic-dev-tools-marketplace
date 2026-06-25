---
name: al-agentic-dev-overview
description: User-facing orientation for the al-agentic-dev plugin — pipeline diagram, 19-skill catalogue plus the subagent prompt blocks, persistence layers, and cold-start guidance. Use when the user asks "what is al-agentic-dev", "what skills are in here", "show me the pipeline", "where do I start from scratch", or wants a tour. Pure static emit; does not inspect repo state. For state-aware navigation mid-feature ("what should I do next"), the dispatcher should prefer /al-steer.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-agentic-dev-overview, Plugin tour

Read `${CLAUDE_SKILL_DIR}/../../references/overview.md` and emit verbatim — the whole file is the response body. Write nothing; inspect no repo state.

Pure static emit is the seam: this skill answers "what does the plugin contain", `/al-steer` answers "what should I do right now". A prompt that wants state-aware navigation ("what's next", "where are we") is `/al-steer` — route, don't tour.

## Next step

Orientation only. `Next: /al-steer` for the state-aware "where am I / what next" read off the current feature.
