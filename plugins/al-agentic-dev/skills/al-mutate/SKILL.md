---
name: al-mutate
description: Validate AL/Business Central test rigor by mutation: inject one mutation at a time, run `/al-build`, classify, revert, report killed/surviving/equivalent mutants. Use mandatorily inside `/al-implement` for non-trivial tasks, or standalone on legacy code before `/al-refactor`.
---

# /al-mutate, Test-rigor gate

Mutate production code one site at a time. Build. Classify. Revert. Survivors are the point: each one is a real coverage gap or a documented equivalence.

## Preconditions

- Tree clean. A dirty tree makes revert ambiguous and turns every survivor into a question mark.
- Baseline `/al-build` green. A red baseline means survivors carry no signal.
- Target is production code; not tests, not generated `.rdlc` or `.xlf`, not captions / labels / tooltips. Surface and generated artifacts produce noise, not test-rigor signal.
- A mutation plan exists. Invoked from `/al-implement`, the plan rides in on the calling task block; standalone, build the plan from the requested file before the first mutation.

Any precondition fails, **Stop** and surface the gap. Do not start mutating to "see what happens."

## What this pass produces

- **Which sites mutated, what mutation at each?** One per site, named by what it inverts (a boundary, a guard, an early exit). Site addressed by file + procedure or `file:line`, in BC vocabulary (posting, ledger entry, document flow), not generic CRUD.
- **Killed, survived, or equivalent?** Killed: a specific test caught it. Survivor: real coverage gap until proven otherwise. Equivalent: mutated code observably identical, with a specific reason recorded.
- **For every survivor, what is the call?** Real gap routes to a killer test (`/al-refine` inside `/al-implement`, direct write standalone). Equivalence carries the reason. Unclear hands back to the caller.
- **Tree back to baseline-green?** Closing gate: full `/al-build` green, `git diff --quiet HEAD` clean.

Unanswerable, the pass is not done. Resolve via another cycle, a survivor decision, or `/grill-me` when the call is the user's.

## Workflow

**One mutation, one build, one revert.** Apply one mutation. `/al-build`. Classify. Revert with `git checkout -- .`. Verify the tree matches `HEAD` before the next mutation. Batched mutations conflate signal; un-reverted mutations poison production and corrupt every subsequent classification. A silent failed revert (file open, line-ending dance, EOL hook rewriting) is the only thing the verify step catches.

**Survivors are the artifact.** The pass exists to surface survivors, not to celebrate kills. A green pass with no survivors and no equivalences means either perfect tests or no decision logic worth mutating; the latter belongs in the plan, not the result. Every survivor is a coverage gap or an equivalence with a stated reason.

**Equivalence needs a specific reason.** "The swapped branch sets the same field to the same value because both paths re-read from the source record before assignment" is an equivalence reason; "looks equivalent" is not. A test that distinguishes equivalent code is testing implementation; recording the reason protects future readers from chasing the un-killable mutant.

**Mutate where bugs hide.** Two filters identify worthwhile sites. *Code-side*: high detection cost (irreversible writes, ledger entries, balance mutations, status flips other code keys off) or branch density (multi-arm `case`, guard chains, boundary comparisons in money math). *Test-side*: the covering test's arrange phase reads as a *story* (sequenced BC process) rather than a *fixture*. Trivial code (pure delegation, accessors, single-line init) does not host hidden bugs; the first caller catches regressions regardless of assertion strength. The trivial-vs-non-trivial call is per site through these qualifiers, not by object type.

**One operator per qualifying site.** Pick the operator most likely to expose underassertion at *that* site: boundary flip in money math, guard inversion in a validation chain, statement removal in a posting subscriber, `Validate()` bypass when a field trigger carries the contract. Operator catalogue and selection heuristics in [tdd.md](../../references/tdd.md). One well-chosen operator is sufficient evidence. **Exception**: a survivor that might be equivalent earns a second operator at the same site to distinguish equivalence from gap.

**Reachability before mutation.** Confirm at least one test exercises the target line. A survivor on an unreached line is not a coverage gap, it is dead code or a missing scenario; route to `/al-refine` (add the scenario) or `/al-refactor` (delete the dead branch).

**No mutation during a refactor in flight.** Land the refactor green, commit, then mutate. A shape still moving produces classifications that drift; survivor lists go stale before the report ships.

**Pure-layer gating via `-UnitTestOnly`.** When `unitTestApp` is configured, P-layer mutations gate via `/al-build -UnitTestOnly` (AL Runner) before the full pipeline; the inner loop shrinks from minutes to seconds. AL Runner `ERROR` / exit 2 means "broke runner contract," not a survivor; note and skip, and run `al-runner --guide` if uncertain which features the runner supports.

## Delegation

Prefer a delegated worker when the host supports subagents. Mutation work is isolated, output-heavy, and context-expensive; the worker owns the mutate-build-revert cycle and the report. Keeping the cycle out of the main session preserves context for survivor classification, where judgement matters. Do not shadow a running worker. Delegation unavailable, run inline.

## Report

Write the durable report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. Survivors are the actionable section, one row per site with classification, killer test (when written) or equivalence reason. Killed mutants map site to catching test. The report is where deliberation lives; the task block carries the verdict.

`/al-mutate` does not flip status; it writes the verdict into the calling task block. Shape (NOTE alert chip, prose line, structured block, table cell) per task. See [html-spec-discipline.md](../../references/html-spec-discipline.md) and [voice-contract.md](../../references/voice-contract.md). Standalone mode emits a Gate report once at pass close, naming the rigor proved (or not) for the user-facing behaviour under test, soft spots that remain by design, and the user's call; inside `/al-implement`, findings fold into the scenario's Gate report.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refactor` (inside `/al-implement` loop), OR standalone on legacy code before `/al-refactor` |
| **Hands off to**   | `/al-refine` (real-gap survivor → killer scenario) inside `/al-implement`; back to caller standalone |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BaseApp behaviour for survivor classification), `/grill-me` (classification call needs the user) |
