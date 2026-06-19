# Scenarios

Walkthroughs for recurring questions. Each follows the four-step procedure: Identify → Search → Inspect → Cross-check. Findings carry file path, object name + ID, and event signature — never a vague summary.

## Force a customer-specific price in V16 price calculation

1. **Identify** — `Price Calculation - V16`, `Sales Line - Price`, `Price Calculation Mgt.` are the standard pricing codeunits.
2. **Search** — narrow to `BaseApp/Source/Base Application/Sales/Pricing/` (or `Pricing` at the relevant level for your version) and locate `Price Calculation - V16`.
3. **Inspect** — confirm: how price sources are selected, which events publish during calculation, the seam where a customer-specific override fits cleanly.
4. **Cross-check** — verify the V16 contract on Microsoft Learn before committing to a hook point.

Return: file path, codeunit ID, event signature, recommended hook.

## Block partial posting of sales orders

1. **Identify** — `Sales-Post`, `Sales-Post (Yes/No)` hold the posting flow.
2. **Search** — locate `OnBeforePostSalesDoc` in `Sales/Posting`. Read the declaration.
3. **Inspect** — confirm where validation happens before the actual post; check whether the extension already subscribes to a related posting event to avoid duplicate logic.
4. **Cross-check** — Learn for the canonical posting contract and partial-posting behaviour.

Return: codeunit name + ID, event signature, hook position relative to existing subscribers.

## Find events that fire during sales order release

1. **Identify** — `Release Sales Document` is the codeunit.
2. **Search** — open the file. Search within for `IntegrationEvent`, `OnBefore`, `OnAfter`.
3. **Inspect** — trace the release flow. Order matters — note when each event fires relative to status update.
4. **Cross-check** — Learn for the documented release contract.

Return: codeunit ID, the ordered list of event signatures with their position in the flow.

## Understand standard test setup for sales documents

1. **Identify** — `Library - Sales` is the helper library.
2. **Search** — locate the codeunit in `BaseApp/Test/Tests-TestLibraries`. Search within for `CreateSalesOrder`, `CreateSalesHeader`, `CreateSalesLine`.
3. **Inspect** — read the helpers. Note which use `LibraryRandom`, which require setup, which return the inserted record.
4. **Cross-check** — match against existing test scaffolding in the workspace; mirror only what fits the project's test layer.

Return: library codeunit name, helper procedure signatures, dependencies on other libraries.
