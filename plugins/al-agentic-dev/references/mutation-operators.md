# AL Mutation Testing

Operator catalogue and selection heuristics for `/al-mutate`. Apply when a TDD cycle changes decision logic.

## When mutation testing is mandatory

Apply whenever a cycle changes decision logic AND at least one site in the cycle's diff qualifies under the SKILL's "mutate where bugs hide" filters (code-side: detection cost or branch density; test-side: story-shaped arrange). Decision logic touched but no qualifying sites means the change is trivial in the senses those filters detect; no mutation pass is owed.

Skip the pass entirely for: metadata-only edits, pure delegation (procedure that only calls another with no branching), property-only changes.

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

1. **Candidate list from the filters**: sites qualifying under the SKILL's site-selection discipline ("mutate where bugs hide"). When invoked from `/al-implement`, the cycle's diff bounds candidates; standalone, the requested file or area does.
2. **One operator per site**: pick the operator most likely to expose underassertion at that site. The catalogue above is the menu; the choice per site is the agent's. A second operator at the same site is justified only when a survivor might be equivalent and the second operator distinguishes equivalence from gap.
3. **Skip obvious equivalences**: `x >= 1` ↔ `x > 0` for integers, semantically identical, skip one.
4. **Reachability first**: confirm at least one test exercises the target line before mutating. An unreached line routes to `/al-refine` (add the scenario) or `/al-refactor` (delete the dead branch), not to a killer test.
5. **Stop when**: every qualifying site mutated singleton; equivalence-exception second operators applied where needed; working tree matches `HEAD`.

Pre-flight self-report before starting the loop: "Candidates: K sites qualifying under the filters (J code-side, L test-side). Planning K mutations singleton, with potential equivalence-exception revisits."

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
