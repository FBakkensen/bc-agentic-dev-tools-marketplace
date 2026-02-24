# Phase 2: Codebase Exploration & Questions

**Goal**: Discover existing AL patterns, extract business rules, resolve ambiguities, and (on approval) post Business Rules Analysis.

Apply `GR-1` through `GR-6` from `SKILL.md`.

## Actions

1. **Explore relevant code**
   - Find similar AL objects (codeunits, tables, pages) for the feature area.
   - Find event patterns: `IntegrationEvent`, `EventSubscriber`, `OnBefore*`, `OnAfter*`, `IsHandled`.
   - Read key files and module structure for existing conventions.

2. **Consult BC/AL guidance**
   - Use BC standard references, project patterns, and SMEs (if available).

3. **Build the Business Rules table**

| Rule # | Business Rule | Source | Event Hook? | BC Standard? | Clarification? |
|--------|---------------|--------|-------------|--------------|----------------|
| 1 | ... | Issue | OnAfter* | No | No |
| 2 | ... | Code | OnBefore* | Yes - Sales-Post | Yes - edge case |

4. **Present findings in chat (not as questions)**
   - Rules table
   - Patterns found
   - Conflicts/gaps/assumptions

5. **Ask batched clarification questions**
   - Every rule marked `Clarification? = Yes` must become a question.
   - Include discovery-driven questions for:
     - pattern conflicts
     - missing scope/edge-case behavior
     - assumptions that need confirmation
   - Use fallback checklist only for uncovered topics:
     - BC event integration
     - IsHandled override behavior
     - posting/`Commit()` considerations
     - permissions (`RIMD`) for new tables
     - multi-company support
     - performance (`SetLoadFields`)

6. **Question resolution gate (Hard Stop)**
   - Do not continue until all required questions are answered.
   - If answers add/change rules, update the table before continuing.

7. **Build comment payload internally**
   - Keep raw markdown internal unless the user asks to see it.
   - Structure:

```markdown
## Business Rules Analysis

| Rule # | Business Rule | Source | Event Hook? | BC Standard? |
|--------|---------------|--------|-------------|--------------|
| 1 | ... | ... | ... | ... |

**BC Subsystems:** ...
**Reference Guidance:** ...
```

8. **Present Phase 2 outcome review (required before write)**
   - write target: issue comment
   - what will be added
   - counts (rules, clarified questions, unresolved items)
   - what remains unchanged
   - risks/assumptions

9. **Approval gate (Hard Stop)**
   - Without explicit approval: no write, no phase completion.

10. **Post comment**
   - Use `GR-5` write procedure.

11. **Post-write verification**
   - Confirm comment has:
     - `## Business Rules Analysis` heading
     - table header + separator rows
     - closed code fences (if any)
   - If verification fails, follow `GR-5` reapply-once rule.

12. **Cleanup**
   - Remove temp file (best effort).

## User Checkpoint

Phase 2 is complete only after:
- clarifications are resolved,
- explicit approval is given,
- comment write and verification succeed.
