# Phase 2: Implementation

**Goal**: Implement feature using Red-Green-Refactor TDD.

## Reference the Repository's Test-Writing Guidance

Use the repository's AL test-writing guidance (for example, `/writing-al-tests`) for:
- DEBUG telemetry patterns
- Test-start checkpoints
- Red-Green-Refactor workflow
- BC event subscriber telemetry pattern

## Implementation Loop

### Pre-Flight (Required)

1. Confirm **zero `DEBUG-*` telemetry** exists at task start (both `app/src/` and `test/src/`).
2. Create a **TodoWrite** checklist for Red/Green/Refactor (per the test-guidance skill).
3. In every test, `DEBUG-TEST-START` must be the **first line after variable declarations**.

For each scenario (or batch of related scenarios):

### RED Phase

1. Write failing test with DEBUG telemetry:
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

1. Implement minimum code to pass

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
