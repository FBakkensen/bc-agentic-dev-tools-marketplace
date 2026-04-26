# al-build

Self-contained build/test gate for AL/Business Central. Compiles, publishes to a local Docker container, runs tests, and emits results to `.output/TestResults/`.

## Layout

```
skills/al-build/
├── SKILL.md            # Agent-facing entry point
├── README.md           # Human-facing notes
├── config/             # Config templates (al-build.json default shape)
└── scripts/            # PowerShell 7.2+: init.ps1, provision.ps1, test.ps1
```

## Lifecycle (in consuming projects)

1. `init.ps1` — drops `al-build.json` into the consumer repo root.
2. `provision.ps1` — one-time symbol/Docker setup.
3. `test.ps1` — the gate. Outputs `last.xml` and `telemetry.jsonl`.

When editing scripts, preserve the config priority chain: CLI flag > env var (`ALBT_*`) > `al-build.json` > built-in defaults.

## Editing rules

- All scripts are PowerShell 7.2+ and runnable from a consumer repo's root, not from this marketplace repo.
- The skill is invoked as a subagent in practice (verbose output) — keep `SKILL.md`'s subagent invocation block accurate.
- Outputs (`.output/TestResults/last.xml`, `telemetry.jsonl`) are part of the contract — `al-debug-logging` reads `telemetry.jsonl`.
