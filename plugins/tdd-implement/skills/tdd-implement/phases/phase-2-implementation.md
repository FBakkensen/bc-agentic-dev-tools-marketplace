# Phase 2: Implementation

**Goal**: Implement feature using Red-Green-Refactor TDD.

## Three Laws of TDD (Robert C. Martin)

These three laws govern every RED-GREEN-REFACTOR cycle. They enforce strict incrementalism -- each cycle produces the minimum possible change.

| Law | Rule | What This Means for the Agent |
|-----|------|-------------------------------|
| **Law 1** | Do not write production code until you have a failing unit test | Never create production AL objects before the test that requires them exists and fails |
| **Law 2** | Do not write more of a unit test than sufficient to fail (not compiling = failing) | A compilation error IS a failing test. Stop writing the test as soon as it fails to compile or fails an assertion |
| **Law 3** | Do not write more production code than sufficient to pass the currently failing test | Write the MINIMUM code to make the current test pass. Resist implementing logic for future scenarios |

**Why Law 3 matters for AI agents:** AI agents tend to implement complete solutions in one pass. This produces code that "works" but was never driven by tests. Each ZOMBIES step in the Scenario Inventory is designed to force a specific increment of production code. If you implement more than the minimum, you bypass this design-emergence mechanism.

**Practical enforcement:**
- Before writing ANY production code, ask: "Which specific failing test am I making pass?"
- After making a test pass, STOP. Do not add logic for the next scenario.
- If you realize the next scenario needs a loop but the current one does not, do NOT add the loop yet.

## Reference the Repository's Test-Writing Guidance

Use the repository's AL test-writing guidance (for example, `/writing-al-tests`) for:
- Execution Markers (`DEBUG-*` telemetry) -- temporary markers that prove which code path ran
- Test-start checkpoints
- Red-Green-Refactor workflow
- BC event subscriber telemetry pattern

## Implementation Loop

### Pre-Flight (Required)

1. Confirm **zero `DEBUG-*` telemetry** exists at task start (both `app/src/` and `test/src/`).
2. Create a **TodoWrite** checklist for Red/Green/Refactor (per the test-guidance skill).
3. In every test, `DEBUG-TEST-START` must be the **first line after variable declarations**.

### ZOMBIES-Driven Ordering

Process scenarios in the order they appear in the Scenario Inventory (which follows ZOMBIES progression from planning). Each scenario is designed to force the next minimal increment of production code:

- **Z/O scenarios**: Expect simple, straight-line production code (no loops, no complex branching)
- **M scenarios**: Expect loops and aggregation to emerge (`FindFirst` becomes `FindSet` + `repeat..until`)
- **B scenarios**: Expect boundary checks and validation to emerge
- **I scenarios**: Expect event signatures and interface contracts to emerge
- **E scenarios**: Expect error handling and guard clauses to emerge

Do NOT reorder scenarios unless you document the reason in a PR comment. The ZOMBIES order is intentional -- it ensures design emerges incrementally.

For each scenario (or batch of related scenarios):

### RED Phase

1. Write failing test with DEBUG telemetry **(Law 1: test first. Law 2: stop at first failure -- a compile error counts)**:
   ```al
   [Test]
   procedure ScenarioName()
   var
       FeatureTelemetry: Codeunit "Feature Telemetry";
   begin
       FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', 'ScenarioName');

       // [SCENARIO] ...
       // [GIVEN] ...
       // [WHEN] ...
       // [THEN] ...
   end;
   ```

2. Add DEBUG branch markers in production code locations

3. Execute the repository's standard build/test process using available tooling - test should FAIL (RED)

4. Verify DEBUG telemetry appears in the expected telemetry output (for example, `.output/TestResults/telemetry.jsonl`)

### GREEN Phase

1. Implement **minimum** code to pass the currently failing test **(Law 3: nothing more)**
   - If the Scenario Inventory shows this is a Z or O step, the production code should be trivially simple (no loops, no complex branching)
   - If this is an M step, a loop may now emerge -- this is the expected design progression

2. Execute the repository's standard build/test process using available tooling - test should PASS (GREEN)

3. Verify correct code path in telemetry

### REFACTOR Phase

1. Clean up code if needed

2. **Remove ALL DEBUG-* telemetry** from both test and production code

3. Execute the repository's standard build/test process using available tooling - tests still pass

4. Verify zero DEBUG-* calls remain

## Progress Tracking

After each scenario completes:

1. Update PR progress table:
   ```markdown
   | 1 | Scenario 1 | [x] | [x] | [x] | Complete |
   ```

2. Add PR comment documenting completion.

3. Re-read the PR description and comment from GitHub to verify basic structure: progress table header and separator rows, checkbox syntax preserved, and any fences opened/closed correctly. If verification fails, reapply the update once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

## Batching Strategy

Group related scenarios that:
- Test the same procedure
- Share similar setup
- Have sequential dependencies

Max 5 scenarios per batch. Document batching decisions in PR comments.

## Progress Table States

The Implementation Progress table uses checkboxes to track TDD phases:

### Checkbox Meanings

| Column | Checked Means |
|--------|---------------|
| Red | Test written and failing |
| Green | Implementation complete, test passing |
| Refactor | Code cleaned, DEBUG telemetry removed |

### Status Values

| Status | Meaning |
|--------|---------|
| Not started | No work begun |
| In progress | Currently being worked on |
| Complete | All three phases done |
| Blocked | Cannot proceed (document reason) |

### Example Progression

**Starting:**
```markdown
| 1 | Happy path | [ ] | [ ] | [ ] | Not started |
```

**After RED phase:**
```markdown
| 1 | Happy path | [x] | [ ] | [ ] | In progress |
```

**After GREEN phase:**
```markdown
| 1 | Happy path | [x] | [x] | [ ] | In progress |
```

**After REFACTOR phase:**
```markdown
| 1 | Happy path | [x] | [x] | [x] | Complete |
```

## Success Criteria

- All scenarios are marked Complete in the progress table.
- Tests pass and required behavior is verified.
- All `DEBUG-*` telemetry has been removed.
- Progress updates and completion notes are recorded in the PR.
