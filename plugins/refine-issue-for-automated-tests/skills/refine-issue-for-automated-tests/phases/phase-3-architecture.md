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

### 7. User Selects Approach

Ask user to choose between approaches:
- **Minimal**: Fewer objects, faster implementation, lower risk
- **Clean/Patterned (Recommended)**: Better structure, event coverage, more testable

Default guidance if user is unavailable:
- Choose **Clean/Patterned** when extensibility, event coverage, or multiple touchpoints are required.
- Choose **Minimal** when the change is localized, low risk, and short-lived.

### 8. Update Issue Body with Architecture

Preserve the original issue description and **merge** the Architecture section using the Issue Template (linked in SKILL.md references).

Architecture section should include:
- Pattern Applied
- AL Object Overview table
- Architecture Diagram (Mermaid)
- Design Decisions with rationale

### 9. Post-Update Verification (Required)

Re-read the updated issue body from GitHub and verify basic structure:
- `## Architecture` heading exists and is in the correct position.
- AL Object Overview and Pattern Applied tables include header and separator rows.
- Mermaid fence is opened and closed properly.
- Horizontal rules (`---`) remain between sections.

If verification fails, reapply the update once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

## User Checkpoints

1. Select architecture approach
2. Approve final architecture before updating issue
