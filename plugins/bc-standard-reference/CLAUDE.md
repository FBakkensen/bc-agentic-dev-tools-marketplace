# bc-standard-reference

Locate canonical Business Central Standard behaviour (BaseApp, System Application, APIV2) — events, codeunits, tables, pages, tests.

## Layout

```
skills/bc-standard-reference/
├── SKILL.md
└── references/
    ├── repo-structure.md
    ├── search-patterns.md
    └── scenarios.md
```

## Editing rules

- **Canonical mirror**: `fbakkensen/bc-w1`. Any rename or move requires updating `SKILL.md` and all three reference files in lockstep.
- **Tool-agnostic**: the procedure describes *what* to find and *how to reason about it*. Cite tools by name only as examples, never as the only path. _Avoid_: hard-coding a specific MCP server or grep tool — describe the search heuristic instead.
- **Reference split**: `repo-structure.md` (paths), `search-patterns.md` (heuristics), `scenarios.md` (walkthroughs). Keep the split — don't merge.
- **Composition**: `/al-research` cites this skill as source #2. When renaming, update `/al-research`'s source-priority table in lockstep.
