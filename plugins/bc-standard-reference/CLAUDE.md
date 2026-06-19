# bc-standard-reference

Locate canonical Business Central Standard behaviour (BaseApp, System Application, APIV2) — events, codeunits, tables, pages, tests.

## Layout

Agent-only plugin — the worker is a declarative agent, no skill.

```
agents/
└── bc-standard-reference.md   # the agent; reads ../references/ via ${CLAUDE_PLUGIN_ROOT}
references/
├── repo-structure.md
├── search-patterns.md
└── scenarios.md
```

## Editing rules

- **Canonical mirror**: `fbakkensen/bc-w1`. Any rename or move requires updating `agents/bc-standard-reference.md` and all three reference files in lockstep.
- **Tool-agnostic**: the procedure describes *what* to find and *how to reason about it*. Cite tools by name only as examples, never as the only path. _Avoid_: hard-coding a specific MCP server or grep tool — describe the search heuristic instead. The agent's `tools:` envelope (`Read, Grep, Glob, WebFetch, WebSearch, mcp__al-symbols-mcp__*`) is what it *may* reach; the body stays heuristic.
- **Reference split**: `repo-structure.md` (paths), `search-patterns.md` (heuristics), `scenarios.md` (walkthroughs). Keep the split — don't merge. References live at plugin level so the agent reads them via `${CLAUDE_PLUGIN_ROOT}/references/`.
- **Composition**: `al-research` agent (the al-agentic-dev agent) reaches this agent as its BaseApp source. When renaming, update `al-research`'s Sources list in lockstep.
