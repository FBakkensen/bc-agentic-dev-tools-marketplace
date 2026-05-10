# AL Testability Pillars

Apply when writing new production codeunits, refactoring existing ones, or reviewing whether a codeunit is agent-friendly. Cited by `/al-grill-adr` for domain-vs-architecture routing. Not relevant for data migrations, config files, or test codeunits (which have their own contracts).

## 7 Pillars of Agent-Friendly Code

| # | Pillar | What it means |
|---|---|---|
| 1 | **Separation of concerns** | Decision logic separated from side-effect invocation |
| 2 | **Explicit contracts** | Signatures, interfaces, enums — if it's not in code, it doesn't exist |
| 3 | **Testability** | Inputs, outputs, and dependencies all visible |
| 4 | **Consistency** | The codebase IS the agent's primary prompt — inconsistency = permission to improvise |
| 5 | **Appropriate abstraction** | Neither too flat nor too deep |
| 6 | **Intent preservation** | The WHY survives agent rewrites — structure, comments, tests, CLAUDE.md |
| 7 | **Reviewability** | Can a reviewer efficiently verify the agent did the right thing? |

## Pillar 2 — Explicit contracts

"If it's not in code, it doesn't exist." Agents violate what they can't see: tribal knowledge, unwritten conventions, assumptions. Implicit contracts break silently; explicit contracts break loudly. If you can't express it as a signature, interface, or test, it won't survive a rewrite.

## Pillar 3 — Testability requires visible inputs

A procedure must receive everything it needs through parameters — not by reading from global variables or setup tables.

Anti-pattern: reading a setup record as a local variable inside logic. Correct: accept `var Setup: Record "<Setup Table>"` as a parameter.

Separate decisions from side effects — you can unit-test decisions without triggering side effects.

## Pillar 4 — Consistency

Every pattern mismatch tells agents "there are multiple correct ways — pick one." Structural consistency matters: error handling shape, module layout, interaction patterns. Naming case is irrelevant to agents; naming semantics is critical.

| Good | Bad |
|---|---|
| `Customer`, `SalesHeader`, `Item` | `C1`, `C2`, `CRec`, `obj` |

## Pillar 6 — Comments are load-bearing

Intent lives in three places: code structure, code comments, and agentic artifacts (skills, rule files, architecture docs). A comment explaining WHY a scenario exists survives refactoring. Tests written against **intent** survive agent rewrites. Tests written against **implementation** die with every refactor.

## What NOT to put in CLAUDE.md

Stop burdening agents with cosmetic rules — they waste context and agents obey them at the cost of functional quality.

**Do not add to CLAUDE.md:**
- Indentation, brace placement, blank line counts
- File/function/parameter count limits
- Physical ordering within a file (locals first, alphabetical, etc.)
- Naming case conventions (PascalCase vs camelCase — case is irrelevant to agents)
- "Avoid abbreviations" as a standalone rule

**Do add (structural):**
- Separation of concerns and single responsibility
- Explicit contract declarations (interface blocks, typed parameters)
- Clear boundaries between decision logic and side effects

Keep linters as a build gate. Do not transcribe linter rules into CLAUDE.md as behavioral contracts.
