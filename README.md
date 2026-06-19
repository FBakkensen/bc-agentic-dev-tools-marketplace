# bc-agentic-dev-tools

Business Central agentic development tools — a Claude Code plugin marketplace for AI-assisted AL development.

## Install

```bash
/plugin marketplace add fbakkensen/bc-agentic-dev-tools
/plugin install <plugin-name>@bc-agentic-dev-tools
```

## Plugins

- `al-agentic-dev` — full AL/BC dev stack. Agentic flow (grill-adr, event-model, design, scope, refine, implement, user-verification, refactor, mutate, code-review, second-opinion, steer) + plugin agents (`al-doc-verify` document gate, `al-research` BC fact verification, `al-review-lens`/`-bc` review lenses) + build/test gate (`/al-build`) + telemetry probes (`/al-debug-logging`)
- `al-language-server` — AL language server for the Claude Code LSP tool (requires the AL dotnet tool ≥ 18.0 on PATH)
- `bc-standard-reference` — BaseApp / System Application / APIV2 canonical lookup
- `grill-me` — interview and stress-test plans
- `release-notes` — PR-driven release note generation

## Manifest

- Marketplace: `.claude-plugin/marketplace.json`
- Plugin: `plugins/<plugin-name>/.claude-plugin/plugin.json`

## License

MIT
