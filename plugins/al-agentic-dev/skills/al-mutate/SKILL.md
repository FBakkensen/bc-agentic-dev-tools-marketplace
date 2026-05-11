---
name: al-mutate
description: Validate AL/Business Central test rigor by mutation testing. Inject one mutation at a time into production code, run /al-build, classify the result, revert, and report killed/surviving/equivalent mutants. Use mandatorily inside /al-implement for non-trivial tasks, or standalone on legacy code before /al-refactor.
---

# /al-mutate, Test-rigor gate

Mutate production code one site at a time. Build. Classify. Revert. Survivors are the point: each one is a coverage gap or a documented equivalent.

**Resolve `tasks.md`:** Branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise standalone, no `tasks.md` write, report only.

## Preflight (gate)

Abort if any fails. Required Yes/No before mutating:

| Check | Yes | No |
|---|---|---|
| Tree clean? | proceed | Stop. Commit or stash. |
| Baseline green? | proceed | Stop. Hand back to `/al-build`. |
| Site is production code? | proceed | Stop. Drop the mutation. |
| Plan has ID, Site, Operator, Expected killer? | proceed | Stop. Build the plan first. |

**Anti-pattern: skip preflight.** A dirty tree or red baseline turns every survivor into a question mark.

## Where Mutations live in `tasks.md`

Two artifacts, distinct lifetimes:

- **Mutation plan** (transient): a `**Mutations plan**` table inside the task's `<details>` block, written by `/al-implement` after the second-opinion gate, just before WIP commit. `/al-mutate` reads this table, runs the mutations, then deletes the block.
- **Mutation result** (durable): a `**Mutations**` chip inside the task's NOTE alert, written by `/al-mutate` after the last mutation classifies. Same value lands in the `Mutations` column of the `## Summary` table on the next Summary regeneration.

No `**Mutations:**` Notes line anywhere. The chip and the Summary cell are the single source of truth (see `notes-discipline.md`).

## Canonical `**Mutations plan**` block

Written by `/al-implement` to the calling task's `<details>` in `tasks.md`, after `**Tests**`. One row per mutation site. `/al-mutate` reads it and replaces it with the NOTE chip plus Summary cell.

```
**Mutations plan**

| ID | Site | Operator | Expected killer |
|---|---|---|---|
| M1 | `Foo.Codeunit.al:47`, guard against blocked customer | remove `not` | T-042#3 |
| M2 | `Foo.Codeunit.al:52`, credit-limit boundary | `>=` → `>` | T-042#4 |
```

`ID`: `M1`, `M2`, monotonic per task. `Site`: `<file>:<line>` plus one phrase in BC vocabulary (posting, dimension, ledger entry, document flow). `Operator`: mutation class name. `Expected killer`: `T-NNN#scenarioNumber` or `?` if the plan does not predict one.

**DO NOT:**

- write narrative prose
- put multiple classifications in one row
- embed fix-it instructions inside cells
- put semicolons inside a cell
- reorder the canonical four columns

## Mutation Classes

Top-down by signal-per-minute. Pick the class that exercises decision logic. Never mutate surface.

- **Boundary flips**, `<` ↔ `<=`, `=` ↔ `<>`, `>` ↔ `>=`.
- **Boolean swaps**, `true` ↔ `false`, `and` ↔ `or`, swap `if` / `else` bodies.
- **Condition negation**: remove a `not`; invert a guard.
- **Off-by-one**, `i := 1` ↔ `i := 0`, `Count` ↔ `Count - 1`.
- **Return-value swaps**, `exit(true)` ↔ `exit(false)`, `Error` ↔ `exit`.
- **Statement removal**: delete an early `exit`, `Error`, `Validate`, `Modify`.

**Anti-pattern: mutate while a refactor is in flight.** The shape is moving; classifications drift. Land the refactor green, commit, then mutate.

## Flow

1. Resolve `tasks.md` per the rule above. Standalone if no match.
2. Read the calling task ID + `**Mutations plan**` block when invoked from `/al-implement`; otherwise build a mutation plan from the requested target file or area.
3. Run preflight.
4. For each mutation in the plan, one at a time:
   - Apply the mutation to one site.
   - Run `/al-build` with tests. *P-layer mutations gate via `/al-build -UnitTestOnly` when `unitTestApp` is configured; AL Runner ERROR / exit 2 from a mutation means "broke runner contract", not a survivor: note and skip. See `al-runner.md`.*
   - Classify per the table below.
   - Revert with `git checkout -- <file>`.
   - Verify revert by re-running `/al-build`. Baseline must return green. If not, abort and surface the broken revert.
5. Write the report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`.
6. When invoked from `/al-implement`, update the calling task's `<details>` in `tasks.md`:
   - Delete the `**Mutations plan**` block.
   - Write the **Mutations** chip into the task's NOTE alert: `**Mutations**: N killed, M equivalent (reason: ...), K survivors.` Join with existing chips via ` · ` separator. Add the NOTE alert if the task does not have one.
   - Regenerate the `## Summary` table; the `Mutations` cell for this task picks up the new chip value.

**Anti-pattern: batch multiple mutations per build.** You learn nothing about which site moved the signal. Queue them, run them one at a time.

## Delegation

Prefer a delegated worker when the host supports subagents. Mutation work is isolated, output-heavy, and context-expensive.

Give the worker the mutation plan, target files, and preflight rules. The worker owns only the mutate-build-revert cycle and the mutation report. DO NOT shadow the worker while it runs. If delegation is unavailable, run the same flow inline.

## Situation To Action

| Situation | Action |
|---|---|
| Mutation survives baseline build | **Real gap**: write a killer test, or route to `/al-refine` when invoked from `/al-implement`. |
| Mutation kills baseline build with compile error | Mutation class invalid for this code. Skip the row, no signal. |
| Mutation passes all tests but is semantically dead | **Equivalent**: record a specific reason. "Looks equivalent" is not a reason. |
| Build hangs | Revert. Reduce mutation scope. Retry once. Stop after the second hang. |
| Multiple mutations queued | One at a time. Never batch. |
| Survivor classification unclear | Defer to caller. Hand back via `/grill-me`. |

## Survivor Classification

Every survivor needs a decision before the report ships:

- **Real gap**: write a test that kills it when standalone, or route to `/al-refine` to add it when inside `/al-implement`; caller decides.
- **Equivalent**: record the specific reason the mutated code is semantically identical, for example "the swapped branch sets the same field to the same value because both paths re-read from the source record".
- **Unclear**: flag for the caller. Do not guess.

**Anti-pattern: chase the killer of an equivalent mutant.** A test that distinguishes equivalent code is testing implementation. Record the equivalence and move on.

## BC Safety

- **`*.rdlc` generated files**, never mutate; they regenerate on build and the diff is noise.
- **`*.xlf` non-source translation files**, generated; mutating them tests the translation pipeline, not the code.
- **Captions, labels, tooltips**: surface. Out of scope.
- **Docker recovery**, `/al-build`'s problem, not this skill's.

**Anti-pattern: mutate captions, labels, or comments.** Surface, not behaviour.

## Output

- **Report** at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`:
  - **Summary**: counts of killed / survived / build-failure.
  - **Surviving mutants**: actionable section. One row per survivor: site, class, classification, killer-test if written, or equivalence reason.
  - **Killed mutants**: table mapping mutation site to catching test.
- **`tasks.md` NOTE chip** written to the calling task's NOTE alert only when invoked from `/al-implement`:
  `**Mutations**: N killed, M equivalent (reason: ...), K survivors.`
- **`tasks.md` Summary cell** updated when the Summary table is regenerated; cell value matches the chip value.
- **`**Mutations plan**` block** deleted from the `<details>` block after the chip lands.

## Voice when writing to `tasks.md`

The NOTE chip is bounded: one chip, the `**Mutations**: N killed, ...` shape above. Do not write operator-priority prose, selection rationale, walked-but-skipped paragraphs, or "Lesson:" entries to `tasks.md`. Those belong in the mutation report or stay in the session.

Voice and chip-shape rules apply to the bounded chip. Full contracts:

- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`, voice rules, em-dash ban.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md`, per-task structure, NOTE alert chip rules, Summary regeneration rule.

## Composition

- `/al-build` runs every iteration. `-UnitTestOnly` for P-layer mutation gating when `unitTestApp` is configured.
- `/al-research` when a survivor needs BaseApp behaviour verified.
- `/al-refactor` consumes the standalone report, gaps drive new tests before any shape change.
- `/grill-me` when a survivor's classification needs the user.

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `mutation-operators.md`, operator catalogue and selection heuristics; pre-flight self-report shape.
- `al-runner.md`, Pure-layer mutation gating; ERROR / exit 2 ≠ survivor.

## Out of scope

- No new behaviour. Mutate, classify, revert.
- No code changes outside the mutate-revert cycle.
- No `tasks.md` restructuring beyond writing the NOTE chip, regenerating the Summary row, and deleting the `**Mutations plan**` block. Survivors surface as the bounded chip value.
- No fix-it edits in the report; that is `/al-refine` and `/al-implement`.
- No mutating test code, generated `.rdlc`, generated `.xlf`, or captions.
- No skipping preflight. Stop. Run `/al-build` until green, then retry.
