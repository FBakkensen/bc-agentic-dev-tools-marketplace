# Item charge allocation, validated at posting

Two modules cooperate under strict R → P → W discipline. Feature touches BaseApp at exactly one place: event subscribers on `Sales-Post` codeunit 80.

| | |
|---|---|
| **Slug**        | sales-charge-validation |
| **ADR**         | ADR-0007 |
| **Event model** | [event-model.example.md](./event-model.example.md) |
| **Tasks**       | [tasks.example.md](./tasks.example.md) |

## Goal

Catch item charge allocation mismatches at posting before invoice posts, surface cause inline on document, produce deterministic audit trail tying each allocation back to source line.

## Module map

| Module | R → P → W | Touchpoint |
|---|---|---|
| `Charge Validation` (new) | Read → Process | Reads `Item Charge Assignment (Sales)`; pure allocation-balance decisions, no BaseApp write. |
| `Charge Post Subscribers` (new) | Write | Brownfield touchpoint in `Sales-Post` codeunit 80. |

## R → P → W boundary

Reads sit on released document. `Charge Validation` opens `Sales Header` by `No.`, iterates `Sales Line` rows it owns, resolves each related `Item Charge Assignment (Sales)`. Reads never reach outside the document.

Processing is pure. `Charge Validation` takes read rows, decides allocation balance per charge against its receiving lines. No `Insert` or `Modify`. Returns decision outcome. Reproducible from inputs.

Writes go through BaseApp. `Charge Post Subscribers` subscribes to `OnAfterCheckSalesDoc` from `Sales-Post`. Calls `Charge Validation`, then writes through `Sales-Post`. Success → posting proceeds; failure → `Error` aborts. Audit entries `Insert` into feature-owned table.

## Brownfield touchpoints

| Object | Kind | What we do |
|---|---|---|
| `Sales-Post` codeunit 80 | Event source | Subscribe; never modify. |
| `OnAfterCheckSalesDoc` | Event subscriber | Run `Charge Validation`, raise `Error` on mismatch. |

## AL realisation per slice

- Slice `post-validates-allocation`: trigger — subscriber on `Sales-Post` `OnAfterCheckSalesDoc` (new codeunit `Charge Post Subscribers`); decision — new codeunit `Charge Validation`; view — new page `Allocation Mismatch Breakdown` (ListPart), new pageextension extends `Sales Order`; state — none, validation is stateless.
- Slice `audit-trail`: state — new table `Allocation Ledger Entry`; write — `Charge Post Subscribers` (new in posting slice; this slice modifies it); view — new page `Allocation Ledger Entries` (List), drill from `Posted Sales Invoice`.

## BC patterns

- Event Subscriber
- Validation Codeunit
- Posting Routine Extension

## Posting flow

Posting routes through four steps: `Release Sales Order` → `Initiate Posting` → `Validate Item Charges` → `Post Sales Invoice`. Mismatch at `Validate Item Charges` loops back to `Released Sales Order Card`; no partial document state written.

## Cross-references

- ADR-0007 Allocation Mismatch Surfacing: in-document mismatch surface and audit policy.
- [event-model.example.md](./event-model.example.md): user-facing chain.
- [tasks.example.md](./tasks.example.md): task bus decomposing this architecture.
