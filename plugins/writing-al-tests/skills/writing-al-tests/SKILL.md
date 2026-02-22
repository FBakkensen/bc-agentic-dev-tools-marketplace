---
name: writing-al-tests
description: "Write, modify, and verify Business Central AL tests with DEBUG telemetry and Red-Green-Refactor. Use for any changes to `test/src/` (required), adding DEBUG-TEST-START and DEBUG-BRANCH-* checkpoints, verifying `.output/TestResults/telemetry.jsonl`, and cleaning DEBUG markers; not for production telemetry or running tests only (use /al-build)."
---

# Write AL Tests with DEBUG Telemetry

## Invocation

| Command | Action |
|---------|--------|
| `/writing-al-tests` | Write or fix AL tests with DEBUG telemetry verification |

## Required Rules

- Keep `DEBUG-*` telemetry at zero at task start and end.
- Insert `DEBUG-TEST-START` as the first line after variable declarations.
- Verify telemetry manually; do not parse or assert telemetry in AL tests.

## Quick Procedure

1. Add `DEBUG-TEST-START` telemetry to each test.
2. Add `DEBUG-BRANCH-*` checkpoints in production code at decision points.
3. Run tests via [al-build](../al-build/SKILL.md).
4. Verify the correct path in `.output/TestResults/telemetry.jsonl`.
5. Remove **all** `DEBUG-*` telemetry from both test and production code.

## Quick Start Snippet

Use this as the first line after variable declarations:
```al
FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', '<ExactProcedureName>');
```

## Compatibility

- Expect `test/src/` and `app/src/` to exist.
- Expect telemetry output at `.output/TestResults/telemetry.jsonl`.
- Expect `Feature Telemetry` codeunit to be available for `LogUsage`.

## Edge Cases

- If any `DEBUG-*` telemetry exists at task start, remove or complete the prior work before proceeding.
- If tests share code paths, rely on `DEBUG-TEST-START` to correlate logs to the correct test.
- If code under test calls `Commit()`, avoid `AutoRollback` and follow the transaction model guidance.

## Plan with Red-Green-Refactor

**Red (Design):**
- Identify test scenarios to cover.
- Plan `DEBUG-*` checkpoints for verification.
- Determine which code paths need proof of execution.

**Green (Implementation):**
- Write tests with `DEBUG-TEST-START`.
- Add `DEBUG-*` checkpoints in production code at decision points.
- Run tests and verify telemetry.jsonl shows correct paths.

**Refactor (Cleanup):**
- Remove all `DEBUG-*` telemetry from test and production code.
- Verify zero `DEBUG-*` calls remain.

## TodoWrite Checklist

```
1. [Red] Add DEBUG-TEST-START to <TestName>
2. [Red] Add DEBUG-BRANCH-* checkpoints to <ProductionCode>
3. [Green] Run al-build and verify test passes
4. [Green] Verify correct path in telemetry.jsonl
5. [Refactor] Remove DEBUG-* from production code
6. [Refactor] Remove DEBUG-TEST-START from test code
7. [Refactor] Verify zero DEBUG-* calls remain
```

## Reference Documentation

| Topic | Reference |
|-------|-----------|
| DEBUG telemetry lifecycle, false positive problem, correlation | [telemetry-workflow.md](references/telemetry-workflow.md) |
| Transaction model guidance (AutoRollback, AutoCommit) | [transaction-model.md](references/transaction-model.md) |
| Debugging BC standard code via event subscribers | [bc-event-subscriber-pattern.md](references/bc-event-subscriber-pattern.md) |
| Test codeunit template | [TestTemplate.Codeunit.al](references/TestTemplate.Codeunit.al) |

## Related Skills

| Skill | Purpose |
|-------|---------|
| [al-build](../al-build/SKILL.md) | Run tests and get results |
| [bc-standard-reference](../bc-standard-reference/SKILL.md) | Find BC events for event subscriber pattern |
| [al-object-id-allocator](../al-object-id-allocator/SKILL.md) | Allocate IDs for new test codeunits |

## Validation (Optional)

If the skill validator CLI is available in your environment, run:

```
skills-ref validate .agents/skills/writing-al-tests
```
