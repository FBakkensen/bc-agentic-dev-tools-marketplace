# bc-agentic-dev-tools

Business Central agentic development tools — Claude Code plugin marketplace for AI-assisted AL development.

## Install

```bash
/plugin marketplace add fbakkensen/bc-agentic-dev-tools
/plugin install <plugin-name>@bc-agentic-dev-tools
```

## Plugins

- `al-agentic-dev` — feature-level agentic flow (grill-adr, design, scope, refine, implement, refactor, mutate, research, steer)
- `al-build` — AL build/test gate
- `al-debug-logging` — temporary `DEBUG-*` runtime probes via `FeatureTelemetry`
- `bc-standard-reference` — BaseApp / System Application / APIV2 canonical lookup
- `grill-me` — interview and stress-test plans
- `release-notes` — PR-driven release note generation

## Manifest

- Marketplace: `.claude-plugin/marketplace.json`
- Plugin: `plugins/<plugin-name>/.claude-plugin/plugin.json`

## License

MIT
