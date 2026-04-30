---
name: al-mutate
description: Validate AL/Business Central test rigor by injecting mutations into production code and verifying at least one test fails per mutation. Use mandatorily inside /al-implement for non-trivial tasks, or standalone on legacy code to audit coverage before /al-refactor.
---

# /al-mutate — Validate test rigor

Inject one mutation at a time into production code, run `/al-build`, classify, revert, verify clean. Survivors are the point — each one is a coverage gap or a documented equivalent. **Mandatory inside `/al-implement` for non-trivial tasks.** Standalone on legacy code before `/al-refactor`.

**Resolve `tasks.md`:** Branch matches `^\d{3}-` → use `specs/<branch>/tasks.md`. Otherwise standalone — no `tasks.md` write, report only.

## Preflight (gate)

Abort if any fails. No skipping to "save time."

- **Working tree clean** — `git status` empty.
- **Baseline green** — `/al-build` passes before the first mutation.
- **Target is production code** — never mutate test code.
- **Discovery list ready** — provided by `/al-implement`, or built fresh standalone by reading the target.

## Flow

Prefer a subagent for output-heavy iteration.

1. **Apply one mutation** to one site. Never batch.
2. **Run `/al-build`** with tests.
3. **Classify** — see table below.
4. **Revert** the mutation.
5. **Verify revert** — re-run `/al-build`; baseline must be green again. If not, abort and report — never leave the workspace half-mutated.
6. **Record** the result. Next mutation.

| Outcome | Meaning | Action |
|---|---|---|
| **killed** | At least one test failed | Record which test caught it. |
| **survived** | All tests pass | Gap or equivalent — flag for decision. |
| **build failure** | Code didn't compile | Skip; no signal. |

## Mutation classes (signal-per-minute, top-down)

State each as one bullet — no enumerated catalogue. Run roughly in this order; stop when the budget is spent.

- **Boundary flips** — `<` ↔ `<=`, `=` ↔ `<>`, `>` ↔ `>=`.
- **Boolean / branch swaps** — `true` ↔ `false`, `and` ↔ `or`, swap `if`/`else` bodies.
- **Condition negation** — remove a `not`; invert a guard.
- **Off-by-one** — `i := 1` ↔ `i := 0`, `Count` ↔ `Count - 1`.
- **Return-value swaps** — `exit(true)` ↔ `exit(false)`; `Error` ↔ `exit`. Catches "rejection looks rejected but isn't."
- **Statement / guard removal** — delete an early `exit`, an `Error`, a `Validate`, a `Modify`.

## Survivors (the whole point)

Every survivor needs an explicit decision before the report ships:

- **Real gap** → write a new test that catches it; add as a `tasks.md` follow-up if standalone.
- **Equivalent mutation** → record a specific reason. *"Looks equivalent"* is not a reason.
- **Unclear** → run `/grill-me` for the call.

## BC-specific safety

- **RDLC and generated files** — revert after every iteration; they regenerate noisily and pollute diffs.
- **Docker recovery** — `/al-build`'s responsibility; inherit via composition.
- **Symbol-only changes** (captions, labels, comments) — out of scope; mutate behaviour, not surface.

## Output

- **Report** at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`:
  - **Summary** — counts of killed / survived / build-failure.
  - **Surviving mutants** — actionable section: gaps and equivalents with rationale.
  - **Killed mutants table** — mutation site → catching test.
- **`tasks.md` line** appended to the calling task (only when invoked from `/al-implement`):
  `**Mutations:** 12 killed, 1 equivalent (reason: …), 0 survivors`

## Composition

- **`/al-build`** every iteration and for revert verification (Docker recovery flows through it).
- **`/al-research`** when a survivor requires verifying BaseApp behaviour to classify equivalent vs gap.
- **`/al-refactor`** consumes the report when run standalone — gaps drive new tests before shape changes.
- **`/grill-me`** when survivor classification needs the user.

## Out of scope

- No code changes outside the mutation/revert cycle.
- No `tasks.md` restructuring — gaps surface as Notes lines, not new tasks here.
- No mutating test code, generated files, or captions.
- No skipping preflight.
