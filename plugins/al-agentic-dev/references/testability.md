# AL Testability

How to make AL/Business Central code unit-testable: three-phase decoupling, three default seams, five kinds of test double. Cited by `/al-design`, `/al-implement`, `/al-refactor`.

Apply when production code resists unit testing because reads, decisions, and writes share one procedure. The signal is `if ... Get() then Validate()` patterns: untestable without a real database.

## Three-phase decoupling

### Phase 1, extract internal procedures

Split each responsibility into one `internal procedure`. `Find*` reads, `Edit*` does pure field assignments, `Modify*` writes, external-call wrappers hold one external dependency each. No decisions in the same procedure as a DB call.

```al
internal procedure FindPurchInvHeader(var PurchInvHeader: Record "Purch. Inv. Header";
    FromPurchInvHeader: Record "Purch. Inv. Header")
begin
    PurchInvHeader.Copy(FromPurchInvHeader);
    PurchInvHeader.ReadIsolation(IsolationLevel::UpdLock);
    PurchInvHeader.Find();
end;
```

### Phase 2, extract interface

Declare `Access = Internal` interface containing only the procedures you want to inject in tests:

```al
interface "IPurchInvEdit"
{
    Access = Internal;
    procedure FindPurchInvHeader(var PurchInvHeader: Record "Purch. Inv. Header";
        FromPurchInvHeader: Record "Purch. Inv. Header");
    procedure EditPurchInvHeader(var PurchInvHeader: Record "Purch. Inv. Header";
        FromPurchInvHeader: Record "Purch. Inv. Header");
    procedure ModifyPurchInvHeader(var PurchInvHeader: Record "Purch. Inv. Header";
        FromPurchInvHeader: Record "Purch. Inv. Header");
}
```

### Phase 3, inject via self-overload (zero breaking changes)

The production codeunit implements its own interface. `OnRun()` passes `This` (self); existing `Codeunit.Run()` callsites stay untouched:

```al
codeunit 50100 "App PurchInvEdit" implements "IPurchInvEdit"
{
    trigger OnRun()
    var
        PurchInvHeader: Record "Purch. Inv. Header";
        This: Codeunit "App PurchInvEdit";
    begin
        DoEditPurchInvHeader(PurchInvHeader, Rec, This);
    end;

    internal procedure DoEditPurchInvHeader(var PurchInvHeader: Record "Purch. Inv. Header";
        var Rec: Record "Purch. Inv. Header"; Edit: Interface "IPurchInvEdit")
    begin
        Edit.FindPurchInvHeader(PurchInvHeader, Rec);
        Edit.EditPurchInvHeader(PurchInvHeader, Rec);
        Edit.ModifyPurchInvHeader(PurchInvHeader, Rec);
    end;
}
```

For public-facing procedures without `OnRun`, add a separate `internal` overload accepting the interface; the public entry point stays backward-compatible while the overload becomes unit-testable.

## Interfaces over Handled events

The "Handled" event pattern (`IsHandled: Boolean` by reference) is an extensibility tool, not a testability tool. Event subscribers in a test app fire globally; you cannot selectively inject per test. Interface parameters inject per call. Use interfaces when the goal is testability, events when the goal is extensibility across apps.

## Zero `Library*` calls in unit tests

A well-decoupled unit test needs no `Library - Sales`, `Library - ERM`, or project `Lib*` factory. If your test calls one to prepare the SUT, the production code is still coupled to BC infrastructure. Assign fields directly:

```al
PurchInvHeader."Payment Reference" := 'REF-001';
// no Insert(), no Library call required
```

Database operations belong at the top of the call stack. Codeunits below receive `var TempRecord: Record X temporary`; they never call the database themselves.

## Three default seams

When the three-phase decoupling refactor declares an interface, it is almost always one of these three categories. Reach for the named pattern first.

| Seam | Interface | Production impl | Stub impl |
|---|---|---|---|
| System environment | `"IEnvironment"` | `"App Environment"` | `"Stub Environment"` |
| External APIs | `"IApiRequest"` | `"App Api Request"` | `"Stub Api Request"` |
| Standard Application | `"IFinance"` (example) | `"App Finance"` | `"Stub Finance"` |

### Naming convention

Interface: `"I<Concept>"`. Production impl: `"App <Concept>"`, ships in the production app. Stub impl: `"Stub <Concept>"`, ships in the unit test app, **never in the production app**. Multiple stub variants: `"Stub <Variant> <Concept>"` (e.g., `"Stub Production Environment"`). Apply your AppSource prefix to every object name when shipping; examples here drop it for clarity.

### Stub location rule

Find the interface's `.Interface.al` file. If the interface lives in the production app, the stub goes in the unit test app's `Stubs/<InterfaceName>/` folder. If the interface lives in the unit test app, the stub co-locates with the test codeunit. No judgment call: the file's location decides.

### IEnvironment

```al
interface "IEnvironment"
{
    procedure SystemEnvironment(): Enum "System Environment"
    procedure ThisCompanyName(): Text[30]
    procedure IsEvaluationCompany(): Boolean
}
```

ApplicationState derivation: Production requires `SystemEnvironment = Production` AND `not IsEvaluationCompany` AND `Licensee = ThisCompanyName`. Test requires only `Licensee = ThisCompanyName`. A company-copy safety subscriber clears `Licensee` on copied companies so they cannot run in Production state.

### IApiRequest, setup-then-return

```al
interface "IApiRequest"
{
    procedure Send(RequestMethod: Enum "Api Method"; RequestUrl: Text; Payload: Text;
        SecretKey: SecretText; var ResponseStatusCode: Integer; var ResponseContent: Text)
}

codeunit 50100 "Stub Api Request" implements "IApiRequest"
{
    var StatusCode: Integer; Content: Text;

    internal procedure SetupResponse(Code: Integer; Body: Text)
    begin StatusCode := Code; Content := Body; end;

    procedure Send(RequestMethod: Enum "Api Method"; RequestUrl: Text; Payload: Text;
        SecretKey: SecretText; var ResponseStatusCode: Integer; var ResponseContent: Text)
    begin ResponseStatusCode := StatusCode; ResponseContent := Content; end;
}
```

Two-step pattern: call `SetupResponse(200, jsonBody)` before the SUT; `Send()` returns the pre-configured values. Test how your code reacts to the response, not whether the API works.

### IFinance (standard application seam)

Hides BaseApp G/L calls: `Gen. Journal Line` `Validate()` and `Insert(true)`, number-series allocation, posting-setup reads. All parameters are `var`; the stub returns data by overwriting the caller's variables (same store/restore pattern as `IApiRequest`). Enables unit tests that assert finance logic without G/L accounts, bank accounts, or posting setup in the database.

### Temporary tables, the cheaper alternative

For logic that only depends on a record's own fields (no external calls), pass `var TempRecord: Record X temporary` instead of declaring an interface. Cheaper than a full interface extraction when the coupling is to a table, not an external system.

```
Does the seam involve...
  ├─ BC runtime / OS environment?    → IEnvironment
  ├─ an external HTTP API?           → IApiRequest
  ├─ standard BC G/L / finance ops?  → IFinance (or IPosting, ISales per seam)
  └─ a record's own data fields?     → var TempRecord (no interface needed)
```

## Five kinds of test double

Meszaros taxonomy. Use the simplest kind that makes the test pass.

| Kind | What it does | When to use |
|---|---|---|
| **Dummy** | Satisfies the interface parameter; no state, no behaviour | Test does not exercise that dependency path |
| **Stub** | Returns pre-configured fixed data | Controlling what the SUT sees without real logic |
| **Fake** | Simplified but working implementation | Test needs real-behaving dependency without real cost |
| **Spy** | Records whether it was called; post-hoc assertion | Asserting an execution path without inspecting return data |
| **Mock** | Combines stub + spy; verifies call contracts | Asserting interaction patterns (call count, order, args) |

Default for the three environment-interface seams above: **Stub**.

### AL code shapes

Dummy:

```al
codeunit 50100 "Dummy IConverter" implements "IConverter"
{
    procedure Convert(Amount: Decimal; CurrencyCode: Code[10]; AtDate: Date): Decimal
    begin
        // intentionally empty, test does not exercise this path
    end;
}
```

Stub (setup-then-return):

```al
codeunit 50100 "Stub IConverter" implements "IConverter"
{
    var ReturnAmount: Decimal;

    internal procedure SetAmount(Value: Decimal) begin ReturnAmount := Value; end;
    procedure Convert(Amount: Decimal; CurrencyCode: Code[10]; AtDate: Date): Decimal
    begin exit(ReturnAmount); end;
}
```

Mock (stub + spy combined):

```al
codeunit 50100 "Mock IPurchInvEdit" implements "IPurchInvEdit"
{
    var Modified: Boolean; var HasEntry: Boolean;

    internal procedure IsModified(): Boolean begin exit(Modified); end;
    internal procedure SetHasEntry(Value: Boolean) begin HasEntry := Value; end;

    procedure ModifyHeader(var Hdr: Record "Purch. Inv. Header") begin Modified := true; end;
    procedure GetEntry(var Entry: Record "Vendor Ledger Entry"): Boolean begin exit(HasEntry); end;
    procedure FindHeader(var Hdr: Record "Purch. Inv. Header") begin end; // no-op
}
```

Spy is a mock without the stub side. Fake is a working implementation (e.g., an in-memory `Customer` repository); rare in BC, but valid when the real dependency is heavy.

### Naming convention

File prefix signals the kind: `Stub`, `Spy`, `Mock`, `Dummy`. Examples (AppSource prefix dropped): `StubIConverter.Codeunit.al`, `SpyILogger.Codeunit.al`, `MockIPurchInvEdit.Codeunit.al`. All test doubles live in the unit test app, never in the production app.

### Common mistakes

- Mock when Stub is enough. Mocks without call assertions are stubs with extra fields.
- Spy when you only need the return value. Use Stub.
- Calling any test double a "mock" regardless of kind. Name the kind exactly.
