# al-build

Build/test gate for AL/Business Central. Compile, publish to a local Docker container, run tests, write results to `.output/TestResults/<dirName>/`.

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
3. `test.ps1` — the gate. Writes per-app `last.xml` and `telemetry.jsonl` plus `summary.json`.

## Smoke test

Use this after changing the skill invocation contract, delegation behavior, script contract, or gate behavior.

1. From the marketplace repo working tree, capture its path: `$marketplace = $PWD.Path`. Then create a disposable dir under `$env:TEMP` with a random suffix and `Set-Location` into it — the rest of the smoke test runs from the disposable dir, and `$marketplace` lets you invoke the dev-time scripts.
2. `git init`, `git checkout -b smoke-<scenario>`, then **`git commit --allow-empty -m "init"`**. The branch name becomes the container name via `Get-BCAgentContainerName`. Without a commit the branch lookup fails and falls back to `bctest`, colliding with the golden container. Never use `main` or `bctest` as branch name.
3. Add a minimal AL app under `app/` and one or more test apps under `test/`, `test-integration/`, etc. Test apps must depend on the main app so provisioning proves local deps are not downloaded as symbol packages.
4. Add repo-root `al-build.json` with `appDir` and `testApps` array.
5. Verify the snapshot image from `container.imageName` exists. Do not bootstrap a golden container unless that is the explicit target.
6. Run `pwsh "$marketplace/plugins/al-agentic-dev/skills/al-build/scripts/provision.ps1"` from the disposable repo before invoking the skill. This is mandatory for smoke tests because it installs/verifies the compiler, AL Runner, and symbol caches for the temp app/test app.
7. From the disposable repo, invoke the `al-build` skill as a black-box skill use. Do not tell the smoke session to run `test.ps1` directly, do not restate the subagent contract, and do not describe the model/reasoning/delegation details from `SKILL.md`. The smoke is testing whether the host follows `SKILL.md` by itself.
8. Verify the host spawned the gate worker according to `SKILL.md`, and inspect the worker's returned gate report plus any emitted `.output/TestResults/<dirName>/last.xml` and `telemetry.jsonl` files.
9. Verify `.output/TestResults/summary.json` lists all test apps with expected pass/fail when the full gate reaches result emission.
10. Clean up: `docker rm -f <container-name>`, then delete the temp dir.

The smoke test must exercise the full gate. Do not use test-codeunit filtering. Run container tests sequentially — one branch/container at a time.

Smoke runs must continue past disposable fixture/setup failures. If the failure is in the temp app, temp test app, generated `al-build.json`, disposable git branch, or other smoke scaffolding, repair the fixture in place, rerun provision when symbols/config changed, and invoke the `al-build` skill again until the smoke reaches a real gate execution through the skill. Do not mark the smoke done on the first setup failure. Only conclude after at least one real full-gate execution path has run through the skill's own instructions and its result has been inspected. A disposable fixture/setup error is input to repair and retry; it is not the final smoke result unless the blocker is non-recoverable or outside the disposable fixture.

Smoke prompts must give detailed fixture setup, provision, repair, artifact, and cleanup requirements. They must not give detailed instructions for how `al-build` itself runs the gate. That behavior belongs in `SKILL.md`; the smoke verifies that the skill contract is sufficient.

## Smoke test: golden container with AL-Go dependencies

Use this after changing dependency-install or gh-CLI dispatch in `new-bc-container.ps1`, `Install-AlGoDependencies`, `Get-ReleaseAppFiles`, or `Get-RepoFromUrl`. The standard smoke test above does not exercise `Install-AlGoDependencies` at all.

1. Same setup as the standard smoke test (capture `$marketplace = $PWD.Path` from the marketplace repo working tree, then disposable-dir + branch + commit).
2. Add a minimal `app/` and repo-root `al-build.json`.
3. Add `.AL-Go/settings.json` with `appDependencyProbingPaths` containing:
   - one github.com entry (a small public AL-Go-published repo, version `latest`),
   - one `*.ghe.com` entry (only if you have GHE creds; otherwise omit).
4. Run `gh auth status` to confirm authentication to each host listed.
5. Run `pwsh "$marketplace/plugins/al-build/skills/al-build/scripts/new-bc-container.ps1"`.
6. Expected: each probing-path app downloaded, published, container prepared for commit; script exits 0.

### Failure-mode checks (run each in isolation)

- **Non-existent repo.** Add a probing path pointing at a repo that does not exist on that host. Expect a warning naming the host and the gh exit code, `exit 1` from `new-bc-container.ps1`, container NOT stopped or prepared for commit.
- **GHE auth gap.** `gh auth logout --hostname <tenant>.ghe.com`, then re-run. Expect: github.com entries still install, warning names the GHE host plus the `gh auth login --hostname` fix command, `exit 1`.
- **Unparseable URL.** Set a probing path's `repo` to garbage (`"not a url"`). Expect warning naming the entry, that probing path counted as failed, `exit 1`.

Failure-mode runs validate the fail-loud contract — silent partial-success is the shape of the original GHE-host defect.

## Editing rules

- **Config priority chain is load-bearing.** CLI flag > env var (`ALBT_*`) > `al-build.json` > built-in defaults. Don't reorder; don't add a fifth tier.
- **Outputs are the contract.** `.output/TestResults/<dirName>/last.xml` (JUnit), `.output/TestResults/<dirName>/telemetry.jsonl`, and `.output/TestResults/summary.json`. `/al-debug-logging` reads `telemetry.jsonl` from subfolders. Don't rename or relocate.
- **Scripts run from the consumer repo root.** Not from this marketplace repo. Keep `Set-Location` discipline; never assume `$PSScriptRoot` is the working dir.
- **PowerShell 7.2+ only.** `#Requires -Version 7.2`. _Avoid_: `powershell.exe` (5.1) — pipeline-chain `&&`/`||` and `??` aren't there.
- **SKILL.md's subagent block is the canonical invocation.** Build output is verbose; the subagent contains it. Keep that block accurate.
- **Container recovery is restart → delete → re-run.** Never document a manual fix path inside the container.
- **AL Runner is a fast gate, not a replacement for container tests.** `Invoke-ALRunnerTest` runs before the container; its result does not appear in final `summary.json` during full-mode runs (the container overwrites `last.xml`). In `-UnitTestOnly` mode, it is the only result.
- **AL Runner installation follows the compiler pattern.** `Install-ALRunner` mirrors `Install-ALCompiler` — global dotnet tool, guarded by `Get-Command`, skip when `unitTestApp` is not configured.
