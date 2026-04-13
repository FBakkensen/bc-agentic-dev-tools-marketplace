# bc-agentic-dev-tools

Business Central agentic development tools - skills for AI-assisted AL development.

This repository is a dual marketplace for Claude Code and Codex. The Claude marketplace remains the source of truth for its existing layout, and the Codex-compatible marketplace mirrors the same plugin membership under a parallel manifest structure.

## Claude Code

Claude Code uses the existing marketplace and plugin manifests:

- Marketplace: `.claude-plugin/marketplace.json`
- Plugin manifest: `plugins/<plugin-name>/.claude-plugin/plugin.json`

Install from the published marketplace as before:

```bash
/plugin marketplace add fbakkensen/bc-agentic-dev-tools
```

Once plugins are available, install them with:

```bash
/plugin install <plugin-name>@bc-agentic-dev-tools
```

## Codex

Codex uses the repository-local marketplace and plugin manifests:

- Marketplace: `.agents/plugins/marketplace.json`
- Plugin manifest: `plugins/<plugin-name>/.codex-plugin/plugin.json`

Point your Codex-compatible tooling at the local marketplace file in this repository. Each published plugin is listed with a local source path rooted at `./plugins/<plugin-name>`.

## Plugins

Published plugins are mirrored across both marketplaces and should keep the same plugin names in both systems.

## License

MIT
