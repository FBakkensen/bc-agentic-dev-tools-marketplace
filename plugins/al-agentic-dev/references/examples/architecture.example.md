# Item charge allocation, validated at posting

Three modules cooperate under strict R → P → W discipline. Feature touches BaseApp at exactly one place: event subscribers on `Sales-Post` codeunit 80.

| | |
|---|---|
| **Slug**        | sales-charge-validation |
| **ADR**         | ADR-0007 |
| **Event model** | [event-model.md](./event-model.md) |
| **Tasks**       | [tasks.md](./tasks.md) |

## Goal

Catch item charge allocation mismatches at posting before invoice posts, surface cause inline on document, produce deterministic audit trail tying each allocation back to source line.

## Module map

| Module | R → P → W | Touchpoint |
|---|---|---|
| `Charge Validation` | Read → Process | Reads `Item Charge Assignment (Sales)`; emits validated allocations. |
| `Allocation Resolver` | Process | Pure. Builds allocation graph; no BaseApp dependency. |
| `Posting Subscribers` | Write | Brownfield touchpoint in `Sales-Post` codeunit 80. |

## R → P → W boundary

Reads sit on released document. `Charge Validation` opens `Sales Header` by `No.`, iterates `Sales Line` rows it owns, resolves each related `Item Charge Assignment (Sales)`. Reads never reach outside the document.

Processing is pure. `Allocation Resolver` takes read rows, produces in-memory graph mapping each charge to its receiving lines. No `Insert` or `Modify`. Returns value object. Reproducible from inputs.

Writes go through BaseApp. `Posting Subscribers` subscribes to `OnAfterCheckSalesDoc` and `OnBeforePostSalesDoc` from `Sales-Post`. Calls `Charge Validation` and `Allocation Resolver`, then writes through `Sales-Post`. Success → posting proceeds; failure → `Error` aborts. Audit entries `Insert` into feature-owned table.

## Brownfield touchpoints

| Object | Kind | What we do |
|---|---|---|
| `Sales-Post` codeunit 80 | Event source | Subscribe; never modify. |
| `OnAfterCheckSalesDoc` | Event subscriber | Run `Charge Validation`, raise `Error` on mismatch. |
| `OnBeforePostSalesDoc` | Event subscriber | Defensive only; main check on `OnAfterCheckSalesDoc`. |

## BC patterns

- Event Subscriber
- Validation Codeunit
- Posting Routine Extension

## Posting flow

Posting routes through four steps: `Release Sales Order` → `Initiate Posting` → `Validate Item Charges` → `Post Sales Invoice`. Mismatch at `Validate Item Charges` loops back to `Released Sales Order Card`; no partial document state written.

## Cross-references

- ADR-0007 Allocation Mismatch Surfacing: in-document mismatch surface and audit policy.
- [event-model.md](./event-model.md): user-facing chain.
- [tasks.md](./tasks.md): task bus decomposing this architecture.
