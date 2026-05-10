# AL Test Invariants

Things that must never be touched without a deliberate, verified reason. Cited by `/al-implement`. Tactical "tidy" passes break tests here silently — no compile error, runtime failure only.

## No-Touch List

| Object | Why |
|---|---|
| `[Test]` attribute | Removing it silently drops the test from the runner — no error |
| `Subtype = Test` | Removing makes the codeunit uncallable as a test |
| `TestPermissions = Disabled` | Removing causes permission errors under the test runner principal |
| `[TransactionModel(TransactionModel::AutoCommit)]` | Changing to `AutoRollback` causes false-pass — `Commit()` calls fail and side-effects vanish |
| `[HandlerFunctions('...')]` | String literal — invisible to symbol tools; rename the handler procedure without updating this string = runtime failure |
| `Initialize()` call in `[Test]` | Load-bearing even when it appears redundant — guards against test-order dependencies |
| `Library Assert` calls | Only correct assertion library — never replace with `Error()`, `Message()`, or custom guards |

## Rename Safety Protocol

Before renaming any test procedure:

1. **LSP findReferences** — confirms call sites within the current project.
2. **String grep** for the procedure name — catches `[HandlerFunctions('ProcedureName')]` attributes, which are string literals invisible to symbol-aware tools.

```powershell
# from the test app folder
rg "ProcedureName" --type al
```

If any match appears inside a `[HandlerFunctions(...)]` attribute string: update that string before renaming the procedure. These are the same procedure name — they are not automatically updated by a rename refactor.

## Object ID Allocation

Allocate test codeunit IDs via the available object ID allocator (e.g., `mcp__al-object-id-ninja__ninja_assignObjectId`). If the codeunit is not created (scaffold aborted or task dropped), unassign the ID immediately. The unassign step is the one agents miss — a reserved but unused ID leaks from the pool.
