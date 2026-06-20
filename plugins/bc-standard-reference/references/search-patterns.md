# Search Patterns

Heuristics over the mirror `fbakkensen/bc-w1`, run through the `gh` CLI. Each pattern names *what* to search for, *where*, and *what to expect on a hit*. The mechanism is the same three commands throughout:

```bash
gh search code "<query>" --repo fbakkensen/bc-w1        # find the declaration line (add path: to narrow)
gh repo read-file "<path>" --repo fbakkensen/bc-w1      # quote it verbatim — no clone
gh repo read-dir "<path>"  --repo fbakkensen/bc-w1      # list a folder when you don't know the filename
```

`gh search code` returns `repo:path: matching line` — that path feeds straight into `read-file`. Narrow with an inline `path:` qualifier; never search the whole repo when the domain is known. Big files (e.g. `SalesPost.Codeunit.al`, ~790 KB) are whole-file reads — pipe through `grep -n` to find the line, then `sed -n 'A,Bp'` for the surrounding block.

## Objects

- **Codeunit** — `gh search code 'codeunit "Sales-Post" path:Sales/Posting' --repo fbakkensen/bc-w1`. Expect: declaration with ID, procedures, event publishers.
- **Table** — `gh search code 'table 18 "Customer"' --repo fbakkensen/bc-w1`. Expect: declaration, field list, triggers.
- **Page** — `gh search code 'page <id> "<name>"' --repo fbakkensen/bc-w1`, narrowed by `path:<Domain>`. Expect: declaration, layout, actions.

## Events

- **Named publisher** — `gh search code 'OnBeforePostSalesDoc path:Sales/Posting' --repo fbakkensen/bc-w1`, then `read-file` the hit. Expect: `[IntegrationEvent(...)]` attribute followed by the empty publisher procedure with its full signature.
- **Discover events near an object** — `read-file` the codeunit, `grep -n 'IntegrationEvent'` for the attribute lines paired with publisher declarations. Read the signature, not the name.
- **External / business events** — `gh search code 'ExternalBusinessEvent path:ExternalEvents' --repo fbakkensen/bc-w1`, narrow further by domain (`ARExternalEvents`, `APExternalEvents`). Expect: `[ExternalBusinessEvent(...)]` declarations.

## Tables and fields

- **Field declaration** — `read-file` the table, `grep -n 'field('` + field name. Expect: type, length, and any `OnValidate` / `OnLookup` / `OnAfterValidate` triggers.
- **Standard ID** — fields with documented IDs (`field(1; "No."; Code[20])`) signal a stable contract you can reference.

## Tests and libraries

- **Library** — `gh search code 'Library - Sales path:BaseApp/Test/Tests-TestLibraries' --repo fbakkensen/bc-w1`. Expect: helper procedures (`CreateSalesOrder`, `CreateSalesHeader`, `CreateSalesLine`).
- **Standard test** — `gh search code '<helper> path:BaseApp/Test/Tests-ERM' --repo fbakkensen/bc-w1` (e.g. `CreateSalesOrder`). Expect: arrange/act/assert flows you can mirror.

## API implementations

- **API page** — `gh search code '<entity> path:APIV2/Source/_Exclude_APIV2_/src/pages' --repo fbakkensen/bc-w1`. Expect: API page declaration with `EntityName`, `EntitySetName`, exposed fields.

## Workflow

Start from a known object or event name. Narrow by `path:`. Confirm the declaration with `read-file` before deciding where to hook or what to mirror.

_Avoid_: matching on a name alone, or `read-file`-ing a 790 KB codeunit whole when a `grep -n` + `sed -n` window is what you need. Read the declaration. Quote the signature.
