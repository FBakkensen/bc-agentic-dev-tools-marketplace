Marketplace of AI-assisted AL/Business Central development plugins for Claude Code.

Plugins live under `plugins/`:

- `al-agentic-dev/` — feature-level agentic flow (steer, grill-adr, event-model, design, scope, refine, research, implement, page-script, user-verification, refactor, mutate, code-review, second-opinion) plus the build/test gate (build, provision, validate-breaking-changes) and telemetry probes (debug-logging)
- `al-language-server/` — AL language server for the Claude Code LSP tool (ships `.lsp.json`)
- `bc-standard-reference/` — BaseApp / System Application lookup via a dedicated subagent
- `grill-me/` — interview and stress-test plans
- `release-notes/` — PR-driven release note generation

Top-level layout:

```
.claude-plugin/marketplace.json   # Claude marketplace manifest — every plugin listed here
plugins/<name>/                   # One folder per plugin
scripts/                          # PowerShell 7.2+ validation scripts (CI gates)
tests/                            # Pester tests for plugin scripts (e.g. al-build)
.github/workflows/                # ci.yml, claude.yml, claude-code-review.yml
```

Every plugin has `.claude-plugin/plugin.json` (Claude manifest — name matches the folder name) and usually a dev-time `CLAUDE.md`. All other components sit at the plugin root and are optional per the Claude Code plugin spec:

```
plugins/<plugin-name>/
├── .claude-plugin/plugin.json    # Claude manifest (name, version, description) — required
├── CLAUDE.md                     # Plugin-specific context — voice and conventions live here
├── skills/                       # Skills
│   └── <skill-name>/
│       ├── SKILL.md              # User-facing skill body
│       ├── scripts/              # PowerShell 7.2+ (optional)
│       └── references/           # Supporting docs (optional)
├── agents/                       # Subagent definitions (<name>.md)
├── hooks/                        # Hook config + scripts
├── references/                   # Plugin-level docs shared across skills/agents
└── .lsp.json                     # Language-server config for the LSP tool
```

Actual shapes: `grill-me` and `release-notes` are skills-only; `al-agentic-dev` adds `hooks/` and plugin-level `references/`; `bc-standard-reference` is `agents/` + `references/` with no skills; `al-language-server` is `.lsp.json` only (no skills, no CLAUDE.md).

Single-skill plugins put their skill at `skills/<plugin-name>/`; multi-skill plugins (like `al-agentic-dev`) put each skill at its own `skills/<skill-name>/`.

## CLAUDE.md scope (this repo)

Every `CLAUDE.md` in this repo — root and per-plugin — is **dev-time only**. They load when you're working in the marketplace repo (this session). Installed users never see them. Any rule the assistant needs at runtime in an end-user's session must live in `SKILL.md` or a `references/*.md` the SKILL explicitly reads — not in any `CLAUDE.md`.

## Git workflow on this repo

**`main` is PR-only.** Never commit on `main`. For every change: fetch and branch off a fresh `origin/main` (`git checkout -b <topic>`), commit there, push the branch, open a PR with `gh pr create`, merge via the PR once CI is green (squash preferred), then delete the branch.

Enforcement: a `pre-commit` hook in `.githooks/` blocks local commits on `main`, and a GitHub ruleset on the remote requires a PR with passing CI. New clones must run `git config core.hooksPath .githooks` once to activate the hook.

Run before pushing:

```powershell
pwsh scripts/Validate-Json.ps1            # All JSON files parse
pwsh scripts/Validate-PowerShell.ps1      # All .ps1 files have valid syntax
pwsh scripts/Validate-PluginStructure.ps1 # Marketplace and per-plugin manifests exist
```

CI (`.github/workflows/ci.yml`) runs all three plus the Pester tests in `tests/` on push/PR to `main`.

Adding or renaming a plugin:

1. Create `plugins/<name>/` with the shape above.
2. Add the entry to `.claude-plugin/marketplace.json`.
3. Run all three validation scripts locally.

Scripts are PowerShell 7.2+ (`#Requires -Version 7.2`), self-contained, runnable from repo root.

`.output/` and `**/secret.json` are gitignored — never commit build artifacts or secrets. `.claude/settings.local.json` is local-only.
