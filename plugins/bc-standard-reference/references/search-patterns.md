# Search Patterns

Heuristics, not commands. Use any repo-search or symbol-discovery method. Each pattern names *what* to search for, *where*, and *what to expect on a hit*.

## Objects

- **Codeunit** — search `codeunit "Sales-Post"` in `BaseApp/Source/Base Application/Sales/Posting`. Expect: declaration with ID, procedures, event publishers.
- **Table** — search `table 18 "Customer"` in `BaseApp/Source/Base Application`. Expect: declaration, field list, triggers.
- **Page** — search `page <id> "<name>"` in the relevant domain folder. Expect: declaration, layout, actions.

## Events

- **Named publisher** — search `OnBeforePostSalesDoc` in `Sales/Posting`. Expect: `[IntegrationEvent(...)]` attribute followed by the empty publisher procedure with its full signature.
- **Discover events near an object** — search `IntegrationEvent` within the codeunit's file. Expect: attribute lines paired with publisher declarations. Read the signature, not the name.
- **External / business events** — search `ExternalEvents/Source/_Exclude_Business_Events_/src/` by domain (AR, AP, Inventory). Expect: `[ExternalBusinessEvent(...)]` declarations.

## Tables and fields

- **Field declaration** — search `field(` + field name in the table file. Expect: type, length, and any `OnValidate` / `OnLookup` / `OnAfterValidate` triggers.
- **Standard ID** — fields with documented IDs (`field(1; "No."; Code[20])`) signal a stable contract you can reference.

## Tests and libraries

- **Library** — search `Library - Sales` in `BaseApp/Test/Tests-TestLibraries`. Expect: helper procedures (`CreateSalesOrder`, `CreateSalesHeader`, `CreateSalesLine`).
- **Standard test** — search a domain test path like `BaseApp/Test/Tests-ERM` for the helper name (e.g., `CreateSalesOrder`). Expect: arrange/act/assert flows you can mirror.

## API implementations

- **API page** — search `pageextension` or `page` matching the entity in `APIV2/Source/_Exclude_APIV2_/src/pages`. Expect: API page declaration with `EntityName`, `EntitySetName`, exposed fields.

## Workflow

Start from a known object or event name. Narrow by domain path. Confirm the declaration before deciding where to hook or what to mirror.

_Avoid_: matching on a name alone. Read the declaration. Quote the signature.
