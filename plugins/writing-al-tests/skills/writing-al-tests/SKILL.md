---
name: writing-al-tests
description: "Write, modify, and verify Business Central AL tests with Execution Markers (DEBUG telemetry) and Red-Green-Refactor. Use for any changes to `test/src/` (required), adding DEBUG-TEST-START and DEBUG-BRANCH-* checkpoints, verifying `.output/TestResults/telemetry.jsonl`, and cleaning DEBUG markers; not for production telemetry or running tests only (use /al-build)."
---

# Write AL Tests with Execution Markers

## Invocation

| Command | Action |
|---------|--------|
| `/writing-al-tests` | Write or fix AL tests with DEBUG telemetry verification |

## Required Rules

- Keep `DEBUG-*` telemetry at zero at task start and end.
- Insert `DEBUG-TEST-START` as the first line after variable declarations.
- Verify telemetry manually; do not parse or assert telemetry in AL tests.
- The test and app extensions must share the same publisher in `app.json` for Execution Markers to work (same-publisher requirement).

## What Are Execution Markers?

Execution Markers are temporary `FeatureTelemetry.LogUsage` calls placed at decision points in production code to prove which code path a test actually exercised. In this skill, all `DEBUG-*` telemetry calls are Execution Markers.

### Why AI Agents Need Execution Markers

AI agents can produce tests that pass assertions but never hit the intended code path. Unlike a human developer who watches a debugger step through code, an AI agent has no visibility into execution flow. Execution Markers are the AI agent's equivalent of stepping through code in a debugger.

**The Three Layers of Trust in TDD:**

| Layer | What It Proves | How |
|-------|---------------|-----|
| Process discipline | Tests drive production code | Three Laws of TDD (see `/tdd-implement`) |
| Coverage direction | Right scenarios in right order | ZOMBIES ordering (see `/refine-issue-for-automated-tests`) |
| Execution proof | Correct code path was hit | Execution Markers (`DEBUG-*` telemetry in this skill) |

All three layers together provide confidence that tests are genuine, not false positives.

### Same-Publisher Requirement

The `Feature Telemetry` codeunit requires that the Telemetry Logger subscriber is in the **same publisher** as the code emitting telemetry. If your test extension and app extension have different publishers, `FeatureTelemetry.LogUsage` calls will not be captured in `telemetry.jsonl`. Ensure both extensions share the same publisher in their `app.json`.

## Quick Procedure

1. Add `DEBUG-TEST-START` Execution Marker to each test.
2. Add `DEBUG-BRANCH-*` Execution Markers in production code at decision points.
3. Run tests via [al-build](../al-build/SKILL.md).
4. Verify the correct path in `.output/TestResults/telemetry.jsonl`.
5. Remove **all** `DEBUG-*` Execution Markers from both test and production code.

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
| Execution Markers lifecycle, false positive problem, correlation | [telemetry-workflow.md](references/telemetry-workflow.md) |
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
