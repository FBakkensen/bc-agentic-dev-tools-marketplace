# Sales Document Posting: Item Charge Allocation Validation

User-facing journey for catching item charge allocation mismatches at posting time. Two Roles cooperate across four event chains. Posting Engine takes the document the moment Order Processor hands over.

| | |
|---|---|
| **Slug**         | sales-charge-validation |
| **ADR**          | ADR-0007 |
| **Architecture** | [architecture.md](./architecture.md) |
| **Tasks**        | [tasks.md](./tasks.md) |

## Roles

Two Roles. **Order Processor** is human; releases document and triggers posting. **Posting Engine** is BC service; once posting starts, owns the document.

## Chain

### Order Processor (Human)

| Action | Business Event | View | Status |
|---|---|---|---|
| Releases Sales Order | Sales Order Released | Released Sales Order Card | Released |
| Initiates Posting | Posting Started | Posting Progress | Posting |

### Posting Engine (System)

| Action | Business Event | View | Status |
|---|---|---|---|
| Validates Item Charges | Item Charge Allocation Validated | Posting Progress | Validating |
| Posts Sales Invoice | Sales Invoice Posted | Posted Sales Invoice | Posted |

## Branch on validation failure

If *Item Charge Allocation Validated* reports mismatch, chain loops back to `Released Sales Order Card` with allocation breakdown surfaced inline. Posting Engine releases the document; no partial state written.
