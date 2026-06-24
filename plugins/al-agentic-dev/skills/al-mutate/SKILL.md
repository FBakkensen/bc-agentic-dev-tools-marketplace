---
name: al-mutate
description: "Validate AL/Business Central test rigor by mutation: inject one mutation at a time, run the script-backed build gate, classify, revert, report killed/surviving/equivalent mutants. The rigor step the user runs after `/al-refactor` on non-trivial tasks, or standalone on legacy code before `/al-refactor`."
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-mutate, Test-rigor gate

Mutate production code one site at a time. Build. Classify. Revert. Each survivor is a real coverage gap or a documented equivalence.

**Layer.** Guards **oracle sensitivity** at the unit/integration driver layers (see [`test-strategy.md`](../../references/test-strategy.md)): mutation proves an assertion actually *catches* the fault, not merely runs green.

## Preconditions

- Tree clean. Dirty tree makes revert ambiguous.
- Committed green baseline. Broad revert returns to `HEAD`; uncommitted green work is not safe.
- Baseline full `/al-build` green. Red baseline → survivors carry no signal.
- Target is production code; not tests, not generated `.rdlc` or `.xlf`, not captions / labels / tooltips.
- Enough scope to plan. `/al-mutate` builds the mutation plan from caller scope, changed files, task context, and requested target; `/al-implement` does not pre-plan sites.

Any precondition fails → **Stop**, surface the gap.

## Workflow

**Plan first, execute second.** Host `/al-mutate` chooses included sites, skipped sites, and one operator per qualifying site. Cross-check non-trivial plans via `/al-second-opinion` before worker execution: *"what mutations are missing or misaligned? AND does this surface any of the eight replan triggers? Return a bulleted list."* Reconcile each returned bullet. Worker executes the approved plan only; it does not add, remove, or replace mutants.

**One mutation, one build, one revert.** Apply one mutation. Run `pwsh "<plugin>/skills/al-build/scripts/test.ps1"` directly with the selected gate. Classify. Revert with `git checkout -- .`. Verify tree matches `HEAD` before next mutation. Batched mutations conflate signal; un-reverted mutations poison production and corrupt every subsequent classification. The verify step catches a silent failed revert.

**Survivors are the artifact.** Green pass with no survivors and no equivalences → either perfect tests or no decision logic worth mutating; the latter belongs in the plan, not the result.

**Equivalence needs a specific reason.** "The swapped branch sets the same field to the same value because both paths re-read from the source record before assignment" is an equivalence reason; "looks equivalent" is not. The recorded reason protects future readers from chasing the un-killable mutant.

**Mutate where bugs hide.** Two filters identify worthwhile sites. *Code-side*: high detection cost (irreversible writes, ledger entries, balance mutations, status flips other code keys off) or branch density (multi-arm `case`, guard chains, boundary comparisons in money math). *Test-side*: covering test's arrange phase reads as a *story* (sequenced BC process) rather than a *fixture*. Trivial code (pure delegation, accessors, single-line init) does not host hidden bugs; first caller catches regressions regardless of assertion strength. Trivial-vs-non-trivial call is per site through these qualifiers, not by object type.

**One operator per qualifying site.** Pick operator most likely to expose underassertion at *that* site: boundary flip in money math, guard inversion in validation chain, statement removal in posting subscriber, `Validate()` bypass when field trigger carries contract. Operator catalogue and selection heuristics in [tdd.md](../../references/tdd.md). No fallback operators. No worker-invented alternate mutation.

**Reachability before mutation.** Confirm at least one test exercises target line. Survivor on unreached line is not coverage gap, it is dead code or missing coverage; route to `/al-refine` (add coverage) or `/al-refactor` (delete dead branch).

**No mutation during refactor in flight.** Land refactor green, commit, then mutate. Shape still moving produces classifications that drift; survivor lists go stale before report ships.

**Unit-layer gating via `-UnitTestOnly`.** Use the narrowest meaningful gate. When `unitTestApp` configured and the site is genuinely P-layer, run `test.ps1 -UnitTestOnly` (AL Runner). Integration-only behaviour, page/TestPage behaviour, install/publish behaviour, permissions, AppSource/public surface, or container-state behaviour uses full `test.ps1`. Final closeout is always full `test.ps1`.

**Runner contract is unclassified.** AL Runner `ERROR` / exit 2 during a mutant → `not_classified_runner_contract`, not killed, not survived, not equivalent. Full gate is not fallback when full gate also runs AL Runner first. Record exact runner output, broad revert, prove clean tree, continue. Host judges evidence sufficiency after the pass.

**Survivors continue the plan.** A survivor fails the current mutation pass, not the task. Keep executing approved mutants after revert proof. A reached real-gap survivor needs a killer test — that is TDD work the user resumes via `/al-implement` (write killer test, prove RED/GREEN, run `/al-build`, rerun the survivor site); name it as the next step, do not run it here. Full plan rerun only when the new test or fix changes shared decision logic.

## Delegation

Use one delegated worker when host supports subagents. Host owns plan generation, plan approval, survivor/equivalence judgement, task-block verdicts, and any killer tests. Worker owns the mutate-build-recovery-revert cycle and `.output` report. Delegation unavailable → run inline with the same boundaries.

After the worker returns its mutation report, close the completed worker thread before the host resumes judgement, killer-test work, or closeout.

A capable coding model fits the worker.

### Worker rules

```
Preflight: record baseline commit SHA, prove `git status --short` empty, prove `git diff --quiet HEAD`.

Execute the approved plan serially. Do not edit source/spec/tasks/config except transient production mutations from the approved plan. Do not commit. Do not invoke `/al-build` as a nested skill. Run `pwsh "<plugin>/skills/al-build/scripts/test.ps1"` directly with the selected flags.

After each mutant attempt, run `git checkout -- .`, then prove `git diff --quiet HEAD` and empty `git status --short` before the next mutant or before stopping. This broad revert is explicitly authorized only inside `/al-mutate` after committed clean baseline proof.

After all mutants are reverted, run final full `test.ps1` and record the result. Host does not rerun this closeout unless evidence is missing or contradictory.

Write `.output/mutation-report/<YYYYMMDD-HHMMSS>.md` and `.output/TestResults/**` only. `.output` is not committed.
```

### Infra recovery inside a live mutant

Documented `/al-build` infra-red only: container connect, publish, stale container state. Keep the mutant applied. Prove the current diff is exactly the expected mutant. Restart the container, rerun the same `test.ps1` command. If still infra-red, recreate the container, rerun the same command. Do not change the mutant. Do not switch gate scope. Do not edit container state manually.

If the rerun reaches compiler/parser failure caused by the mutant → `killed`. If it reaches test assertion/exception caused by the mutant → `killed`. If it passes → `survived` or `equivalent_candidate`. If infra-red remains after recreate → `blocked_infra_repeat`, stop after broad revert and clean proof. Unknown tooling failure → `blocked_infra_unknown`, stop after evidence, broad revert, and clean proof.

Container/tooling failure never counts as killed.

## Report

Write durable session report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. It is ignored output, not committed. Survivors are actionable section, one row per site with classification and proposed killer-test direction. Killed mutants map site to catching test. Equivalent candidates carry specific reason; host confirms. Include plan rationale, skipped-site rationale, baseline SHA, per-mutant gate command, recovery attempts, final full-gate result, and counts: killed / survived / equivalent / unclassified / blocked.

The task file gets the `Closeout` mutation verdict shape from [test-specification.md](../../references/test-specification.md): borderless two-column table (baseline SHA, report path, mutant count with a rationale lede, killed, survivors, final full-gate result) plus labeled `Survivor:` / `Why kept:` lines per survivor. One fact per landing line; no prose wall, no full mutation table in the task file.

`/al-mutate` does not flip status. See [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md) and [voice-contract.md](../../references/voice-contract.md). Emit the Gate report once at pass close, naming rigor proved (or not) for user-facing behaviour under test, soft spots that remain by design, and the user's call; the task-file `Closeout` mutation verdict lands alongside it.

## Next step

End by naming the concrete next move, read off the verdict:

- **Clean verdict** (no survivors, or every survivor a documented equivalence) → name the slice gate: more `ready-for-implementation` tasks in the slice → `Next: /al-implement` (next task); slice-done (the slice's last technical task `done`, either slice type) → `Next: /al-code-review` per-slice — the review gate runs before the verify task is opened.
- **Reached real-gap survivor** → `Next: /al-implement` to resume TDD and write the killer test, then rerun the survivor site.
- **Unreached-line / missing-coverage survivor** → `Next: /al-refine` (add coverage). **Blocked** (infra-repeat, replan-class) → `Next: /al-steer`.

If state can't be read, fall back to `/al-code-review`.

## Feed

Three moments narrate to the branch feed; per-mutant churn stays in the `.output` report. At each, hand `/al-feed` a brief — what happened, why it matters to a wary dev, the kind — and `/al-feed` composes the punchline + layers and appends the card. Compose by name; do not inline its mechanics.

- **decision** — when the mutation plan is fixed (included/skipped sites, one operator each) and `/al-second-opinion` reconciled. Captures *where the agent will try to break the code and what it is leaving alone* — per-site operator and skip rationale.
- **surprise** — per survivor, when a mutant lands survived or equivalent. Captures *the code was broken on purpose and the tests stayed green — a gap they did not catch* — site + operator, real-gap vs stated equivalence, the killer-test direction.
- **verdict** — at pass close, after final full gate green and clean-tree proof. Captures *tests caught N of M planted faults, K real gaps remain, code safely back to green* — full counts, evidence gaps, baseline SHA and report path.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refactor` (the rigor step the user runs after reshape), OR standalone on legacy code before `/al-refactor` |
| **Hands off to**   | `/al-code-review` on a clean verdict (slice/feature gate); `/al-implement` for a reached real-gap survivor (resume TDD for the killer test) or for the next `ready-for-implementation` task; `/al-refine` only for unreached-line or missing-coverage cases |
| **Calls directly** | `/al-second-opinion` (cross-check non-trivial mutation plans before execution) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BaseApp behaviour for survivor classification), `/grill-me` (classification call needs the user) |
