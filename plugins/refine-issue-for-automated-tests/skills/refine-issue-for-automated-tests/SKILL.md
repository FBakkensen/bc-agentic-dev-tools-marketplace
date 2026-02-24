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

## User Interaction Principles (Required)

These principles apply across all phases and govern how the agent interacts with the user during the workflow.

### Separate Findings from Questions

Phase outputs, summaries, tables, comparisons, and context **must** be presented in the chat as regular messages. Only actual questions go through the question/interaction mechanism. Never embed phase output, findings, or review summaries inside questions.

The flow is always:
1. **Present findings in chat** — show what you discovered, including tables, comparisons, and summaries as a regular chat message.
2. **Then ask questions separately** — only the questions themselves, referencing the findings you just presented.

### Discovery-Driven Questioning

After any research or exploration step, review what you learned, identify what is ambiguous or uncertain, and surface those items to the user as questions. Prioritize questions derived from actual codebase findings over generic checklists.

### Batch Questions

Ask all questions together in one round, grouped by topic (e.g., events, permissions, test scope). Avoid asking one question at a time in separate rounds. Questions must be concise — provide context and background in the chat message before asking, not inside the questions themselves.

### Present Options with Trade-Offs

When a question has identifiable alternatives, present them as choices with brief trade-off descriptions. Include a recommended option when you have a basis for one. This helps the user make faster, more informed decisions.

### Hard Checkpoints

Do not proceed past a questioning step until the user has responded. If the user's answers change prior conclusions (e.g., invalidate a business rule, shift architecture direction), update earlier outputs before continuing.

### No Silent Assumptions

If you are uncertain about a requirement, constraint, or design choice, ask rather than assume. When presenting a question, explicitly state what you would assume if the user does not answer, so the user can either confirm or correct.

## Phase Review + Approval Gates (Required)

Before **any** GitHub write, present a phase outcome review in a format that is easy to understand (not raw markdown), then request explicit approval.

Required review format before write:
- Intended write target (`issue comment` or `issue body`)
- What will change (sections added/updated, key decisions, counts)
- What stays unchanged
- Structure preview (headings/tables/fences that will exist after write)
- Risks/assumptions

Approval gates:
- **Phase 2 gate**: Present Business Rules outcome and proposed comment changes, then ask approval before posting comment.
- **Phase 3 gate**: Present Architecture outcome and proposed issue body changes, then ask approval before editing issue body.
- **Phase 4 gate**: Present Test Plan outcome and proposed issue body changes, then ask approval before editing issue body.

Rules:
- No explicit approval = no GitHub write.
- No explicit approval = phase does not complete.
- Do not auto-advance after presenting review summary.
- Keep raw markdown payload internal unless user explicitly asks to see it.

## GitHub Write Safety (Required)

To avoid escaping/quoting failures, all GitHub writes must use a temp file under `$env:TEMP` and `--body-file`.

Required write procedure:
1. Build final markdown payload internally.
2. Present review summary and get explicit approval.
3. Write payload to unique temp file in `$env:TEMP` using UTF-8.
4. Execute GitHub write with `--body-file`:
   - Issue body update: `gh issue edit <number> --body-file <temp-file>`
   - Issue comment: `gh issue comment <number> --body-file <temp-file>`
5. Re-read from GitHub and run formatting verification.
6. If verification fails, reapply once with corrected payload, then verify again.
7. If verification still fails, stop and report mismatch.
8. Remove temp file (best effort) after verification.

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
