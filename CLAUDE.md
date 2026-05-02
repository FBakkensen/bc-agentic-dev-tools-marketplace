Marketplace of AI-assisted AL/Business Central development plugins for Claude Code.

Plugins live under `plugins/`:

- `al-agentic-dev/` — feature-level agentic flow (design, scope, refine, implement, refactor, mutate)
- `al-build/` — AL build/test gate
- `al-debug-logging/` — temporary runtime probes via FeatureTelemetry
- `bc-standard-reference/` — BaseApp / System Application lookup
- `grill-me/` — interview and stress-test plans
- `release-notes/` — PR-driven release note generation

Top-level layout:

```
.claude-plugin/marketplace.json   # Marketplace manifest — every plugin listed here
plugins/<name>/                   # One folder per plugin
scripts/                          # PowerShell 7.2+ validation scripts (CI gates)
.github/workflows/                # ci.yml, claude.yml, claude-code-review.yml
```

Every plugin has the same shape:

```
plugins/<plugin-name>/
├── .claude-plugin/plugin.json    # Claude manifest (name, version, description)
├── CLAUDE.md                     # Plugin-specific context — voice and conventions live here
├── skills/                       # One or more skills
│   └── <skill-name>/
│       ├── SKILL.md              # User-facing skill body
│       ├── scripts/              # PowerShell 7.2+ (optional)
│       └── references/           # Supporting docs (optional)
└── agents/                       # Optional — declare in plugin.json via "agents": "./agents/"
    └── <agent-name>.md           # Frontmatter + system prompt
```

Plugin name in `plugin.json` matches the folder name. Single-skill plugins put their skill at `skills/<plugin-name>/`; multi-skill plugins (like `al-agentic-dev`) put each skill at its own `skills/<skill-name>/`. Plugin agents are namespaced as `<plugin-name>:<agent-name>` when invoked via the `Agent` tool.

Run before pushing:

```powershell
pwsh scripts/Validate-Json.ps1            # All JSON files parse
pwsh scripts/Validate-PowerShell.ps1      # All .ps1 files have valid syntax
pwsh scripts/Validate-PluginStructure.ps1 # Marketplace and per-plugin manifests exist
```

CI (`.github/workflows/ci.yml`) runs all three on push/PR to `main`/`master`.

Adding or renaming a plugin:

1. Create `plugins/<name>/` with the shape above.
2. Add the entry to `.claude-plugin/marketplace.json`.
3. Run all three validation scripts locally.

Scripts are PowerShell 7.2+ (`#Requires -Version 7.2`), self-contained, runnable from repo root.

`.output/` and `**/secret.json` are gitignored — never commit build artifacts or secrets. `.claude/settings.local.json` is local-only.
