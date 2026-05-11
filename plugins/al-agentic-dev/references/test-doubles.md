# AL Test Doubles

Five kinds (Meszaros). Use the simplest kind that makes the test pass. Cited by `/al-implement` and `LANGUAGE.md`'s doubles entries.

## Taxonomy

| Kind | What it does | When to use |
|---|---|---|
| **Dummy** | Satisfies the interface parameter; no state, no behavior | Test doesn't exercise that dependency path at all |
| **Stub** | Returns pre-configured fixed data | Controlling what the SUT "sees" without real logic |
| **Fake** | Simplified but working implementation | Test needs real-behaving dependency without real cost |
| **Spy** | Records whether it was called; post-hoc assertion | Asserting an execution path without inspecting return data |
| **Mock** | Combines stub + spy; verifies call contracts | Asserting interaction patterns (call count, order, args) |

Default for environment-interface seams (`IEnvironment`, `IApiRequest`, `IFinance`-family): **Stub**. See `environment-interfaces.md`.

## AL Code Shapes

### Dummy
```al
codeunit 50100 "Dummy IConverter" implements "IConverter"
{
    procedure Convert(Amount: Decimal; CurrencyCode: Code[10]; AtDate: Date): Decimal
    begin
        // intentionally empty, test does not exercise this path
    end;
}
```

### Stub, setup-then-return
```al
codeunit 50100 "Stub IConverter" implements "IConverter"
{
    var ReturnAmount: Decimal;

    internal procedure SetAmount(Value: Decimal)
    begin
        ReturnAmount := Value;
    end;

    procedure Convert(Amount: Decimal; CurrencyCode: Code[10]; AtDate: Date): Decimal
    begin
        exit(ReturnAmount);
    end;
}
```
Call `SetAmount()` before the SUT call; `Convert()` returns the configured value.

### Spy
```al
codeunit 50100 "Spy IConverter" implements "IConverter"
{
    var Invoked: Boolean;

    procedure Convert(Amount: Decimal; CurrencyCode: Code[10]; AtDate: Date): Decimal
    begin
        Invoked := true;
    end;

    internal procedure IsInvoked(): Boolean
    begin
        exit(Invoked);
    end;
}
```

### Mock (Stub + Spy combined)
```al
codeunit 50100 "Mock IPurchInvEdit" implements "IPurchInvEdit"
{
    var Modified: Boolean;
    var HasEntry: Boolean;

    internal procedure IsModified(): Boolean begin exit(Modified); end;
    internal procedure SetHasEntry(Value: Boolean) begin HasEntry := Value; end;

    procedure ModifyHeader(var Hdr: Record "Purch. Inv. Header") begin Modified := true; end;
    procedure GetEntry(var Entry: Record "Vendor Ledger Entry"): Boolean begin exit(HasEntry); end;
    procedure FindHeader(var Hdr: Record "Purch. Inv. Header") begin end; // no-op
}
```

## Naming Convention

File prefix signals the kind: `Stub`, `Spy`, `Mock`, `Dummy`. Apply your AppSource prefix when shipping.

Examples (prefix dropped for clarity):
- `StubIConverter.Codeunit.al`
- `SpyILogger.Codeunit.al`
- `MockIPurchInvEdit.Codeunit.al`

All test doubles live in the unit test app, never in the production app. Location rule (co-located vs `Stubs/` folder) depends on where the interface is defined, see `environment-interfaces.md`.

## Common mistakes

- Using Mock when Stub is enough, mocks without call assertions are just stubs with extra fields.
- Using Spy when you only need the return value, a Stub is simpler.
- Calling any test double a "mock" regardless of kind, name the kind exactly.
