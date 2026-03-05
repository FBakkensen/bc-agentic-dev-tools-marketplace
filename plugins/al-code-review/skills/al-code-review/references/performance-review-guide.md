# AL Performance Review Guide

This guide is a reference for AI code review agents analyzing AL/Business Central pull request diffs for performance issues. Use it to identify concrete anti-patterns, inefficient data access, and suboptimal AL constructs. Flag only issues visible in the diff — do not speculate about code outside the changeset.

---

## Boolean Expression Optimization

- **Short-circuit evaluation order**: In `AND` expressions, place the condition most likely to be `false` first so the second condition is skipped more often. In `OR` expressions, place the condition most likely to be `true` first.
  ```al
  // Bad — expensive call evaluated even when Status is wrong
  if ExpensiveLookup() and (Status = Status::Open) then
  // Good — cheap check first, short-circuits the expensive call
  if (Status = Status::Open) and ExpensiveLookup() then
  ```
- **Eliminate double negatives**: Replace `not (not Condition)` with `Condition`. Negated compound expressions like `not (A or B)` should become `(not A) and (not B)` only if it improves readability.
- **Remove redundant conditions**: If a prior branch already guarantees a state (e.g., `Status = Status::Active`), a subsequent `Status <> Status::Inactive` check is redundant and adds noise.
- **Extract complex boolean expressions**: When a boolean expression spans multiple conditions, extract it into a named boolean variable. This improves readability and gives the compiler a single evaluation point.
  ```al
  IsEligibleForDiscount := (Customer."Credit Limit" > 0) and (not Customer.Blocked) and (SalesHeader."Amount Including VAT" > 1000);
  if IsEligibleForDiscount then
  ```

---

## Record Access Patterns

- **Use the right Find method**:
  - `FindSet` — use when iterating over multiple records.
  - `FindFirst` / `FindLast` — use when you need exactly one record.
  - Avoid legacy `Find('-')` and `Find('+')` — they are less readable and functionally equivalent to `FindFirst`/`FindLast`.
- **Filter before FindSet**: Always apply `SetRange`/`SetFilter` before calling `FindSet`. Retrieving all records and filtering in AL code is far more expensive than letting the server filter.
  ```al
  // Bad
  if SalesLine.FindSet() then
      repeat
          if SalesLine."Document No." = DocNo then
              // process
      until SalesLine.Next() = 0;

  // Good
  SalesLine.SetRange("Document No.", DocNo);
  if SalesLine.FindSet() then
      repeat
          // process
      until SalesLine.Next() = 0;
  ```
- **Use SetLoadFields**: When only specific fields are needed (e.g., checking a status or summing a single column), call `SetLoadFields` to avoid loading the entire record from the database.
  ```al
  SalesHeader.SetLoadFields(Status, "No.");
  ```
- **Cache with temporary tables**: If the same record is retrieved via `Get` repeatedly inside a loop, load it once into a temporary record variable or a `Dictionary` and look it up from there.
- **CalcFields only when needed**: Do not call `CalcFields` speculatively. Only calculate FlowFields when the value is actually consumed.
- **SetAutoCalcFields for loops**: When a FlowField is read on every iteration of a loop, call `SetAutoCalcFields` before `FindSet` instead of calling `CalcFields` inside the loop — it reduces per-record overhead.

---

## Loop Efficiency

- **Lonely repeat anti-pattern**: A `repeat...until` that always exits after one iteration is misleading. Replace with a straight `if FindFirst then` or a guarded `if FindSet then repeat...until`.
  ```al
  // Bad — "lonely repeat", always runs once
  SalesHeader.FindFirst();
  repeat
      ProcessHeader(SalesHeader);
  until SalesHeader.Next() = 0;

  // Good
  if SalesHeader.FindSet() then
      repeat
          ProcessHeader(SalesHeader);
      until SalesHeader.Next() = 0;
  ```
- **Don't loop to find a filterable record**: If the loop body checks a condition and breaks, the condition should be a filter instead.
- **IsEmpty over Count**: Do not call `Count` or `CountApprox` just to check whether records exist. `IsEmpty` is O(1) and does not scan the table.
  ```al
  // Bad
  if SalesLine.Count() > 0 then
  // Good
  if not SalesLine.IsEmpty() then
  ```
- **Avoid expensive calls in tight loops**: Procedure calls that perform database access, HTTP requests, or heavy computation should be hoisted out of inner loops or batched.

---

## Data Access & Query Optimization

- **Server-side filtering**: Always prefer `SetRange` and `SetFilter` over retrieving records and filtering in AL. The SQL engine is orders of magnitude faster at filtering.
- **Align filters with table keys**: Filters that match an existing key (primary or secondary) allow index seeks. Filters on non-indexed fields cause table scans. When reviewing, check if the filtered fields correspond to a defined key on the table.
- **Targeted CalcSums**: `CalcSums` computes the sum over the current filters. If you only need a partial sum, apply tighter filters rather than summing everything and subtracting.
- **Minimize database round-trips**: Batch related reads together. Avoid patterns where a single procedure makes dozens of small `Get` calls when a single filtered `FindSet` could retrieve all needed records.
- **Avoid unnecessary sorting**: Only apply `SetCurrentKey` when the sort order is actually required. Changing the key forces the server to use a potentially less efficient index.

---

## Variable & Memory Management

- **Narrow scope for variables**: Declare variables in the innermost procedure or block where they are used. AL scoping is procedure-level, so prefer smaller helper procedures to keep large buffers short-lived.
- **Clear large text and blob variables**: After processing large `Text`, `BigText`, or `Blob` (via `InStream`/`OutStream`) variables, call `Clear()` to release memory.
  ```al
  Clear(LargeTextBuffer);
  ```
- **Use temporary tables for in-memory work**: When building intermediate result sets, use a record variable with `Temporary` property instead of inserting into real tables. This avoids database writes and cleanup.
- **Minimize Commit() calls**: Each `Commit()` is a database round-trip that also ends the current write transaction. Avoid calling `Commit()` inside loops. Prefer a single `Commit()` after the entire batch completes.
  ```al
  // Bad — commit per record
  repeat
      ProcessAndModify(Rec);
      Commit();
  until Rec.Next() = 0;

  // Good — single commit after batch
  repeat
      ProcessAndModify(Rec);
  until Rec.Next() = 0;
  Commit();
  ```

---

## AL-Specific Anti-Patterns

- **Modify/Insert in loops vs. bulk operations**: When modifying or deleting all records matching a filter, prefer `ModifyAll` or `DeleteAll` over a `repeat...until` loop with individual `Modify`/`Delete` calls. Bulk operations execute as a single SQL statement.
  ```al
  // Bad
  if SalesLine.FindSet() then
      repeat
          SalesLine.Status := SalesLine.Status::Released;
          SalesLine.Modify();
      until SalesLine.Next() = 0;

  // Good
  SalesLine.ModifyAll(Status, SalesLine.Status::Released);
  ```
- **Init + full field assignment vs. TransferFields**: When copying most fields from one record to another, use `TransferFields` instead of `Init()` followed by individual field assignments. It is shorter, less error-prone, and avoids missing new fields added later.
- **Repeated Get with the same key**: Multiple `Get` calls with the same primary key value in the same procedure indicate a missing local variable cache. Retrieve once, store in a variable, and reuse.
  ```al
  // Bad
  Item.Get(SalesLine."No.");
  DoSomething(Item);
  // ... later in the same procedure ...
  Item.Get(SalesLine."No.");  // redundant round-trip
  DoSomethingElse(Item);

  // Good — retrieve once
  Item.Get(SalesLine."No.");
  DoSomething(Item);
  DoSomethingElse(Item);
  ```
- **FindSet(true) without modification**: `FindSet(true)` acquires an update lock. If the loop body does not modify the record, use `FindSet()` (without the parameter) to avoid unnecessary locking.
- **Text concatenation in loops**: Building large strings by repeated `+=` concatenation inside a loop creates O(n²) memory allocations. Use `TextBuilder` for incremental string construction.

---

## Review Checklist (Quick Reference)

When scanning a PR diff for performance issues, look for these signals:

| Signal | What to check |
|---|---|
| `Find('-')` or `Find('+')` | Replace with `FindFirst` / `FindLast` |
| `FindSet` without prior `SetRange`/`SetFilter` | Missing server-side filter |
| `Count` or `Count()` | Should it be `IsEmpty`? |
| `CalcFields` inside a loop | Use `SetAutoCalcFields` before the loop |
| `Get` called multiple times with same key | Cache in a local variable |
| `Modify()` / `Delete()` in a loop | Consider `ModifyAll` / `DeleteAll` |
| `Commit()` inside a loop | Move outside the loop |
| `FindSet(true)` | Is the record actually modified in the loop? |
| No `SetLoadFields` | Are all fields needed, or only a subset? |
| Complex boolean in `if` | Can it be extracted or reordered? |
