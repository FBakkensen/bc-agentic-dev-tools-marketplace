---
name: bc-standard-reference
description: "Locate canonical Business Central Standard behavior (BaseApp, System Application, APIV2, etc.) to identify events, event publishers, codeunits, tables/fields, tests, pages, codeunits, APIs, etc.. Use when you need standard behavior, event signatures, or reference implementation patterns."
---

# BC Standard Reference

Use the canonical mirror of the Business Central Standard repo `fbakkensen/bc-w1` to locate events, APIs, tables, fields, tests, and implementation patterns. The focus is on *what* to find and *how to reason about it*, not on any specific tools.

## When to Use

- Finding events to subscribe to (e.g., "What events fire when posting a sales order?")
- Understanding standard implementations (e.g., "How does BC calculate line discounts?")
- Locating test patterns (e.g., "How do standard tests set up sales documents?")
- Finding API implementations (e.g., "How does the APIV2 handle customer creation?")
- Discovering table fields and their purposes
- Learning how BC implements a specific feature

## What You Need

- Target domain (Sales, Purchases, Inventory, etc.)
- Object name or behavior you're investigating
- Optional: event name or API endpoint if you already know it

## Procedure (Tool-Agnostic)

### Step 1: Identify Standard Objects and Events

Identify the relevant codeunits, tables, pages, and events for the behavior you need. Use any symbol discovery method available to you (dependency metadata, symbols, reference notes, or docs).

### Step 2: Search the Standard Source Mirror

Search the repo `fbakkensen/bc-w1` using object/event names and narrow by domain paths (e.g., Sales/Posting, Pricing, Inventory). Your goal is to find the exact file that defines the object or publishes the event.

### Step 3: Inspect Implementation

Open the candidate file and confirm:
- The object declaration (name/ID)
- The event publisher and signature (if relevant)
- The implementation flow surrounding the event or behavior

### Step 4: Cross-Check Official Documentation

Use official documentation to confirm AL syntax, BC concepts, and best practices that contextualize what you saw in source.

## Outputs / Success Criteria

- File path(s) in the standard mirror
- Object name and ID
- Event signature(s) and publisher location
- A recommended hook point or reference pattern

## Subagent Exploration (Optional)

For open-ended questions, delegate to a subagent with a focused brief:

```
Search the standard mirror `fbakkensen/bc-w1` for [topic]. Identify candidate files, inspect implementations, and report back with relevant events, patterns, and example locations.
```

## References

For detailed examples and repository structure:

- [Repository Structure](./references/repo-structure.md) - Full folder layout and key paths
- [Search Patterns](./references/search-patterns.md) - Tool-agnostic search heuristics
- [Scenario Walkthroughs](./references/scenarios.md) - Step-by-step guides for common tasks
