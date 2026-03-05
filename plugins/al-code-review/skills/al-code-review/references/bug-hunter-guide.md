# AL Bug Hunter Guide

This guide is a reference for AI code review agents analyzing AL/Business Central pull request diffs.
Its purpose is to identify **bugs, runtime errors, and data integrity risks** — not style issues.
Each category lists concrete defect patterns with brief explanations of why they matter.

---

## Case Statement Defects

- **Missing `else` clause** —
  When a `case` statement handles specific enum/option values but has no `else`,
  any unhandled value causes silent no-op execution. This is especially dangerous
  when enum extensions add new values that the original code never anticipated.

- **No input validation before `case`** —
  If the expression evaluated by `case` can be blank, zero, or uninitialized,
  execution silently skips all branches. Validate or assert before entering case logic.

- **Type mismatch between expression and values** —
  Comparing an Enum to an Integer (or vice versa) compiles but produces
  unexpected runtime matching behavior.

- **Enum extension risk** —
  Other AppSource extensions can extend your enums. Without an `else` clause
  (ideally with `Error()`), new values are silently ignored.
  Always add: `else Error('Unsupported value %1', MyEnum)`.

- **Generic or missing error in `else`** —
  An `else` that calls `Error('An error occurred')` without including the
  offending value is nearly impossible to diagnose in production. Always include
  the variable value and context in the error message.

---

## Null Reference & Uninitialized State

- **Unchecked `Get` calls** —
  `Record.Get(PK)` throws a runtime error if the record doesn't exist.
  Use `if not Record.Get(PK) then` or handle the failure explicitly
  unless the record is guaranteed to exist.

- **Unchecked `FindFirst` / `FindSet`** —
  These return `Boolean`. Accessing fields after a failed find reads stale
  or default values. Always check the return: `if Record.FindFirst() then`.

- **Accessing Option/Enum before initialization** —
  Option and Enum variables default to ordinal 0 (the first value). If business
  logic assumes a deliberate assignment, this causes wrong-path execution.

- **Unassigned variables in conditional branches** —
  When a variable is assigned inside an `if` but used after the block, the
  `else` path leaves it uninitialized (default zero/empty). Ensure all code
  paths assign the variable, or initialize it before the branch.

- **Calling procedures on uninitialized Codeunit variables** —
  Codeunit variables declared but never instantiated (or not set via
  `Codeunit.Run`) will cause runtime errors when their procedures are called.

---

## Scope & Control Flow Bugs

- **Begin-end block mismatch** —
  A statement intended to execute inside a `begin..end` block is accidentally
  placed outside it. This is the AL equivalent of a dangling-statement bug.
  Review indentation against actual `begin..end` boundaries.

- **`else` binding to wrong `if`** —
  In nested `if` statements without `begin..end`, `else` binds to the nearest
  `if`. This is a frequent source of logic inversion. When nesting, always use
  explicit `begin..end`.

- **Dead code after early exit** —
  An `else` branch after an `if` that contains `exit` or `Error()` is
  unreachable. While not a runtime bug, it signals confused logic and can mask
  real defects during future edits.

- **Missing `exit` after case branch logic** —
  If code after a `case` statement should only run for unhandled values, but
  there's no `exit` in the handled branches, it executes unconditionally.

- **Non-terminating `repeat..until`** —
  A loop whose `until` condition depends on state that the loop body never
  modifies will run forever. Check that loop variables are updated within
  the body.

---

## Data Integrity Risks

- **Missing `TestField` before posting** —
  Critical fields like `"Posting Date"`, `"Gen. Bus. Posting Group"`, and
  `"No."` must be validated with `TestField` before posting routines. Missing
  checks allow invalid documents to post, creating corrupt ledger entries.

- **`Modify(true)` vs `Modify(false)`** —
  `Modify(true)` runs `OnModify` triggers; `Modify(false)` does not. Using
  `true` in high-volume loops causes severe performance degradation. Using
  `false` when triggers enforce business rules causes data corruption. Be
  intentional about the choice.

- **`Insert(true)` in batch operations** —
  Triggers on insert can fire validation, number series, and event subscribers.
  In batch/migration scenarios, this causes unexpected overhead or errors.
  Use `Insert(false)` when triggers are not needed.

- **Missing `LockTable`** —
  When reading a record, modifying it, and writing it back, another session
  can modify the same record between the read and write. Use `LockTable`
  before the read to prevent lost updates.

- **`Commit()` before validation completes** —
  A `Commit()` writes all pending changes to the database. If subsequent
  validation fails and raises an error, the already-committed data cannot
  be rolled back, leaving the database in an inconsistent state.

- **`DeleteAll(true)` with expensive triggers** —
  `DeleteAll(true)` fires `OnDelete` for every record individually. On large
  tables with complex triggers, this can cause timeouts. Use `DeleteAll(false)`
  when trigger execution is not required, or process in batches.

---

## Testability Code Smells (Bug Indicators)

These are not bugs themselves, but structural patterns that reliably correlate
with hidden bugs and make defects harder to catch in testing.

- **Direct table access in business logic** —
  Procedures that directly read/write BC tables (e.g., `Customer.Get(...)`
  inline) are tightly coupled to storage. This makes unit testing impossible
  and hides data-dependent bugs.

- **Hardcoded external service calls** —
  HTTP requests, file I/O, or web service calls without an abstraction layer
  (interface or codeunit indirection) cannot be mocked in tests. Failures in
  these paths go undetected until production.

- **Mixed data access and business logic** —
  A single procedure that queries records, applies business rules, and writes
  results is doing too much. Bugs hide at the boundaries between these
  responsibilities.

- **Configuration-driven branching** —
  Large `case Setup."Integration Type" of` blocks that switch behavior based
  on setup values are a sign that an interface pattern should be used instead.
  Each new type added risks breaking existing branches.

- **Tests using `DeleteAll` in setup** —
  Test procedures that wipe tables before running indicate the test depends on
  database state rather than testing isolated logic. These tests are fragile
  and often mask bugs in the code under test.

---

## Error Handling Deficiencies

- **No error handling around external calls** —
  HTTP calls (`HttpClient.Send`), file operations (`File.Open`), and XMLport
  processing can all fail at runtime. Wrapping these in
  `if not TryFunction() then` or checking return values is mandatory.

- **Generic error messages** —
  `Error('Something went wrong')` provides zero diagnostic value. Include the
  operation attempted, the record/key involved, and the actual error:
  `Error('Failed to post Sales Invoice %1: %2', SalesHeader."No.", GetLastErrorText())`.

- **Swallowed errors in try functions** —
  A `[TryFunction]` that catches an error but neither logs it nor re-raises
  it hides failures. At minimum, log to telemetry with `Session.LogMessage()`.

- **Missing `if not TryFunction() then` pattern** —
  For recoverable operations (e.g., sending an email, calling an external API),
  use the try-function pattern to handle failure gracefully instead of letting
  the error crash the entire transaction.

---

## Transaction & Concurrency

- **`Commit()` inside loops** —
  Each `Commit()` creates a separate database transaction. Inside a loop
  processing N records, this produces N transactions instead of one atomic
  operation. If iteration K fails, records 1 through K-1 are already committed
  and cannot be rolled back.

- **Missing record locking (read-modify-write)** —
  The pattern `Get → modify fields → Modify` without `LockTable` is a race
  condition. Two sessions can read the same record, both modify it, and the
  second write silently overwrites the first.

- **Inconsistent `if Codeunit.Run then` usage** —
  `Codeunit.Run` isolates errors in a separate transaction. Mixing direct
  calls and `Codeunit.Run` calls to the same logic creates inconsistent
  transaction boundaries, making it unclear what gets rolled back on failure.

- **Lock escalation in nested calls** —
  When procedure A locks and modifies Table X, then calls procedure B which
  also modifies Table X, SQL Server may escalate row locks to table locks.
  This causes blocking and deadlocks under concurrent load. Review nested
  call chains for overlapping table access.
