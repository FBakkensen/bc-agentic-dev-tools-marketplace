# AL Decoupling

Three-phase legacy refactor for AL/Business Central code that mixes DB calls with decisions. Cited by `/al-design`, `/al-implement`, `/al-refactor`. Apply when production code resists unit testing because reads, decisions, and writes share one procedure.

## When to apply

Any procedure that mixes a DB call with a decision is a decoupling target:

```al
// BEFORE — untestable: decision + DB read in the same procedure
if VendorLedgerEntry.Get(PurchInvHeader."Vendor Ledger Entry No.") then
    VendorLedgerEntry.Validate("Payment Reference", Rec."Payment Reference");
```

The `if ... Get() then Validate()` pattern cannot be unit-tested without a real database. Phase 1 extracts it.

## Three-Phase Decoupling

### Phase 1 — Extract internal procedures

Split every distinct responsibility into `internal procedure` methods. Each does exactly one thing:
- `Find*` — read from DB (no decisions)
- `Edit*` — pure field assignments (no DB calls)
- `Modify*` — write to DB (no decisions)
- External-call wrappers — one per external dependency

```al
internal procedure FindPurchInvHeader(var PurchInvHeader: Record "Purch. Inv. Header";
    FromPurchInvHeader: Record "Purch. Inv. Header")
begin
    PurchInvHeader.Copy(FromPurchInvHeader);
    PurchInvHeader.ReadIsolation(IsolationLevel::UpdLock);
    PurchInvHeader.Find();
end;
```

### Phase 2 — Extract interface

Declare `Access = Internal` interface containing only procedures you want to inject in tests:

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

### Phase 3 — Inject via overload (self-injection, zero breaking changes)

The production codeunit implements its own interface. `OnRun()` passes `This` (self) — all existing `Codeunit.Run()` callsites are untouched:

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

For public-facing procedures without `OnRun`, add a separate `internal` overload accepting the interface:

```al
// Public entry point — backward-compatible, no callers change
procedure GetItemPrice(ItemNo: Code[20]): Decimal
var
    Converter: Codeunit "App Converter";
begin
    // reads Item, UserSetup, etc., then delegates
    exit(GetItemPrice(Item."Unit Price", UserSetup."Currency Code", Converter));
end;

// Testable overload — interface injected, no DB reads
internal procedure GetItemPrice(UnitPrice: Decimal; CurrencyCode: Code[10];
    Converter: Interface "IConverter"): Decimal
begin
    if CurrencyCode = '' then exit(UnitPrice);
    exit(Converter.Convert(UnitPrice, CurrencyCode, WorkDate()));
end;
```

## Interfaces over Handled events

The "Handled" event pattern (`IsHandled: Boolean` by reference) is an extensibility tool, not a testability tool.

- **Use interfaces** when the goal is testability — inject a stub per test call.
- **Use events** when the goal is extensibility across apps — external ISVs subscribe.

An event subscriber in a test app fires globally and cannot be selectively injected per test. An interface parameter is injected per call. Use the right tool.

## A well-decoupled unit test needs zero `Library*` calls

If a test needs `Library - Sales`, `Library - ERM`, or any project `Lib*` factory to prepare its SUT, the production code is still coupled to BC infrastructure. Assign fields directly in the test:

```al
PurchInvHeader."Payment Reference" := 'REF-001';
// no Insert(), no Library call required
```

Database operations belong at the top level of the call stack. Codeunits below receive `var TempRecord: Record X temporary` — they never call the database themselves.
