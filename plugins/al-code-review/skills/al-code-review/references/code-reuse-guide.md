# AL Code Reuse & Maintainability Review Guide

This guide defines the categories and patterns an AI code review agent should check when analyzing AL/Business Central PR diffs for code reuse and maintainability issues. Each section lists concrete anti-patterns with examples. Flag issues only when they appear in the changed lines of the diff.

---

## Variable Naming Conventions

- **Local variables** use camelCase starting with lowercase; **global variables** start with uppercase.
  - ✅ `isValid`, `totalAmount` (local) — `IsValid`, `TotalAmount` (global)
  - ❌ `IsValid` as a local variable, `totalAmount` as a global variable
- **Record variables** must match the table name exactly.
  - ✅ `Customer`, `SalesHeader`, `GenJournalLine`
  - ❌ `CustRec`, `CustomerRecord`, `SalesHdr`, `Rec`
- **Temporary record variables** use a `Temp` prefix.
  - ✅ `TempCustomer`, `TempSalesLine`
  - ❌ `CustomerBuffer`, `CustTemp`, `TmpCust`
- **Boolean variables** use `Is`, `Has`, or `Can` prefixes.
  - ✅ `IsPosted`, `HasPermission`, `CanProcess`
  - ❌ `Posted`, `PermissionCheck`, `ProcessFlag`
- **Codeunit variables** include `Mgt` or `Management` suffix where appropriate.
  - ✅ `SalesMgt`, `ItemTrackingManagement`
  - ❌ `SalesHelper`, `ItemTrackUtils`
- **Avoid** Hungarian notation (`recCustomer`, `txtName`), generic names (`Rec`, `Buffer`, `Temp`), and non-standard abbreviations.
- **Use BC-standard abbreviations** only: `Qty`, `Amt`, `No.`, `Desc`, `Pct`, `Dim`, `Gen`, `Jnl`, `Cust`, `Vend`, `Purch`.

## Variable Declaration Order

- Follow the standard AL declaration order:
  1. Record
  2. Report
  3. Codeunit
  4. XMLport
  5. Page
  6. Query
  7. Notification
  8. BigText / TextBuilder
  9. FilterPageBuilder, JsonObject, and other complex types
  10. Primitives: Text, Code, Integer, Decimal, Boolean, Date, etc.
- Within each type group, order by usage frequency or alphabetically — follow team convention consistently.
- **Constants** should be clearly separated and named using `ALL_CAPS` or a descriptive label.
  - ✅ `MAX_RETRY_COUNT`, `DEFAULT_POSTING_DATE_FORMULA`
  - ❌ Magic number `3` or string `'POSTED'` inline

## Code Organization & DRY

- **Duplicated logic within an object** — extract into a shared local procedure.
  - Flag: two or more blocks with near-identical logic (filtering, validation, calculation).
- **Duplicated logic across objects** — extract into a shared codeunit.
  - Flag: same validation or calculation pattern appears in multiple codeunits or pages.
- **Copy-pasted event subscribers** — consolidate into a common handler procedure or codeunit.
  - Flag: multiple subscribers with identical bodies differing only in the source table/page.
- **Hardcoded values** that belong in a setup table field or enum.
  - Flag: literal option values, status codes, or posting group codes embedded in logic.
  - ✅ `SetupRec."Default Posting Group"` or `Enum::Posted`
  - ❌ `'DOMESTIC'`, `2` (meaning "Posted")
- **Validation logic duplicated** between page triggers and codeunits — centralize in table `OnValidate` triggers or a dedicated validation codeunit.
- **Long procedures** (>50 lines) mixing multiple concerns — split by responsibility.
  - Flag: a single procedure that validates, calculates, filters, and posts.

## Event-Based Extensibility

- **Direct object modifications** where an event subscriber would be more maintainable.
  - Flag: modifying base logic inline when the standard object publishes relevant events.
- **Missing event publishers** at natural extensibility points.
  - Flag: procedures that perform multi-step business logic without `OnBefore`/`OnAfter` integration events.
  - ✅ `[IntegrationEvent(false, false)] local procedure OnBeforePostDocument(...)` 
- **Business logic in page triggers** instead of table triggers or codeunits.
  - Flag: complex validation, calculation, or posting logic in `OnValidate`, `OnAction` page triggers.
  - This logic is harder to extend via events and cannot be reused from other entry points.
- **Tightly coupled objects** that should communicate via events.
  - Flag: Codeunit A directly calls internal procedures of Codeunit B instead of raising an event.

## Formatting & Readability

- **Inconsistent begin-end blocks** — if some single-statement conditions use `begin..end` and others don't within the same procedure, flag the inconsistency.
- **Binary operator spacing** — operators (`+`, `-`, `*`, `/`, `:=`, `<>`, `>=`) should have consistent spacing.
  - ✅ `Amount := Quantity * UnitPrice;`
  - ❌ `Amount:=Quantity *UnitPrice;`
- **Comment spacing** — use a space after `//`.
  - ✅ `// Calculate total amount`
  - ❌ `//Calculate total amount`
- **Indentation** — must be consistent (typically 4 spaces in AL). Flag mixed indentation levels within the same block.
- **Multiple statements per line** — each statement should be on its own line.
  - ❌ `x := 1; y := 2; Validate();`
- **Keyword positioning** — `begin`, `end`, `then`, `do` should follow team convention consistently (line-start vs. inline).

## Pattern Consistency

- **If-else formatting** — use a consistent style for `end else begin` blocks throughout the codebase.
  ```al
  // Consistent style — pick one and stick with it:
  if Condition then begin
      DoSomething();
  end else begin
      DoOtherThing();
  end;
  ```
- **Blank lines** — maintain consistent blank line usage between procedures, between variable declarations and logic, and between logical sections within a procedure.
- **Compound statements** — if the team convention is to always use `begin..end` even for single statements, flag violations consistently (and vice versa).
- **Procedure naming** — verb-first PascalCase following BC conventions.
  - ✅ `CreateCustomer`, `ValidateEmail`, `PostSalesOrder`, `FindOpenEntries`
  - ❌ `CustomerCreation`, `EmailValidator`, `DoPost`, `ProcessStuff`
- **Event naming** — follow `OnBefore{Action}{Object}` / `OnAfter{Action}{Object}` pattern.
  - ✅ `OnBeforePostSalesOrder`, `OnAfterInsertCustomer`
  - ❌ `SalesOrderPosting`, `CustomerInserted`, `HandlePost`
- **Test naming** — use `GivenX_WhenY_ThenZ` pattern for test procedures.
  - ✅ `GivenPostedInvoice_WhenCreditMemoCreated_ThenEntriesReversed`
  - ❌ `TestCreditMemo`, `CreditMemoTest1`

## Refactoring Opportunities

- **Guard clauses over deep nesting** — prefer early `exit` or `Error` to reduce indentation depth.
  ```al
  // ❌ Deep nesting
  if Customer.Find() then
      if Customer."Credit Limit" > 0 then
          if not Customer.Blocked then
              PostOrder();

  // ✅ Guard clauses
  if not Customer.Find() then
      exit;
  if Customer."Credit Limit" = 0 then
      exit;
  if Customer.Blocked then
      exit;
  PostOrder();
  ```
- **Boolean expression simplification** — apply De Morgan's laws, eliminate double negatives.
  - ✅ `if IsPosted and HasPermission then`
  - ❌ `if not (not IsPosted or not HasPermission) then`
- **Extract method for complex conditionals** — replace multi-part boolean expressions with a descriptive procedure.
  - ✅ `if IsEligibleForDiscount(Customer) then`
  - ❌ `if (Customer.Balance > 1000) and (Customer."Payment Terms Code" = 'NET30') and (not Customer.Blocked) then`
- **Replace magic numbers/strings** with named constants or enum values.
  - ✅ `if Status = Status::Released then`
  - ❌ `if Status = 2 then`
- **Replace if-else chains with case statements** when checking the same variable.
  ```al
  // ❌ If-else chain
  if Type = 'ITEM' then ... else if Type = 'RESOURCE' then ... else if Type = 'G/L' then ...

  // ✅ Case statement
  case Type of
      'ITEM': ...;
      'RESOURCE': ...;
      'G/L': ...;
  end;
  ```
- **Simplify record filtering** — use readable filter patterns and avoid redundant `Reset` calls immediately after `Init` or declaration.

---

**Review principle:** Flag issues found in the diff with specific line references. Suggest the minimal change needed — do not propose large-scale refactors unless the diff itself introduces the problem. Prioritize issues that affect correctness and extensibility over pure style preferences.
