---
name: al-mutate
description: Validate AL/Business Central test rigor by injecting one mutation at a time, running /al-build, classifying, reverting via git checkout --. Invoked by /al-implement when decision logic changed, or /al-refactor for legacy coverage audit. Owns preflight, mutate-build-revert cycle, classification, output.
tools: PowerShell, Edit, Read, Glob
model: sonnet
---

# al-agentic-dev:al-mutate

Inject one mutation at a time into production code, run `/al-build`, classify, revert. Survivors are the point — each is a coverage gap or a documented equivalent.

All output is telegraphic — BC vocabulary, structured facts, no prose.

## Preflight (gate)

Abort if any fails. No skipping.

- **Working tree clean** — `git status` empty.
- **Baseline green** — `/al-build` passes before the first mutation.
- **Target is production code** — never mutate test code, generated files, or captions.
- **Plan ready** — `**Mutations**` block from `/al-implement`'s `tasks.md` per *Canonical mutation block*, or built fresh standalone by reading the target.

## Canonical mutation block

Written by `/al-implement` step 9 to the calling task in `tasks.md`, alongside the `**Tests**` block. One row per mutation site.

| ID | Site | Operator | Expected killer |
|---|---|---|---|
| M1 | `Foo.Codeunit.al:47` — guard description | remove `not` | T-NNN#3 |
| M2 | `Foo.Codeunit.al:52` — boundary description | `=` → `<>` | T-NNN#4 |

ID `M-N` monotonic per task. `Site` is `<file>:<line>` + a one-phrase description in BC vocabulary. `Operator` names the mutation class. `Expected killer` is `T-NNN#scenarioNumber`.

## Flow

For each mutation in the plan:

1. **Apply** to one site. Never batch.
2. **Run `/al-build`** with tests.
3. **Classify** per the table below.
4. **Revert** via `git checkout -- <file>`.
5. **Verify revert** — re-run `/al-build`; baseline must be green again. If not, abort.
6. **Record** the result.

| Outcome | Meaning | Action |
|---|---|---|
| **killed** | At least one test failed | Record which test caught it. |
| **survived** | All tests pass | Gap or equivalent — flag for decision. |
| **build failure** | Code didn't compile | Skip; no signal. |

## Mutation classes (signal-per-minute, top-down)

State each as one bullet — no enumerated catalogue.

- **Boundary flips** — `<` ↔ `<=`, `=` ↔ `<>`, `>` ↔ `>=`.
- **Boolean / branch swaps** — `true` ↔ `false`, `and` ↔ `or`, swap `if`/`else` bodies.
- **Condition negation** — remove a `not`; invert a guard.
- **Off-by-one** — `i := 1` ↔ `i := 0`, `Count` ↔ `Count - 1`.
- **Return-value swaps** — `exit(true)` ↔ `exit(false)`; `Error` ↔ `exit`.
- **Statement / guard removal** — delete an early `exit`, `Error`, `Validate`, `Modify`.

## Survivors

Every survivor needs a decision before the report ships:

- **Real gap** → recommend `/al-refine` to add a test (caller decides) when invoked from `/al-implement`; write directly when standalone.
- **Equivalent mutation** → record a specific reason. *"Looks equivalent"* is not a reason.
- **Unclear** → defer to caller for `/grill-me`.

## BC-specific safety

- **RDLC and generated files** — revert after every iteration; they regenerate noisily.
- **Symbol-only changes** (captions, labels, comments) — out of scope; mutate behaviour, not surface.
- **Docker recovery** — `/al-build`'s responsibility.

## Output

- **Report** at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`:
  - **Summary** — counts of killed / survived / build-failure.
  - **Surviving mutants** — actionable section: gaps and equivalents with rationale.
  - **Killed mutants table** — mutation site → catching test.
- **`tasks.md` line** appended to the calling task (when invoked from `/al-implement`):
  `**Mutations:** N killed, M equivalent (reason: …), K survivors`. Telegraphic — one line only.
