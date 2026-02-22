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

Ask clarifying questions with AL/BC-specific focus:

**Standard Questions:**
- "Does this need to integrate with existing BC events (OnBefore/OnAfter patterns)?"
- "Should subscribers be able to override behavior (IsHandled pattern)?"
- "Will this affect posting routines or require Commit() control?"
- "Are there permission considerations (RIMD on new tables)?"
- "Should this support multi-company scenarios?"
- "Are there performance concerns requiring SetLoadFields?"

Reference specific patterns found through codebase exploration and reference guidance.

### 6. Post Business Rules to Issue

Post Business Rules as an **issue comment** with this structure:

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

## User Checkpoint

All clarifying questions must be answered before Phase 3.
