# AL Mutation Testing

Operator catalogue and selection heuristics for `/al-mutate`. Apply when a TDD cycle changes decision logic.

## When mutation testing is mandatory

Apply whenever a cycle changes decision logic: `if`/`case` branches, comparison operators, boolean guards, arithmetic, loop conditions.

Skip for: metadata-only edits, pure delegation (procedure that only calls another with no branching), property-only changes.

## Operator Catalogue

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

The `Validate()` skip is BC-specific, it bypasses trigger firing, which is a behavioral change distinct from simple field assignment.

## Selection Heuristics

1. **Candidate list from the diff**: only mutate lines changed in the current cycle.
2. **Priority order**: (1) conditionals and comparators on changed lines, (2) assignments to record fields / return values / error paths, (3) `Validate()` skips and lock calls, (4) constants last.
3. **Skip equivalences**: `x >= 1` ↔ `x > 0` for integers, semantically identical, skip one.
4. **Reachability first**: confirm at least one test exercises the target line before mutating.
5. **Breadth before depth**: one mutation per operator class before any class gets a second site.
6. **Stop when**: every behavioral line mutated by ≥ 1 operator AND new survivors duplicate prior survivors.

Pre-flight self-report before starting the loop: "Diff: N changed lines, M behavioral. Planning ~K mutations across J operator classes."

## Revert Mechanism

Revert is `git checkout -- <file>` against the Refactor-end commit. Deterministic and crash-safe, no in-memory state to lose.

**Precondition**: the working tree must be clean before starting. A dirty tree means the Refactor commit was skipped, `git checkout --` would clobber uncommitted work.

```powershell
# Precondition check, must return empty output
git status --porcelain
```

Each mutation cycle:
1. Edit one operator in one file.
2. Run `/al-build`.
3. Test fails → mutation caught. Revert: `git checkout -- <file>`. Verify green.
4. All tests pass → survivor found. Record it, revert, then strengthen the assertion.
5. Verify green after every revert before the next mutation.
