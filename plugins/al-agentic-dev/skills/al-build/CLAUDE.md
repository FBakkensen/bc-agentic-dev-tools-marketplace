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
2. `provision.ps1` — per-feature freshness refresh (compiler, symbols, ALCops, and the breaking-change baseline when enabled). Reuses an installed compiler by default; `-UpdateCompiler` is explicit. It already re-fetches symbols every run; owning the baseline (which advances per release) makes the per-feature re-run the norm, not one-time machine setup.
3. `test.ps1` — the gate. Writes per-run result XML (`last.xml` container, `al-runner.xml` AL Runner) and `telemetry.jsonl` plus `summary.json`.

### Breaking-change baseline

`download-baseline.ps1` is the **sole baseline fetcher**, invoked by `provision.ps1` when `breakingChange.enabled`. It caches the latest release `.app` + AL-Go deps (flat) under `baselinePackageCachePath` and writes `version` + `baselinePackageCachePath` into `app/AppSourceCop.json` from the *same* fetch → `AS0003` (version-not-in-cache) is structurally impossible. `validate-breaking-changes.ps1` (heavyweight `Run-AlValidation`) **reads** that cache, never downloads, and fails loud on an empty cache. The compile-time path needs no script — AppSourceCop reports `AS00xx` during `Invoke-ALBuild` once `version` + cache are set.

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
9. Verify `.output/TestResults/summary.json` lists all test runs (`runs[]` with `runner`, `passed`, `counts`) with expected pass/fail when the full gate reaches result emission.
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

## Smoke test: analyzers

Use after changing `Install-ALCops`, `Get-EnabledAnalyzerPath`, `Select-CompilerCandidate`, or the analyzer wiring in `Invoke-ALBuild`. Container-free: analyzers act at `alc` time on the host; Docker is never involved.

The oracle is seeded violations — one per diagnostic family, all ten prefixes must surface in the compile output (`AA` `AW` `AS` `PTE` `AC` `DC` `FC` `LC` `PC` `TA`). "Compile exits 0 with `/analyzer:` args" is a weak oracle: alc can fail to load one DLL, warn, and still compile green. A diagnostic per family is the evidence each DLL loaded *and* executed.

1. Same scaffolding as the standard smoke: capture `$marketplace`, disposable dir, `git init`, branch `smoke-analyzers`, empty commit.
2. Minimal `app/` (idRange 50000-50149) and a unit-test app (idRange 50150-50199, depends on the main app, configured as `unitTestApp` in `al-build.json`). The main `app.json` needs `"application"` and `"features": ["TranslationFile"]` — without them AppSourceCop aborts the build with AS0100/AS0015 before any seed surfaces.
3. `AppSourceCop.json` in the main app: `{"mandatoryAffixes": ["SMK"]}` only. No `name`/`publisher`/`version` keys — those activate baseline comparison and fire AS0003.
4. Repo-root `.vscode/settings.json`, official AL notation only: `${CodeCop}`, `${UICop}`, `${AppSourceCop}`, `${PerTenantExtensionCop}`, six `${analyzerFolder}ALCops.*.dll` entries plus `${analyzerFolder}ALCops.Common.dll`.
5. Repo-root `al.ruleset.json`: downgrade `AS0011` + `PTE0008` (Error→Warning, else the build aborts before warnings print) and escalate `AC0014`, `DC0001`, `TA0001` (Info→Warning, else invisible). `warnAsError: false` in `al-build.json`.
6. Seed one violation per family. The proven set (v0.8.6; severities read from tagged `DiagnosticDescriptors.cs`, which overrules the alcops.dev rule tables when they disagree):

| Family | Rule | Seed |
|---|---|---|
| AA | AA0008 | parameterless call without `()` |
| AW | AW0008 | `repeater` on a Card page |
| AS | AS0011 | object name without the SMK affix (empty codeunit) |
| PTE | PTE0008 | action without `ApplicationArea` on a table-free page named with the affix |
| AC | AC0014 | `ToolTip` not ending with a dot (table field; `InherentPermissions = RIMD` keeps AC0010 quiet) |
| DC | DC0001 | `Commit()` without a `//` comment (local procedure keeps DC0004 quiet) |
| FC | FC0001 | `procedure Foo();` — trailing semicolon with a `begin end` body |
| LC | LC0003 | `Customer: Record 18;` — numeric object reference |
| PC | PC0001 | FlowField without `Editable = false` |
| TA | TA0001 | global non-`[Test]` procedure in a `Subtype = Test` codeunit — **in the main app**: `-UnitTestOnly` never runs `Invoke-ALBuild` on the unit-test app (AL Runner compiles it internally, without `/analyzer:` args), so a test-app seed can't surface |

7. `pwsh "$marketplace/plugins/al-agentic-dev/skills/al-build/scripts/provision.ps1"` → expect exit 0, the seven `ALCops.*.dll` files in the compiler's `Analyzers` folder, and no `BusinessCentral.LinterCop.dll` (provision deletes the legacy DLL — shared diagnostic IDs, the two must never co-load).
8. `pwsh "$marketplace/plugins/al-agentic-dev/skills/al-build/scripts/test.ps1" -UnitTestOnly`, full output captured → assert every one of the ten prefixes appears as a diagnostic.
9. A seed that will not fire is a switch-the-rule signal, not a tune-harder signal — the smoke proves the *prefix family*, not any specific rule ID. ALCops is pre-1.0; rule IDs and default severities churn between releases.
10. Failure-mode check (fail-loud contract): remove one ALCops DLL from the Analyzers folder, re-run the gate, expect the build to throw naming the unresolvable analyzer — never a green compile with reduced coverage. Re-run provision to restore.
11. Per-app config check: drop a reduced `app/.vscode/settings.json` (e.g. only `${CodeCop}` + `${analyzerFolder}ALCops.LinterCop.dll`), re-run, expect exactly those families and nothing else; delete it after. App-local settings win over the repo-root fallback. Note the asymmetry: the main app and each test app resolve analyzers from their own `.vscode/settings.json`, but in `-UnitTestOnly` mode the unit-test app is never analyzed at all — test-app analyzer config only takes effect in the full container gate.
12. Cleanup: delete the temp dir. No container to remove.

## Editing rules

- **Config priority chain is load-bearing.** CLI flag > env var (`ALBT_*`) > `al-build.json` > built-in defaults. Don't reorder; don't add a fifth tier.
- **`provision.ps1` is the only script allowed to write consumer source.** It writes `version` + `baselinePackageCachePath` into `app/AppSourceCop.json` (via `download-baseline.ps1`). The gate worker (`test.ps1`, delegated, runs constantly) stays read-only on source — never give it a source-mutating step. AppSourceCop edits use a PSCustomObject read-modify-write (preserves key order → stable diffs); the `version`/`baselinePackageCachePath` keys are provision-owned, the rest (affixes, countries) are the dev's.
- **`validateCurrent` is a `Run-AlValidation` param, not the enable switch.** `breakingChange.enabled` gates the feature. Resolve `validateCurrent` through `ConvertTo-Boolean`, never `-eq "1"` — the env round-trip stringifies the JSON boolean (`true` → `"True"`), so a string compare reads false silently.
- **Outputs are the contract.** `.output/TestResults/<dirName>/last.xml` (container, JUnit), `.output/TestResults/<dirName>/al-runner.xml` (AL Runner, JUnit), `.output/TestResults/<dirName>/telemetry.jsonl`, and `.output/TestResults/summary.json` (`gate` + per-runner `totals` + `runs[]` with `counts`). `/al-debug-logging` reads `telemetry.jsonl` from subfolders. Don't rename or relocate.
- **Both result XMLs are deliberately JUnit, one parser.** `Invoke-ALTest` passes `JUnitResultFileName` (not `XUnitResultFileName` — BcContainerHelper supports both, the XUnit dialect differs down to the failure element); AL Runner's `--output-junit` is also JUnit. `Get-JUnitTestCounts` parses both; counts are never derived from console lines (the `Codeunit … Success` stream lines are test codeunits, not tests). Missing/unparseable XML → `counts: null`, never zeros.
- **Scripts run from the consumer repo root.** Not from this marketplace repo. Keep `Set-Location` discipline; never assume `$PSScriptRoot` is the working dir.
- **PowerShell 7.2+ only.** `#Requires -Version 7.2`. _Avoid_: `powershell.exe` (5.1) — pipeline-chain `&&`/`||` and `??` aren't there.
- **SKILL.md's subagent block is the canonical invocation.** Build output is verbose; the subagent contains it. Keep that block accurate.
- **Container recovery is restart → delete → re-run.** Never document a manual fix path inside the container.
- **AL Runner is a fast gate, not a replacement for container tests.** `Invoke-ALRunnerTest` runs before the container and lands as a first-class `runner: al-runner` record in `summary.json` in every mode, writing `al-runner.xml` so the container's `last.xml` never overwrites it. The unit test app legitimately appears twice in a full gate (al-runner + container) — that's why `totals` aggregate per runner and never across.
- **AL Runner installation follows the compiler pattern.** `Install-ALRunner` mirrors `Install-ALCompiler` — global dotnet tool, guarded by `Get-Command`, skip when `unitTestApp` is not configured.
