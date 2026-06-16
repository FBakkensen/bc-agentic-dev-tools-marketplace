---
task: T-005
status: ready-for-implementation
slice: audit-trail
kind: technical
depends_on: [T-002, T-006]
---
# T-005 — Persist allocation audit entries via Allocation Ledger Entry table

On every successful posting, `Insert` one ledger entry per resolved allocation: source `Sales Line`, receiving `Sales Line`, allocated quantity, `Posting Date`. Audit trail referenced by ADR-0007.

Test Specification:

Acceptance Intent:
Allocation audit entries preserve posting traceability by recording the source and receiving Sales Lines for each posted allocation.

## New and Modified Objects

- New: table `Allocation Ledger Entry`
  - Field: `Entry No.` (Integer)
  - Field: `Document No.` (Code[20])
  - Field: `Source Sales Line No.` (Integer)
  - Field: `Receiving Sales Line No.` (Integer)
  - Field: `Allocated Quantity` (Decimal)
  - Field: `Posting Date` (Date)
- New: page `Allocation Ledger Entries` (List)
- Modified: codeunit `Charge Post Subscribers`
  - `local procedure InsertAllocationLedgerEntries(SalesHeader: Record "Sales Header")` — W

Contract notes:
- Zero Unit cases — structural: insert wiring only.
- Decision surface proved: T-002.

## Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | Successful posting inserts one Allocation Ledger Entry per resolved allocation | InsertsAllocationLedgerEntries |
| B2 | Failed posting inserts no Allocation Ledger Entry rows | SkipsAuditEntriesWhenPostingFails |

## AAA Cases

### InsertsAllocationLedgerEntries
Procedure: `InsertsAllocationLedgerEntries`
Scope: Integration
Covers: B1
Arrange:
- Sales Order has balanced item charge allocation across two receiving Sales Lines.
Act:
- Post the Sales Order.
Assert:
- Two Allocation Ledger Entry rows are inserted.
- Each entry carries source Sales Line, receiving Sales Line, allocated quantity, and Posting Date.

### SkipsAuditEntriesWhenPostingFails
Procedure: `SkipsAuditEntriesWhenPostingFails`
Scope: Integration
Covers: B2
Arrange:
- Sales Order has mismatched item charge allocation.
Act:
- Post the Sales Order.
Assert:
- Posting is blocked.
- No Allocation Ledger Entry rows are inserted.
