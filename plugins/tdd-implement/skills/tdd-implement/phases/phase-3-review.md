# Phase 3: Review & Summary

**Goal**: Ensure quality and finalize PR.

## Actions

### 1. Execute Standard Build/Test Process

Execute the repository's standard build/test process using available tooling and confirm tests pass with zero warnings.

### 2. Run Code Analysis

On changed files:
- Check for warnings in build output
- Review test coverage
- Verify no DEBUG-* telemetry remains

### 3. Present Findings by Severity

- **Critical**: Must fix before merge
- **Warning**: Should fix, can defer
- **Info**: Optional improvements

### 4. User Decision

Ask user how to handle findings:
- **Fix all now**: Address all issues before marking ready
- **Fix critical only**: Fix critical issues, create follow-up issue for rest
- **Proceed as-is**: Mark ready for review without changes

### 5. Mark PR Ready

Mark the PR as ready for review (no longer draft).

### 6. Generate Summary

Add PR comment with implementation summary:

```markdown
## Implementation Summary

**What was built:**
- [feature description]

**Tests:**
- {N} scenarios implemented
- All passing, zero DEBUG telemetry

**Key decisions:**
- [architecture choice and why]
- [notable implementation decisions]

**Files changed:**
- [list of key files]
```

## Checklist Completion

Update the Review Checklist in PR description:

```markdown
## Review Checklist

- [x] All scenarios passing
- [x] Zero DEBUG-* telemetry in codebase
- [ ] Code review comments addressed
- [x] Build gate passing
- [x] Ready for merge
```

## Post-Update Verification (Required)

Re-read the PR description and the summary comment from GitHub and verify basic structure:
- Review Checklist checkboxes are intact and correctly formatted.
- Summary comment headings and sections are intact.
- Code/Mermaid fences are opened and closed properly.

If verification fails, reapply the update once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

## Workflow Complete

After Phase 3, the implementation workflow is complete. The PR is ready for human review and merge.

## Success Criteria

- Tests pass with zero warnings and required coverage is verified.
- No `DEBUG-*` telemetry remains in code.
- Review Checklist is updated and PR is marked ready for review.
- Implementation Summary comment is posted.
