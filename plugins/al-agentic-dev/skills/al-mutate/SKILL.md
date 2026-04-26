---
name: al-mutate
description: Validate that the AL/Business Central test suite catches real behaviour changes by injecting mutations into production code and verifying at least one test fails per mutation. Mandatory inside /al-implement for non-trivial tasks. Also runnable standalone on legacy code to audit test rigor before a refactor or to find coverage gaps.
---

# /al-mutate — Validate test rigor

Inject mutations into production code; verify at least one test fails per mutation. **Mandatory for non-trivial tasks.** Also runnable standalone on legacy code.

## Preflight (non-negotiable — abort if any fails)

- Working tree clean.
- Baseline tests green via `/al-build`.
- Target is production code, not test code.
- Mutation discovery list exists (provided by `/al-implement`, or built fresh on standalone use by reading the target code).

## Mutation loop (one at a time)

Apply one mutation → `/al-build` with tests → classify → revert → verify revert restored baseline → record. Then next mutation.

**Classify each result:**
- **killed** — at least one test failed; record which.
- **survived** — all tests pass; gap or equivalent — flag for decision.
- **build failure** — code didn't compile; skip, not useful signal.

## Operator priority (signal-per-minute, top-down)

- **Comparison flips** — `<` ↔ `<=`, `=` ↔ `<>`
- **Boolean flips** — `true` ↔ `false`, `and` ↔ `or`
- **Condition negation** — remove a `not`, swap `if/else` branches
- **Arithmetic swaps** — `+` ↔ `-`, `*` ↔ `/`
- **Guard removal** — delete an early `exit` / `Error`
- **Validate/error swap** — replace `Error(…)` with `exit` (and vice versa); catches "rejection looks rejected but isn't"

## BC-specific safety

- Revert RDLC / generated files after every iteration — they regenerate noisily and pollute diffs.
- Docker recovery is `/al-build`'s responsibility — `/al-mutate` inherits it via composition.
- **If revert fails, abort and report.** Never leave the workspace half-mutated.

## Survivors (the whole point)

Each survivor needs an explicit decision:

- **Real gap** → write a new test that catches it.
- **Equivalent mutation** → record a specific reason. *"Looks equivalent"* is not a reason.
- `/grill-me` when classification is unclear.

## Output

- `.output/mutation-report/<YYYYMMDD-HHMMSS>.md` with:
  - **Summary** — counts of killed / survived / build-failure
  - **Surviving mutants** — actionable section: gaps and equivalents with rationale
  - **Killed mutants table** — mutation → catching test
- One-line mutation result appended to the calling task in `tasks.md`, e.g.
  `**Mutations:** 12 killed, 1 equivalent (reason: …), 0 survivors`

## Composition

- `/al-build` for every iteration (and for Docker recovery).
- `/grill-me` when survivor classification needs the user.

## Out of scope

- No code changes outside the mutation/revert cycle.
- No `tasks.md` restructuring.
- No skipping preflight to "save time."
