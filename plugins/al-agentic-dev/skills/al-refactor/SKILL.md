---
name: al-refactor
description: Refactor AL/Business Central production and test code while keeping tests green. Improves shape — extracts interfaces for testable design, applies Read → Process → Write, simplifies, renames to BC vocabulary. Use after green inside /al-implement, or standalone on legacy code that needs cleanup. May add new tests when refactoring reveals uncovered branches.
---

# /al-refactor — Improve shape while green

Refactor production and test code while keeping tests green. Use `/al-build` between meaningful changes. **Stop if a green test goes red.**

## Architecture

- **Testable by construction:** extract interfaces for external dependencies (DB I/O, time, HTTP, environment). Inject via overload pattern to preserve back-compat. Use interfaces as the standard tool for clean, testable design.
- **Read → Process → Write.** Read inputs first (DB, services, parameters), pass them as records-by-value or DTOs into a pure procedure, write outputs last. **The middle has no DB calls and no external calls** — unit-testable in isolation.
- Prefer standard BC patterns over clever abstractions. If a pattern needs explaining, it's probably wrong for AL.

## Naming and vocabulary (state explicitly — do not rely on CLAUDE.md)

- **BC vocabulary:** Insert / Modify / Delete (records — not Create/Update/Remove), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Record variables** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures:** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Simplification (lives inside /al-refactor)

- Remove dead code, redundant guards, unused variables, dead branches.
- Collapse equivalent test scenarios via shared setup or parameterised data — without losing the `[SCENARIO]` intent comment.
- Rename when the name lies. Prefer the BC term over a generic programming term.

## Discipline

- Run `/al-build` after every meaningful change. Tests stay green throughout.
- Refactor production AND test code together — both are first-class.
- May add new tests when refactoring reveals uncovered branches.
- If refactor reveals a hidden requirement or design flaw → stop, add a Notes line to `tasks.md`, recommend `/al-refine`. **No silent scope expansion.**
- No comments unless the WHY is non-obvious. No comment churn.

## Composition

- `/al-build` after every meaningful change.
- `/bc-standard-reference` when reaching for a BC pattern, event signature, or BaseApp behaviour.
- `/al-research` when prior knowledge is uncertain.
- `/grill-me` when a non-obvious design trade-off needs the user.

## Out of scope

- **No new behaviour.** Anything that changes what the system *does* belongs in `/al-implement` (new task) or `/al-refine` (re-plan).
