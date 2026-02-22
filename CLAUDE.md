# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BC Agentic Dev Tools is a plugin marketplace for AI-assisted AL/Business Central development. It works with Claude Code, GitHub Copilot, Cursor, and other AI coding assistants.

## Commands

### Validation (CI checks)
```powershell
pwsh scripts/Validate-Json.ps1            # Validate all JSON files
pwsh scripts/Validate-PowerShell.ps1      # Validate all PowerShell syntax
pwsh scripts/Validate-PluginStructure.ps1 # Verify plugin.json exists in each plugin
```

## Architecture

```
plugins/                # Plugin directory (add new plugins here)
```

### Plugin Structure Pattern
```
plugins/<plugin-name>/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata (name, version)
├── commands/            # Slash commands (optional)
│   └── *.md
├── hooks/               # Event hooks (optional)
│   └── hooks.json
└── skills/
    └── <plugin-name>/
        ├── SKILL.md     # Agent-facing documentation
        ├── scripts/     # PowerShell scripts
        └── config/      # JSON configuration with schemas
```

### Key Concepts

**Skills**: Markdown-based instructions (SKILL.md) that AI assistants consume directly. Scripts are PowerShell 7.2+ and self-contained.
