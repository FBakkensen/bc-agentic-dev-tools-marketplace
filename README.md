# bc-agentic-dev-tools

Business Central agentic development tools — Claude Code and Codex plugin marketplace for AI-assisted AL development.

## Install

### Claude Code

```bash
/plugin marketplace add fbakkensen/bc-agentic-dev-tools
/plugin install <plugin-name>@bc-agentic-dev-tools
```

### Codex

From Codex, add this repo as a plugin marketplace and install the plugin you need:

```bash
codex plugin marketplace add fbakkensen/bc-agentic-dev-tools
```

Codex can then browse the marketplace from `/plugins`, or install plugins from the Codex plugin UI.

## Plugins

- `al-agentic-dev` — full AL/BC dev stack. Agentic flow (grill-adr, event-model, design, scope, refine, implement, user-verification, refactor, mutate, code-review, second-opinion, research, steer) + build/test gate (`/al-build`) + telemetry probes (`/al-debug-logging`)
- `bc-standard-reference` — BaseApp / System Application / APIV2 canonical lookup
- `grill-me` — interview and stress-test plans
- `release-notes` — PR-driven release note generation

## Manifest

- Claude marketplace: `.claude-plugin/marketplace.json`
- Claude plugin: `plugins/<plugin-name>/.claude-plugin/plugin.json`
- Codex marketplace: `.agents/plugins/marketplace.json`
- Codex plugin: `plugins/<plugin-name>/.codex-plugin/plugin.json`

## License

MIT
