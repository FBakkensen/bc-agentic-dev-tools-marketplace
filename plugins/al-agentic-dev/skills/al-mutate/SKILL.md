---
name: al-mutate
description: "Validate AL/Business Central test rigor by mutation: inject one mutation at a time, run `/al-build`, classify, revert, report killed/surviving/equivalent mutants. Use mandatorily inside `/al-implement` for non-trivial tasks, or standalone on legacy code before `/al-refactor`."
---

**Style:** Drop articles, filler, hedging. Fragments OK. Arrows for causality. Technical terms exact, code unchanged, errors quoted exact. **Exception**: shift to prose where clarity or safety would be hurt.

# /al-mutate, Test-rigor gate

Mutate production code one site at a time. Build. Classify. Revert. Survivors are the point: each one is a real coverage gap or a documented equivalence.

## Preconditions

- Tree clean. Dirty tree makes revert ambiguous → every survivor becomes a question mark.
- Baseline `/al-build` green. Red baseline → survivors carry no signal.
- Target is production code; not tests, not generated `.rdlc` or `.xlf`, not captions / labels / tooltips. Surface and generated artifacts produce noise, not test-rigor signal.
- Mutation plan exists. Invoked from `/al-implement` → plan rides in on calling task block; standalone → build plan from requested file before first mutation.

Any precondition fails → **Stop**, surface the gap. Do not start mutating to "see what happens."

## What this pass produces

- **Which sites mutated, what mutation at each?** One per site, named by what it inverts (boundary, guard, early exit). Site addressed by file + procedure or `file:line`, in BC vocabulary (posting, ledger entry, document flow), not generic CRUD.
- **Killed, survived, or equivalent?** Killed: specific test caught it. Survivor: real coverage gap until proven otherwise. Equivalent: mutated code observably identical, with specific reason recorded.
- **For every survivor, what is the call?** Real gap → killer test (`/al-refine` inside `/al-implement`, direct write standalone). Equivalence carries reason. Unclear hands back to caller.
- **Tree back to baseline-green?** Closing gate: full `/al-build` green, `git diff --quiet HEAD` clean.

Unanswerable → pass not done. Resolve via another cycle, survivor decision, or `/grill-me` when call is user's.

## Workflow

**One mutation, one build, one revert.** Apply one mutation. `/al-build`. Classify. Revert with `git checkout -- .`. Verify tree matches `HEAD` before next mutation. Batched mutations conflate signal; un-reverted mutations poison production and corrupt every subsequent classification. Silent failed revert (file open, line-ending dance, EOL hook rewriting) is the only thing the verify step catches.

**Survivors are the artifact.** Pass exists to surface survivors, not to celebrate kills. Green pass with no survivors and no equivalences → either perfect tests or no decision logic worth mutating; latter belongs in plan, not result. Every survivor is a coverage gap or an equivalence with a stated reason.

**Equivalence needs a specific reason.** "The swapped branch sets the same field to the same value because both paths re-read from the source record before assignment" is an equivalence reason; "looks equivalent" is not. Test that distinguishes equivalent code is testing implementation; recording the reason protects future readers from chasing the un-killable mutant.

**Mutate where bugs hide.** Two filters identify worthwhile sites. *Code-side*: high detection cost (irreversible writes, ledger entries, balance mutations, status flips other code keys off) or branch density (multi-arm `case`, guard chains, boundary comparisons in money math). *Test-side*: covering test's arrange phase reads as a *story* (sequenced BC process) rather than a *fixture*. Trivial code (pure delegation, accessors, single-line init) does not host hidden bugs; first caller catches regressions regardless of assertion strength. Trivial-vs-non-trivial call is per site through these qualifiers, not by object type.

**One operator per qualifying site.** Pick operator most likely to expose underassertion at *that* site: boundary flip in money math, guard inversion in validation chain, statement removal in posting subscriber, `Validate()` bypass when field trigger carries contract. Operator catalogue and selection heuristics in [tdd.md](../../references/tdd.md). One well-chosen operator is sufficient evidence. **Exception**: survivor that might be equivalent earns a second operator at same site to distinguish equivalence from gap.

**Reachability before mutation.** Confirm at least one test exercises target line. Survivor on unreached line is not coverage gap, it is dead code or missing scenario; route to `/al-refine` (add scenario) or `/al-refactor` (delete dead branch).

**No mutation during refactor in flight.** Land refactor green, commit, then mutate. Shape still moving produces classifications that drift; survivor lists go stale before report ships.

**Pure-layer gating via `-UnitTestOnly`.** When `unitTestApp` configured, P-layer mutations gate via `/al-build -UnitTestOnly` (AL Runner) before full pipeline; inner loop shrinks from minutes to seconds. AL Runner `ERROR` / exit 2 → "broke runner contract," not a survivor; note and skip, run `al-runner --guide` if uncertain which features the runner supports.

## Delegation

Prefer delegated worker when host supports subagents. Mutation work is isolated, output-heavy, context-expensive; worker owns mutate-build-revert cycle and report. Keeping cycle out of main session preserves context for survivor classification, where judgement matters. Do not shadow running worker. Delegation unavailable → run inline.

## Report

Write durable report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. Survivors are actionable section, one row per site with classification, killer test (when written) or equivalence reason. Killed mutants map site to catching test. Report is where deliberation lives; task block carries verdict.

`/al-mutate` does not flip status; it writes verdict into calling task block. Shape (NOTE alert chip, prose line, structured block, table cell) per task. See [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md) and [voice-contract.md](../../references/voice-contract.md). Standalone mode emits Gate report once at pass close, naming rigor proved (or not) for user-facing behaviour under test, soft spots that remain by design, and user's call; inside `/al-implement`, findings fold into the scenario's Gate report.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refactor` (inside `/al-implement` loop), OR standalone on legacy code before `/al-refactor` |
| **Hands off to**   | `/al-refine` (real-gap survivor → killer scenario) inside `/al-implement`; back to caller standalone |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BaseApp behaviour for survivor classification), `/grill-me` (classification call needs the user) |
