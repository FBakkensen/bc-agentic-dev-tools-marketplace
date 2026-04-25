# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

BC Agentic Dev Tools is a plugin marketplace for AI-assisted AL/Business Central development. It works with Codex, GitHub Copilot, Cursor, and other AI coding assistants.

## Commands

### Validation (CI checks)
```powershell
pwsh scripts/Validate-Json.ps1            # Validate all JSON files
pwsh scripts/Validate-PowerShell.ps1      # Validate all PowerShell syntax
pwsh scripts/Validate-PluginStructure.ps1 # Verify plugin.json exists in each plugin
```

CI runs all three on push/PR to main/master (`.github/workflows/ci.yml`).

## Architecture

```
plugins/                # Plugin directory (add new plugins here)
scripts/                # Validation scripts (used by CI)
.github/workflows/      # CI (ci.yml), Codex agent (Codex.yml), code review (Codex-review.yml)
```

### Plugins

al-build, al-debug-logging, al-object-id-allocator, bc-standard-reference, refine-issue-for-automated-tests, release-notes, tdd-implement, video-to-issue

### Plugin Structure Pattern
```
plugins/<plugin-name>/
├── .Codex-plugin/
│   └── plugin.json      # Plugin metadata (name, version)
└── skills/
    └── <plugin-name>/
        ├── SKILL.md     # Agent-facing documentation
        ├── scripts/     # PowerShell scripts (optional)
        └── references/  # Supporting docs and templates (optional)
```

### Key Concepts

**Skills**: Markdown-based instructions (SKILL.md) that AI assistants consume directly. Scripts are PowerShell 7.2+ and self-contained.

## Gotchas

- `.output/` is gitignored — build artifacts and test results go here
- `**/secret.json` is gitignored — never commit secrets
- `.Codex/settings.local.json` is local-only (gitignored)
