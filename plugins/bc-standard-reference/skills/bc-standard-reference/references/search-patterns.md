# Search Patterns (Tool-Agnostic)

These patterns describe *what to search for* and *what to expect*. Use any repository search or browsing method you have.

## Find Objects

- Search for: `codeunit "Sales-Post"`
- Scope: `BaseApp/Source/Base Application/Sales/Posting`
- Expect: the codeunit declaration and its procedures

- Search for: `table 18 "Customer"`
- Scope: `BaseApp/Source/Base Application`
- Expect: the table declaration and field list

## Find Events

- Search for: `OnBeforePostSalesDoc`
- Scope: `BaseApp/Source/Base Application/Sales/Posting`
- Expect: an event publisher with a clear signature

- Search for: `IntegrationEvent` near your target object
- Expect: event attributes followed by procedure definitions

## Tables and Fields

- Search for: `table 37 "Sales Line"`
- Expect: field definitions and trigger logic

- Search for: `field(` + field name
- Expect: the field declaration and any triggers or validations

## Tests and Libraries

- Search for: `Library - Sales`
- Scope: `BaseApp/Test/Tests-TestLibraries`
- Expect: helper procedures for sales document setup

- Search for: `CreateSalesOrder`
- Scope: `BaseApp/Test/Tests-ERM`
- Expect: standard test setup patterns you can reuse

## API Implementations

- Search for: `API page` + entity name (e.g., `Customer`)
- Scope: `APIV2/Source/_Exclude_APIV2_/src/pages`
- Expect: API page definitions and fields exposed

## Workflow Tip

Start from known object or event names, then narrow by domain path. Once you find a candidate file, confirm the exact declaration and signature before you decide where to hook or replicate behavior.
