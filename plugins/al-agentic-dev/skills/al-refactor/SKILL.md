---
name: al-refactor
description: Refactor AL/Business Central production and test code while keeping tests green, find deepening opportunities, apply Read → Process → Write, rename to AL/BC vocabulary and project terminology (per CONTEXT.md), extract real seams. Use after green inside /al-implement (mandatory full pass on whole task diff, once per task), or standalone on legacy code; may add tests when refactoring uncovers branches.
---

# /al-refactor, Improve shape while green

Reshape AL code so the modules that earn their keep deepen and the ones that don't dissolve. Observable behaviour does not change. The disciplines below are the substance you bring; nothing here is a numbered flow to walk.

`/al-build` is the gate between meaningful changes. The moment a green test goes red, stop and recover before continuing.

## Preconditions

- Build is green. Refactor against a red build is not refactor; it is debug, and belongs in `/al-implement`.
- Called from `/al-implement` after green on the current task, OR standalone on legacy code.
- Standalone mode: branch matches `^\d{3}-` and `specs/<branch>/tasks.html` exists, OR the work is pure legacy-code reshape with no calling task. Calling task `data-status="blocked"`: **Stop**, run `/al-steer`.
- Legacy spec folder (`tasks.md` without `tasks.html`): frozen; hand-migrate before continuing.
- Legacy-code mode (no covering tests): write the baseline tests first. A reshape without a regression signal is speculation. Use `${CLAUDE_SKILL_DIR}/references/legacy-refactor-plan.md`.

## What you answer before reshape

The refactor pass produces a code diff, not a durable artifact. What the diff embodies, expressed as questions you must have answers to:

- **What seam is being introduced, hardened, or dissolved?** Name the mechanism (publisher event, AL `interface`, `Implementation` enum, internal helper behind `Access = Internal`) and the adapters that justify it.
- **Where does the R → P → W boundary cut in this area?** R = reads / inputs / events subscribed. P = pure procedure, no DB, no side effects, the unit-test surface. W = effects.
- **Which names lie?** Procedures, records, parameters, fields, objects. A name lies when it describes a generic operation while the body does a BC-specific one; when it uses CRUD vocabulary where the BC verb exists; when the project's CONTEXT.md term has drifted out of the code.
- **What crosses a published API?** Shipped objects, table fields, page actions, public procedures that other extensions may bind to. The answer constrains rename, removal, and signature change.
- **Does the refactor surface new behaviour or a hidden requirement?** If yes, the work belongs elsewhere; route the discovery, do not absorb it.

If a question is unanswerable from the diff, the area is not ready to reshape. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), or `/al-steer` (replan).

## Vocabulary

Architectural vocabulary in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`: Module, Interface, Implementation, Seam, Adapter, Depth, Leverage, Locality. Use these terms exactly. Consistent language is the point.

Voice rules for any prose written into `tasks.html`: `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. Notes destination map: `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md`. Surgical-edit contract on `tasks.html`: `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md`.

## Disciplines

These are how to think about reshape for BC. Apply where each one's *Why* lands. The agent maps rationale to the diff in front of it; no step ordering is implied.

### R → P → W as reshape, not annotation

When a procedure mixes I/O and computation, splitting it along that line *is* the refactor. **Why**: pulling pure decision logic out of read/write context is what makes unit testing possible without standing up DB state. P is the most load-bearing line in the design; it names what is testable without a real database. Annotating the tangle "this part is the read, this part is the process" without splitting changes nothing.

### Deletion test, on every module that smells shallow

Imagine deleting the module. If complexity vanishes, the module was a pass-through; inline at call sites and remove it. If complexity reappears across N callers, the module earned its place and probably wants deepening. **Why**: pass-through modules add navigation cost without hiding anything; one-line wrappers around `SalesHeader.Modify` that add only a name are the canonical case. A posting validator orchestrating dimension checks, No. Series consumption, and ledger writes is the opposite. Does not apply when the seam is a published event with no in-tree callers.

### Two adapters or no seam

A seam without two adapters is hypothetical. **Why**: one adapter is a tautology; the seam is just one codeunit pretending to be flexible. Production + an in-memory test adapter that actually exists counts as two. Two real production transports already deployed counts. "Interface for testability" with no test fake written is one, not two. AL `interface` objects, `Implementation` enums, and event publishers are seam *mechanisms*; picking among them is a shape decision, separate from whether the seam earns its place.

### Depth over indirection

A deep module hides much behaviour behind a small interface. **Why**: depth gives callers leverage (capability per unit of interface they must learn) and gives maintainers locality (change, bugs, knowledge concentrated in one place). Long procedures break into private helpers behind `Access = Internal`. Feature-envious procedures move to where the data lives. Primitive obsession (`Code[20]` carrying meaning) becomes a small record or enum. The interface stays narrow.

### Internal seams stay internal

A unit test reaching past `Access = Internal` is a signal that the responsibility is on the wrong codeunit, not that `Access` should widen. **Why**: widening pushes implementation into the contract; splitting the responsibility into a smaller internal codeunit makes the surface tell the truth. The interface is the test surface; E2E crosses `Access = Public` and survives internal refactor, unit tests live alongside the implementation against `Access = Internal` and update when internals rename.

### Introduce seams before injecting

When extracting a seam in legacy code, the order is: extract internals behind a new interface → ship the interface → inject the adapter. **Why**: injecting first strands existing callers mid-refactor with a half-built seam; the build goes red and stays red across multiple commits. Full pattern in `${CLAUDE_SKILL_DIR}/../../references/decoupling.md`. The three default BC seams (`IEnvironment`, `IApiRequest`, `IFinance`-family) plus the temp-record alternative live in `${CLAUDE_SKILL_DIR}/../../references/environment-interfaces.md`; name an existing pattern before extracting a fresh one.

### Rename to AL/BC vocabulary and project terminology

Rename when the name lies. BC verbs over generic CRUD: Insert / Modify / Delete (records), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method). Objects follow `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`. Records match the table name. Procedures PascalCase, verb-first. Events `OnBefore{Action}{Object}` / `OnAfter{Action}{Object}`. Tests short PascalCase scenario names (`PostSalesOrderWithItemCharge`), BaseApp style.

Project-specific terminology lives in `CONTEXT.md` (`## Language` and `## Flagged ambiguities`). For multi-context repos, `CONTEXT-MAP.md` lists contexts; pick the one covering `src/<module>/`. `architecture.html` and ADRs under `docs/adr/` carry conventions when `CONTEXT.md` is thin. For user/API-facing features, `event-model.html` carries the canonical Role / Action / Business Event / View names that downstream skills cite; preserve those names verbatim during rename passes.

**Why**: AL reads naturally to AL developers only when it uses BC vocabulary; CRUD-vocabulary procedures and `Method` suffixes signal a developer who has not internalised the platform. Renaming a test or editing `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` triggers Gherkin re-verification against the originating bullet in `tasks.html`; if intent shifts, update the bullet via `/al-refine` in the same change.

### Tests are first-class

Production and tests refactor together. Tests survive internal refactors because they assert on observable outcomes through the interface (record state, ledger entries, error messages, returned values), not internal state. New tests appear when reshape uncovers an uncovered branch; those tests must pass against the *current* code before reshape proceeds, so the regression signal stays honest. Unit tests on modules that the refactor merges away get deleted, not layered; replace, do not stack.

**Why**: tests-as-afterthought becomes tests-never-written, and tests that document a contract the module no longer has are a future maintainer's trap. The deletion test applies to test code too.

### Comments earn their place

A comment lands only when the *why* is non-obvious from BC vocabulary and the surrounding code. **Why**: comments restating what code already says rot the moment behaviour drifts and train the reader to ignore the next comment.

| | Comment |
|---|---|
| _Avoid_ | `// Insert the customer record` before `Customer.Insert(true);` |
| Use | `// BaseApp Codeunit 80 fires OnAfterPostSalesDoc twice for partial shipments, guard against double-post` |

### AppSource compliance at refactor time

Never rename a shipped object, table field, page action, or procedure that other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce the new name alongside. **Why**: rename across a published API breaks every binding extension silently. Internal-only symbols (`Access = Internal`, unpublished codeunits) rename freely.

Extracted interfaces and event publishers keep signatures stable once shipped, the public surface is the contract. No BaseApp modification, even during refactor. New permission set entries, captions, and schema migrations through install/upgrade codeunits ride with the same change that introduces the symbol they cover.

### Replan when reshape surfaces architectural gaps

If the refactor reveals a missing module, a pattern conflict, an unnamed brownfield touchpoint, an R→P→W boundary that cuts across tasks, or a sibling task whose description the reshape invalidates: **Stop**. Code stays green; the halt is on planning. Route to `/al-steer`. **Why**: absorbing architectural drift inside a refactor is invisible to every downstream skill; the architecture corrupts silently and the next task pays. `/al-steer` owns the seven triggers and the venue.

### No new behaviour during refactor

The diff leaves observable behaviour identical. New behaviour belongs to `/al-implement` (new task) or `/al-refine` (re-plan). **Why**: feature creep under the refactor banner ships untested behaviour past every gate that exists to catch it.

## Floor

`/al-refactor` does not edit `architecture.html` and writes no Notes by default. Routine reshape lives in code only.

`tasks.html` is touched only when an operational outcome demands it: status flips on replan (handled by `/al-steer` as the venue), or a forward-facing fact a future agent needs that has no better home. The only surgical-edit contract is `data-task` + `data-status`; see `html-spec-discipline.md`. Any other write inside the task block regenerates that portion whole; shape is your call per task.

**Names are the citation.** No inline `(see: file.al:120)` annotations anywhere. Future readers grep; the IDE gives line numbers for free.

## Composition

- `/al-build` after every meaningful change. Red after a step = revert that step, do not pile on.
- `/al-second-opinion` when the checklist is non-trivial; solo blindness on refactor lists is real. Returns a bulleted gap list verbatim or `Second opinion skipped: <reason>`.
- `/al-mutate` runs after `/al-refactor` in the inner `/al-implement` loop to validate test rigor against the reshaped code.
- `/bc-standard-reference` for BC patterns, event signatures, BaseApp behaviour.
- `/al-research` when prior BC knowledge is uncertain.
- `/al-design` when standalone-on-legacy work surfaces real architecture that should land upfront.
- `/grill-me` when a non-obvious trade-off needs the user.
- `/al-steer` is the replan venue.

Standalone-on-legacy mode reads `${CLAUDE_SKILL_DIR}/references/legacy-refactor-plan.md` for the phased plan (baseline tests first, dependency-classified deepening, replace-don't-layer testing).

## Out of scope

- **No new behaviour.** Belongs in `/al-implement` (new task) or `/al-refine` (re-plan).
- **No replan mutations.** `/al-steer` owns triggers and `.out-of-scope/`.
- **No upfront architecture.** When standalone legacy work reveals real architecture, route to `/al-design` and re-enter through the normal pipeline.
- **No Gherkin authoring.** `/al-refine`.
- **No markdown-mode tasks.html.** Legacy spec folders (`tasks.md` without `tasks.html`) are frozen.
