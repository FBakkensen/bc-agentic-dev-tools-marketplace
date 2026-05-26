# Tasks: Sales Document Posting, Item Charge Allocation Validation

| | |
|---|---|
| **Slug**         | sales-charge-validation |
| **ADR**          | ADR-0007 |
| **Event model**  | [event-model.md](./event-model.md) |
| **Architecture** | [architecture.md](./architecture.md) |
| **Tasks**        | 5 technical + 2 verify |
| **Slices**       | post-validates-allocation, audit-trail |

## Goal

Catch item charge allocation mismatches at posting before invoice posts, surface cause inline on document, produce deterministic audit trail tying each allocation back to source line.

## Slice: post-validates-allocation

### T-001 [x] — Read released sales order item charge assignments
<!-- task=T-001 status=done slice=post-validates-allocation kind=technical -->

Resolve `Item Charge Assignment (Sales)` rows for released `Sales Header`, grouped by source `Sales Line`. Reads only; no `Insert` or `Modify`.

**Tests** (Gherkin, ZOMBIES):

```gherkin
Scenario: One charge, one assignment
  Given released Sales Header with No. "SO-1001"
   And  one Item Charge Assignment (Sales) on a freight charge line
  When  Charge Validation reads assignments for "SO-1001"
  Then  one assignment is returned
   And  it carries the source Sales Line reference

Scenario: No assignments yields empty
  Given released Sales Header with no Item Charge Assignment (Sales) rows
  When  Charge Validation reads assignments
  Then  result is empty
   And  validation is short-circuited as balanced
```

### T-002 [x] — Validate allocated quantities sum to charge quantity
<!-- task=T-002 status=done slice=post-validates-allocation kind=technical -->

For each `Item Charge Assignment (Sales)`, verify sum of allocated quantities equals charge quantity. Both inequality directions count as mismatches.

**Tests** (Gherkin, ZOMBIES):

```gherkin
Scenario: Sum equals charge quantity
  Given charge of quantity 10
   And  allocations of 4 and 6 across two Sales Line rows
  When  Charge Validation validates
  Then  result is balanced

Scenario: Sum less than charge quantity
  Given charge of quantity 10
   And  allocations of 4 and 4 across two Sales Line rows
  When  Charge Validation validates
  Then  result is Mismatch with shortfall 2

Scenario: Sum greater than charge quantity
  Given charge of quantity 10
   And  allocations of 6 and 6 across two Sales Line rows
  When  Charge Validation validates
  Then  result is Mismatch with overflow 2
```

### T-003 [~] — Subscribe to OnAfterCheckSalesDoc, route through validator
<!-- task=T-003 status=in-progress slice=post-validates-allocation kind=technical -->

**Depends on:** T-001, T-002

Add event subscriber on `Sales-Post` codeunit 80 delegating to `Charge Validation`. Mismatch raises `Error` before any `Insert` or `Modify` on posting tables.

**Tests** (Gherkin, ZOMBIES):

```gherkin
Scenario: Validation fires before posting writes
  Given released Sales Header with one valid Item Charge Assignment (Sales)
  When  user calls Post
  Then  Charge Validation runs before OnBeforePostSalesDoc
   And  Posted Sales Invoice created with Posting Date matching the header

Scenario: Mismatch aborts posting, no partial writes
  Given released Sales Header with mismatched Item Charge Assignment (Sales)
  When  user calls Post
  Then  posting halts with Allocation Mismatch
   And  no Posted Sales Invoice row is Inserted
```

### T-004 [ ] — Surface validation failure inline on Sales Order Card with breakdown
<!-- task=T-004 status=ready slice=post-validates-allocation kind=technical -->

**Depends on:** T-003

When validation reports mismatch, render allocation breakdown inline on `Sales Order Card`: one row per receiving `Sales Line`, allocated and required quantities side by side, imbalance highlighted.

**Tests** (Gherkin, ZOMBIES):

```gherkin
Scenario: Breakdown shows allocated vs required per line
  Given mismatched assignment with allocations 6 and 6 against charge of 10
  When  user views Sales Order Card after failed Post
  Then  breakdown lists both Sales Line rows with allocated and required quantities
   And  overflow row is marked as the imbalance

Scenario: Breakdown clears when allocation corrected
  Given corrected allocation that sums to charge quantity
  When  user re-opens Sales Order Card
  Then  breakdown is hidden
   And  Validate action reports balanced
```

### T-006 [!] — Verify: Order Processor posts a sales document with charge allocation
<!-- task=T-006 status=blocked slice=post-validates-allocation kind=verify -->

**Depends on:** T-001, T-002, T-003, T-004

User-facing slice `post-validates-allocation`: Order Processor releases and posts `Sales Header` with `Item Charge Assignment (Sales)`. Balanced allocations post cleanly; mismatched halt posting with inline breakdown on `Sales Order Card`.

**User test plan** (numbered steps, ZOMBIES):

1. **Posting a balanced allocation succeeds end-to-end**
   1. Open `Sales Order Card` for `SO-1041` with charge of quantity 10 and allocations of 4 and 6.
   2. Click `Post` on action bar.
   3. Confirm posting dialog.
   4. **Expected:** `Posted Sales Invoice` created; Sales Order Status flips to `Released`.

2. **Mismatched allocation halts posting with breakdown**
   1. Open `Sales Order Card` for `SO-1042` with charge of quantity 10 and allocations of 6 and 6.
   2. Click `Post`.
   3. **Expected:** posting halts with `Allocation Mismatch` message.
   4. **Expected:** breakdown shows both `Sales Line` rows; overflow row highlighted.

3. **Boundary at exact zero allocation**
   1. Open `Sales Order Card` for `SO-1043` with charge of quantity 10 and no allocations.
   2. Click `Post`.
   3. **Expected:** posting halts with `Allocation Mismatch` shortfall 10.
   4. **Expected:** breakdown rendered with zero allocated.

## Slice: audit-trail

### T-005 [!] — Persist allocation audit entries via Allocation Ledger Entry table
<!-- task=T-005 status=blocked slice=audit-trail kind=technical -->

**Depends on:** T-002, T-006

On every successful posting, `Insert` one ledger entry per resolved allocation: source `Sales Line`, receiving `Sales Line`, allocated quantity, `Posting Date`. Audit trail referenced by ADR-0007.

### T-007 [!] — Verify: Allocation Ledger Entry rows persist after successful posting
<!-- task=T-007 status=blocked slice=audit-trail kind=verify -->

**Depends on:** T-005

User-facing slice `audit-trail`: after successful `Post` on balanced allocation, audit trail surfaces one `Allocation Ledger Entry` row per resolved allocation, queryable from `Posted Sales Invoice`.

**User test plan** (numbered steps, ZOMBIES):

1. **One allocation, one ledger entry**
   1. Post `SO-1041` with charge allocated against one `Sales Line`.
   2. Open resulting `Posted Sales Invoice`.
   3. Drill into `Allocation Ledger Entries` from fact box.
   4. **Expected:** one row with source `Sales Line`, allocated quantity, invoice `Posting Date`.

2. **Many allocations, one row per resolved allocation**
   1. Post `SO-1044` with charge of quantity 12 allocated as 4 + 4 + 4 across three `Sales Line` rows.
   2. Open `Posted Sales Invoice`, drill into `Allocation Ledger Entries`.
   3. **Expected:** three rows, each carrying source `Sales Line` reference and allocated quantity.
   4. **Expected:** summed `Allocated Quantity` across three rows equals 12.

