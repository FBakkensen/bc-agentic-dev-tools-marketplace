# Phase 1: Discovery

**Goal**: Understand the issue in repository context and identify the affected BC/AL areas.

Apply `GR-1`, `GR-2`, and `GR-3` from `SKILL.md`.

## Actions

1. **Load project context**
   - Review repo conventions (README, CONTRIBUTING, docs, internal guidance).

2. **Retrieve issue details**
   - Read title, body, labels, and status.
   - Warn if issue is closed.

3. **Identify impacted scope**
   - Project areas:
     - Core domain functionality
     - BC standard integrations
     - Extension points/events
     - UI surfaces
     - Business rules/validation
   - BC subsystems:
     - Sales, Purchase, Inventory, Manufacturing, Finance, Warehouse, Other
   - Likely AL object types:
     - Tables/TableExtensions
     - Codeunits
     - Pages/PageExtensions
     - Event subscribers
     - Interfaces/Enums
     - Reports/XMLports

4. **Optional quick file discovery**
   - Search for files matching issue keywords to prepare Phase 2.

5. **Present Phase 1 summary in chat**
   - Issue title + key requirements
   - Labels/context
   - Impacted project areas
   - BC subsystems
   - Likely AL object types
   - Current issue body structure (if any)

## User Checkpoint (Hard Stop)

Ask for confirmation before Phase 2.

Example:
> "I've analyzed issue #{number} in repository context and summarized affected areas/subsystems. Ready to proceed to codebase exploration?"

Do not proceed to Phase 2 without user confirmation.
