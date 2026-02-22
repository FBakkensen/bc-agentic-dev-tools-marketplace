# Phase 1: Setup

**Goal**: Prepare feature branch and draft PR from issue with completed planning.

## Prerequisites

Validate the issue has completed planning:
- Architecture section present
- Test Plan section present

If missing, abort and suggest running `/refine-issue-for-automated-tests #N` first.

## Actions

Use any available GitHub access method to read and update issue/PR content.

### 1. Obtain Issue Details

Gather issue title, body, labels, and state.

### 2. Validate Planning Complete

Parse issue body for required sections:
- `## Architecture` must be present
- `## Test Plan` must be present with Scenario Inventory table

If validation fails:
> "Issue #{number} is missing required planning sections. Please run `/refine-issue-for-automated-tests #{number}` first to complete planning."

### 3. Ensure Feature Branch Exists

Ensure a feature branch named `issue/{number}-{slug}` exists where:
- `slug` is derived from the issue title (lowercase, hyphenated, max 50 chars)

### 4. Ensure Draft PR Exists

Extract **Architecture** and **Test Plan** from the issue body. Build the **Implementation Progress** table by copying the Scenario Inventory rows, preserving scenario names and order.

Ensure the draft PR description uses this structure (see [pr-template.md](../references/pr-template.md) for full template):

```markdown
## Summary
Closes #{issue-number}
[Brief description from issue]

---
## Architecture
[Copy from issue body]

---
## Test Plan
[Copy from issue body]

---
## Implementation Progress
| # | Scenario | Red | Green | Refactor | Status |
|---|----------|-----|-------|----------|--------|
| 1 | [Scenario 1] | [ ] | [ ] | [ ] | Not started |
...

---
## Review Checklist
- [ ] All scenarios passing
- [ ] Zero DEBUG-* telemetry in codebase
- [ ] Code review comments addressed
- [ ] Build gate passing
- [ ] Ready for merge
```

### 5. Post-Update Verification (Required)

Re-read the PR description from GitHub and verify basic structure:
- `## Summary`, `## Architecture`, `## Test Plan`, `## Implementation Progress`, and `## Review Checklist` headings exist and are ordered.
- Implementation Progress table includes header and separator rows.
- Code/Mermaid fences are opened and closed properly.
- Horizontal rules (`---`) remain between sections.

If verification fails, reapply the update once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

### 6. Present Summary

```
## Setup Complete

**Branch:** issue/{number}-{slug}
**PR:** #{pr-number} (draft)

Architecture and Test Plan copied from issue to PR.
Implementation Progress table initialized with {N} scenarios.

Ready to begin implementation?
```

## Success Criteria

- Feature branch exists with the expected naming convention.
- Draft PR exists and includes Summary, Architecture, Test Plan, Implementation Progress, and Review Checklist sections.
- Implementation Progress table is initialized with all scenarios in order.

## User Checkpoint

Wait for user confirmation before Phase 2.

## Error Handling

**Issue not found**: Abort with clear error message.

**No planning sections**: Suggest running `/refine-issue-for-automated-tests` first.

**Branch already exists**: Ask user whether to use existing branch or create new one.

**PR already exists**: Ask user whether to resume from existing PR or create new one.

## Example Responses

- Missing planning: "Issue #{number} is missing required planning sections. Please run `/refine-issue-for-automated-tests #{number}` first to complete planning."
- Branch exists: "Branch `issue/{number}-{slug}` already exists. Do you want to use it or create a new branch?"
- PR exists: "A draft PR already exists for this work. Do you want to resume it or create a new one?"
