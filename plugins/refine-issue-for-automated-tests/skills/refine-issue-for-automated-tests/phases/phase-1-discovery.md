# Phase 1: Discovery

**Goal**: Understand what needs to be built from the GitHub issue, load project context, and identify affected areas.

## Actions

1. **Load project context**: Review repository conventions if available (README, CONTRIBUTING, docs, internal guidelines).

2. **Retrieve issue details**: Read the GitHub issue to understand requirements.

3. **Validate issue state**: Warn if issue is closed.

4. **Identify project-specific areas affected**:
   Based on repository context, identify which modules/features are impacted.

   _Example checklist (adapt to current project):_
   - [ ] Core domain functionality
   - [ ] Integration with BC standard areas
   - [ ] Extension points / Events
   - [ ] UI components
   - [ ] Business rules / validation

5. **Identify BC subsystems affected**:
   - [ ] Sales (Documents, Pricing, Posting)
   - [ ] Purchase (Documents, Vendors)
   - [ ] Inventory (Items, Locations, Tracking)
   - [ ] Manufacturing (Production Orders, BOMs, Routing)
   - [ ] Finance (G/L, Journals, Posting)
   - [ ] Warehouse (Picks, Puts, Receipts)
   - [ ] Other: ___

6. **Identify likely AL object types**:
   - [ ] New Tables / TableExtensions
   - [ ] New Codeunits (Business Logic)
   - [ ] New Pages / PageExtensions
   - [ ] Event Subscribers
   - [ ] Interfaces / Enums
   - [ ] Reports / XMLports

7. **Initial file discovery** (optional): Search for files matching feature keywords or use semantic search.

8. **Present summary**:
   - Issue title and key requirements
   - Labels and context
   - Project areas affected (from project overview)
   - BC subsystems affected
   - AL object types likely needed
   - Current issue body structure (if any)

## User Checkpoint

> "I've analyzed issue #{number} in context of the repository. Here's my understanding: [summary]. Project areas: [list]. BC subsystems: [list]. Ready to proceed with codebase exploration?"

Wait for user confirmation before Phase 2.
