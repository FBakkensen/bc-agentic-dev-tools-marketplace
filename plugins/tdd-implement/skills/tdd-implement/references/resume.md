# Resuming from PR

When argument is detected as a PR reference, restore context and continue from the appropriate phase.

## Context Restoration Process

### 1. Obtain PR Data

Gather PR title, body, state, branch names, and linked issues.

### 2. Obtain Linked Issues

For each linked issue (from `closingIssuesReferences` or parsed from `Closes #N`), gather original requirements.

### 3. Parse PR Description for State

Extract workflow state from PR body sections:

**Implementation Progress Table** - Look for:
```markdown
## Implementation Progress
| # | Scenario | Red | Green | Refactor | Status |
```
Parse checkbox states to determine current scenario.

### 4. Determine Resume Point

**Phase Detection Logic:**

| Progress Table | Resume At |
|----------------|-----------|
| Missing or empty | Phase 1: Setup (may need to recreate PR) |
| No checkboxes | Phase 2: Start first scenario |
| Partial | Phase 2: Resume at incomplete scenario |
| All complete | Phase 3: Review & Summary |

**Mid-Scenario Detection** (parse progress table rows):

| Red | Green | Refactor | Resume At |
|-----|-------|----------|-----------|
| [ ] | [ ] | [ ] | Start RED phase |
| [x] | [ ] | [ ] | Start GREEN phase |
| [x] | [x] | [ ] | Start REFACTOR phase |
| [x] | [x] | [x] | Next scenario |

### 5. Rebuild Task List

Create task list showing completed/pending phases:

```
[Phase 1] Setup - Prepare branch and PR ✓
[Phase 2] Implementation - Resume at Scenario 3 (GREEN phase)
[Phase 3] Review & Summary
```

### 6. Present Resume Summary

```
## Resume Summary

**PR:** #{number} - {title}
**Branch:** {headRefName}
**Linked Issue:** #{issue-number}

**Current State:**
- Implementation: {M}/{N} scenarios complete
- Next: Scenario {X} - {name} ({phase} phase)

Ready to continue?
```

## Branch Verification

Before resuming, verify the current branch matches the PR's head branch. If not, ask user whether to switch branches or stay on current.

## Edge Cases

**PR is not draft:** Ask user whether to convert back to draft or add changes to ready PR.

**PR is closed/merged:** Inform user the PR is no longer active. Suggest creating a new issue/PR for additional work.

**Missing sections:** Warn about incomplete state. Offer to reconstruct from linked issue or re-run Phase 1.

**Conflicts with main:** Check if branch is behind main and suggest merging main into feature branch first.

## Example Responses

- PR not draft: "This PR is already ready for review. Do you want to convert it back to draft or continue work on a ready PR?"
- PR closed/merged: "This PR is closed/merged. For additional work, please create a new issue or PR."
- Missing sections: "The PR is missing required sections (Architecture/Test Plan/Progress). Do you want to reconstruct from the linked issue or rerun Phase 1?"
