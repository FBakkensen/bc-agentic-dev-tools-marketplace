---
task: T-004
status: done
slice: post-validates-allocation
kind: technical
depends_on: [T-003]
---
# T-004 — Surface validation failure inline on Sales Order Card with breakdown

When validation reports mismatch, render allocation breakdown inline on `Sales Order Card`: one row per receiving `Sales Line`, allocated and required quantities side by side, imbalance highlighted.

Test Specification:

Acceptance Intent:
The Sales Order Card explains allocation mismatch at the point of correction so the Order Processor can fix the affected Sales Lines.

## New and Modified Objects

- New: page `Allocation Mismatch Breakdown` (ListPart)
- New: pageextension `Sales Order Ext` extends `Sales Order`
  - Part: `Allocation Mismatch Breakdown`, visible on mismatch

## Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | Mismatched allocation breakdown shows allocated and required quantities per Sales Line | ShowsAllocationMismatchBreakdown |
| B2 | Corrected allocation hides the breakdown | HidesBreakdownAfterAllocationCorrection |

## AAA Cases

### ShowsAllocationMismatchBreakdown
Procedure: `ShowsAllocationMismatchBreakdown`
Scope: Integration
Covers: B1
Arrange:
- Sales Order has item charge quantity 10.
- Allocations total 12 across two Sales Lines.
Act:
- Open Sales Order Card after failed posting validation.
Assert:
- Breakdown lists both Sales Lines.
- Allocated and required quantities are visible.
- Overflow row is marked as imbalance.

### HidesBreakdownAfterAllocationCorrection
Procedure: `HidesBreakdownAfterAllocationCorrection`
Scope: Integration
Covers: B2
Arrange:
- Sales Order has corrected allocation that balances to charge quantity.
Act:
- Reopen Sales Order Card.
Assert:
- Breakdown is hidden.
- Validate action reports balanced allocation.

Closeout:
- Unit: none
- Integration: `ShowsAllocationMismatchBreakdown`, `HidesBreakdownAfterAllocationCorrection`
- Build: full gate green

Mutation verdict:

| | |
|---|---|
| Baseline | `c91e07d5` |
| Report | `.output/mutation-report/20260115-091847.md` |
| Mutants | 2 — breakdown visibility guard, correction-state re-evaluation |
| Killed | 2 by named tests |
| Survivors | 0 |
| Final gate | full green |
