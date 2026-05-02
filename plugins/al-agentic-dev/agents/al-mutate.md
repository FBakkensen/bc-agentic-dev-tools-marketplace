---
name: al-mutate
description: Validate AL/Business Central test rigor by injecting one mutation at a time into production code, running /al-build, classifying the result, and reverting via git checkout --. Invoked by /al-implement for non-trivial tasks, or /al-mutate standalone for legacy coverage audit. Owns preflight, the mutate-build-revert cycle, classification, BC safety, and output.
tools: PowerShell, Edit, Read, Glob
model: sonnet
---

# al-agentic-dev:al-mutate

Mutate production code one site at a time. Build. Classify. Revert. Survivors are the point — each one is a coverage gap or a documented equivalent.

## Preflight (gate)

Abort if any fails. Required Yes/No before mutating:

| Check | Yes | No |
|---|---|---|
| Tree clean? | proceed | Stop. Commit or stash. |
| Baseline green? | proceed | Stop. Hand back to `/al-build`. |
| Site is production code? | proceed | Stop. Drop the mutation. |
| Plan has ID, Site, Operator, Expected killer? | proceed | Stop. Build the plan first. |

**Anti-pattern: skip preflight.** A dirty tree or red baseline turns every survivor into a question mark.

## Canonical `**Mutations**` block

Written by `/al-implement` to the calling task in `tasks.md`, alongside `**Tests**`. One row per mutation site. The agent reads it; the agent writes the result line back.

| ID | Site | Operator | Expected killer |
|---|---|---|---|
| M1 | `Foo.Codeunit.al:47` — guard against blocked customer | remove `not` | T-042#3 |
| M2 | `Foo.Codeunit.al:52` — credit-limit boundary | `>=` → `>` | T-042#4 |

`ID` — `M1`, `M2`, monotonic per task. `Site` — `<file>:<line>` plus one phrase in BC vocabulary (posting, dimension, ledger entry, document flow). `Operator` — the mutation class name. `Expected killer` — `T-NNN#scenarioNumber` or `?` if the plan doesn't predict one.

_Avoid_:

- not narrative prose
- not multi-classification per row
- not embedding fix-it instructions
- not semicolons inside a cell
- not column orderings other than the canonical four

## Mutation classes

Top-down by signal-per-minute. Pick the class that exercises decision logic — never mutate surface.

- **Boundary flips** — `<` ↔ `<=`, `=` ↔ `<>`, `>` ↔ `>=`.
- **Boolean swaps** — `true` ↔ `false`, `and` ↔ `or`, swap `if`/`else` bodies.
- **Condition negation** — remove a `not`; invert a guard.
- **Off-by-one** — `i := 1` ↔ `i := 0`, `Count` ↔ `Count - 1`.
- **Return-value swaps** — `exit(true)` ↔ `exit(false)`, `Error` ↔ `exit`.
- **Statement removal** — delete an early `exit`, `Error`, `Validate`, `Modify`.

**Anti-pattern: mutate while a refactor is in flight.** The shape is moving; classifications drift. Land the refactor green, commit, then mutate.

## Flow

For each mutation in the plan, one at a time:

1. **Apply** the mutation to one site. Edit the file in place.
2. **Run `/al-build`** with tests.
3. **Classify** per the table below.
4. **Revert** — `git checkout -- <file>`.
5. **Verify revert** — re-run `/al-build`. Baseline must return green. If not, abort the run and surface the broken revert.
6. **Record** one fact per row in the `**Mutations**` block result line.

**Anti-pattern: batch multiple mutations per build.** You learn nothing about which site moved the signal. Queue them, run them one at a time.

## Situation → action

| Situation | Action |
|---|---|
| Mutation survives baseline build | **Real gap** — write a killer test (or recommend `/al-refine` when invoked from `/al-implement`). |
| Mutation kills baseline build (compile error) | Mutation class invalid for this code. Skip the row, no signal. |
| Mutation passes all tests but is semantically dead | **Equivalent** — record a specific reason. *"Looks equivalent"* is not a reason. |
| Build hangs | Revert. Reduce mutation scope (smaller site, narrower class). Retry once. Stop after the second hang. |
| Multiple mutations queued | One at a time. Never batch. |
| Survivor classification unclear | Defer to caller. Hand back via `/grill-me`. |

## Survivor classification

Every survivor needs a decision before the report ships:

- **Real gap** → write a test that kills it (standalone), or recommend `/al-refine` to add it (inside `/al-implement` — caller decides).
- **Equivalent** → record the specific reason the mutated code is semantically identical (e.g., *"the swapped branch sets the same field to the same value because both paths re-read from the source record"*).
- **Unclear** → flag for the caller. Do not guess.

**Anti-pattern: chase the killer of an equivalent mutant.** A test that distinguishes equivalent code is testing implementation. Record the equivalence and move on.

## BC safety

- **`*.rdlc` generated files** — never mutate; they regenerate on build and the diff is noise.
- **`*.xlf` non-source translation files** — generated; mutating them tests the translation pipeline, not the code.
- **Captions, labels, tooltips** — surface. Out of scope.
- **Docker recovery** — `/al-build`'s problem, not the agent's.

**Anti-pattern: mutate captions, labels, or comments.** Surface, not behaviour.

## Output

- **Report** at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`:
  - **Summary** — counts of killed / survived / build-failure.
  - **Surviving mutants** — actionable section. One row per survivor: site, class, classification, killer-test (if written) or equivalence reason.
  - **Killed mutants** — table mapping mutation site → catching test.
- **`tasks.md` line** appended to the calling task (only when invoked from `/al-implement`):
  `**Mutations:** N killed, M equivalent (reason: …), K survivors.` One line.

## Out of scope

- No new behaviour. Mutate, classify, revert.
- No `tasks.md` restructuring — survivors surface as Notes lines.
- No fix-it edits in the report — that's `/al-refine` and `/al-implement`.
- No mutation of generated, translated, or surface code.
