# Transaction Model Best Practices

## Default: Do NOT Specify `[TransactionModel]`

Microsoft's standard BC tests (40,000+ test methods) rely on the **TestRunner's `TestIsolation` property** rather than individual test attributes. Only ~3% of BC standard tests specify `[TransactionModel]`.

## How Isolation Works in BC

| Level | Where Configured | Effect |
|-------|------------------|--------|
| TestRunner | `TestIsolation` property on test runner codeunit | Controls rollback for all tests run by that runner |
| Test Method | `[TransactionModel]` attribute | Overrides TestRunner for that specific test |

## When to Use `[TransactionModel]` (Exceptions Only)

| Attribute | Use When |
|-----------|----------|
| `[TransactionModel(AutoRollback)]` | Testing pure logic that MUST NOT call `Commit()`. Will ERROR if code under test commits. |
| `[TransactionModel(AutoCommit)]` | Testing code that calls `Commit()` (posting routines, job queue, background sessions). Requires explicit cleanup. |
| `[TransactionModel(None)]` | Simulating real user behavior where each page interaction is a separate transaction. Rare. |

## Why NOT to Default to AutoRollback

1. Breaks if production code calls `Commit()` (posting, background jobs)
2. Duplicates TestRunner isolation if already configured
3. Inconsistent with Microsoft's own test patterns
4. Limits ability to test realistic business scenarios

## Test Template Reference

When creating new test codeunits, follow the structure in [TestTemplate.Codeunit.al](./TestTemplate.Codeunit.al).

**Key elements:**
1. Subtype = Test, Access = Internal
2. `FeatureTelemetry` and `IsInitialized` variables
3. Gherkin comments: `[SCENARIO]`, `[GIVEN]`, `[WHEN]`, `[THEN]`
4. `Initialize()` procedure with IsInitialized guard
5. Test-start telemetry as first line after declarations
6. **No `[TransactionModel]` by default** — let TestRunner handle isolation

## New Test Codeunit Setup

1. Create file in appropriate folder: `test/src/Workflows/<Feature>/<Feature>Test.Codeunit.al`
2. Allocate a new object ID (see [al-object-id-allocator](../../al-object-id-allocator/SKILL.md))
3. Only add `[TransactionModel]` if you have a specific reason (see table above)
