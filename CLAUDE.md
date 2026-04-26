# CLAUDE.md

Marketplace of AI-assisted AL/Business Central development plugins. Targets Claude Code and Codex; usable from any agent that consumes SKILL.md.

Plugin-specific context lives in `plugins/<plugin-name>/CLAUDE.md`. This file covers only what is shared across the marketplace.

## Repo layout

```
.claude-plugin/marketplace.json   # Claude marketplace manifest
.agents/plugins/marketplace.json  # Codex marketplace manifest (must stay in sync)
plugins/<name>/                   # One folder per plugin
scripts/                          # PowerShell 7.2+ validation scripts (CI gates)
.github/workflows/                # ci.yml, claude.yml, claude-code-review.yml
```

## Plugin shape (every plugin must follow this)

```
plugins/<name>/
├── .claude-plugin/plugin.json    # Claude manifest (name, version, description)
├── .codex-plugin/plugin.json     # Codex manifest (same name/version + interface block)
├── CLAUDE.md                     # Plugin-specific context for AI editors
└── skills/<name>/
    ├── SKILL.md                  # Agent-facing instructions (the actual product)
    ├── scripts/                  # PowerShell 7.2+ (optional)
    └── references/               # Supporting docs (optional)
```

Both manifests are required — `Validate-PluginStructure.ps1` fails if either is missing or if the two marketplace.json files list different plugins.

## Validation (run before pushing)

```powershell
pwsh scripts/Validate-Json.ps1            # All JSON files parse
pwsh scripts/Validate-PowerShell.ps1      # All .ps1 files have valid syntax
pwsh scripts/Validate-PluginStructure.ps1 # Marketplaces in sync; both manifests exist per plugin
```

CI (`.github/workflows/ci.yml`) runs all three on push/PR to `main`/`master`.

## Adding or renaming a plugin (the easy-to-miss steps)

1. Create `plugins/<name>/` with the shape above (both `.claude-plugin/` and `.codex-plugin/` manifests).
2. Add the plugin to **both** marketplace manifests in the **same order** — `Validate-PluginStructure.ps1` enforces order parity.
3. Run all three validation scripts locally before pushing.

## Conventions

- Scripts: PowerShell 7.2+ (`#Requires -Version 7.2`), self-contained, runnable from repo root.
- SKILL.md frontmatter must include `name` and `description`; the description is what triggers the skill.
- Plugin name in `plugin.json`, folder name, and `skills/<name>/` folder name must match.

## Gotchas

- `.output/` and `**/secret.json` are gitignored — never commit build artifacts or secrets.
- `.claude/settings.local.json` is local-only.
- Codex manifest needs an extra `interface` block (`displayName`, `category`, etc.) that the Claude manifest does not.
