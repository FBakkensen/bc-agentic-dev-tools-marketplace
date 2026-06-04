# Tasks: Sales Document Posting, Item Charge Allocation Validation

| | |
|---|---|
| **Slug**         | sales-charge-validation |
| **ADR**          | ADR-0007 |
| **Event model**  | [event-model.example.md](./event-model.example.md) |
| **Architecture** | [architecture.example.md](./architecture.example.md) |
| **Tasks**        | 6 technical + 2 verify |
| **Slices**       | post-validates-allocation, audit-trail |

## Goal

Catch item charge allocation mismatches at posting before invoice posts, surface cause inline on document, produce deterministic audit trail tying each allocation back to source line.

## Slice: post-validates-allocation

### T-001 [x] — Read released sales order item charge assignments
<!-- task=T-001 status=done slice=post-validates-allocation kind=technical -->

Resolve `Item Charge Assignment (Sales)` rows for released `Sales Header`, grouped by source `Sales Line`. Reads only; no `Insert` or `Modify`.

Test Specification:

### Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | One released Sales Order item charge assignment is returned with source Sales Line reference | ReadsSingleItemChargeAssignment |
| B2 | Released Sales Order with no item charge assignments returns empty result | ReadsNoItemChargeAssignmentsAsEmpty |

### AAA Cases

#### ReadsSingleItemChargeAssignment
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

#### ReadsNoItemChargeAssignmentsAsEmpty
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

### T-002 [x] — Validate allocated quantities sum to charge quantity
<!-- task=T-002 status=done slice=post-validates-allocation kind=technical -->

For each `Item Charge Assignment (Sales)`, verify sum of allocated quantities equals charge quantity. Both inequality directions count as mismatches.

Test Specification:

Acceptance Intent:
Allocation validation protects posting correctness by rejecting Sales Orders where item charge quantity and assigned quantity do not balance.

### Decision Matrix

| Case | Charge Quantity | Allocated Quantity | Expected Result | Covered By |
|---|---:|---:|---|---|
| R1 | 10 | 10 | Balanced | AcceptsBalancedAllocationQuantity |
| R2 | 10 | 8 | Mismatch shortfall 2 | RejectsShortfallAllocationQuantity |
| R3 | 10 | 12 | Mismatch overflow 2 | RejectsOverflowAllocationQuantity |

### AAA Cases

#### AcceptsBalancedAllocationQuantity
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

#### RejectsShortfallAllocationQuantity
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

#### RejectsOverflowAllocationQuantity
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
- Mutation: task-end quantity comparison mutants killed at Unit layer

### T-003 [x] — Subscribe to OnAfterCheckSalesDoc, route through validator
<!-- task=T-003 status=done slice=post-validates-allocation kind=technical -->

**Depends on:** T-001, T-002

Add event subscriber on `Sales-Post` codeunit 80 delegating to `Charge Validation`. Mismatch raises `Error` before any `Insert` or `Modify` on posting tables.

Test Specification:

Acceptance Intent:
Posting validation prevents Sales Orders with unbalanced item charge allocations from creating posted documents or partial posting state.

### Decision Matrix

| Case | Allocation Balanced | Expected Posting | Posted Invoice Created | Covered By |
|---|---:|---|---:|---|
| R1 | Yes | Allowed | Yes | PostsSalesOrderWithBalancedAllocation |
| R2 | No | Blocked | No | BlocksPostingWithMismatchedAllocation |

### AAA Cases

#### PostsSalesOrderWithBalancedAllocation
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

#### BlocksPostingWithMismatchedAllocation
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
- Mutation: posting guard and event-subscriber delegation mutants killed at Integration layer

### T-004 [x] — Surface validation failure inline on Sales Order Card with breakdown
<!-- task=T-004 status=done slice=post-validates-allocation kind=technical -->

**Depends on:** T-003

When validation reports mismatch, render allocation breakdown inline on `Sales Order Card`: one row per receiving `Sales Line`, allocated and required quantities side by side, imbalance highlighted.

Test Specification:

Acceptance Intent:
The Sales Order Card explains allocation mismatch at the point of correction so the Order Processor can fix the affected Sales Lines.

### Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | Mismatched allocation breakdown shows allocated and required quantities per Sales Line | ShowsAllocationMismatchBreakdown |
| B2 | Corrected allocation hides the breakdown | HidesBreakdownAfterAllocationCorrection |

### AAA Cases

#### ShowsAllocationMismatchBreakdown
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

#### HidesBreakdownAfterAllocationCorrection
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
- Mutation: breakdown visibility and correction-state mutants killed at Integration layer

### T-006 [x] — Verify: Order Processor posts a sales document with charge allocation
<!-- task=T-006 status=done slice=post-validates-allocation kind=verify -->

**Depends on:** T-001, T-002, T-003, T-004

User-facing slice `post-validates-allocation`: Order Processor releases and posts `Sales Header` with `Item Charge Assignment (Sales)`. Balanced allocations post cleanly; mismatched allocations halt posting with inline breakdown on `Sales Order Card`.

Verification Plan:

### Journey Examples

#### V1 PostsBalancedAllocationFromSalesOrderPage
Scope: E2E
Role: Order Processor
Action:
- Open Sales Order Card for a Sales Order with item charge quantity 10 and allocations 4 + 6.
- Choose `Post`.
- Confirm the posting dialog.
Observable Checks:
- Posted Sales Invoice is created.
- Sales Order Status remains `Released`.

#### V2 BlocksMismatchedAllocationFromSalesOrderPage
Scope: E2E
Role: Order Processor
Action:
- Open Sales Order Card for a Sales Order with item charge quantity 10 and allocations 6 + 6.
- Choose `Post`.
Observable Checks:
- Allocation mismatch error is visible.
- Posted Sales Invoice is not created.
- Breakdown shows both Sales Lines and marks the overflow.

### Exploration Charters

#### X1 AllocationMismatchGuidesCorrection
Scope: Exploration
Charter: Judge whether the mismatch breakdown tells the Order Processor which Sales Line allocation to fix.
Prompts:
- Is the affected Sales Line easy to identify?
- Are allocated and required quantities understandable without opening another page?
- Does the flow return the user to a useful correction point?

Closeout:
- E2E: `pagescripts/recordings/007-sales-charge-validation__post-validates-allocation.yml`
- Verification: Journey Examples passed; Exploration Charter recorded no blocking usability findings

## Slice: audit-trail

### T-005 [>] — Persist allocation audit entries via Allocation Ledger Entry table
<!-- task=T-005 status=ready-for-implementation slice=audit-trail kind=technical -->

**Depends on:** T-002, T-006

On every successful posting, `Insert` one ledger entry per resolved allocation: source `Sales Line`, receiving `Sales Line`, allocated quantity, `Posting Date`. Audit trail referenced by ADR-0007.

Test Specification:

Acceptance Intent:
Allocation audit entries preserve posting traceability by recording the source and receiving Sales Lines for each posted allocation.

### Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | Successful posting inserts one Allocation Ledger Entry per resolved allocation | InsertsAllocationLedgerEntries |
| B2 | Failed posting inserts no Allocation Ledger Entry rows | SkipsAuditEntriesWhenPostingFails |

### AAA Cases

#### InsertsAllocationLedgerEntries
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

#### SkipsAuditEntriesWhenPostingFails
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

### T-007 [ ] — Derive allocation audit reason values
<!-- task=T-007 status=ready slice=audit-trail kind=technical -->

**Depends on:** T-002

Translate allocation validation outcomes into audit reason values so ledger entries can distinguish balanced postings, shortfalls, and overflows.

### T-008 [!] — Verify: Allocation Ledger Entry rows persist after successful posting
<!-- task=T-008 status=blocked slice=audit-trail kind=verify -->

**Depends on:** T-005, T-007

User-facing slice `audit-trail`: after successful `Post` on balanced allocation, audit trail surfaces one `Allocation Ledger Entry` row per resolved allocation, queryable from `Posted Sales Invoice`.
