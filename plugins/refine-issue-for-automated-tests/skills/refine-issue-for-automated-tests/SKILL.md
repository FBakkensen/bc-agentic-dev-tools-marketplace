---
name: refine-issue-for-automated-tests
description: "AL/BC issue refinement workflow for GitHub issues. Produce architecture + automated test plan in the issue body"
---

# AL/BC Issue Refinement for Automated Tests

4-phase planning workflow for turning a GitHub issue into:

- `## Architecture` in the issue body
- `## Test Plan` in the issue body
- `## Business Rules Analysis` as an issue comment (Phase 2 output)

> **Planning only**: For implementation, use `/tdd-implement` after planning is complete.

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

## Workflow at a Glance

| Stage | Phase | Focus | GitHub Write |
|-------|-------|-------|--------------|
| Discovery | 1 | Understand requirements and affected areas | No |
| Discovery | 2 | Explore patterns, build rules, resolve questions | Yes - issue comment |
| Planning | 3 | Select architecture and document decisions | Yes - issue body |
| Planning | 4 | Build test plan and traceability | Yes - issue body |

## Global Rules (Required)

### GR-1: Findings first, questions second

- Present findings, tables, and summaries as normal chat output.
- Ask only actual questions through the question mechanism.
- Never embed findings/reviews inside question payloads.

### GR-2: Discovery-driven, batched questions

- Derive questions from issue/codebase findings, not generic checklists.
- Ask questions in one round, grouped by topic.
- When alternatives exist, provide options with trade-offs and (if justified) a recommendation.
- State the default assumption for each question if unanswered.

### GR-3: Hard checkpoints, no silent assumptions

- Do not continue past a questioning step until the user responds.
- If answers change conclusions, update prior outputs before proceeding.
- If uncertain, ask explicitly; do not assume silently.

### GR-4: Review + explicit approval before any write

Before any GitHub write, present:

- write target (`issue comment` or `issue body`)
- what changes
- what remains unchanged
- structure preview (headings/tables/fences)
- risks/assumptions

Rules:

- No explicit approval = no write.
- No explicit approval = phase incomplete.
- Do not auto-advance after presenting a review.
- Keep raw markdown payload internal unless the user asks to see it.

### GR-5: Safe write procedure (`--body-file` only)

1. Build final markdown payload internally.
2. Write payload to a unique UTF-8 temp file in `$env:TEMP`.
3. Execute write with `--body-file`:
   - `gh issue comment <number> --body-file <temp-file>`
   - `gh issue edit <number> --body-file <temp-file>`
4. Re-read updated content from GitHub.
5. Run formatting verification (GR-6).
6. If verification fails, reapply once and verify again.
7. If it still fails, stop and report mismatch.
8. Remove temp file (best effort).

### GR-6: Formatting verification baseline

After any write, verify:

- required headings exist and are in order
- tables include header + separator rows
- code/Mermaid fences are closed
- required horizontal rules (`---`) remain for issue body updates

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

1. Parse issue number.
2. Create task list for all 4 phases.
3. Begin [Phase 1](./phases/phase-1-discovery.md).

## Task List Structure

When starting a new workflow, create:

```text
[Phase 1] Discovery - Understand requirements
[Phase 2] Exploration - Explore patterns, ask questions
[Phase 3] Architecture - Design approach, update issue
[Phase 4] Test Plan - Write Gherkin scenarios, update issue
```

## References

- [Issue Template](./references/issue-template.md) - issue body structure for planning state
- [BC Test Libraries](./references/bc-test-libraries.md) - common library codeunits for test setup

## Quality Gate (Required)

- Every business rule maps to at least one test scenario.
- Architecture section is present and complete in the issue body.
- Test plan includes at least one negative/error scenario.

## Next Steps

After all phases are approved and GitHub writes are verified, proceed with `/tdd-implement` for implementation.
