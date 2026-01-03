# bc-agentic-dev-tools

Business Central agentic development tools - skills for AI-assisted AL development.

These skills are agent-agnostic and work with Claude Code, GitHub Copilot, Cursor, and other AI coding assistants that support skill-based workflows.

## Plugins

| Plugin | Description |
|--------|-------------|
| **al-build** | Build and test AL/Business Central projects. Runs compilation, publishing, and test execution. |
| **bc-w1-reference** | Local mirror of BC W1 source code for searching events, APIs, tables, fields, and tests. |
| **al-object-id-allocator** | Allocate the next available AL object ID by scanning .al files and app.json. |
| **tdd** | Red-Green-Refactor test workflow with telemetry verification. |
| **al-agentic-guidelines** | Local mirror of AL Guidelines (alguidelines.dev) for coding standards and best practices. |

## Installation (Claude Code)

### Add the marketplace

```bash
/plugin marketplace add fbakkensen/bc-agentic-dev-tools
```

### Install individual plugins

```bash
/plugin install al-build@bc-agentic-dev-tools
/plugin install bc-w1-reference@bc-agentic-dev-tools
/plugin install al-object-id-allocator@bc-agentic-dev-tools
/plugin install tdd@bc-agentic-dev-tools
/plugin install al-agentic-guidelines@bc-agentic-dev-tools
```

## Slash Commands

After installing plugins, these slash commands become available:

| Command | Description |
|---------|-------------|
| `/al-build:test` | Run AL build gate (compile, publish, test) |
| `/al-build:provision` | One-time setup for AL build (compiler + symbols) |
| `/al-build:clean` | Clean AL build artifacts |
| `/al-object-id-allocator:next-id` | Get next available AL object ID |
| `/bc-w1-reference:setup` | Clone BC W1 source mirror |
| `/bc-w1-reference:update` | Update BC W1 source mirror |
| `/al-agentic-guidelines:setup` | Clone AL Guidelines mirror |
| `/al-agentic-guidelines:update` | Update AL Guidelines mirror |

The **tdd** plugin provides context via SKILL.md (no slash commands).

## Auto-enable for BC projects

Add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "bc-agentic-dev-tools": {
      "source": {
        "source": "github",
        "repo": "fbakkensen/bc-agentic-dev-tools"
      }
    }
  },
  "enabledPlugins": {
    "al-build@bc-agentic-dev-tools": true,
    "bc-w1-reference@bc-agentic-dev-tools": true,
    "al-object-id-allocator@bc-agentic-dev-tools": true,
    "tdd@bc-agentic-dev-tools": true,
    "al-agentic-guidelines@bc-agentic-dev-tools": true
  }
}
```

## Manual usage (any agent)

The skills in this repo are markdown-based and can be used with any AI coding assistant:

1. Copy the `skills/<skill-name>` folder to your project's `.claude/skills/` or equivalent
2. Reference the SKILL.md in your agent's context
3. Run the PowerShell scripts as documented in each skill

## Prerequisites

- PowerShell 7.2+
- Docker Desktop (for al-build)
- BcContainerHelper module (for al-build)

## License

MIT
