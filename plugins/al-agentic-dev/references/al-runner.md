# AL Runner

Fast pre-check for AL unit tests. Transpiles AL to C# in-memory and runs against in-memory mocks of BC runtime types — no BC service tier, no Docker, no SQL. Cited by `/al-implement` and `/al-mutate` for Pure-layer gating; cited by `tdd-cycle.md` and `mutation-operators.md` for `-UnitTestOnly` invocation.

Upstream: `https://github.com/StefanMaron/BusinessCentral.AL.Runner`. Coverage map: `docs/coverage.yaml`. Limitations: `docs/limitations.md`.

## What AL Runner is

A standalone test executor that compiles AL source to C# via the BC compiler's public API, rewrites BC runtime types to in-memory mocks, and executes test codeunits in milliseconds. Wrapped by `/al-build -UnitTestOnly` when `unitTestApp` is configured in `al-build.json`.

AL Runner runs **before** the full BC pipeline as a fast pre-check, **not in place of it**. The full pipeline (BcContainerHelper / on-Linux) remains the fidelity gate before merge.

```
Pull Request
  ↓
al-runner (seconds)            ← catches AL logic failures fast
  ↓ (only if al-runner passes)
Full BC pipeline (45+ min)     ← full fidelity
```

## Three pipeline outcomes

| Outcome | Meaning | Exit code |
|---|---|---|
| **PASS** | Codeunit's direct logic is correct | `0` |
| **FAIL** | Assertion failed or test threw — real failure | `1` |
| **ERROR** | Codeunit reaches for an unsupported runner feature — configuration issue, not test failure | `2` (use `--strict` to promote to `1`) |
| *(compile)* | AL compilation error | `3` |

**The guarantee:** if al-runner says FAIL, it is a real failure. Silent passes due to missing event subscriber side-effects are an accepted known limitation — always run the full pipeline after al-runner.

## What's supported

- **Core language**: variables, procedures (by-value and by-ref), expressions, control flow, asserterror, error handling, enums, interfaces, arrays, `List`, `Dictionary`, `TextBuilder`, temporary tables.
- **Record operations**: `Insert` / `Modify` / `Delete` / `Get` / `Find` / `FindSet` / `FindFirst` / `FindLast` / `Next` / `SetRange` / `SetFilter` / `SetCurrentKey` / `CalcFields` / `CalcSums` / `Init` / `Validate` / `Copy` / `TransferFields`, field triggers, composite primary keys, secondary keys with sorting.
- **Cross-codeunit dispatch**: codeunit-to-codeunit calls, interface dispatch, manual and integration event subscribers. With `--init-events`, BC lifecycle events (`OnCompanyInitialize`, `OnInstallAppPerCompany`) fire **once** at startup; the resulting DB state is snapshotted as the baseline for every test.
- **Mock subsystems**: `RecordRef` / `FieldRef`, `TestPage`, `Notification`, `BigText`, JSON types, `HttpClient` (mock responses), BLOB / `InStream` / `OutStream`, `Media`, `Image` (real PNG/JPEG/GIF/BMP header parse, real pixel dimensions), `File`, `IsolatedStorage`, `TaskScheduler`, `DataTransfer`.
- **Single-dataitem queries**: `Open` / `Read` / `Close`, `SetFilter`, `SetRange`, `TopNumberOfRows`.
- **Report triggers**: `OnPreReport`, `OnPreDataItem`, `OnAfterGetRecord`, `OnPostDataItem`, `OnPostReport`.

## Built-in test toolkit

Auto-loaded — no stubs needed:

| Codeunit | ID | Purpose |
|---|---|---|
| `Library Assert` | 130 / 130002 | `AreEqual`, `IsTrue`, `IsFalse`, `ExpectedError` |
| `Library - Variable Storage` | 131004 | `Enqueue` / `Dequeue` for handler communication |
| `Any` | 130500 | Random test data (`IntegerInRange`, `AlphanumericText`, `GuidValue`) |
| `Library - Random` | 130440 | Pseudo-random numbers, dates, text |
| `Library - Utility` | 131003 | `GenerateGUID`, `GenerateRandomCode`, `GenerateRandomText` |
| `Library - Test Initialize` | 132250 | Integration events for test setup hooks |

## What's not supported (and how to work around)

| Limitation | Workaround |
|---|---|
| Code inside `.app` packages does not execute | Auto-stubbed (returns defaults). Provide controlled stubs via `--stubs`, or compile dependency AL to a rewritten DLL via `--compile-dep`. |
| `Commit()` / `Rollback()` are no-ops | None at runner layer — assert state, not commit boundaries. |
| `StartSession` runs inline | None — design tests to assume serial execution. |
| No UI rendering — page layout, field visibility, report rendering | Test the underlying procedures directly. |
| Multi-dataitem queries — JOINs, aggregation | Single-dataitem queries work; restructure or move to E2E. |
| `HttpClient.Send()` throws | Inject via AL interface — see `environment-interfaces.md` `IApiRequest`. |
| `XmlPort.Import()` / `Export()` throw | XmlPort variables compile and surrounding logic runs; move I/O to E2E. |

If AL code fails for a reason not in `docs/limitations.md`, that is a runner gap — report upstream.

## ERROR / exit 2 resolution

When a Pure-tagged bullet returns ERROR (exit 2) under `/al-build -UnitTestOnly`, work through these in order — cheapest first:

1. **Review the test.** Was the test reaching for an unsupported feature unnecessarily (`HttpClient.Send` directly, multi-dataitem query, `Commit()`-dependent assertion)? Adjust the test to exercise the same behaviour without the unsupported feature.
2. **Refactor production.** Extract a seam via `decoupling.md` (three-phase) so the test can inject a stub. The unsupported call moves behind the seam; the SUT becomes a unit-runnable shape.
3. **Reclassify the bullet as E2E.** The bullet fundamentally needs a container (multi-dataitem query, real `XmlPort` import, real `Commit()` / `Rollback()` semantics). Move the test to a container test app. Last resort.

## Testability pattern

Inject dependencies via AL interfaces. Anything that can't be injected can't be unit-tested by the runner — and that's the right boundary.

```al
interface "IInventoryCheck"
    procedure HasStock(ItemNo: Code[20]): Boolean;
end

codeunit 50100 "Order Processor"
    procedure Process(ItemNo: Code[20]; Checker: Interface "IInventoryCheck")
    begin
        if not Checker.HasStock(ItemNo) then
            Error('Item %1 is out of stock', ItemNo);
    end;
end
```

Greenfield: `environment-interfaces.md` for the three default seams. Legacy: `decoupling.md` for the three-phase extract.

## Pipeline ordering

`/al-build -UnitTestOnly` (al-runner) runs first; full `/al-build` runs second. The runner shrinks the inner loop to seconds; the container guarantees fidelity at the gate. Both are required — neither replaces the other.
