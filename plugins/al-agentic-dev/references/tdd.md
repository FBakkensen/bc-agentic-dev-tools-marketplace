# AL TDD

Red-green cycle, task execution order, mutation operators, and test invariants you never touch. Cited by `/al-implement`, `/al-mutate`, and supporting refinement guidance.

TDD applies to all new development, feature changes, and bug fixes. The only exception is when the user explicitly says to skip ("skip TDD", "no tests", "without TDD"). "Quickly add X" does not count.

The durable task grammar lives in [test-specification.md](test-specification.md). The execution pyramid lives in [test-strategy.md](test-strategy.md). This file owns the red-green cycle.

## Three layers of trust

| Layer | What it proves | Mechanism |
|---|---|---|
| Process discipline | Tests drive production code | Three laws below |
| Coverage direction | Right cases at the right layer | Unit-first task execution |
| Behavioural proof | Assertions actually catch bugs | Mutation testing |

A passing-but-wrong-path test looks green. Branch coverage does not prove an assertion catches a bug; mutation testing is the proof.

## Three laws

1. Write no production code without a failing test.
2. Write no more test than is enough to fail.
3. Write no more production code than is enough to make the failing test pass.

Violations: writing a full feature then back-filling tests; writing all tests before any production code; writing more logic than the current failing test demands.

## Five phases

| Phase | Exit criterion |
|---|---|
| **Scaffold** | Compilable stubs exist; build green; new test codeunit and production procedure declared but empty |
| **Red** | Test fails on an **assertion**, not a runtime error, not a compile error. Existing suite still passes. |
| **Green** | Minimal production change makes the target test pass. Full suite still green. |
| **Refactor** | Implementation tidied; any `DEBUG-*` markers removed; full suite green. |
| **Mutate** | Targeted mutations compile, run, and are caught by ≥ 1 failing assertion; reverted; green confirmed. A compile-caught mutant is stillborn, not a kill. |

A compile error is not a Red; fix compile errors first, then get to an assertion failure. The same holds under mutation: a compile error is not a kill — a mutant the compiler rejects never ran. Refactor exit gate: a full grep for `DEBUG-` returns nothing before committing.

## Task execution order

Technical tasks run lower-layer proof first:

1. `Unit` AAA cases red -> green -> gate.
2. `Integration` AAA cases red -> green -> gate.
3. Refactor full task diff once.
4. Full gate.
5. Mutation at task end for whatever arrived without a red.

Within each scope, follow ascending coverage ID order in `Test Specification`: `B1`, `B2`, `B3`, ... or `R1`, `R2`, `R3`, ...

When a unit seam exists, run Unit first. When the seam should exist but does not, an Integration characterization test may land first to anchor current behaviour; then extract the lower-layer seam and add Unit proof. Behaviour that only exists through BC runtime, database, page, install, permission, or event wiring uses Integration.

Use edge discovery while refining and implementing: empty, missing, single, multiple, boundary, error, and regression cases where relevant. Final task order still follows the pyramid.

### Test naming

Each AAA case becomes one short PascalCase test procedure name in BaseApp style:

- `RuleSetWithNoEntriesReturnsDefault`
- `RuleSetWithSingleEntryMatchesExactly`
- `RuleSetBoundaryValueMatchesUpperLimit`
- `RuleSetWithBlockedRecordThrowsError`
- `RuleSetCopyPreservesIntervals`

### Fixture tokens

Fixture-data literals (the right-hand side of `TemplateID := '...'` and peers) carry UPPER_SNAKE role tokens derived from the scenario — never workflow identifiers. A task ID, scenario number, PR number, or ticket ID inside fixture data is process noise: the test procedure name already carries scenario identity, and the literal outlives the workflow that minted it. Paired variables sharing a fixture role share a role prefix (`CLONE_BASE_SRC` / `CLONE_BASE_TGT`), so the relationship reads off the data. Respect the target field's width — a `Code[20]` field rejects a 21-character token at the first `Insert`. Keep tokens distinct across test procedures: per-test isolation in both runners depends on fixtures not colliding.

## Mutation operators

A red is a killed mutant — deleting the code is the strongest mutation, and TDD runs it first. Apply operators where code or assertions moved without one: a test edited after green lost its red the same way refactor-added prod logic never had one. The operators below apply at qualifying sites only: branching, comparisons, boolean ops, guards, arithmetic. Plain delegation, property-only, and metadata edits carry no test-rigor signal at the site level.

A mutation that removes behaviour must still compile — the compiler catching a fault is not a test catching it. A compile-breaking mutant is `invalid_stillborn`, not a kill; reconsider the operator. This mirrors Scaffold-before-Red: a red is forced onto an assertion by first making the code compile, and a kill is forced onto a test the same way.

| Operator | Before | After |
|---|---|---|
| Flip boolean condition | `if IsBlocked then` | `if not IsBlocked then` |
| Swap equality | `if Amount = 0 then` | `if Amount <> 0 then` |
| Swap comparator | `if Qty > MaxQty then` | `if Qty >= MaxQty then` or `if Qty < MaxQty then` |
| Swap arithmetic | `BaseAmount + Discount` | `BaseAmount - Discount` |
| Comment out assignment | `Amount := Base * Factor;` | *(line removed)* |
| Replace literal | `if Factor = 1 then` | `if Factor = 0 then` |
| Early-return insertion | *(add `exit` before logic block)* | |
| Skip Validate() | `Rec.Validate("Amount", Value);` | `Rec.Amount := Value;` |

The `Validate()` skip is BC-specific: it bypasses trigger firing, a behavioural change distinct from plain field assignment.

Two operators risk a stillborn in AL. **Comment out assignment** can leave an unused or unwritten local — a compile error under `warningsAsErrors`; prefer replacing the RHS value where the variable is later read, so the wrong value flows and a test must catch it. **Early-return insertion** makes the code after `exit` unreachable, which AL flags as a compile error; prefer a guard flip that reaches the same skip behaviourally. Verify the mutant compiles before trusting any classification — a non-compiling mutant is stillborn, re-plan a compiling operator.

### Selection heuristics

One operator per qualifying site; pick the operator most likely to expose underassertion. A second operator at the same site is justified only when a survivor might be equivalent and the second distinguishes equivalence from gap. Skip obvious equivalences (`x >= 1` vs. `x > 0` for integers). Confirm at least one test exercises the target line before mutating; an unreached line routes to `/al-refine` (add coverage) or `/al-refactor` (delete the dead branch), not to a killer test.

Pre-flight self-report: *"Candidates: K sites that arrived without a red (L skipped, reasons recorded). Planning K mutations singleton, with potential equivalence-exception revisits."*

### Revert cycle

Revert is `git checkout -- <file>` against the Refactor-end commit. Deterministic and crash-safe. Precondition: working tree clean before starting (a dirty tree means the Refactor commit was skipped; `git checkout --` would clobber uncommitted work).

```powershell
git status --porcelain   # must return empty
```

Per mutation: edit one operator in one file -> `/al-build` -> classify (caught: revert and verify green; survivor: record, revert, strengthen the assertion) -> verify green before the next.

## No-touch invariants

Tactical "tidy" passes break tests here silently: no compile error, runtime failure only.

| Object | Why |
|---|---|
| `[Test]` attribute | Removing it silently drops the test from the runner, no error |
| `Subtype = Test` | Removing makes the codeunit uncallable as a test |
| `TestPermissions = Disabled` | Removing causes permission errors under the test runner principal |
| `[TransactionModel(TransactionModel::AutoCommit)]` | Changing to `AutoRollback` causes false-pass: `Commit()` calls fail and side effects vanish |
| `[HandlerFunctions('...')]` | String literal, invisible to symbol tools; rename the handler procedure without updating the string and the runner errors at runtime |
| `Initialize()` call in `[Test]` | Load-bearing even when it appears redundant; guards against test-order dependencies |
| `Library Assert` calls | The only correct assertion library; never replace with `Error()`, `Message()`, or custom guards |

### Rename safety

Before renaming any test procedure: LSP findReferences confirms call sites within the project; a string grep for the procedure name catches `[HandlerFunctions('ProcedureName')]` attributes, which are string literals invisible to symbol-aware tools.

```powershell
rg "ProcedureName" --type al    # from the test app folder
```

If a match appears inside a `[HandlerFunctions(...)]` attribute, update the string before renaming the procedure; symbol-aware refactors miss it.

### Object ID allocation

Allocate test codeunit IDs via the available allocator (e.g., `mcp__al-objid-mcp-server__ninja_assignObjectId`). If the codeunit is not created (scaffold aborted, task dropped), unassign the ID immediately. The unassign step is the one agents miss; a reserved-but-unused ID leaks from the pool.
