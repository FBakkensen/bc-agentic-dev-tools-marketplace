---
task: T-003
status: done
slice: post-validates-allocation
kind: technical
depends_on: [T-001, T-002]
---
# T-003 — Subscribe to OnAfterCheckSalesDoc, route through validator

Add event subscriber on `Sales-Post` codeunit 80 delegating to `Charge Validation`. Mismatch raises `Error` before any `Insert` or `Modify` on posting tables.

Test Specification:

Acceptance Intent:
Posting validation prevents Sales Orders with unbalanced item charge allocations from creating posted documents or partial posting state.

## New and Modified Objects

- New: codeunit `Charge Post Subscribers`
  - `local procedure OnAfterCheckSalesDoc(var SalesHeader: Record "Sales Header")` subscribes `Sales-Post` `OnAfterCheckSalesDoc` — W

Contract notes:
- Oracle: posted-document absence — `BlocksPostingWithMismatchedAllocation` asserts no Posted Sales Invoice exists, not the error text alone.
- Zero Unit cases — structural: the subscriber delegates to `Charge Validation` and adds no decision logic of its own.
- Decision surface proved: T-002.
- Transaction: validation raises `Error` before any posting-table write — blocked posting leaves no partial state to assert away.

Out of automated reach:
- Subscriber placement on `OnAfterCheckSalesDoc` — a later posting event satisfies the same assertions; code-review invariant.

## Decision Matrix

| Case | Allocation Balanced | Expected Posting | Posted Invoice Created | Covered By |
|---|---:|---|---:|---|
| R1 | Yes | Allowed | Yes | PostsSalesOrderWithBalancedAllocation |
| R2 | No | Blocked | No | BlocksPostingWithMismatchedAllocation |

## AAA Cases

### PostsSalesOrderWithBalancedAllocation
Procedure: `PostsSalesOrderWithBalancedAllocation`
Scope: Integration
Covers: R1
Arrange:
- Released Sales Order has balanced item charge allocation.
Act:
- Post the Sales Order.
Assert:
- Posted Sales Invoice is created.
- Posting Date matches the Sales Order.

### BlocksPostingWithMismatchedAllocation
Procedure: `BlocksPostingWithMismatchedAllocation`
Scope: Integration
Covers: R2
Arrange:
- Released Sales Order has mismatched item charge allocation.
Act:
- Post the Sales Order.
Assert:
- Allocation mismatch error is raised.
- Posted Sales Invoice is not created.

Closeout:
- Unit: none
- Integration: `PostsSalesOrderWithBalancedAllocation`, `BlocksPostingWithMismatchedAllocation`
- Build: full gate green

Mutation verdict:

| | |
|---|---|
| Baseline | `4f1c9a2e` |
| Report | `.output/mutation-report/20260114-103012.md` |
| Mutants | 3 — posting guard inversion, subscriber delegation removal, empty-assignment early exit |
| Killed | 2 by named tests |
| Survivors | 1 |
| Final gate | full green |

Survivor: empty-assignment early-exit removal in the posting subscriber.
Why kept: equivalent — the validator returns balanced on an empty assignment set; the early exit is a fast path with no observable difference.
