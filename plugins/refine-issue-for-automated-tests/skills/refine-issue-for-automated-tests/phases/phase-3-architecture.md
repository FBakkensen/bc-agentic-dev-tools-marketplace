# Phase 3: Architecture Design

**Goal**: Produce an AL architecture approach, get user selection, and (on approval) merge Architecture into the issue body.

Apply `GR-1` through `GR-6` from `SKILL.md`.

## Actions

1. **Collect architecture inputs**
   - Issue requirements
   - Business Rules (Phase 2)
   - Clarifications and constraints
   - BC subsystems (Phase 1)

2. **Analyze patterns and criteria**
   - Relevant AL patterns: Façade, Generic Method, Event Bridge, Document, Discovery Event
   - Existing repository patterns (`Access = Public|Internal`, events, layering)
   - Risk factors (posting, permissions, `Commit()`, change footprint)

3. **Build design comparison**

| Criteria | Minimal | Clean/Patterned |
|----------|---------|-----------------|
| AL objects changed | ... | ... |
| New AL objects | ... | ... |
| Event coverage | ... | ... |
| Testability | ... | ... |
| Extensibility | ... | ... |
| Risk | ... | ... |

4. **Present findings in chat**
   - comparison table
   - trade-offs
   - open constraints

5. **Ask architecture questions + approach selection**
   - Ask about unresolved constraints, pattern conflicts, and scope/risk trade-offs.
   - Request explicit approach choice:
     - **Minimal**: lower change footprint, faster
     - **Clean/Patterned (Recommended)**: stronger extensibility/testability
   - If user declines to choose (or interaction is unavailable), default:
     - choose **Clean/Patterned** for extensibility/event-heavy work
     - choose **Minimal** for localized short-lived change

6. **Resolution gate (Hard Stop)**
   - Do not continue until architecture questions are resolved and approach is selected.
   - Update comparison if user responses change conclusions.

7. **Build issue body payload internally**
   - Preserve original issue description and prior approved sections.
   - Merge `## Architecture` using the [Issue Template](../references/issue-template.md).
   - Include:
     - Pattern Applied table
     - AL Object Overview table
     - Mermaid architecture diagram
     - Design decisions with rationale
   - Keep raw markdown internal unless the user asks.

8. **Present Phase 3 outcome review (required before write)**
   - write target: issue body
   - what will change
   - what remains unchanged
   - structure preview
   - risks/assumptions

9. **Approval gate (Hard Stop)**
   - Without explicit approval: no write, no phase completion.

10. **Update issue body**
   - Use `GR-5` write procedure.

11. **Post-write verification**
   - Confirm updated body contains:
     - `## Architecture` heading in correct position
     - `AL Object Overview` and `Pattern Applied` tables with header + separator rows
     - properly closed Mermaid fence
     - required horizontal rules (`---`)
   - If verification fails, follow `GR-5` reapply-once rule.

12. **Cleanup**
   - Remove temp file (best effort).

## User Checkpoints

1. Architecture questions answered
2. Approach selected
3. Phase 3 review approved before write
