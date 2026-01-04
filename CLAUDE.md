# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BC Agentic Dev Tools is a plugin marketplace for AI-assisted AL/Business Central development. It provides five modular plugins that work with Claude Code, GitHub Copilot, Cursor, and other AI coding assistants.

## Commands

### Validation (CI checks)
```powershell
pwsh scripts/Validate-Json.ps1            # Validate all JSON files
pwsh scripts/Validate-PowerShell.ps1      # Validate all PowerShell syntax
pwsh scripts/Validate-PluginStructure.ps1 # Verify plugin.json exists in each plugin
```

## Architecture

```
plugins/
├── al-build/           # Build and test AL projects (Docker-based)
├── al-object-id-allocator/  # Allocate next AL object ID from app.json ranges
├── bc-w1-reference/    # Local mirror of BC W1 source code
├── al-agentic-guidelines/   # Local mirror of AL Guidelines (alguidelines.dev)
└── tdd/                # Red-Green-Refactor workflow with telemetry verification
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

**Local Mirrors**: bc-w1-reference and al-agentic-guidelines clone external repos to `_aldoc/` (sibling folder) for offline searching.

**TDD Workflow**: Uses DEBUG-* telemetry markers to verify code paths during testing. These markers must be removed after verification (zero DEBUG-* at task start and end).

## Plugin Details

### al-build
Build gate for AL projects: compilation → publish → test.
- Output: `.output/TestResults/last.xml` (JUnit), `.output/TestResults/telemetry.jsonl`
- Requires: Docker Desktop, BcContainerHelper module
- Configuration: `plugins/al-build/skills/al-build/config/al-build.json`

### al-object-id-allocator
Scans `app.json` idRanges and existing `.al` files to find next available object ID.
- Script: `Get-NextALObjectNumber.ps1 -AppPath ".\app" -ObjectType "table"`
- Supports 23+ object types (table, page, codeunit, report, enum, interface, etc.)

### tdd
Test-driven development with telemetry verification.
- Every test must start with: `FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', '<ProcedureName>')`
- Production code adds branch telemetry to prove execution paths
- Verify in `telemetry.jsonl`, then remove all DEBUG-* calls

## Environment Variables (al-build)

| Variable | Default | Description |
|----------|---------|-------------|
| ALBT_APP_DIR | app | Main app directory |
| ALBT_TEST_DIR | test | Test app directory |
| WARN_AS_ERROR | 1 | Treat warnings as errors |
| ALBT_BC_CONTAINER_NAME | - | Docker container name |
| ALBT_BC_ARTIFACT_COUNTRY | w1 | BC artifact country |
