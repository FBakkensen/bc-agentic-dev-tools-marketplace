# Phase 3: Architecture Design

**Goal**: Design AL implementation approach with BC/AL reference guidance, user selects, update issue body.

## Actions

### 1. Consult BC/AL Reference Guidance

Gather architecture guidance based on:
- Feature description
- Business Rules from Phase 2
- Constraints from clarifications
- BC Subsystems from Phase 1

### 2. Get Pattern Guidance

Review BC/AL patterns relevant to the feature: facade, event bridge, document pattern.

### 3. Analyze Existing Patterns

Search codebase for existing access modifier patterns (`Access = Public|Access = Internal`).

### 4. Determine Architecture Criteria

- Feature type (enhancement, new feature, integration)
- AL pattern fit (Façade, Generic Method, Event Bridge, Document)
- Event design (IntegrationEvent, BusinessEvent, IsHandled)
- Access modifiers (Public API vs Internal)
- Risk areas (posting, permissions, Commit())

### 5. AL Pattern Selection

| Pattern | When to Use | Characteristics |
|---------|-------------|-----------------|
| **Façade** | Public API to subsystem | Public codeunit (`Access = Public`) + Internal implementation |
| **Generic Method** | Isolate one business method | UI Layer + Event Layer (OnBefore/OnAfter) + Method Layer |
| **Event Bridge** | Multiple interface implementations | Interface + Triggers codeunit with published events |
| **Document** | Header/Lines structures | Header Table + Lines Table + Card + Subpage |
| **Discovery Event** | Self-registration | Publisher event + registration callback |

### 6. Design Comparison

Present trade-offs:

| Criteria | Minimal | Clean/Patterned |
|----------|---------|-----------------|
| AL Objects changed | X | Y |
| New AL Objects | A | B |
| Event coverage | ... | ... |
| Testability | ... | ... |
| Extensibility | ... | ... |
| Risk | ... | ... |

### 7. Surface Architecture Uncertainties & Select Approach

Apply the **User Interaction Principles** from SKILL.md. Before asking the user to select an approach, surface any unresolved architecture questions discovered during Steps 1–6.

#### 7a. Discovery-Driven Architecture Questions

Review the design comparison and your codebase exploration. Identify and ask about:

- **Conflicting patterns**: "The codebase uses [pattern A] in `Module X` and [pattern B] in `Module Y`. Which direction should this feature follow?" _(present trade-offs)_
- **Unresolved constraints**: "This approach requires a new table with RIMD permissions — is that acceptable for this feature area?"
- **Scope decisions**: "Should this include event coverage for third-party extensibility, or is internal-only sufficient for now?"
- **Risk trade-offs**: "The clean approach touches N existing objects — are there change-freeze or release constraints to consider?"

#### 7b. Batching & Presentation

- **Batch architecture questions with the approach selection** into a single interaction. Present:
  1. Architecture uncertainties (with options/trade-offs where applicable)
  2. Approach selection (Minimal vs Clean/Patterned with the comparison table from Step 6)
- **State defaults**: For each question, state what you would assume if the user does not answer.

#### 7c. Approach Selection

Ask user to choose between approaches:
- **Minimal**: Fewer objects, faster implementation, lower risk
- **Clean/Patterned (Recommended)**: Better structure, event coverage, more testable

Always attempt to ask the user. Only fall back to the default below if the user explicitly declines to choose or the environment does not support interactive questioning:
- Choose **Clean/Patterned** when extensibility, event coverage, or multiple touchpoints are required.
- Choose **Minimal** when the change is localized, low risk, and short-lived.

#### 7d. Resolution Gate (Hard Stop)

Do not proceed to Step 8 until the user has responded to architecture questions and selected an approach. If the user's answers change the design comparison or invalidate an option, update before proceeding.

### 8. Build Updated Issue Body Payload (Internal)

Preserve the original issue description and **merge** the Architecture section using the Issue Template (linked in SKILL.md references).

Architecture section should include:
- Pattern Applied
- AL Object Overview table
- Architecture Diagram (Mermaid)
- Design Decisions with rationale

Do not present raw markdown by default; keep it internal unless the user explicitly asks for it.

### 9. Present Phase Outcome Review (Required Before Write)

Present a review-friendly summary (not raw markdown) that includes:
- Intended write target: issue body update
- What will change: Architecture section content (pattern, object overview, diagram, design decisions)
- What remains unchanged: original issue description and prior approved sections
- Structure preview: expected heading/table/fence layout after update
- Risks/assumptions: unresolved architecture choices or constraints

### 10. Approval Gate (Hard Stop)

Ask for explicit approval before updating the issue body.
- If approved: proceed to write.
- If not approved or unclear: stop, revise summary/payload, and wait.
- Do not complete Phase 3 without explicit approval.

### 11. Update Issue Body via Temp File (Required)

- Write payload to unique temp file in `$env:TEMP` (UTF-8).
- Update with `gh issue edit <number> --body-file <temp-file>`.
- Do not use inline `--body`.

### 12. Post-Update Verification (Required)

Re-read the updated issue body from GitHub and verify basic structure:
- `## Architecture` heading exists and is in the correct position.
- AL Object Overview and Pattern Applied tables include header and separator rows.
- Mermaid fence is opened and closed properly.
- Horizontal rules (`---`) remain between sections.

If verification fails, reapply the update once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

### 13. Cleanup

Delete the temp file (best effort) after verification.

## User Checkpoints

1. Select architecture approach
2. Review Phase 3 outcome summary
3. Approve final architecture update before writing to GitHub
