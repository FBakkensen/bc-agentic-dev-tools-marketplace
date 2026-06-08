# Breaking-change detection in al-build — spec

Make "did this change break a previously-released public API?" a normal outcome of the build, not a separate script a dev remembers to run.

## Decision in one line

Two mechanisms, split by cost: **A** (compile-time AppSourceCop) runs in every gate for free; **B** (`Run-AlValidation`) stays a standalone heavyweight check for feature-end / CI. Provision owns the one baseline fetch.

## Mechanism A — compile-time, in every gate

- AppSourceCop is already in the analyzer set. Activating breaking-change detection = `version` set in `AppSourceCop.json` + the previous release `.app` (and its deps) in `baselinePackageCachePath`.
- A breaking change then surfaces as a normal `AS00xx` diagnostic inside the existing `Invoke-ALBuild` step — `-UnitTestOnly` included (line 179 compiles the main app unconditionally).
- **No special handling.** `AS00xx` is a compile diagnostic like any other (`AA`/`AW`/`DC`/…). `AS0001–AS0018` default to **Error** → they block the build. The user tunes severity via `al.ruleset.json`. No distinct verdict slot, no `summary.json` change, no `AS`-prefix scanner. The rule ID *is* the distinct signal.
- Honesty falls out free: no `version` → detection cleanly off (R3, no false green); `version` set but cache empty → `AS0003`/`AS0091` error, loud and named (R4).

## Mechanism B — standalone heavyweight check

- `validate-breaking-changes.ps1` kept (not deleted), re-scoped: the broader AppSource sim (per-country, install/upgrade) that A's compile pass can't do.
- **Reads the provisioned cache; does not download.** Old lines 94–163 (the `gh release` + dependency-probing fetch) move into provision. B keeps only the `AppSourceCop.json` affix/country reads + `Run-AlValidation`.
- Empty cache → **fail loud**: "baseline cache empty → run provision.ps1" (`Exit.Contract`), never the current silent `exit 0`. Same shape as `test.ps1`'s missing-symbols stop.
- Exit codes unchanged (`Analysis 3` / `Contract 4` / `MissingTool 6`). B never enters `test.ps1`, so nothing to unify.

## Provision — sole baseline owner

- New `download-baseline.ps1`, mirrors `download-symbols.ps1` (a sub-script provision invokes), gated by the config key:
  - `gh release view` (no `--repo` — resolves the repo's own remote host automatically; works on GHE; only needs auth to that host).
  - `Get-ReleaseAppFiles` for previous app + every dependency-probing-path dep (those *do* pass explicit `--repo <host>/<owner>/<repo>`) → `baselinePackageCachePath`.
  - Writes `version` into `AppSourceCop.json`. Because version + cache come from the same fetch, `AS0003` (version-not-in-cache) is structurally impossible.
  - No release exists → omit `version`, leave cache empty → A and B both cleanly off.
- Provision's identity shifts from "one-time machine setup" → "per-feature freshness refresh" (it already re-fetches symbols every run; baseline advances per release). Update SKILL.md / README / CLAUDE.md in lockstep.

## Config

| Setting | Decision |
|---|---|
| `breakingChange.enabled` | New key, **default `false`**. On → provision fetches baseline + writes `version`; B may run. Off → nothing happens. |
| `validateCurrent` (existing, broken) | Fix only: replace `-eq "1"` with `ConvertTo-Boolean` (the helper `WarnAsError` already uses). It's a `Run-AlValidation` param, not the enable switch — keep separate. |
| `baselinePackageCachePath` | Fixed convention under `.output/` (already gitignored). Path string committed in `AppSourceCop.json`; folder contents ignored. |

## Out of scope (parked)

- `/al-scope` generating an **initial provision task** (T-001 setup) and a **final validate-breaking-changes task** (last task) — together bracketing the feature. No `al-scope/SKILL.md` edit now. Note: a provision/infra task is a new non-behavioural task category for `/al-scope`, to reconcile when de-parked.

## Live smoke (GTM-BC-9AAdvMan-ItemConfigurator, GHE repo)

End-to-end verified against a real GHE consumer repo:

- `download-baseline.ps1` + `provision.ps1` step 5 — fetched release `27.9.0` from `9altitudes.ghe.com` (no `--repo`, auto-host), derived version `27.9.556.0` from the `.app` filename (tag `27.9.0` would have been wrong → filename-first vindicated), pulled the GHE dependency `License 27.0.30.0`, wrote `version` + `baselinePackageCachePath` into `AppSourceCop.json` without corrupting the single-element arrays, cache flat + gitignored.
- Mechanism A compile resolution — **no `AS0003`/`AS0091`**: AppSourceCop found the baseline + dep at `../.output/baseline-cache` and reported breaking changes, red gate under `warnAsError`. The load-bearing path-resolution assumption holds.

### Baseline symbol closure (the false-positive fix)

First smoke run flooded with `changed from '__MissingTypeSymbol__'` diagnostics: the baseline cache held the app + AL-Go deps but **not** the Microsoft platform/base/system symbols the baseline references, so AppSourceCop could not resolve base types (`Item`, standard enums) on the baseline side and reported every reference as a change. `AS0091` did not catch it — the Microsoft closure is pulled via `application`/`platform`, not the baseline's explicit `dependencies`.

Fix: `download-baseline.ps1` also copies the resolved `Microsoft.*.app` symbols from the project's build symbol cache (`Get-SymbolCacheInfo`) into the baseline cache. They are the current platform version, not the baseline's — but base type identities are stable across minors, and resolving *both* sides against the same Microsoft symbols isolates the diff to the app's own schema changes. Re-smoke: `__MissingTypeSymbol__` dropped to **0**, leaving **5 genuine breaks** (`AS0035` ×2, `AS0040` ×2, `AS0086`). Trustworthy signal.

## What the brief wanted that we rejected

- B wired into `test.ps1` / a `test.ps1` flag → **no.** B never touches the gate; A is the in-gate detector.
- Distinct `breakingChanges` verdict block in `summary.json` + worker contract change → **no.** `AS00xx` is a plain compile diagnostic.
- Unified exit-code story across both scripts → **moot.** A rides the compile, B stays standalone.
