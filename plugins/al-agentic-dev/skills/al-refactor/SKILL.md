---
name: al-refactor
description: Refactor AL/Business Central production and test code while keeping tests green — find deepening opportunities, apply Read → Process → Write, rename to BC vocabulary, extract real seams. Use after green inside /al-implement, or standalone on legacy code; may add tests when refactoring uncovers branches.
---

# /al-refactor — Improve shape while green

Surface friction in AL code and reshape modules that earn their keep. Run `/al-build` between meaningful changes. Stop the moment a green test goes red.

**Resolve `tasks.md`:** Branch matches `^\d{3}-`? Use `specs/<branch>/tasks.md`. Otherwise `Stop.` — run `/al-design` first. Calling task is `[!]`? `Stop.` — `T-X is [!] — run /al-steer to clear the replan.`

**Anti-pattern: refactor while red.** Refactor only against a green build. If `/al-build` is red, the work belongs in `/al-implement` (drive to green) or in a fresh red→green cycle, not here.

## Vocabulary

Full discipline in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`.

Read before writing to `tasks.md`:
- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` — voice rules for the prose itself.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md` — what goes in a Notes line vs an ADR; trigger test; valid shapes.

Use these terms exactly. Don't substitute "component," "service," "API," or "boundary." Consistent language is the point.

- **Module** — anything with an interface and an implementation: a procedure, a codeunit, a folder under `src/<module>/`, or a tier-spanning slice.
- **Interface** — everything a caller must know to use the module: signatures, invariants, ordering, error modes, required setup, permissions. Includes but exceeds the AL `interface` keyword.
- **Implementation** — the code inside.
- **Seam** — a place where you can alter behaviour without editing in place. Publisher event, AL `interface` boundary, `Implementation` enum injection point.
- **Adapter** — a concrete codeunit satisfying an interface at a seam.
- **Depth** — leverage at the interface. **Deep** = much behaviour behind a small interface. **Shallow** = interface nearly as complex as the implementation.
- **Leverage** — what callers get from depth: capability per unit of interface they have to learn.
- **Locality** — what maintainers get from depth: change, bugs, knowledge concentrated in one place.

## Flow

1. **Plan.** Walk the changed area and write a refactor checklist — one bullet per real gap, grouped by category: *Smells*, *Reshape*, *Naming*, *AppSource*. Drop categories with no gap. Seed from `architecture.md` brownfield touchpoints when present.
2. **Second opinion (gate).** See below. **No silent skip.**
3. **Refactor.** Apply the checklist inline. `/al-build` after every meaningful change. Production and tests are first-class — refactor both.
4. **Replan check (gate).** See below.

**Standalone legacy code without tests.** Use `${CLAUDE_SKILL_DIR}/references/legacy-refactor-plan.md` — phased plan starting with "write tests first," dependency-classified deepening, replace-don't-layer testing strategy.

## Smells

After the green build, look for:

- **Duplication** — extract a procedure/codeunit. The deletion test should pass: removing the duplicate concentrates complexity at one place, not spreads it.
- **Long methods** — break into private helpers behind `Access = Internal`. Tests stay on the public interface; helpers are not the test surface.
- **Shallow modules** — interface nearly as complex as the implementation. Merge upward, or deepen by absorbing callers' boilerplate.
- **Feature envy** — procedure reaches into another record/codeunit's data more than its own. Move the procedure to where the data lives.
- **Primitive obsession** — `Code[20]` carrying meaning ("if first char is 'X' it's blocked") becomes a small record or enum.
- **Existing code revealed.** The new test has unmasked a flaw upstream — the surrounding module is wrong, not just the diff. Note it; reshape if cheap, otherwise stop and run `/al-steer`.

## Reshape

- **Deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through — delete it. If complexity reappears across N callers, it earned its keep — keep and probably deepen. Skip when the seam is a published event with no in-tree callers.
- **Two adapters = real seam.** One adapter is a hypothetical seam — speculative bloat. Production + test fakes usually justify a real seam; one-adapter "interfaces for testability" do not. The prove-it threshold is two adapters that already need to coexist.
- **Read → Process → Write.** Read inputs first (DB, services, parameters). Pass records-by-value or DTOs into a pure Process procedure. Write outputs last. **The Process layer has no DB calls and no external calls** — unit-testable in isolation.
- **R → P → W is the reshape rule, not a label.** When a procedure mixes I/O and computation, splitting it along this line is the refactor — not annotating the existing tangle.
- **Two test surfaces.** E2E crosses `Access = Public` and survives internal refactors. Unit tests live inside the module against `Access = Internal` — especially the Process layer. Internal renames break unit tests; update tests alongside, do not push tests outward.
- **A unit test reaching past `Access = Internal`** signals reshape, not widen — split the responsibility into a smaller internal codeunit so the surface tells the truth.
- **The interface is the test surface.** If you want to test past it, the module is the wrong shape.
- Prefer standard BC patterns. If a pattern needs explaining, it is wrong for AL.

## Naming

Rename when the name lies. BC term over generic programming term. AL reads naturally to AL developers.

| Verb | _Avoid_ |
|---|---|
| **Insert** (record operations) | Create, Add, New |
| **Modify** (record operations) | Update, Change, Set |
| **Delete** (record operations) | Remove, Drop, Destroy |
| **Post** | Submit, Process, Commit |
| **Validate** | Check, Verify, Ensure |
| **Get** / **Find** | Fetch, Retrieve, Load, Query |
| **Ledger Entry** | Transaction, History, Movement |
| **No.** | ID, Identifier, Code |
| **Procedure** | Method, Function, Routine |

- **Objects:** `"Prefix Feature Suffix"` — suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.
- **Tests** PascalCase scenario name (`PostSalesOrderWithItemCharge`), not `GivenX_WhenY_ThenZ`.

**Gherkin sync rule.** Renaming a test or editing `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]`? Re-verify against the originating Gherkin bullet in `tasks.md`. If intent shifts, update the bullet alongside via `/al-refine`.

## AppSource

- **Anti-pattern: rename across published API.** Never rename a shipped object, table field, page action, or procedure that other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce the new name alongside. Internal-only symbols (`Access = Internal`, unpublished codeunits) rename freely.
- Extracted interfaces and event publishers keep their signatures stable once shipped — the public surface is the contract.
- No BaseApp modification, even during refactor.
- Any new permission set entry ships in the same change. Every new `Caption` is translatable. Schema migrations route through install/upgrade codeunits.

## Second opinion (gate)

Cross-check the refactor checklist via `/al-second-opinion` — independent perspective, not authority.

**Invoke:** `/al-second-opinion` with the prompt body below.

**Prompt body shape:** the area + the checklist + *"what is missing for R→P→W, BC vocabulary, simplification, and AppSource compliance? Return a bulleted list."* `/al-second-opinion` prepends the role frame and applies the canonical safety envelope.

**Reconcile each returned bullet:** accept (update checklist) or reject. Rejection rationale stays in the session — DO NOT write it to Notes. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`. `/grill-me` when judgement needs the user. If `/al-second-opinion` returns `Second opinion skipped: <reason>`, note it in the session and proceed.

## Replan check (gate)

Run after tests are green. Triggers in scope: #2 hidden pre-req, #4 sibling now wrong, #6 architecture decomposition wrong. **All hard-halt.**

| # | Detect | Action |
|---|---|---|
| 2 | Refactor surfaces a table, codeunit, or permission with no covering task | Set calling task `[!]`, append `**Replan** trigger #2: <reason>`, stop. |
| 4 | Reshape invalidates another task's context line or scenarios | Set `[!]`, append `**Replan** trigger #4: <reason>`, stop. |
| 6 | R→P→W boundary cuts across tasks, or `architecture.md` is wrong | Set `[!]`, append `**Replan** trigger #6: <reason>`, stop. |

**Trivia exception** (precedes hard-halt). Missing scaffolding — permission set entry, object ID assignment, caption for a new object, BC-vocabulary rename — is not a replan trigger. Apply inline (≤3 lines), append `**Absorbed**: <one line>` to Notes, re-run `/al-build`, continue. Cap: one absorption per task. Never absorbs schema changes, new event publishers, new codeunits, or test-outcome changes.

Standalone refactors with no calling task: append the Notes line to a temporary note and run `/al-steer`. Code stays at green — planning halt, not rollback. Replan venue is `/al-steer`.

## Discipline

- **Anti-pattern: feature creep during refactor.** No new behaviour. New behaviour belongs in `/al-implement` (new task) or `/al-refine` (re-plan). The refactor diff should leave observable behaviour identical.
- May add new tests when refactoring reveals uncovered branches — those tests must pass against the *current* code before the refactor proceeds.
- If a hidden requirement or design flaw surfaces → stop, append a Notes line, route to `/al-design` or `/al-refine` via `/al-steer`. **No silent scope expansion.**
- `tasks.md` Notes entries are forward-facing facts — each independently actionable by a future agent.
- A comment earns its place only when WHY is non-obvious from BC vocabulary and the surrounding code. No comment churn.

  | | Comment |
  |---|---|
  | _Avoid_: | `// Insert the customer record` before `Customer.Insert(true);` |
  | Use: | `// BaseApp Codeunit 80 fires OnAfterPostSalesDoc twice for partial shipments — guard against double-post` |
- Prefer a subagent for output-heavy work.

## Composition

`/al-build` after every meaningful change. `/bc-standard-reference` for BC patterns, event signatures, BaseApp behaviour. `/al-research` when prior knowledge is uncertain. `/grill-me` when a non-obvious trade-off needs the user. `/al-design` for upfront architecture when refactoring legacy without a calling task. `/al-steer` is the replan venue. `/al-implement` calls `/al-refactor` only after green; `/al-mutate` runs after refactor to validate test rigor. `/al-second-opinion` is the advisory gate (read-only sandbox; copilot CLI under the hood).

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `decoupling.md` — three-phase legacy refactor (extract internals → interface → inject); Phase 3 self-injection lands the seam without breaking callers.
- `environment-interfaces.md` — three default seams (`IEnvironment`, `IApiRequest`, `IFinance`-family) plus temp-record alternative; name the pattern before extracting a fresh one.

## Out of scope

- **No new behaviour.** Belongs in `/al-implement` (new task) or `/al-refine` (re-plan).
- **No test changes that aren't sync.** Test edits are limited to: Gherkin-bullet sync after a rename, new tests for branches the refactor reveals, deletion of unit tests on modules the refactor merges away.
- **No cross-task scope drift.** One task, one refactor. Surfacing work for a sibling task is a replan, not a side quest.
- No replan mutations — `/al-steer`.
