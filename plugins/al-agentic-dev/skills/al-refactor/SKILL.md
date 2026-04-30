---
name: al-refactor
description: Refactor AL/Business Central production and test code while keeping tests green. Improves shape — extracts interfaces for testable design, applies Read → Process → Write, simplifies, renames to BC vocabulary. Use after green inside /al-implement, or standalone on legacy code that needs cleanup. May add new tests when refactoring reveals uncovered branches.
---

# /al-refactor — Improve shape while green

Refactor production and test code while keeping tests green. Use `/al-build` between meaningful changes. **Stop if a green test goes red.**

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-design` first. If the calling task is `[!]`, stop: `T-X is [!] — run /al-steer to clear the replan.`

## Plan

Before changing code, write a 5–10 bullet refactor checklist for the area, drawing from *Architecture* and *Simplification* below — what to extract, simplify, rename, or reshape under R→P→W and BC vocabulary. **If the calling task's spec folder has `architecture.md`, seed the checklist from its brownfield touchpoints.** Append to the calling task's Notes (or a temporary note if standalone).

**Standalone refactor of legacy code without sufficient tests.** When refactoring pre-test legacy code (no calling task, no `architecture.md`, behaviour not covered by tests), use the 11-step phased process in `${CLAUDE_SKILL_DIR}/references/legacy-refactor-plan.md`. That plan starts with "write tests first" and sequences safe / structural / API-modernisation phases with `/al-build` between every phase. The inline *Architecture* and *Simplification* sections of this skill compose with that plan.

## Architectural vocabulary (state inline)

Use these terms exactly. Full discipline in `${CLAUDE_SKILL_DIR}/../al-design/references/LANGUAGE.md`.

- **Module** — a folder under `src/<module>/` containing a cohesive unit. The whole feature lives inside the same AL app.
- **Interface** — everything a caller must know: signatures, invariants, ordering, error modes, required setup. Includes but is not limited to AL `interface` objects.
- **Seam** — a place where behaviour can be altered without editing in place. Publisher event, AL `interface` boundary, Implementer injection point.
- **Adapter** — a concrete codeunit satisfying an interface at a seam.
- **Depth** — leverage at the interface. Deep = a lot of behaviour behind a small interface. Shallow = interface as complex as the implementation.
- **Deletion test** — imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep. Doesn't apply when the seam is a published event with no in-tree callers.
- **Two adapters = real seam.** One adapter is a hypothetical seam — don't introduce a port unless at least two adapters justify it (typically production + test). One-adapter "interfaces for testability" are speculative bloat.

## Architecture

- **Testable by construction:** extract interfaces for external dependencies (DB I/O, time, HTTP, environment) — but only when at least two adapters justify the seam. Inject via overload pattern to preserve back-compat.
- **Read → Process → Write.** Read inputs first (DB, services, parameters), pass them as records-by-value or DTOs into a pure procedure, write outputs last. **The middle has no DB calls and no external calls** — unit-testable in isolation.
- **Apply the deletion test** to anything that looks shallow. If the module is a pass-through, delete it; if removing concentrates complexity at N callers, it earned its keep.
- **Two test surfaces, both first-class.** Integration / E2E tests cross the external seam (`Access = Public`) and survive internal refactors. Unit tests live inside the module against `Access = Internal` procedures — especially the P (pure process) layer of R→P→W. Refactors that change internal procedure names break unit tests; that's expected. The fix is to update tests alongside, not to push tests out to the external seam.
- **When a unit test reaches past `Access = Internal`** (wanting to test a `local` procedure), reshape rather than widen visibility — split the responsibility into a smaller internal codeunit so the test reaches it through legitimate internal seams.
- Prefer standard BC patterns over clever abstractions. If a pattern needs explaining, it's probably wrong for AL.

## AppSource compliance (state inline — applies to changing shape)

- No BaseApp modification, even during refactor.
- Renames: never rename a shipped object, table field, page action, or procedure that other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce the new name alongside.
- Extracted interfaces / event publishers must keep their signatures stable once shipped — the public surface IS the contract.
- Every new permission set entry needed by the refactored shape gets added in the same change.
- Translations: every new `Caption` ships translatable.
- If the refactor implies a schema migration, route it through an install/upgrade codeunit — never silent.

## Naming and vocabulary (state explicitly — do not rely on CLAUDE.md)

- **BC vocabulary:** Insert / Modify / Delete (records — not Create/Update/Remove), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Record variables** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures:** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Simplification (lives inside /al-refactor)

- Remove dead code, redundant guards, unused variables, dead branches.
- Collapse equivalent test scenarios via shared setup or parameterised data — without losing the `[SCENARIO]` intent comment.
- Rename when the name lies. Prefer the BC term over a generic programming term.
- **When renaming a test or editing `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` comments, re-verify the comments still match the originating Gherkin bullet in `tasks.md`.** If a rename loses the bullet's intent, update the bullet alongside the test.

## Second opinion (gate)

Cross-check the refactor checklist with copilot CLI for completeness. Independent perspective from a different training distribution — not authority.

**Invoke:** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt meta-shape:** the area + the checklist + the question *"what's missing for R→P→W, BC vocabulary, simplification, and AppSource compliance?"*. Ask for a bulleted list of gaps. No predefined out-of-scope rules — trust copilot to identify what matters in context.

**Reconcile each bullet:** accept (update checklist) or reject with a one-line reason as a Notes line. **No silent skip.** `/grill-me` when judgement needs the user.

**Trust:** copilot's AL/BC training is also thin — weigh against this skill's discipline and *"standard BC patterns over clever abstractions."*

**Failure:** if copilot is unavailable / errors / times out, record `Second opinion skipped: <reason>` as a Notes line and proceed.

## Discipline

- Run `/al-build` after every meaningful change. Tests stay green throughout.
- Refactor production AND test code together — both are first-class.
- May add new tests when refactoring reveals uncovered branches.
- If refactor reveals a hidden requirement or design flaw → stop, add a Notes line to `tasks.md`, recommend `/al-design` (architecture reshape) or `/al-refine` (Gherkin reshape) via `/al-steer`. **No silent scope expansion.**
- No comments unless the WHY is non-obvious. No comment churn.
- **Prefer a subagent for output-heavy work.**

## Replan check (gate)

Run at the end of the refactor, after tests are green. Triggers in scope: #2 hidden pre-req, #4 sibling now wrong, #6 architecture decomposition wrong. **All hard-halt.**

| # | Detect | Action |
|---|---|---|
| 2 | Refactor surfaces a table, codeunit, or permission with no covering task | Set the calling task `[!]`, append `**Replan** trigger #2: <reason>`, stop. |
| 4 | Reshaped code invalidates another task's context line or scenarios | Set `[!]`, append `**Replan** trigger #4: <reason>`, stop. |
| 6 | The R→P→W boundary now cuts across tasks — extracted module/pattern straddles task boundaries, or the feature-level architecture in `architecture.md` is wrong | Set `[!]`, append `**Replan** trigger #6: <reason>`, stop. |

Standalone refactors with no calling task: append the Notes line to a temporary note and recommend `/al-steer`. Code state stays as it lands at green — planning halt, not rollback.

## Composition

- `/al-build` after every meaningful change.
- `/bc-standard-reference` when reaching for a BC pattern, event signature, or BaseApp behaviour.
- `/al-research` when prior knowledge is uncertain.
- `/grill-me` when a non-obvious design trade-off needs the user.
- `/al-design` for upfront feature architecture when refactoring legacy code without a calling task. May reshape `architecture.md`.
- copilot CLI — second-opinion gate on the refactor checklist before changes start.

## Out of scope

- **No new behaviour.** Anything that changes what the system *does* belongs in `/al-implement` (new task) or `/al-refine` (re-plan).
- No replan mutations — that's `/al-steer`.
