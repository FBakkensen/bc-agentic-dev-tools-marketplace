# Phase 4: Test Plan

**Goal**: Create the AL test plan (ZOMBIES-ordered scenarios + rule traceability) and, on approval, merge it into the issue body.

Apply `GR-1` through `GR-6` from `SKILL.md`.

## Actions

1. **Collect test inputs**
   - Feature description
   - Business Rules (Phase 2)
   - Architecture decisions (Phase 3)

2. **Discover existing test patterns**
   - Review related `[Test]` procedures and test codeunits.
   - Identify available test libraries and handler patterns.

3. **Present findings in chat**
   - Existing test patterns/libraries
   - testability constraints from architecture
   - likely coverage gaps

4. **Ask test-scope questions**
   - Clarify edge/error cases not documented
   - Decide coverage strategy (depth vs breadth)
   - Confirm infrastructure constraints (libraries/handlers)
   - Resolve whether to extend existing test codeunits or create new ones

5. **Resolution gate (Hard Stop)**
   - Do not write scenarios until user responds.
   - If answers change scope, update plan inputs before continuing.

6. **Order scenarios using ZOMBIES**
   - Required order in Scenario Inventory: **Z, O, M, B, I, E** (`S` is implicit).
   - Within each letter, order by increasing risk.

| Step | Focus | What it should force into existence |
|------|-------|--------------------------------------|
| Z | Zero | Guard clauses, empty/default behavior |
| O | One | Single-record happy-path logic |
| M | Many | Iteration/aggregation logic |
| B | Boundary | Edge/threshold validation |
| I | Interface | Event/API contract behavior |
| E | Exception | Explicit error handling |

7. **Apply BC-specific checklist**
   - Data/transactions: FlowField/CalcField, `SetLoadFields`, `Commit()`, multi-company
   - Events/integration: OnBefore/OnAfter, IsHandled branches, BC standard events
   - UI handlers: Confirm/Message/Page/StrMenu handlers when applicable
   - Posting/documents: pre-posting checks, posting execution, ledger effects, number series

8. **Build test plan content**
   - Test Codeunit name + tags
   - Scenario Inventory table
   - Rule-to-Scenario Traceability table
   - Scenario details (`GIVEN/WHEN/THEN`, procedure, evidence target)
   - Use [BC Test Libraries](../references/bc-test-libraries.md) when selecting setup helpers.

9. **Build updated issue body payload internally**
   - Preserve original issue description and previously approved sections.
   - Append/merge `## Test Plan` using the [Issue Template](../references/issue-template.md).
   - Keep raw markdown internal unless the user asks.

10. **Present Phase 4 outcome review (required before write)**
   - write target: issue body
   - what will change
   - coverage summary (rules mapped, Z/O/M/B/I/E coverage, negative scenarios)
   - what remains unchanged
   - structure preview
   - risks/assumptions

11. **Approval gate (Hard Stop)**
   - Without explicit approval: no write, no phase completion.

12. **Update issue body**
   - Use `GR-5` write procedure.

13. **Post-write verification**
   - Confirm updated body contains:
     - `## Test Plan` heading in correct position
     - Scenario Inventory and Rule Traceability tables (header + separator rows)
     - scenario headings for each scenario
     - closed code/Mermaid fences
     - required horizontal rules (`---`)
   - If verification fails, follow `GR-5` reapply-once rule.

14. **Quality self-review**
   - every business rule mapped to >=1 scenario
   - Z/O/M/B/I/E order preserved
   - at least one negative/error scenario
   - BC-specific checklist items addressed
   - evidence targets are specific

15. **Cleanup**
   - Remove temp file (best effort).

## User Checkpoint

> "Test plan draft complete with {N} scenarios covering {M} business rules. After explicit approval and successful GitHub update, planning is complete. Next: `/tdd-implement #{number}`."
