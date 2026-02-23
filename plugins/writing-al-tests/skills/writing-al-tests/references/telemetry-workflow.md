# Execution Markers Workflow (DEBUG Telemetry)

Execution Markers are temporary `DEBUG-*` telemetry calls that prove which code path a test exercised. They are the third layer of TDD trust: while the Three Laws ensure tests drive code (process discipline) and ZOMBIES ensures the right scenarios in the right order (coverage direction), Execution Markers provide **execution proof** -- evidence that the intended code path actually ran.

## Assertions vs Execution Markers

**They verify different things:**

| Tool | Verifies | Question Answered |
|------|----------|-------------------|
| Assertions | Production code behavior | "Does the code produce correct output?" |
| DEBUG telemetry | Test setup correctness | "Did we exercise the intended code path?" |

## The False Positive Problem

Assertions can pass even when test setup is wrong. Example:
- Test intends to verify "Sales Line branch" produces Quantity=7
- Assertion passes: `Assert.AreEqual(7, ActualQuantity)`
- But test setup was wrong—code actually took the "Config Header branch"
- That branch also happened to produce Quantity=7 (coincidence)
- Without production telemetry, you cannot detect this

**Why this matters especially for AI agents:** An AI agent writing tests cannot observe execution in a debugger. It infers correctness from assertion results alone. When assertions pass coincidentally (as above), the AI agent has no way to detect the problem without Execution Markers. This is why Execution Markers are not optional scaffolding -- they are the primary mechanism by which an AI agent verifies its own test setup.

**Solution: Production code telemetry proves which path ran:**
- `DEBUG-TEST-START` in test → identifies which test is running
- `DEBUG-*` in production → proves which branch executed
- Correlation → confirms "Test X exercised code path Y"

## DEBUG Telemetry is Always Temporary

**Expected starting state:** Zero `DEBUG-*` telemetry calls in both production code (`app/src/`) and test code (`test/src/`).

**Why:** DEBUG telemetry is temporary scaffolding for proving code paths during development. It is NOT production instrumentation. If you find existing DEBUG-* calls, they indicate incomplete previous work.

**Lifecycle:**
1. Start clean (expect no DEBUG-* anywhere)
2. Add DEBUG-* calls during Red phase to prove execution
3. Verify in telemetry.jsonl during Green phase
4. **Remove ALL DEBUG-* calls during Refactor phase** (REQUIRED)
5. End clean (no DEBUG-* anywhere)

**If you find existing DEBUG-* calls:**
- Complete the previous work (remove them after verification), OR
- Remove them immediately if they're orphaned from abandoned work

## Mandatory: Test-Start Telemetry Checkpoint

Every test procedure MUST begin with a telemetry checkpoint immediately after variable declarations:

```al
[Test]
procedure GivenX_WhenY_ThenZ()
var
    FeatureTelemetry: Codeunit "Feature Telemetry";
    // other variables...
begin
    // FIRST LINE - Always add this checkpoint
    FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', 'GivenX_WhenY_ThenZ');

    // [SCENARIO] ...
    // [GIVEN] ...
    // [WHEN] ...
    // [THEN] ...
end;
```

### Why Test-Start Telemetry is Critical

Production code telemetry (e.g., pricing calculations, rule evaluations) can emit from multiple tests. Without test-start markers:
- Cannot determine which test triggered a specific log entry
- Cannot correlate DEBUG-* checkpoints in production code to the test that exercised them
- Cannot isolate test failures when multiple tests touch the same code paths

With test-start markers in `telemetry.jsonl`:
```json
{"eventId":"DEBUG-TEST-START","message":"GivenX_WhenY_ThenZ",...}
{"eventId":"DEBUG-PRICING-CALC","message":"Configuration method selected",...}
{"eventId":"DEBUG-COMPONENT-TOTAL","message":"Sum: 150.00",...}
```

Now you can grep for your test name and see all subsequent logs belong to that test.

## Red Phase: Add Temporary Telemetry

**Step A (REQUIRED):** Add test-start checkpoint as FIRST line after declarations:
```al
FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', '<ExactProcedureName>');
```

**Step B (REQUIRED):** Add branch checkpoints in PRODUCTION code at decision points:
```al
// In the function under test (production code)
if SalesLine.FindFirst() then begin
    FeatureTelemetry.LogUsage('DEBUG-BRANCH-SALESLINE', 'FeatureName', 'Sales Line found');
    // ... Sales Line path
end else begin
    FeatureTelemetry.LogUsage('DEBUG-BRANCH-NOSALESLINE', 'FeatureName', 'Using Config Header');
    // ... Config Header path
end;
```

Rules:
- Use `FeatureTelemetry.LogUsage()` (not `Session.LogMessage()`)
- Use exact procedure name in test-start for grep-ability
- Keep event IDs stable and searchable (DEBUG-TEST-START, DEBUG-BRANCH-*)
- Use `Format()` for non-text values in custom dimensions
- Production code markers are REQUIRED—they verify test setup correctness

## Green Phase: Verify Path Execution

1. Run the full test gate (see [al-build](../../al-build/SKILL.md))
2. Confirm test pass/fail in `.output/TestResults/last.xml`
3. Manually confirm expected branch ran in `.output/TestResults/telemetry.jsonl`

Useful telemetry fields: `eventId`, `message`, `testCodeunit`, `testProcedure`, `callStack`, `customDimensions`

## Refactor Phase: Remove Temporary Logs

Once tests are verified and green, delete **all** `DEBUG-*` telemetry from both locations:

**Production code:**
- Remove branch checkpoints (e.g., `DEBUG-PRICING-CALC`, `DEBUG-COMPONENT-TOTAL`)
- Keep only long-lived production instrumentation (non-DEBUG event IDs)

**Test code:**
- Remove test-start checkpoints (`DEBUG-TEST-START`)
- Remove any other `DEBUG-*` calls added for verification

Both must be cleaned up—leaving DEBUG telemetry in either location pollutes logs and signals incomplete work.

## Telemetry Correlation Example

After running tests, `telemetry.jsonl` shows execution order:

```
Test 1: GivenSalesLineExists...
  DEBUG-TEST-START → GivenSalesLineExists...
  DEBUG-BRANCH-SALESLINE → Sales Line found     ✓ Correct path

Test 2: GivenNoSalesLine...
  DEBUG-TEST-START → GivenNoSalesLine...
  DEBUG-BRANCH-NOSALESLINE → Using Config Header  ✓ Correct path
```

**If wrong telemetry appears, test setup is broken:**
```
Test 1: GivenSalesLineExists...  (expects SALESLINE branch)
  DEBUG-TEST-START → GivenSalesLineExists...
  DEBUG-BRANCH-NOSALESLINE → Using Config Header  ✗ WRONG PATH!
```

This catches bugs that assertions cannot—the assertion might still pass if both paths produce the same value.

## Analyzing Telemetry

After running tests, correlate logs to specific tests:

```text
# Example (rg)
rg "GivenX_WhenY_ThenZ" .output/TestResults/telemetry.jsonl
rg "DEBUG-TEST-START" .output/TestResults/telemetry.jsonl
```

```powershell
# Example (PowerShell)
Select-String -Path .output/TestResults/telemetry.jsonl -Pattern "GivenX_WhenY_ThenZ"
Select-String -Path .output/TestResults/telemetry.jsonl -Pattern "DEBUG-TEST-START"
```

In `telemetry.jsonl`, logs appear in execution order. After a `DEBUG-TEST-START` entry, all subsequent logs belong to that test until the next `DEBUG-TEST-START`.

## Same-Publisher Requirement

`FeatureTelemetry.LogUsage` calls are captured by a Telemetry Logger codeunit that subscribes to telemetry events. This subscriber must be in the **same publisher** as the emitting code. If your test extension (`test/app.json`) and app extension (`app/app.json`) have different `publisher` values, Execution Markers will silently fail to appear in `telemetry.jsonl`.

**Diagnostic checklist:**
- `app/app.json` publisher matches `test/app.json` publisher
- Telemetry Logger codeunit is present in the test extension
- `telemetry.jsonl` shows `DEBUG-TEST-START` entries after running tests (smoke test)

If `DEBUG-TEST-START` does not appear in telemetry.jsonl after a test run, the same-publisher requirement is the most common cause.
