# Scenarios

Walkthroughs for recurring questions. Each follows the four-step procedure: Identify → Search → Inspect → Cross-check. Search and Inspect run through the `gh` CLI against the mirror (`gh search code` to find the line, `gh repo read-file` to quote it); Cross-check is the only web step. Findings carry file path, object name + ID, and event signature — never a vague summary.

## Force a customer-specific price in V16 price calculation

1. **Identify** — `Price Calculation - V16`, `Sales Line - Price`, `Price Calculation Mgt.` are the standard pricing codeunits.
2. **Search** — `gh search code '"Price Calculation - V16" path:Sales/Pricing' --repo fbakkensen/bc-w1` to find the declaration's path.
3. **Inspect** — `read-file` the hit: how price sources are selected, which events publish during calculation, the seam where a customer-specific override fits cleanly.
4. **Cross-check** — verify the V16 contract on Microsoft Learn before committing to a hook point.

Return: file path, codeunit ID, event signature, recommended hook.

## Block partial posting of sales orders

1. **Identify** — `Sales-Post`, `Sales-Post (Yes/No)` hold the posting flow.
2. **Search** — `gh search code 'OnBeforePostSalesDoc path:Sales/Posting' --repo fbakkensen/bc-w1` to locate the publisher.
3. **Inspect** — `read-file` `SalesPost.Codeunit.al` (~790 KB — `grep -n` the event, `sed -n` the window). Confirm where validation happens before the actual post; check whether the extension already subscribes to a related posting event to avoid duplicate logic.
4. **Cross-check** — Learn for the canonical posting contract and partial-posting behaviour.

Return: codeunit name + ID, event signature, hook position relative to existing subscribers.

## Find events that fire during sales order release

1. **Identify** — `Release Sales Document` is the codeunit.
2. **Search** — `gh search code '"Release Sales Document" path:Sales' --repo fbakkensen/bc-w1` for the file path.
3. **Inspect** — `read-file` it, `grep -n 'IntegrationEvent\|OnBefore\|OnAfter'`. Trace the release flow. Order matters — note when each event fires relative to status update.
4. **Cross-check** — Learn for the documented release contract.

Return: codeunit ID, the ordered list of event signatures with their position in the flow.

## Understand standard test setup for sales documents

1. **Identify** — `Library - Sales` is the helper library.
2. **Search** — `gh search code 'CreateSalesOrder path:BaseApp/Test/Tests-TestLibraries' --repo fbakkensen/bc-w1`, or `read-dir` the folder when the filename is unknown.
3. **Inspect** — `read-file` the helpers. Note which use `LibraryRandom`, which require setup, which return the inserted record.
4. **Cross-check** — match against existing test scaffolding in the workspace; mirror only what fits the project's test layer.

Return: library codeunit name, helper procedure signatures, dependencies on other libraries.
