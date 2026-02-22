---
name: tdd-implement
description: "Implements AL/Business Central features via TDD after planning is complete; use when issues include Architecture and Test Plan sections or when resuming implementation from a PR."
---

# TDD Implementation Workflow

## Overview

3-phase workflow for implementing features using TDD, starting from an issue that has completed planning (architecture + test plan). This skill focuses on outcomes and checkpoints, not specific tools. Use whatever tools your agent/environment provides.

> **Prerequisite**: Run `/refine-issue-for-automated-tests #123` first to complete planning phases.

## When to Use

- The issue already contains **Architecture** and **Test Plan** sections.
- You need to implement the feature and keep PR state in sync with TDD progress.
- You are resuming from an existing PR and need to continue the TDD cycle.

## When Not to Use

- Planning is incomplete or missing (use `/refine-issue-for-automated-tests`).
- Work is outside AL/Business Central or not using TDD.
- The task is release management, deployment, or production operations.

## Guidelines

- Validate planning completeness before any implementation.
- Treat the PR description as the source of truth for architecture, test plan, and progress.
- Follow Red-Green-Refactor for every scenario.
- Update progress and notes immediately after each phase.
- Pause for user confirmation before starting Phase 2.

## GitHub Operations

The workflow requires GitHub issue and PR access, but does not assume any specific tool.
Use any available method (web UI, API client, custom tool) to:
- Read issue and PR content/metadata
- Create or update PR descriptions and comments
- Change PR draft/ready status

## Formatting Verification (Required)

After **any** PR description or comment update:
- Re-read the updated content from GitHub using the same access method.
- Verify **basic structure** includes required headings in order, tables with header and separator rows, closed code/Mermaid fences, and required horizontal rules (`---`).
- If verification fails, **reapply the update once**, then re-read and verify again.
- If it still fails, **stop and report** the formatting mismatch.

## Do / Don't

**Do**
- Ensure a draft PR exists and contains Architecture, Test Plan, and Implementation Progress.
- Keep the progress table updated at every Red/Green/Refactor checkpoint.
- Remove all `DEBUG-*` telemetry before completing a scenario.
- Batch related scenarios conservatively (max 5) and document the batching decision.
- Surface blockers immediately and document them.

**Don't**
- Start implementation without Architecture and Test Plan sections.
- Leave `DEBUG-*` telemetry in code after refactor.
- Skip the RED failing-test verification.
- Reorder scenarios without documenting why.
- Mark a PR ready for review without completing the Review Checklist.

## Invocation

| Command | Action |
|---------|--------|
| `/tdd-implement #123` | Start from issue with planning complete |
| `/tdd-implement https://.../issues/123` | Start from issue with planning complete |
| `/tdd-implement #42 --pr` | Resume from existing PR |
| `/tdd-implement https://.../pull/42` | Resume from existing PR |

## Phase Overview

| Stage | Phases | Mode | Primary Focus |
|-------|--------|------|---------------|
| **Setup** | 1 | Branch/PR setup | Prepare feature branch and draft PR |
| **Implementation** | 2 | Code changes | Red-Green-Refactor TDD cycles |
| **Review** | 3 | Finalization | Code review, finalize PR |

## Workflow Phases

- [Phase 1: Setup](./phases/phase-1-setup.md) - Prepare branch and draft PR
- [Phase 2: Implementation](./phases/phase-2-implementation.md) - Red-Green-Refactor TDD
- [Phase 3: Review](./phases/phase-3-review.md) - Code review, finalize PR

## Resuming Work

For resume logic when starting from a PR, see [resume.md](./references/resume.md).

## Argument Detection

| Pattern | Type | Action |
|---------|------|--------|
| `#N` (no --pr) | Issue | Validate planning, start Phase 1 |
| `https://.../issues/N` | Issue | Validate planning, start Phase 1 |
| `#N --pr` | PR | Parse state, resume |
| `https://.../pull/N` | PR | Parse state, resume |

### Starting from Issue

1. Parse issue number
2. Validate issue has Architecture and Test Plan sections
3. Create task list for 3 phases
4. Begin [Phase 1](./phases/phase-1-setup.md)

### Resuming from PR

1. Parse PR number
2. Follow [resume logic](./references/resume.md) to determine phase
3. Continue from detected point

## Task List Structure

When starting new workflow, create tasks:

```
[Phase 1] Setup - Prepare branch and PR
[Phase 2] Implementation - Red-Green-Refactor cycles
[Phase 3] Review - Code review, finalize PR
```

## Optional Related Skills

Use these only if available in the environment:

| Skill | When Used |
|-------|-----------|
| `/writing-al-tests` | Phase 2 - DEBUG telemetry, R-G-R patterns |
| `/al-build` | Phase 2, 3 - Build and test |
| `/bc-standard-reference` | Phase 2 - BC events, patterns |
| `/al-object-id-allocator` | Phase 2 - New object IDs |

## Examples

**Start from issue:**
```
/tdd-implement #123
```

**Resume from PR:**
```
/tdd-implement #42 --pr
```

**Invalid (planning not complete):**
```
/tdd-implement #123
```
Expected: halt and recommend `/refine-issue-for-automated-tests #123` before implementation.

## References

- [PR Template](./references/pr-template.md) - PR description structure
- [Resume](./references/resume.md) - Resume from PR logic
