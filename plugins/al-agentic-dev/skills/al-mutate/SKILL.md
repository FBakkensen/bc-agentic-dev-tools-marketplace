---
name: al-mutate
description: Validate AL/Business Central test rigor by mutation testing. Inject one mutation at a time into production code, run /al-build, classify the result, revert, and report killed/surviving/equivalent mutants. Use mandatorily inside /al-implement for non-trivial tasks, or standalone on legacy code before /al-refactor.
---

# /al-mutate, Test-rigor gate

Mutate production code one site at a time. Build. Classify. Revert. Survivors are the point: each one is a real coverage gap or a documented equivalence. The disciplines below are the substance you bring; how you shape the result write into `tasks.html` is your call per task.

## Preconditions

- Tree clean. A dirty tree makes the revert step ambiguous and turns every survivor into a question mark.
- Baseline `/al-build` green. A red baseline means survivors carry no signal.
- Target is production code, not test code, not generated `.rdlc`, not generated `.xlf`, not captions / labels / tooltips. Surface and generated artifacts produce noise, not test-rigor signal.
- A mutation plan exists. When invoked from `/al-implement` the plan rides in on the calling task block; standalone, build the plan from the requested file or area before the first mutation.

If any precondition fails, **Stop** and surface the gap. Do not start mutating to "see what happens."

## What this pass produces

What the next reader needs from you, expressed as questions you must have answers to:

- **Which sites were mutated, and what mutation at each?** One mutation per site, named by what it inverts (a boundary, a guard, an early exit). Site addressed by file + procedure or `file:line`, in BC vocabulary (posting, ledger entry, document flow), not generic CRUD.
- **Did each mutation die, survive, or prove equivalent?** Killed means a specific test caught it. Survivor means a real coverage gap until proven otherwise. Equivalent means the mutated code is observably identical to the original, with a specific reason recorded, not "looks equivalent."
- **For every survivor, what is the call?** Real gap routes to a killer test (`/al-refine` when inside `/al-implement`; write the test directly when standalone). Equivalence carries the reason. Unclear hands back to the caller, never guessed.
- **Did the working tree return to baseline-green after the last revert?** Closing gate: full `/al-build` green, `git diff --quiet HEAD` clean. If not, the rigor verdict cannot ship.
- **What goes back into the task block?** When invoked from `/al-implement`, write the result into the calling `<details data-task="T-NNN">`. The shape (chip, alert, prose line, table cell) is your call per task; what survives is the verdict and survivor count, not the deliberation.

If a question cannot be answered, the pass is not done. Resolve via another mutation cycle, a survivor decision, or `/grill-me` when the classification call is the user's.

## Disciplines

These are how to think about mutation testing for BC. Apply where each one's *why* lands. The skills upstream trust that you ran these where they applied.

### One mutation, one build, one revert

Apply one mutation. Run `/al-build`. Classify. Revert with `git checkout -- .`. Verify the working tree matches `HEAD` before the next mutation. **Why**: batched mutations conflate signal; you cannot tell which site moved the build. Un-reverted mutations leave production poisoned and corrupt every subsequent classification.

### Survivors are the artifact

The pass exists to surface survivors, not to celebrate kills. **Why**: a green mutation pass with no survivors and no equivalences means either perfect tests or no decision logic worth mutating; the former is rare, the latter belongs in the plan, not the result. Every survivor is a coverage gap or an equivalence with a stated reason. Anything else is a deferred decision masquerading as completion.

### Equivalence needs a specific reason

"The swapped branch sets the same field to the same value because both paths re-read from the source record before assignment." That is an equivalence reason. "Looks equivalent" is not. **Why**: a test that distinguishes equivalent code is testing implementation. Recording the reason is what protects future readers from chasing the un-killable mutant. Without a reason, the equivalence is indistinguishable from a survivor someone wanted to suppress.

### Mutate where bugs hide

Two filters identify sites worth mutating. *Code-side*: high detection cost (irreversible writes, ledger entries, balance mutations, status flips other code keys off) or branch density (multi-arm `case`, guard chains, boundary comparisons in money math, validation pipelines). *Test-side*: the covering test's arrange phase reads as a *story* (sequenced BC process whose choreography makes the assertion reachable) rather than a *fixture* (records created, then act). The two filters select independently; their union is the candidate set. **Why**: trivial code (pure delegation, accessors, single-line init, code whose correctness is obvious from one read) does not host hidden bugs, the first caller catches regressions regardless of assertion strength. Consequential or branch-dense code does. Story-shaped tests do too, because expensive setup competes for the attention budget that should have gone to the assertion, leaving false confidence under a passing test. The trivial-vs-non-trivial call is per site, applied through the two qualifiers above; no enumerated list of object types decides it for you.

### One operator per qualifying site

Pick the operator most likely to expose underassertion at *that* site: a boundary flip in money math, a guard inversion in a validation chain, statement removal in a posting subscriber, `Validate()` bypass when a field trigger carries the contract. Apply, build, classify, revert, move on. The catalogue lives in the reference; the per-site choice is yours. **Why**: most operators at most sites produce the same kill-or-survive verdict, one well-chosen operator is sufficient evidence. Piling on operators multiplies wall-clock cost without multiplying signal. **Exception**: when a mutation survives and the survivor might be equivalent, a second operator at the same site distinguishes survival-by-equivalence from survival-by-coverage-gap. Real-gap survivors do not earn a second operator; route them to `/al-refine` inside `/al-implement`, or record as gaps standalone.

### Reachability before mutation

Confirm at least one test exercises the target line before mutating it. **Why**: a survivor on an unreached line is not a coverage gap, it is dead code or a missing scenario. The right response is `/al-refine` (add the scenario) or `/al-refactor` (delete the dead branch), not a killer test.

### Don't mutate during a refactor in flight

Land the refactor green, commit, then mutate. **Why**: a shape that is still moving produces classifications that drift; survivor lists go stale before the report ships.

### Single-line revert, verified

`git checkout -- .` then `git diff --quiet HEAD`. **Why**: a silent failed revert (file kept open, line-ending dance, EOL hook rewriting) leaves the next mutation stacked on top of the previous one. The verify step is the only thing that catches it before classifications corrupt.

### Pure-layer gating routes through `/al-build -UnitTestOnly`

When `unitTestApp` is configured, P-layer mutations gate via `-UnitTestOnly` (AL Runner) before the full pipeline. **Why**: the inner loop shrinks from minutes to seconds, and the rigor signal lands fast enough to keep the cycle one-at-a-time. AL Runner `ERROR` / exit 2 means "broke runner contract," not a survivor; note and skip per `${CLAUDE_SKILL_DIR}/../../references/al-runner.md`.

## Delegation

Prefer a delegated worker when the host supports subagents. Mutation work is isolated, output-heavy, and context-expensive; the worker owns only the mutate-build-revert cycle and the report. **Why**: keeping the cycle out of the main session preserves the context for survivor classification, which is where judgement actually matters. Do not shadow a running worker. If delegation is unavailable, run the same flow inline.

## Floor

`tasks.html` carries two attributes the maintaining skills depend on: `data-task="T-NNN"` and `data-status`. `/al-mutate` does not flip status; it writes the verdict into the calling task block so the next reader knows the rigor pass ran and what it found. Shape (NOTE alert chip, prose line, structured block, table cell) is your call per task. Consistency across tasks is fine; identical shape across tasks is not required.

**Names are the citation.** No inline `(see: file.al:120)` annotations in the verdict. Site addresses live in the report; the task block carries the outcome.

## Report

Write the durable report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. Survivors are the actionable section, one row per site with classification, killer test (when written) or equivalence reason. Killed mutants map site to catching test. The report is where deliberation lives; the task block carries the verdict.

## Composition

- `/al-build` runs every iteration; `-UnitTestOnly` for P-layer gating when `unitTestApp` is configured.
- `/al-research` when a survivor needs BaseApp behaviour verified before classification.
- `/al-refine` consumes real-gap survivors when invoked from `/al-implement`; the gap becomes a new scenario.
- `/al-refactor` consumes the standalone report; gaps drive new tests before any shape change.
- `/grill-me` when a survivor's classification needs the user.

## Lazy reference reads

| Source (read-only) | Trigger |
|---|---|
| `${CLAUDE_SKILL_DIR}/../../references/mutation-operators.md` | when building the mutation plan |
| `${CLAUDE_SKILL_DIR}/../../references/al-runner.md` | when P-layer gating via `-UnitTestOnly` |
| `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` | before writing the verdict into `tasks.html` or the report |
| `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` | before writing HTML into `tasks.html` |

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Sites** addressed in BC vocabulary (posting guard, dimension default, ledger entry write), not generic CRUD.
- **Tests** referenced by their short PascalCase scenario name, matching BaseApp style.

## Out of scope

- No new behaviour. Mutate, classify, revert.
- No code changes outside the mutate-revert cycle.
- No fix-it edits in the report or the task block; those are `/al-refine` and `/al-implement`.
- No mutating test code, generated `.rdlc`, generated `.xlf`, or captions.
- No status flips on `tasks.html`; that is `/al-implement` and `/al-steer`.
