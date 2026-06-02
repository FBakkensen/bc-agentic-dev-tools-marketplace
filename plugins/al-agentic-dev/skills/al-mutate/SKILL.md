---
name: al-mutate
description: "Validate AL/Business Central test rigor by mutation: inject one mutation at a time, run the script-backed build gate, classify, revert, report killed/surviving/equivalent mutants. Use mandatorily inside `/al-implement` for non-trivial tasks, or standalone on legacy code before `/al-refactor`."
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-mutate, Test-rigor gate

Mutate production code one site at a time. Build. Classify. Revert. Survivors are the point: each one is a real coverage gap or a documented equivalence.

**Layer.** Guards **oracle sensitivity** at the unit/integration driver layers (see [`test-strategy.md`](../../references/test-strategy.md)): mutation proves an assertion actually *catches* the fault, not merely runs green — the empirical answer to the oracle problem (the same insensitivity that lets a page-script recording false-green).

## Preconditions

- Tree clean. Dirty tree makes revert ambiguous → every survivor becomes a question mark.
- Committed green baseline. `HEAD` is the implementation state under test. Broad revert returns to `HEAD`; uncommitted green work is not safe.
- Baseline full `/al-build` green. Red baseline → survivors carry no signal.
- Target is production code; not tests, not generated `.rdlc` or `.xlf`, not captions / labels / tooltips. Surface and generated artifacts produce noise, not test-rigor signal.
- Enough scope to plan. `/al-mutate` builds the mutation plan from caller scope, changed files, task context, and requested target; `/al-implement` does not pre-plan sites.

Any precondition fails → **Stop**, surface the gap. Do not start mutating to "see what happens."

## What this pass produces

- **Which sites mutated, what mutation at each?** One per site, named by what it inverts (boundary, guard, early exit). Site addressed by file + procedure or `file:line`, in BC vocabulary (posting, ledger entry, document flow), not generic CRUD.
- **Why these sites?** Plan rationale names included decision points and skipped areas. Counts without rationale are weak evidence.
- **Killed, survived, or equivalent candidate?** Killed: specific test caught it. Survivor: real coverage gap until proven otherwise. Equivalent candidate: mutated code appears observably identical, with specific reason recorded for host confirmation.
- **For every survivor, what is the call?** Real gap → same host session writes killer test inside `/al-implement`; standalone mode hands the decision to caller. Equivalence carries reason. Unclear hands back to caller.
- **Tree back to baseline-green?** Closing gate: full `test.ps1` green, `git diff --quiet HEAD` clean, `git status --short` empty.

Unanswerable → pass not done. Resolve via another cycle, survivor decision, or `/grill-me` when call is user's.

## Workflow

**Plan first, execute second.** Host `/al-mutate` chooses included sites, skipped sites, and one operator per qualifying site. Cross-check non-trivial plans via `/al-second-opinion` before worker execution: *"what mutations are missing or misaligned? AND does this surface any of the eight replan triggers? Return a bulleted list."* Reconcile each returned bullet. Worker executes the approved plan only; it does not add, remove, or replace mutants.

**One mutation, one build, one revert.** Apply one mutation. Run `pwsh "<plugin>/skills/al-build/scripts/test.ps1"` directly with the selected gate. Classify. Revert with `git checkout -- .`. Verify tree matches `HEAD` before next mutation. Batched mutations conflate signal; un-reverted mutations poison production and corrupt every subsequent classification. Silent failed revert (file open, line-ending dance, EOL hook rewriting) is the only thing the verify step catches.

**Survivors are the artifact.** Pass exists to surface survivors, not to celebrate kills. Green pass with no survivors and no equivalences → either perfect tests or no decision logic worth mutating; latter belongs in plan, not result. Every survivor is a coverage gap or an equivalence with a stated reason.

**Equivalence needs a specific reason.** "The swapped branch sets the same field to the same value because both paths re-read from the source record before assignment" is an equivalence reason; "looks equivalent" is not. Test that distinguishes equivalent code is testing implementation; recording the reason protects future readers from chasing the un-killable mutant.

**Mutate where bugs hide.** Two filters identify worthwhile sites. *Code-side*: high detection cost (irreversible writes, ledger entries, balance mutations, status flips other code keys off) or branch density (multi-arm `case`, guard chains, boundary comparisons in money math). *Test-side*: covering test's arrange phase reads as a *story* (sequenced BC process) rather than a *fixture*. Trivial code (pure delegation, accessors, single-line init) does not host hidden bugs; first caller catches regressions regardless of assertion strength. Trivial-vs-non-trivial call is per site through these qualifiers, not by object type.

**One operator per qualifying site.** Pick operator most likely to expose underassertion at *that* site: boundary flip in money math, guard inversion in validation chain, statement removal in posting subscriber, `Validate()` bypass when field trigger carries contract. Operator catalogue and selection heuristics in [tdd.md](../../references/tdd.md). No fallback operators. No worker-invented alternate mutation. Rare unclassified sites are evidence gaps, not permission to improvise.

**Reachability before mutation.** Confirm at least one test exercises target line. Survivor on unreached line is not coverage gap, it is dead code or missing scenario; route to `/al-refine` (add scenario) or `/al-refactor` (delete dead branch).

**No mutation during refactor in flight.** Land refactor green, commit, then mutate. Shape still moving produces classifications that drift; survivor lists go stale before report ships.

**Pure-layer gating via `-UnitTestOnly`.** Use the narrowest meaningful gate. When `unitTestApp` configured and the site is genuinely P-layer, run `test.ps1 -UnitTestOnly` (AL Runner). Integration-only behaviour, page/TestPage behaviour, install/publish behaviour, permissions, AppSource/public surface, or container-state behaviour uses full `test.ps1`. Final closeout is always full `test.ps1`.

**Runner contract is unclassified.** AL Runner `ERROR` / exit 2 during a mutant → `not_classified_runner_contract`, not killed, not survived, not equivalent. Full gate is not fallback when full gate also runs AL Runner first. Record exact runner output, broad revert, prove clean tree, continue. Host judges evidence sufficiency after the pass.

**Survivors continue the plan.** A survivor fails the current mutation pass, not the task. Keep executing approved mutants after revert proof. Inside `/al-implement`, the same host session resumes TDD after the worker returns: write killer test, prove RED/GREEN, run `/al-build`, then rerun the survivor site by default. Full plan rerun only when the new test or fix changes shared decision logic.

## Delegation

Use one delegated worker when host supports subagents. Mutation execution is isolated, output-heavy, context-expensive, and serial through the worktree. Host owns plan generation, plan approval, survivor/equivalence judgement, task-block verdicts, and any killer tests. Worker owns mutate-build-recovery-revert cycle and `.output` report. Do not shadow the worker. Delegation unavailable → run inline with the same boundaries.

Model:
- Codex `spawn_agent`: `gpt-5.4-mini`, `reasoning_effort=low`
- Claude Code `Agent`: `haiku`

### Worker rules

```
Preflight: record baseline commit SHA, prove `git status --short` empty, prove `git diff --quiet HEAD`.

Execute the approved plan serially. Do not edit source/spec/tasks/config except transient production mutations from the approved plan. Do not commit. Do not invoke `/al-build` as a nested skill. Run `pwsh "<plugin>/skills/al-build/scripts/test.ps1"` directly with the selected flags.

After each mutant attempt, run `git checkout -- .`, then prove `git diff --quiet HEAD` and empty `git status --short` before the next mutant or before stopping. This broad revert is explicitly authorized only inside `/al-mutate` after committed clean baseline proof.

After all mutants are reverted, run final full `test.ps1` and record the result. This closeout gate proves the committed baseline and full environment after mutation churn; host does not rerun it unless evidence is missing or contradictory.

Write `.output/mutation-report/<YYYYMMDD-HHMMSS>.md` and `.output/TestResults/**` only. `.output` is not committed.
```

### Infra recovery inside a live mutant

Documented `/al-build` infra-red only: container connect, publish, stale container state. Keep the mutant applied. Prove the current diff is exactly the expected mutant. Restart the container, rerun the same `test.ps1` command. If still infra-red, recreate the container, rerun the same command. Do not change the mutant. Do not switch gate scope. Do not edit container state manually.

If the rerun reaches compiler/parser failure caused by the mutant → `killed`. If it reaches test assertion/exception caused by the mutant → `killed`. If it passes → `survived` or `equivalent_candidate`. If infra-red remains after recreate → `blocked_infra_repeat`, stop after broad revert and clean proof. Unknown tooling failure → `blocked_infra_unknown`, stop after evidence, broad revert, and clean proof.

Container/tooling failure never counts as killed.

## Report

Write durable session report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. It is ignored output, not committed. Survivors are actionable section, one row per site with classification and proposed killer-test direction. Killed mutants map site to catching test. Equivalent candidates carry specific reason; host confirms. Include plan rationale, skipped-site rationale, baseline SHA, per-mutant gate command, recovery attempts, final full-gate result, and counts: killed / survived / equivalent / unclassified / blocked.

Task block gets compact verdict only: baseline SHA, report path, counts, final full-gate result, and survivor follow-up or insufficiency note. No full mutation table in `tasks.md`.

`/al-mutate` does not flip status. Shape (NOTE alert chip, prose line, structured block, table cell) per task. See [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md) and [voice-contract.md](../../references/voice-contract.md). Standalone mode emits Gate report once at pass close, naming rigor proved (or not) for user-facing behaviour under test, soft spots that remain by design, and user's call; inside `/al-implement`, findings fold into the scenario's Gate report.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refactor` (inside `/al-implement` loop), OR standalone on legacy code before `/al-refactor` |
| **Hands off to**   | `/al-refine` (real-gap survivor → killer scenario) inside `/al-implement`; back to caller standalone |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BaseApp behaviour for survivor classification), `/grill-me` (classification call needs the user) |
