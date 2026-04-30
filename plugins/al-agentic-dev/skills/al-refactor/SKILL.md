---
name: al-refactor
description: Refactor AL/Business Central production and test code while keeping tests green — extract interfaces, apply Read → Process → Write, simplify, rename to BC vocabulary. Use after green inside /al-implement, or standalone on legacy code; may add tests when refactoring uncovers branches.
---

# /al-refactor — Improve shape while green

Refactor production and test code without changing behaviour. Run `/al-build` between meaningful changes. **Stop if a green test goes red.**

**Resolve `tasks.md`:** Branch matches `^\d{3}-`? Use `specs/<branch>/tasks.md`. Otherwise `Stop.` — run `/al-design` first. Calling task is `[!]`? `Stop.` — `T-X is [!] — run /al-steer to clear the replan.`

## Flow

1. **Plan.** Write a 5–10 bullet refactor checklist for the area, drawn from *Architecture* and *Simplification* — what to extract, simplify, rename, reshape under R→P→W and BC vocabulary. If `architecture.md` exists, seed from its brownfield touchpoints. Append to the calling task's Notes (or a temporary note if standalone).
2. **Second opinion (gate).** See below. **No silent skip.**
3. **Refactor.** Apply *Architecture*, *Simplification*, *AppSource*, *Naming* inline. Run `/al-build` after every meaningful change. Production and tests are first-class — refactor both.
4. **Replan check (gate).** See below.

**Standalone legacy code without tests.** Use `${CLAUDE_SKILL_DIR}/references/legacy-refactor-plan.md` — phased plan starting with "write tests first", with `/al-build` between phases. *Architecture* and *Simplification* below compose with it.

## Architecture

- **Testable by construction** — extract interfaces for DB I/O, time, HTTP, environment seams. Inject via overload pattern to preserve back-compat.
- **Two adapters = real seam.** One adapter is hypothetical. Production + test usually justify; one-adapter "interfaces for testability" are speculative bloat.
- **Read → Process → Write.** Read inputs first (DB, services, parameters), pass records-by-value or DTOs into a pure procedure, write outputs last. **The middle has no DB calls and no external calls** — unit-testable in isolation.
- **Deletion test.** If removing a module makes complexity vanish, it was a pass-through — delete it. If removing concentrates complexity at N callers, it earned its keep. Skip when the seam is a published event with no in-tree callers.
- **Two test surfaces.** E2E crosses `Access = Public` and survives internal refactors. Unit tests live inside the module against `Access = Internal` — especially the P layer. Internal renames break unit tests; update tests alongside, do not push tests outward.
- **A unit test reaching past `Access = Internal`** means reshape, not widen — split the responsibility into a smaller internal codeunit.
- Prefer standard BC patterns. If a pattern needs explaining, it is wrong for AL.

## Simplification

- Remove dead code, redundant guards, unused variables, dead branches.
- Collapse equivalent test scenarios via shared setup or parameterised data — preserve `[SCENARIO]` intent.
- Rename when the name lies. BC term over generic programming term.
- Rename a test or edit `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]`? Re-verify against the originating Gherkin bullet in `tasks.md` — if intent shifts, update the bullet alongside.

## AppSource compliance

- No BaseApp modification, even during refactor.
- Never rename a shipped object, table field, page action, or procedure that other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce the new name alongside.
- Extracted interfaces and event publishers keep their signatures stable once shipped — the public surface is the contract.
- Any new permission set entry ships in the same change. Every new `Caption` is translatable. Schema migrations route through install/upgrade codeunits.

## Architectural vocabulary

Full discipline in `${CLAUDE_SKILL_DIR}/../al-design/references/LANGUAGE.md`.

- **Module** — folder under `src/<module>/`, cohesive unit.
- **Interface** — everything a caller must know: signatures, invariants, ordering, error modes, required setup. Includes but exceeds AL `interface` objects.
- **Seam** — where behaviour can be altered without editing in place. Publisher event, AL `interface` boundary, Implementer injection point.
- **Adapter** — concrete codeunit at a seam. **Two adapters = real seam.**
- **Depth** — leverage at the interface. Deep = much behaviour behind a small interface.

## Naming and vocabulary

- **BC verbs:** Insert / Modify / Delete (records — not Create/Update/Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` — suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Second opinion (gate)

Cross-check the refactor checklist with copilot CLI for completeness — independent perspective, not authority.

**Invoke:** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt shape:** the area + the checklist + *"what is missing for R→P→W, BC vocabulary, simplification, and AppSource compliance?"*. Ask for a bulleted list of gaps. No predefined out-of-scope.

**Reconcile each bullet:** accept (update checklist) or reject with a one-line Notes reason. `/grill-me` when judgement needs the user. **No silent skip.** Failure / unavailable / timeout → `Second opinion skipped: <reason>` as a Notes line, proceed.

## Replan check (gate)

Run after tests are green. Triggers in scope: #2 hidden pre-req, #4 sibling now wrong, #6 architecture decomposition wrong. **All hard-halt.**

| # | Detect | Action |
|---|---|---|
| 2 | Refactor surfaces a table, codeunit, or permission with no covering task | Set calling task `[!]`, append `**Replan** trigger #2: <reason>`, stop. |
| 4 | Reshape invalidates another task's context line or scenarios | Set `[!]`, append `**Replan** trigger #4: <reason>`, stop. |
| 6 | R→P→W boundary cuts across tasks, or `architecture.md` is wrong | Set `[!]`, append `**Replan** trigger #6: <reason>`, stop. |

**Trivia exception** (precedes hard-halt). Missing scaffolding — permission set entry, object ID assignment, caption for a new object, BC-vocabulary rename — is not a replan trigger. Apply inline (≤3 lines), append `**Absorbed**: <one line>` to Notes, re-run `/al-build`, continue. Cap: one absorption per task. Never absorbs schema changes, new event publishers, new codeunits, or test-outcome changes.

Standalone refactors with no calling task: append the Notes line to a temporary note and recommend `/al-steer`. Code stays at green — planning halt, not rollback. Replan venue is `/al-steer`.

## Discipline

- May add new tests when refactoring reveals uncovered branches.
- If a hidden requirement or design flaw surfaces → stop, append a Notes line, recommend `/al-design` or `/al-refine` via `/al-steer`. **No silent scope expansion.**
- No comments unless the WHY is non-obvious. No comment churn.
- Prefer a subagent for output-heavy work.

## Composition

`/al-build` after every meaningful change. `/bc-standard-reference` for BC patterns, event signatures, BaseApp behaviour. `/al-research` when prior knowledge is uncertain. `/grill-me` when a non-obvious trade-off needs the user. `/al-design` for upfront architecture when refactoring legacy without a calling task. `/al-steer` is the replan venue. copilot CLI — second-opinion gate.

## Out of scope

- **No new behaviour.** Belongs in `/al-implement` (new task) or `/al-refine` (re-plan).
- No replan mutations — `/al-steer`.
