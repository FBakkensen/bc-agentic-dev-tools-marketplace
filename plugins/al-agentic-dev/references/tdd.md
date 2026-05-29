# AL TDD

TDD cycle, scenario ordering, mutation operators, and the test invariants you never touch. Cited by `/al-refine`, `/al-implement`, `/al-mutate`.

TDD applies to all new development, feature changes, and bug fixes. The only exception is when the user explicitly says to skip ("skip TDD", "no tests", "without TDD"). "Quickly add X" does not count.

## Three layers of trust

| Layer | What it proves | Mechanism |
|---|---|---|
| Process discipline | Tests drive production code | Three laws below |
| Coverage direction | Right scenarios in right order | ZOMBIES ordering |
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
| **Mutate** | Targeted mutations caught by ≥ 1 failing assertion; reverted; green confirmed. |

A compile error is not a Red; fix compile errors first, then get to an assertion failure. Refactor exit gate: a full grep for `DEBUG-` returns nothing before committing.

## ZOMBIES scenario ordering

Build the scenario list bottom-up. This order surfaces edge cases that happy-path-first planning misses.

| Letter | Category | AL example |
|---|---|---|
| **Z** | Zero / empty | Empty configuration, zero attribute lines, no matching rule, empty rule set |
| **O** | One | Single attribute line, one rule entry, first sub-configuration, single mapping |
| **M** | Many | Full rule set, batch of headers, multiple simultaneous attribute updates |
| **B** | Boundary | Period cutoff date, max/min field values, exact threshold match, last day of posting period |
| **I** | Interface | Implementer substitution, different stub injected per scenario (unit layer) |
| **E** | Exceptional | Error paths: blocked record, missing setup, permission denied, duplicate key, invalid state |
| **S** | Simple | The happy path, named last because it is never the most revealing |

Write Zero first. If the system cannot handle empty input, everything else is irrelevant. A scenario list that only covers S is a demo script, not a test plan. Writing scenarios top-down from the feature description ("user creates, edits, copies, deletes") only covers S and misses the spectrum.

### Scenario naming

Each ZOMBIES scenario becomes one short PascalCase test name (BaseApp style):

- Z: `RuleSetWithNoEntriesReturnsDefault`
- O: `RuleSetWithSingleEntryMatchesExactly`
- B: `RuleSetBoundaryValueMatchesUpperLimit`
- E: `RuleSetWithBlockedRecordThrowsError`
- S: `RuleSetCopyPreservesIntervals`

## Mutation operators

Apply when prod or tests moved in the cycle: prod move → catches under-tested new logic; test move → catches new assertions that don't actually pin prod behaviour. The operators below apply at qualifying sites only — branching, comparisons, boolean ops, guards, arithmetic; pure delegation, property-only, and metadata edits carry no test-rigor signal at the site level.

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

### Selection heuristics

One operator per qualifying site; pick the operator most likely to expose underassertion. A second operator at the same site is justified only when a survivor might be equivalent and the second distinguishes equivalence from gap. Skip obvious equivalences (`x >= 1` ↔ `x > 0` for integers). Confirm at least one test exercises the target line before mutating; an unreached line routes to `/al-refine` (add the scenario) or `/al-refactor` (delete the dead branch), not to a killer test.

Pre-flight self-report: *"Candidates: K sites qualifying under the filters (J code-side, L test-side). Planning K mutations singleton, with potential equivalence-exception revisits."*

### Revert cycle

Revert is `git checkout -- <file>` against the Refactor-end commit. Deterministic and crash-safe. Precondition: working tree clean before starting (a dirty tree means the Refactor commit was skipped; `git checkout --` would clobber uncommitted work).

```powershell
git status --porcelain   # must return empty
```

Per mutation: edit one operator in one file → `/al-build` → classify (caught: revert and verify green; survivor: record, revert, strengthen the assertion) → verify green before the next.

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
