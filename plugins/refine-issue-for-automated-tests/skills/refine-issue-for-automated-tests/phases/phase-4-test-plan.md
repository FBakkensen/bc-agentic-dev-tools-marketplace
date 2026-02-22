# Phase 4: Test Plan

**Goal**: Create AL test scenarios with BC/AL reference guidance and add to issue body.

## Actions

### 1. Consult BC/AL Testing Guidance

Gather test strategy based on:
- Feature description
- Architecture from Phase 3
- Business Rules from Phase 2

### 2. Get Test Pattern Knowledge

Review BC/AL testing patterns (isolation, handlers, error testing, transaction boundaries).

### 3. Find Existing Test Patterns

Search existing test folders for `[Test]` procedures matching the feature area.

### 4. Apply ZOMBIES Checklist

- **Z**ero - Empty/null inputs, zero quantities
- **O**ne - Single item/record cases
- **M**any - Multiple items/records
- **B**oundary - Edge cases, limits, max values
- **I**nterface - API contracts, event interfaces
- **E**xceptions - Error handling, guard clauses
- **S**imple - Happy path

### 5. Apply BC-Specific Checklist

**Data & Transactions:**
- [ ] FlowField/CalcField calculations verified
- [ ] SetLoadFields for performance (partial record loading)
- [ ] LockTable considerations (note: AL tests run single-session; true concurrency cannot be tested)
- [ ] Commit() timing and transaction boundaries
- [ ] Multi-company scenarios (if applicable)

**Events & Integration:**
- [ ] Event subscriber coverage (OnBefore/OnAfter pairs)
- [ ] IsHandled pattern tested (both handled and not handled)
- [ ] BC standard events exercised

**UI & Handlers:**
- [ ] ConfirmHandler for confirmation dialogs
- [ ] MessageHandler for message dialogs
- [ ] PageHandler for page interactions
- [ ] StrMenuHandler for option menus

**Posting & Documents (if applicable):**
- [ ] Pre-posting validation
- [ ] Posting routine execution
- [ ] Ledger entry verification
- [ ] Document number series

### 6. BC Test Library Reference

See the **BC Test Libraries** reference linked in SKILL.md.

### 7. Write AL Test Plan

Create test plan with this structure:

**Test Codeunit:** `[Prefix] [Feature] Test`
**Tags:** `[FEATURE] [Area] [Subarea]`

**Scenario Inventory table:**
| # | Scenario | Type | Risk | Procedure | TransactionModel | Handlers | Evidence |
|---|----------|------|------|-----------|------------------|----------|----------|

**Rule to Scenario Traceability table:**
| Rule # | Rule | Scenarios | Notes |
|--------|------|-----------|-------|

**Scenarios:** Each with Rule(s), Procedure name, GIVEN/WHEN/THEN, Evidence target (if applicable).

### 8. Update Issue Body with Test Plan

Append the Test Plan section to the issue body, preserving existing content. Use the Issue Template (linked in SKILL.md references).

### 9. Post-Update Verification (Required)

Re-read the updated issue body from GitHub and verify basic structure:
- `## Test Plan` heading exists and is in the correct position.
- Scenario Inventory and Rule to Scenario Traceability tables include header and separator rows.
- Scenario headings exist for each scenario.
- Code/Mermaid fences are opened and closed properly.
- Horizontal rules (`---`) remain between sections.

If verification fails, reapply the update once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

### 10. Quality Gate Self-Review

- Every business rule has at least one scenario
- ZOMBIES coverage is adequate
- BC-specific checklist items addressed
- Evidence targets are specific and verifiable
- Test libraries identified for setup

## User Checkpoint

> "Test plan complete with {N} scenarios covering {M} business rules. BC checklist verified. Planning is complete. To begin implementation, run `/tdd-implement #{number}`."

## Next Steps

After user approves, the planning workflow is complete. Direct user to `/tdd-implement` skill for implementation.
