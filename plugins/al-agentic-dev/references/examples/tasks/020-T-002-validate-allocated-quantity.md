---
task: T-002
status: done
slice: post-validates-allocation
kind: technical
depends_on: []
---
# T-002 — Validate allocated quantities sum to charge quantity

For each `Item Charge Assignment (Sales)`, verify sum of allocated quantities equals charge quantity. Both inequality directions count as mismatches.

Test Specification:

Acceptance Intent:
Allocation validation protects posting correctness by rejecting Sales Orders where item charge quantity and assigned quantity do not balance.

## New and Modified Objects

- Modified: codeunit `Charge Validation`
  - `internal procedure ValidateAllocatedQuantity(ChargeQty: Decimal; AllocatedQty: Decimal; var Imbalance: Decimal): Boolean` — P

## Decision Matrix

| Case | Charge Quantity | Allocated Quantity | Expected Result | Covered By |
|---|---:|---:|---|---|
| R1 | 10 | 10 | Balanced | AcceptsBalancedAllocationQuantity |
| R2 | 10 | 8 | Mismatch shortfall 2 | RejectsShortfallAllocationQuantity |
| R3 | 10 | 12 | Mismatch overflow 2 | RejectsOverflowAllocationQuantity |

## AAA Cases

### AcceptsBalancedAllocationQuantity
Procedure: `AcceptsBalancedAllocationQuantity`
Scope: Unit
Covers: R1
Arrange:
- Item charge quantity is 10.
- Allocations total 10.
Act:
- Validate allocated quantity.
Assert:
- Result is balanced.

### RejectsShortfallAllocationQuantity
Procedure: `RejectsShortfallAllocationQuantity`
Scope: Unit
Covers: R2
Arrange:
- Item charge quantity is 10.
- Allocations total 8.
Act:
- Validate allocated quantity.
Assert:
- Result is mismatch.
- Shortfall is 2.

### RejectsOverflowAllocationQuantity
Procedure: `RejectsOverflowAllocationQuantity`
Scope: Unit
Covers: R3
Arrange:
- Item charge quantity is 10.
- Allocations total 12.
Act:
- Validate allocated quantity.
Assert:
- Result is mismatch.
- Overflow is 2.

Closeout:
- Unit: `AcceptsBalancedAllocationQuantity`, `RejectsShortfallAllocationQuantity`, `RejectsOverflowAllocationQuantity`
- Integration: none
- Build: full gate green

Mutation verdict:

| | |
|---|---|
| Baseline | `8b2d41ca` |
| Report | `.output/mutation-report/20260112-141503.md` |
| Mutants | 3 — quantity comparison boundaries, shortfall/overflow branch |
| Killed | 3 by named tests |
| Survivors | 0 |
| Final gate | full green |
