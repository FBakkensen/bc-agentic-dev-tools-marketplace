# Phase 2: Codebase Exploration & Questions

**Goal**: Understand existing AL code patterns, discover business rules, consult BC/AL references or SMEs, ask clarifying questions.

## Actions

### 1. Explore Codebase

- Search for similar AL objects (codeunits, tables, pages) matching feature keywords
- Find event patterns: `IntegrationEvent`, `EventSubscriber`, `OnBefore*`, `OnAfter*`
- Find event subscribers for BC codeunits
- Read key files to understand existing patterns
- List directory structure for feature areas

### 2. Consult BC/AL References or SMEs

Gather guidance on patterns, events, error handling, and testing approaches from:
- Business Central standard documentation
- Existing project patterns in the repo
- BC/AL subject matter experts (if available)

### 3. Read Key Files

Read implementation details of discovered files to understand patterns and conventions.

### 4. Create Business Rules Table

Map discovered rules with AL/BC-specific columns:

| Rule # | Business Rule | Source | Event Hook? | BC Standard? | Clarification? |
|--------|---------------|--------|-------------|--------------|----------------|
| 1 | ... | Issue | OnAfter* | No | No |
| 2 | ... | Code | OnBefore* | Yes - Sales-Post | Yes - edge case |
| 3 | ... | Reference/SME | IsHandled | Yes | No |

### 5. Ask Clarifying Questions

Apply the **User Interaction Principles** from SKILL.md. Questions must be discovery-driven, batched, and presented with options where applicable.

#### 5a. Discovery-Driven Questions (Primary)

Review what you found in Steps 1–4. For every gap, ambiguity, or assumption, formulate a specific question grounded in your findings:

- **Business Rules table gaps**: Every rule flagged "Yes" in the Clarification column **must** produce a question. Do not skip flagged rules.
- **Pattern conflicts**: If the codebase uses multiple patterns for similar features, ask which the user prefers and why.
- **Missing context**: If the issue description is vague about scope, affected flows, or expected behavior, surface those gaps explicitly.
- **Assumption surfacing**: For each assumption you are making, state it and ask the user to confirm or correct.

Examples of discovery-driven questions:
- "I found that `Codeunit X` uses `OnAfterPost` but doesn't handle [scenario]. Is that intentional, or should the new feature cover it?"
- "The existing code has two patterns for [area]: [pattern A] in `Module X` and [pattern B] in `Module Y`. Which should this feature follow?" _(present trade-offs for each)_
- "The issue doesn't specify behavior when [edge case]. I'd assume [default]. Does that match your expectation?"

#### 5b. Standard BC/AL Questions (Fallback Checklist)

After discovery-driven questions, review this checklist for anything not already covered:

- Does this need to integrate with existing BC events (OnBefore/OnAfter patterns)?
- Should subscribers be able to override behavior (IsHandled pattern)?
- Will this affect posting routines or require Commit() control?
- Are there permission considerations (RIMD on new tables)?
- Should this support multi-company scenarios?
- Are there performance concerns requiring SetLoadFields?

#### 5c. Batching & Presentation

- **Batch all questions** into a single interaction, grouped by topic (e.g., business rules, events, permissions, performance).
- **Present options**: When a question has identifiable alternatives, present them as choices with brief trade-off descriptions. Include a recommended option when you have a basis for one.
- **State defaults**: For each question, state what you would assume if the user does not answer.

#### 5d. Question Resolution Gate (Hard Stop)

Do not proceed to Step 6 until:
- All questions flagged in the Business Rules table (Clarification column = "Yes") are resolved.
- The user has responded to discovery-driven questions.
- If the user's answers reveal new rules or invalidate existing ones, update the Business Rules table before proceeding.

### 6. Build Business Rules Comment Payload (Internal)

Prepare the final issue comment markdown payload using this structure:

```markdown
## Business Rules Analysis

| Rule # | Business Rule | Source | Event Hook? | BC Standard? |
|--------|---------------|--------|-------------|--------------|
| 1 | ... | Issue | ... | ... |
| 2 | ... | Code | ... | ... |

**BC Subsystems:** [list from Phase 1]
**Reference Guidance:** Sources consulted - key insights: [summary]

Questions clarified in conversation. Proceeding to architecture design.
```

Do not present raw markdown by default; keep it internal unless the user explicitly asks for it.

### 7. Present Phase Outcome Review (Required Before Write)

Present a review-friendly summary (not raw markdown) that includes:
- Intended write target: new issue comment
- What will be added: Business Rules Analysis heading + table + BC subsystems + reference guidance summary
- Counts: number of rules, number of clarified questions, number of unresolved items
- What remains unchanged: issue body content
- Risks/assumptions: any uncertain rules or follow-up needed

### 8. Approval Gate (Hard Stop)

Ask for explicit approval before posting the comment.
- If approved: proceed to write.
- If not approved or unclear: stop, revise summary/payload, and wait.
- Do not proceed to Phase 3 without explicit approval.

### 9. Post Comment via Temp File (Required)

- Write payload to unique temp file in `$env:TEMP` (UTF-8).
- Post with `gh issue comment <number> --body-file <temp-file>`.
- Do not use inline `--body`.

### 10. Post-Update Verification (Required)

Re-read the created issue comment from GitHub and verify basic structure:
- `## Business Rules Analysis` heading exists.
- Business Rules table includes header and separator rows.
- Any code fences are properly opened/closed.

If verification fails, reapply the comment once, re-read, and verify again. If it still fails, stop and report the formatting mismatch.

### 11. Cleanup

Delete the temp file (best effort) after verification.

## User Checkpoint

All clarifying questions must be answered and Phase 2 write must be explicitly approved before Phase 3.
