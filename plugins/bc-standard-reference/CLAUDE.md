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

- The skill targets `fbakkensen/bc-w1` as the canonical mirror. Any rename or move of that repo requires updating SKILL.md and all three reference files.
- The skill is intentionally **tool-agnostic** — the procedure is described without prescribing a specific MCP server or grep tool, so it works for any agent. Preserve that abstraction; if you cite a tool by name, do it as an example, not as the only path.
- Reference files trade off: `repo-structure.md` (paths), `search-patterns.md` (heuristics), `scenarios.md` (walkthroughs). Keep that split.
