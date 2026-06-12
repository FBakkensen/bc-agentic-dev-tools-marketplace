# Test layout — two peer test apps

Where a test lives and what a test app looks like. Sits alongside `test-strategy.md` (the execution pyramid — *why* layers exist), `tdd.md` (the red-green *cycle*), and `testability.md` (seams and doubles); this file owns the *placement* axis and the authoring contract of the test apps themselves. Cited by `/al-scope`, `/al-refine`, `/al-implement`, `/al-refactor`.

Read-only. Read in place via `${CLAUDE_SKILL_DIR}/../../references/test-layout.md`.

## The layout

```
app/                  production app
unit-tests/           AL Runner-runnable tests — fast pre-gate, no container
integration-tests/    container-only tests — the authoritative gate
```

`unit-tests` and `integration-tests` are **peer apps — no dependency edge between them**. Both depend on the production app. A production seam (interface in the production app) is doubled **independently in each test app** (`Stubs/<InterfaceName>/`, `Spies/<InterfaceName>/`): the two doubles implement the same interface but belong to different runtimes (AL Runner vs container), so they are not duplicates and must not be shared. Double kinds and the stub-location rule live in [testability.md](testability.md).

`/al-build` wires the split: AL Runner runs `unit-tests/` only (the `unitTestApp` config entry); the container gate compiles and tests both apps. The container remains authoritative; AL Runner is the fast pre-check that makes red-first cycles cheap.

## Placement rule

A test belongs in `unit-tests/` **iff every codepath it traverses is runnable by AL Runner**. The split is mechanical, not aspirational — AL Runner can run the test, or it can't. Decide before writing the first line. A test that drifts into needing real BaseApp codeunit behaviour is an integration test: **reclassify it — never relax the unit contract** to keep it.

The boundary in practice:

- **Inserting into BaseApp tables** (`Sales Header`, `Item`, `Customer`, …) is fine. AL Runner has an in-memory table store and handles any table resolvable from the symbol packages. Tables are data shapes; AL Runner cares about *code*.
- **Depending on a BaseApp codeunit's behaviour** is not fine — `.app` package code auto-stubs. `Codeunit::"Sales-Post".Run()` executes as a no-op; `ConfirmManagement.GetResponseOrDefault()` returns `false`. A test that needs the real behaviour is an integration test.
- **Reading BaseApp tables your test populated** is fine. **Reading BaseApp tables that real BaseApp codeunits populate during execution** (ledger entries from posting, lines from validation) is not — those codeunits never ran.
- **`Commit()` mid-test** is a no-op under AL Runner. If the commit must be observable (`asserterror` after a real `Commit`, post-commit state), the test is integration.
- FlowFields are fine — `CalcFields` evaluates against tables in scope, so asserting on a FlowField over rows the test inserted inline is a unit-test pattern.

## AL Runner capability map

[AL Runner](https://github.com/StefanMaron/BusinessCentral.AL.Runner) transpiles AL source to C# and executes it in-memory — no service tier, no Docker, no SQL Server. Field-verified as of June 2026; the boundary moves with the tool, so when a claim here contradicts an observed run, re-derive against the current release rather than assuming either side.

**Runs:** all `.al` source in scope — tables, codeunits, enums, interfaces, queries, page extensions (business logic), report triggers. All record operations (`Insert`, `Modify`, `Delete`, `Get`, `Find*`, `SetRange`, `SetFilter`, `Validate`, `Copy`, `TransferFields`, `CalcFields`, `CalcSums`), composite and secondary keys, field triggers. Cross-codeunit dispatch, interface dispatch, event subscribers. Mocked subsystems: TestPage, Notification, BigText, JSON, BLOB streams, File, IsolatedStorage, TaskScheduler, DataTransfer, single-dataitem queries.

**Auto-stubs** (compile and link, execute as no-ops returning `0` / `''` / `false`): everything inside `.app` package dependencies — BaseApp codeunits, BaseApp test libraries (`Library - Sales`, `Library - Inventory`, `Library - ERM`, …), and any project test-library app.

**Throws or skips:** real `HttpClient.Send()` (throws — inject via an AL interface), XmlPort `Import`/`Export` (throw), multi-dataitem queries with JOINs, real `Commit()`/`Rollback()` semantics (no-ops — transaction boundaries don't exist), `StartSession` (runs inline synchronous). UI rendering — page layout, field visibility, report rendering — is never evaluated.

**Auto-loaded test toolkit** (no stubs needed): `Library Assert`, `Library - Variable Storage`, `Any`, `Library - Random`, `Library - Utility`, `Library - Test Initialize`.

Forbidden dependencies in `unit-tests/` follow directly: no BaseApp codeunits whose behaviour the test depends on, no BaseApp or project test-library calls (they auto-stub — and per [testability.md](testability.md), a unit test that *wants* a `Library*` factory is a decoupling smell anyway), no real HTTP, no XmlPort I/O, no JOIN queries, no reliance on commit semantics.

Speed is the point of the tier: target well under a second per test so the whole unit suite runs in seconds, keeping the red-first inner loop instant.

## Container isolation semantics

The container gate runs both test apps under a test-runner codeunit declared `TestIsolation = Codeunit;` — per the [TestIsolation property](https://learn.microsoft.com/dynamics365/business-central/dev-itpro/developer/properties/devenv-testisolation-property), all changes roll back **after each test codeunit**, not after each method. Consequences:

- All `[Test]` methods in one codeunit share one transaction. **Per-test isolation is your job** — `Initialize()` resets state (typically `DeleteAll()` on every table the codeunit writes), called as the first statement of every `[Test]`.
- Cross-codeunit bleed is impossible: codeunit-end rollback restores prior state, including changes committed via `Commit()`.

AL Runner has no test-runner-codeunit concept (`Commit`/`Rollback` are no-ops there). The explicit per-test reset is what makes a test **portable between AL Runner and the container** — never lean on runner-specific isolation.

### TransactionModel

Default (no attribute) is `AutoRollback`. Add `[TransactionModel(TransactionModel::AutoCommit)]` only when the code under test calls `Commit()` explicitly — required for most integration tests that drive posting flows. Without it the production `Commit()` fails and every side effect (ledger entries, status changes) silently vanishes: **the test greens while testing nothing**. That false-pass is why the attribute sits on the no-touch list in [tdd.md](tdd.md). When adding it, a comment names which `Commit()` call it covers, so a later reader can tell deliberate from cargo-culted.

## Authoring contract

What every test codeunit in either app carries, and why:

- **Attributes, mandatory:** `Subtype = Test;` (without it the codeunit is not callable as a test), `TestPermissions = Disabled;` (permission checks under the test-runner principal fail otherwise), `Access = Internal;` (prevents accidental production dependency on test code).
- **`Initialize()` guard:** the `if IsInitialized then exit;` pattern for one-time setup, plus per-test state reset; every `[Test]` calls it as its first statement. Load-bearing even when it looks redundant — it is the only thing standing between you and test-order dependence (see the no-touch list in [tdd.md](tdd.md)).
- **Handlers live on the test codeunit itself**, never in a shared handlers codeunit — `[HandlerFunctions('…')]` binds by string literal, and a shared home turns every handler rename into a cross-file runtime failure.
- **Assertions:** `Library Assert` only — never `Error()`, `Message()`, or custom guards. For computed decimals where `Round()` leaves a residual, `Assert.AreNearlyEqual(Expected, Actual, 0.01, Msg)`; `Assert.AreEqual` for exact values only.
- **Naming:** the codeunit is named for the feature or scenario it proves; no tier infix (`Unit`, `Intg`) — the app already says the tier.

### Integration-test libraries

Setup helpers in `integration-tests/` follow a deliberately anti-DRY discipline, because shared test plumbing is where suites rot:

- **One focused library codeunit per test codeunit**, co-located in the same folder. No library serves two test codeunits — **duplicate the procedure before sharing it**. Shared setup couples unrelated scenarios; an edit for one silently reshapes the other's fixture.
- A single shared base library may exist, carrying **only setup used by virtually every test** (company, posting periods, basic ledger). Anything narrower lives in the per-test library.
- **Libraries are stateless** — no global variables, no `OnRun` state. **No assertions in libraries** — assertions live on the test codeunit, where the failure message points at the scenario. **No event subscribers in libraries** — a subscriber in shared plumbing fires for every test in the app.

`unit-tests/` needs none of this: each test codeunit owns its setup inline, and a unit test whose arrange phase outgrows inline setup is usually telling you the production seam is missing ([testability.md](testability.md)).
