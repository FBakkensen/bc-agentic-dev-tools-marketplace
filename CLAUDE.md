# CLAUDE.md

Marketplace of AI-assisted AL/Business Central development plugins. Targets Claude Code.

Plugin-specific context lives in `plugins/<plugin-name>/CLAUDE.md`. This file covers only what is shared across the marketplace.

## Repo layout

```
.claude-plugin/marketplace.json   # Claude marketplace manifest
plugins/<name>/                   # One folder per plugin
scripts/                          # PowerShell 7.2+ validation scripts (CI gates)
.github/workflows/                # ci.yml, claude.yml, claude-code-review.yml
```

## Plugin shape (every plugin must follow this)

```
plugins/<name>/
├── .claude-plugin/plugin.json    # Claude manifest (name, version, description)
├── CLAUDE.md                     # Plugin-specific context for AI editors
├── skills/<name>/
│   ├── SKILL.md                  # User-facing skill body
│   ├── scripts/                  # PowerShell 7.2+ (optional)
│   └── references/               # Supporting docs (optional)
└── agents/                       # Plugin-defined Claude Code agents (optional)
    └── <name>.md                 # Frontmatter + system prompt
```

The `agents/` directory is optional — plugins ship agents only when an orchestrator dispatch path benefits from a focused subagent (tool restrictions, dedicated system prompt). Declare in `plugin.json` via `"agents": "./agents/"`.

## Validation (run before pushing)

```powershell
pwsh scripts/Validate-Json.ps1            # All JSON files parse
pwsh scripts/Validate-PowerShell.ps1      # All .ps1 files have valid syntax
pwsh scripts/Validate-PluginStructure.ps1 # Marketplace and per-plugin manifests exist
```

CI (`.github/workflows/ci.yml`) runs all three on push/PR to `main`/`master`.

## Adding or renaming a plugin (the easy-to-miss steps)

1. Create `plugins/<name>/` with the shape above.
2. Add the plugin to the marketplace manifest at `.claude-plugin/marketplace.json`.
3. Run all three validation scripts locally before pushing.

## Conventions

- Scripts: PowerShell 7.2+ (`#Requires -Version 7.2`), self-contained, runnable from repo root.
- SKILL.md frontmatter must include `name` and `description`; the description is what triggers the skill.
- Plugin name in `plugin.json`, folder name, and `skills/<name>/` folder name must match.
- Plugin agents are namespaced as `<plugin-name>:<agent-name>` when invoked via the `Agent` tool.

## Authoring style (skills, prompts, agents)

Match the style of `plugins/al-agentic-dev/skills/`. Applies to **every change to an existing skill** and to **every new skill, slash-command prompt, or agent definition** added to this marketplace. Treat that plugin as the canonical exemplar; when in doubt, mirror it.

**Voice**

- Imperative, second-person, terse. Short sentences. State rules; don't explain them.
- Opinionated — *"Seven is the ceiling."*, *"One task, one session."* No hedging, no *"you might want to"*.
- Plain prose. No emoji, no marketing fluff, no *"Welcome to…"*, no callout admonitions.

**Frontmatter**

- `name` + a `description` that doubles as a trigger sentence — what it does, when to use it, what it composes with. The description is the only thing the agent sees before activation; it must earn the dispatch.

**Shape**

- H1: `# /<name> — <one-line role>` (em dash, not colon).
- Lead = 1–3 imperative sentences restating the contract before any section.
- Recurring sections, in this order when relevant: `Resolve tasks.md` (or equivalent precondition block), `Flow` (numbered), `Power model` / `Preflight`, `Tests` / `Output` / `Notes`, `Second opinion (gate)`, `Composition`, `Out of scope`.
- Bold lead-ins on bullets as inline labels (`**Real gap** → write a test...`).
- Tables for situation→action menus or priority lists.
- Fenced code blocks only for canonical formats (file shape, invocation lines).
- Close with `Out of scope` — explicit non-goals.

**Content rules**

- State naming, vocabulary, and conventions **inline**. Skills run in projects without this CLAUDE.md present — they cannot rely on it.
- Cross-reference peers by slash-command name (`/al-build`, `/grill-me`, …); name composed peers explicitly.
- Hard stop semantics: when a precondition fails, write `Stop.` and name the prerequisite skill.
- Escape hatch over silent expansion: append a Notes line and hand control back to the user, never improvise scope.
- Prefer gates (`Second opinion`, `Preflight`) over advisory checklists.

**Do not write**

- No *"Background"* / *"Why this matters"* / *"Overview"* intros.
- No enumerated reference checklists for completeness — they rot fast and fight the prose.
- No code samples beyond canonical doc shapes (Gherkin block, `tasks.md` entry, CLI invocation).
- No Mermaid, no ASCII diagrams unless the shape itself is the contract.

When editing an existing skill, scan its siblings for cross-references and update them in lockstep — composition by name only works if names stay accurate.

## Gotchas

- `.output/` and `**/secret.json` are gitignored — never commit build artifacts or secrets.
- `.claude/settings.local.json` is local-only.
