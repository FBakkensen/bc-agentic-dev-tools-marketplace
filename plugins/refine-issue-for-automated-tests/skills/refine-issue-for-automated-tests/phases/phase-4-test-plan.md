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

### 4. Clarify Test Scope & Priorities

Apply the **User Interaction Principles** from SKILL.md. Before writing scenarios, surface what you learned from test pattern discovery and resolve open questions.

#### 4a. Discovery-Driven Test Questions

Review findings from Steps 1–3 and ask about:

- **Undocumented edge cases**: "Are there specific failure modes or edge cases you know about that aren't captured in the business rules?"
- **Coverage strategy**: "Should test coverage prioritize depth (thorough testing of core flow with many boundary cases) or breadth (covering all rules with basic scenarios)?" _(present trade-offs for the specific feature)_
- **Test infrastructure constraints**: "I found existing tests use [library X] but not [library Y]. Are there test infrastructure limitations to be aware of (e.g., missing test libraries, no UI test handlers)?"
- **Architecture testability concerns**: "The architecture from Phase 3 introduces [pattern]. This means [testability implication] — is that acceptable, or should we adjust?"
- **Existing test conflicts**: "I found existing tests in [codeunit] that cover [area]. Should the new tests extend that codeunit or create a separate one?"

#### 4b. Presentation & Questioning (Two-Step)

**Step A — Present findings in chat:** Before asking questions, present what you learned from test pattern discovery (Steps 1–3) as a regular chat message — existing test patterns found, test libraries in use, and any testability concerns from the architecture. This is context, not part of the questions.

**Step B — Ask questions separately:** After presenting findings, ask test scope questions in a separate interaction. Questions must be concise and reference the findings already shown in chat. Group by topic (scope, infrastructure, coverage). When a question has identifiable alternatives, present them as choices with trade-offs. For each question, state what you would assume if the user does not answer.

Do **not** embed findings, summaries, or test pattern analysis inside questions.

#### 4c. Resolution Gate (Hard Stop)

Do not proceed to scenario writing (Step 5) until the user has responded to test scope questions. If answers change the expected scope or coverage approach, factor those into scenario design.

### 5. Order Scenarios Using ZOMBIES

ZOMBIES defines the **order** in which test scenarios are written, not just a coverage checklist. Each letter drives new production code into existence. Design EMERGES from this sequence -- for example, `FindFirst` appears at the "O" (One) step and evolves into `FindSet` + loop at the "M" (Many) step.

Write and order scenarios in this progression:

| Step | Focus | What It Drives Into Existence |
|------|-------|-------------------------------|
| **Z** - Zero | Empty/null/zero inputs | Guard clauses, empty checks, default returns |
| **O** - One | Single happy-path case | Core logic for one record |
| **M** - Many | Multiple inputs, iteration | Loops, aggregation (`FindSet` + `repeat..until`) |
| **B** - Boundary | Edge cases, thresholds, limits | Boundary validation, off-by-one protection |
| **I** - Interface | Public API, events, contracts | IntegrationEvent signatures, IsHandled pattern |
| **E** - Exception | Error cases, missing setup | `asserterror`, guard `Error()` calls |
| **S** - Simple | Confirm simplest cases pass | Already covered by Z and O (implicit) |

**Ordering rule:** Scenarios in the Scenario Inventory MUST be ordered Z, O, M, B, I, E. Within each ZOMBIES step, order by ascending risk. This ensures each test forces the minimal next increment of production code.

### 6. Apply BC-Specific Checklist

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

### 7. BC Test Library Reference

See the **BC Test Libraries** reference linked in SKILL.md.

### 8. Write AL Test Plan

Create test plan with this structure:

**Test Codeunit:** `[Prefix] [Feature] Test`
**Tags:** `[FEATURE] [Area] [Subarea]`

**Scenario Inventory table:**
| # | ZOMBIES | Scenario | Type | Risk | Procedure | TransactionModel | Handlers | Evidence |
|---|---------|----------|------|------|-----------|------------------|----------|----------|

**Rule to Scenario Traceability table:**
| Rule # | Rule | Scenarios | Notes |
|--------|------|-----------|-------|

**Scenarios:** Each with Rule(s), Procedure name, GIVEN/WHEN/THEN, Evidence target (if applicable).

### 9. Build Updated Issue Body Payload (Internal)

Append the Test Plan section to the issue body, preserving existing content. Use the Issue Template (linked in SKILL.md references).

Do not present raw markdown by default; keep it internal unless the user explicitly asks for it.

### 10. Present Phase Outcome Review (Required Before Write)

Present a review-friendly summary (not raw markdown) that includes:
- Intended write target: issue body update
- What will change: Test Plan section, scenario inventory, rule traceability, scenario count
- Coverage summary: business rules covered, Z-O-M-B-I-E coverage, negative/error scenarios
- What remains unchanged: original issue description and prior approved sections
- Structure preview: expected heading/table/fence layout after update
- Risks/assumptions: uncovered rules, weak evidence targets, or pending clarifications

### 11. Approval Gate (Hard Stop)

Ask for explicit approval before updating the issue body.
- If approved: proceed to write.
- If not approved or unclear: stop, revise summary/payload, and wait.
- Do not complete Phase 4 without explicit approval.

### 12. Update Issue Body via Temp File (Required)

- Write payload to unique temp file in `$env:TEMP` (UTF-8).
- Update with `gh issue edit <number> --body-file <temp-file>`.
- Do not use inline `--body`.

### 13. Post-Update Verification (Required)

Re-read the updated issue body from GitHub and verify basic structure:
- `## Test Plan` heading exists and is in the correct position.
- Scenario Inventory and Rule to Scenario Traceability tables include header and separator rows.
- Scenario headings exist for each scenario.
- Code/Mermaid fences are opened and closed properly.
- Horizontal rules (`---`) remain between sections.

If verification fails, reapply the update once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

### 14. Quality Gate Self-Review

- Every business rule has at least one scenario
- ZOMBIES coverage is adequate
- Scenarios are ordered Z-O-M-B-I-E in the Scenario Inventory
- Each ZOMBIES step introduces scenarios that force new production code (design-emergence check)
- BC-specific checklist items addressed
- Evidence targets are specific and verifiable
- Test libraries identified for setup

### 15. Cleanup

Delete the temp file (best effort) after verification.

## User Checkpoint

> "Test plan draft complete with {N} scenarios covering {M} business rules. Review summary presented. After explicit approval and successful GitHub update, planning is complete. To begin implementation, run `/tdd-implement #{number}`."

## Next Steps

After user approves, the planning workflow is complete. Direct user to `/tdd-implement` skill for implementation.
