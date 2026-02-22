---
name: refine-issue-for-automated-tests
description: "AL/BC issue refinement workflow for GitHub issues. Produce architecture + automated test plan in the issue body"
---

# AL/BC Issue Refinement for Automated Tests

4-phase workflow for analyzing Business Central GitHub issues and producing AL architecture + automated test plans. Architecture and Test Plan are persisted in the GitHub issue body; Business Rules may be added as an issue comment.

> **Note**: This skill handles planning only. For implementation, use `/tdd-implement` after planning is complete.

## Invocation

| Command | Action |
|---------|--------|
| `/refine-issue-for-automated-tests #123` | Start from GitHub issue |
| `/refine-issue-for-automated-tests https://.../issues/123` | Start from GitHub issue |

## GitHub Actions (Tool-Agnostic)

- Retrieve issue details (title, body, labels, status)
- Update issue body (append/merge Architecture and Test Plan sections)
- Post issue comment (Business Rules Analysis)
- Preserve original issue description at the top

## Formatting Verification (Required)

After **any** issue body or comment update:
- Re-read the updated content from GitHub using the same access method.
- Verify **basic structure** includes required headings in order, tables with header and separator rows, closed code/Mermaid fences, and required horizontal rules (`---`).
- If verification fails, **reapply the update once**, then re-read and verify again.
- If it still fails, **stop and report** the formatting mismatch.

## Phase Overview

| Stage | Phases | Mode | Primary Focus |
|-------|--------|------|---------------|
| **Discovery** | 1-2 | Read-only | Issue analysis, codebase exploration, BC expert consultation |
| **Planning** | 3-4 | Design | Architecture design, test plan creation, issue updates |

## Workflow Phases

- [Phase 1: Discovery](./phases/phase-1-discovery.md) - Understand requirements from issue
- [Phase 2: Exploration](./phases/phase-2-exploration.md) - Explore codebase, ask questions
- [Phase 3: Architecture](./phases/phase-3-architecture.md) - Design approach, update issue
- [Phase 4: Test Plan](./phases/phase-4-test-plan.md) - Write Gherkin scenarios, update issue

## Argument Detection

| Pattern | Type | Action |
|---------|------|--------|
| `#N` | Issue | Start Phase 1 |
| `https://.../issues/N` | Issue | Start Phase 1 |

### Starting from Issue

1. Parse issue number
2. Create task list for 4 phases
3. Begin [Phase 1](./phases/phase-1-discovery.md)

## Task List Structure

When starting new workflow, create tasks:

```
[Phase 1] Discovery - Understand requirements
[Phase 2] Exploration - Explore patterns, ask questions
[Phase 3] Architecture - Design approach, update issue
[Phase 4] Test Plan - Write Gherkin scenarios, update issue
```

## Related Resources

- Business Central standard documentation and examples (events, patterns, tests)
- Existing project code patterns in the repo

## AL/BC Terminology Quick Reference

| Generic Term | AL/BC Term |
|--------------|------------|
| Component | AL Object (Codeunit, Table, Page, etc.) |
| Class | Codeunit |
| Data Model | Table / TableExtension |
| Factory | Library Codeunit (e.g., Library - Sales) |
| Unit Test | Test Procedure |
| Test Suite | Test Codeunit (`Subtype = Test`) |
| Hook/Event | IntegrationEvent / EventSubscriber |
| Interface | Interface (AL) |
| Enum | Enum |

## References

- [Issue Template](./references/issue-template.md) - Issue body structure for planning state
- [BC Test Libraries](./references/bc-test-libraries.md) - Common library codeunits for test setup

## Next Steps

After completing all 4 phases, the issue body will contain:
- Architecture decisions and component overview
- Test plan with Gherkin scenarios

If an implementation workflow exists in your environment, proceed with it for the same issue.

## Quality Gate (Required)

- Every business rule maps to at least one test scenario
- Architecture section is present and complete in the issue body
- Test plan includes at least one negative/error scenario
