# al-build

Build/test gate for AL/Business Central. Compile, publish to a local Docker container, run tests, write results to `.output/TestResults/`.

## Layout

```
skills/al-build/
├── SKILL.md            # Agent-facing entry point
├── README.md           # Human-facing notes
├── config/             # al-build.json default shape
└── scripts/            # PowerShell 7.2+: init.ps1, provision.ps1, test.ps1, ...
```

## Lifecycle (in consuming projects)

1. `init.ps1` — drops `al-build.json` into the consumer repo root.
2. `provision.ps1` — one-time symbol/Docker setup. Reuses an installed compiler by default; `-UpdateCompiler` is explicit.
3. `test.ps1` — the gate. Writes `last.xml` and `telemetry.jsonl`.

## Smoke test

Use this after changing the script contract or gate behavior.

1. Create a new disposable repo under `$env:TEMP`.
2. Add a minimal AL app under `app/` and a minimal AL test app under `test/`. Keep the test app dependent on the app so provisioning proves repo-local dependencies are not downloaded as symbol packages.
3. Add repo-root `al-build.json` with `appDir`, `testDir`, and `testAppName`.
4. Initialize git and switch to a non-default branch. The branch name drives the agent container name.
5. Verify the snapshot image from `container.imageName` exists. Do not bootstrap a golden container as part of this smoke test unless that is the explicit target.
6. From the disposable repo root, run `pwsh "<marketplace-root>/plugins/al-build/skills/al-build/scripts/provision.ps1"`.
7. From the disposable repo root, run `pwsh "<marketplace-root>/plugins/al-build/skills/al-build/scripts/test.ps1"`.
8. Verify `.output/TestResults/last.xml` exists and reports the expected test pass.

The smoke test must exercise the full gate. Do not use test-codeunit filtering.

## Editing rules

- **Config priority chain is load-bearing.** CLI flag > env var (`ALBT_*`) > `al-build.json` > built-in defaults. Don't reorder; don't add a fifth tier.
- **Outputs are the contract.** `.output/TestResults/last.xml` (JUnit) and `.output/TestResults/telemetry.jsonl`. `/al-debug-logging` reads `telemetry.jsonl`. Don't rename or relocate.
- **Scripts run from the consumer repo root.** Not from this marketplace repo. Keep `Set-Location` discipline; never assume `$PSScriptRoot` is the working dir.
- **PowerShell 7.2+ only.** `#Requires -Version 7.2`. _Avoid_: `powershell.exe` (5.1) — pipeline-chain `&&`/`||` and `??` aren't there.
- **SKILL.md's subagent block is the canonical invocation.** Build output is verbose; the subagent contains it. Keep that block accurate.
- **Container recovery is restart → delete → re-run.** Never document a manual fix path inside the container.
