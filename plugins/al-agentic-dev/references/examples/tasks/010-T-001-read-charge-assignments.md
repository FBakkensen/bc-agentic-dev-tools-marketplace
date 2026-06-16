---
task: T-001
status: done
slice: post-validates-allocation
kind: technical
depends_on: []
---
# T-001 — Read released sales order item charge assignments

Resolve `Item Charge Assignment (Sales)` rows for released `Sales Header`, grouped by source `Sales Line`. Reads only; no `Insert` or `Modify`.

Test Specification:

## New and Modified Objects

- New: codeunit `Charge Validation`
  - `internal procedure FindItemChargeAssignments(SalesHeader: Record "Sales Header"; var TempItemChargeAssignmentSales: Record "Item Charge Assignment (Sales)" temporary)` — R

## Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | One released Sales Order item charge assignment is returned with source Sales Line reference | ReadsSingleItemChargeAssignment |
| B2 | Released Sales Order with no item charge assignments returns empty result | ReadsNoItemChargeAssignmentsAsEmpty |

## AAA Cases

### ReadsSingleItemChargeAssignment
Procedure: `ReadsSingleItemChargeAssignment`
Scope: Unit
Covers: B1
Arrange:
- Released Sales Order has one freight charge line.
- One item charge assignment exists for the freight charge line.
Act:
- Read item charge assignments for the Sales Order.
Assert:
- One assignment is returned.
- Assignment carries source Sales Line reference.

### ReadsNoItemChargeAssignmentsAsEmpty
Procedure: `ReadsNoItemChargeAssignmentsAsEmpty`
Scope: Unit
Covers: B2
Arrange:
- Released Sales Order has no item charge assignment rows.
Act:
- Read item charge assignments for the Sales Order.
Assert:
- Empty result is returned.
- Allocation validation can short-circuit as balanced.

Closeout:
- Unit: `ReadsSingleItemChargeAssignment`, `ReadsNoItemChargeAssignmentsAsEmpty`
- Integration: none
- Build: full gate green
