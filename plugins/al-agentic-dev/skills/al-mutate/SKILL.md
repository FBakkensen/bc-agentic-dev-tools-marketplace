---
name: al-mutate
description: "Validate AL/Business Central test rigor by mutation: inject one mutation at a time, run the script-backed build gate, classify, revert, report killed/surviving/equivalent mutants. The rigor step the user runs after `/al-refactor` on whatever arrived without a red, or standalone on legacy code before `/al-refactor`."
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

**Survivors are the artifact.** Green pass with no survivors and no equivalences → either perfect tests or no unproven logic worth mutating; the latter belongs in the plan, not the result.

**Equivalence needs a specific reason.** "The swapped branch sets the same field to the same value because both paths re-read from the source record before assignment" is an equivalence reason; "looks equivalent" is not. The recorded reason protects future readers from chasing the un-killable mutant.

**A red is a killed mutant.** The strongest mutation is deleting the code — and TDD ran it first: the test failed while the production code did not yet exist. Mutation testing asks the same question after the fact. Ask it only where it was never asked: code that arrived without a red — legacy paths, tests written after their code, branches a refactor introduced, work absorbed without its own red (`deviations:` is the breadcrumb). Never answer it by reading the tests and finding the assertions rigorous; that judgment is the one mutation exists to replace.

**A kill is behavioural, never a compile error** — the exact symmetry of the red, which fails on an assertion, not a compile error (`tdd.md`: Red phase, Scaffold-before-Red). The mutation-time analogue of "deleting the code" removes *behaviour while preserving compilation*: comment out an assignment whose variable still reads, not one whose removal breaks the build. A mutant the compiler rejects never ran — it forces no test to answer, so it proves nothing about the assertions. Force the kill onto a test the way Scaffold forces the red onto an assertion: make the mutant compile, then let behaviour catch it.

**The red guards a behaviour, not lines.** Reshape moves code; the test that once failed against the rule still fails wherever the rule lives now. Only what the reshape added never failed anything. When you can't tell how code arrived, it arrived without a red — and the tie breaks harder toward mutating the more a fault costs to catch: irreversible writes, ledger entries, status flips other code keys off. Trivial code (pure delegation, accessors, single-line init) does not host hidden bugs; the first caller catches regressions regardless of assertion strength. Each skip is a recorded claim — "this behaviour has failed a test" — for the report and the cross-check to attack.

**One operator per qualifying site.** Pick operator most likely to expose underassertion at *that* site: boundary flip in money math, guard inversion in validation chain, statement removal in posting subscriber, `Validate()` bypass when field trigger carries contract. Operator catalogue and selection heuristics in [tdd.md](../../references/tdd.md). No fallback operators. No worker-invented alternate mutation.

**Reachability before mutation.** Confirm at least one test exercises target line. Survivor on unreached line is not coverage gap, it is dead code or missing coverage; route to `/al-refine` (add coverage) or `/al-refactor` (delete dead branch).

**No mutation during refactor in flight.** Land refactor green, commit, then mutate. Shape still moving produces classifications that drift; survivor lists go stale before report ships.

**Unit-layer gating via `-UnitTestOnly`.** Use the narrowest meaningful gate. When `unitTestApp` configured and the site is genuinely P-layer, run `test.ps1 -UnitTestOnly` (AL Runner). Integration-only behaviour, page/TestPage behaviour, install/publish behaviour, permissions, AppSource/public surface, or container-state behaviour uses full `test.ps1`. Final closeout is always full `test.ps1`.

**Compile failure is not a kill.** A mutant that fails to compile or parse is `invalid_stillborn`: the gate never reached the tests, no oracle spoke. It does not count as killed and it does not close the site. Detect it by the gate's own signal, not the exit code — a compile failure and a test failure both exit `1`; the newest `.output/logs/build-timing.jsonl` line reads `outcome:"error"` for a compile/publish failure, `outcome:"failed"` for a test that went red, `outcome:"passed"` for green (`.output/TestResults/summary.json` is refreshed only when compilation succeeded — a corroborating tell). Stillborn is a mutation-coverage gap, not a pass: the host re-plans a *compiling* operator at that site so a test must answer — only a test-caught kill or a genuine survivor closes it. Record the compiler output, broad revert, prove clean tree, continue.

**Runner contract is unclassified.** AL Runner `ERROR` / exit 2 during a mutant → `not_classified_runner_contract`, not killed, not survived, not equivalent. Full gate is not fallback when full gate also runs AL Runner first. Record exact runner output, broad revert, prove clean tree, continue. Host judges evidence sufficiency after the pass.

**Survivors continue the plan.** A survivor fails the current mutation pass, not the task. Keep executing approved mutants after revert proof. A reached real-gap survivor needs a killer test — that is TDD work the user resumes via `/al-implement` (write killer test, prove RED/GREEN, run `/al-build`, rerun the survivor site); name it as the next step, do not run it here. Full plan rerun only when the new test or fix changes shared decision logic.

## Delegation

Use one delegated worker when host supports subagents. Host owns plan generation, plan approval, survivor/equivalence judgement, task-block verdicts, and any killer tests. Worker owns the mutate-build-recovery-revert cycle and `.output` report. Delegation unavailable → run inline with the same boundaries. The spawn prompt includes verbatim: findings must name file, object, and the observed fact; no verdict words without the check that produced them ([voice-contract.md](../../references/voice-contract.md) Relaying subagent findings).

After the worker returns its mutation report, close the completed worker thread before the host resumes judgement, killer-test work, or closeout.

Spawn the worker on `sonnet` — a mechanical mutate-build-revert cycle (see [model-selection.md](../../references/model-selection.md)).

### Worker rules

```
Preflight: record baseline commit SHA, prove `git status --short` empty, prove `git diff --quiet HEAD`.

Execute the approved plan serially. Do not edit source/spec/tasks/config except transient production mutations from the approved plan. Do not commit. Do not invoke `/al-build` as a nested skill. Run `pwsh "<plugin>/skills/al-build/scripts/test.ps1"` directly with the selected flags.

Classify each mutant by the gate's outcome signal, not the exit code (compile and test failures both exit 1): read the newest line of `.output/logs/build-timing.jsonl` — `outcome:"error"` → `invalid_stillborn` (compile/publish failed, no test ran; NOT killed); `outcome:"failed"` → `killed` (a test went red — assertion or runtime exception from the mutated path); `outcome:"passed"` → `survived` or `equivalent_candidate`. AL Runner's own exit-3 compile error maps to `outcome:"failed"`; because the app is analyzer-compiled before AL Runner runs, that combination is contradictory → `not_classified_runner_contract`, never killed. Record `invalid_stillborn` and continue; do not re-plan (re-planning a compiling operator at the site is host territory).

After each mutant attempt, run `git checkout -- .`, then prove `git diff --quiet HEAD` and empty `git status --short` before the next mutant or before stopping. This broad revert is explicitly authorized only inside `/al-mutate` after committed clean baseline proof.

After all mutants are reverted, run final full `test.ps1` and record the result. Host does not rerun this closeout unless evidence is missing or contradictory.

Write `.output/mutation-report/<YYYYMMDD-HHMMSS>.md` and `.output/TestResults/**` only. `.output` is not committed.
```

### Infra recovery inside a live mutant

Documented `/al-build` infra-red only: container connect, publish, stale container state. Keep the mutant applied. Prove the current diff is exactly the expected mutant. Restart the container, rerun the same `test.ps1` command. If still infra-red, recreate the container, rerun the same command. Do not change the mutant. Do not switch gate scope. Do not edit container state manually.

If the rerun reaches compiler/parser failure caused by the mutant (`outcome:"error"`) → `invalid_stillborn`, **not killed**: the compiler caught it, no test did; the host re-plans a compiling operator at the site. If it reaches test assertion/exception caused by the mutant (`outcome:"failed"`) → `killed`. If it passes → `survived` or `equivalent_candidate`. If infra-red remains after recreate → `blocked_infra_repeat`, stop after broad revert and clean proof. Unknown tooling failure → `blocked_infra_unknown`, stop after evidence, broad revert, and clean proof.

Container/tooling failure never counts as killed.

## Report

Write durable session report at `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. It is ignored output, not committed. Survivors and stillborns are the actionable sections, one row per site with classification and next action — killer-test direction for a survivor, the re-planned compiling operator for a stillborn. Killed mutants map site to the catching **test**; a "kill" with no named catching test is not a kill, it is a stillborn or a mislabeled survivor. Equivalent candidates carry specific reason; host confirms. A non-zero stillborn count blocks the clean verdict the same way a survivor does — its action is a host re-plan of a compiling operator, not a killer test. Include plan rationale, skipped-site rationale, baseline SHA, per-mutant gate command and `outcome`, recovery attempts, final full-gate result, and counts: killed / survived / equivalent / stillborn / unclassified / blocked.

The task file gets the `Closeout` mutation verdict shape from [test-specification.md](../../references/test-specification.md): borderless two-column table (baseline SHA, report path, mutant count with a rationale lede, killed, survivors, stillborn when non-zero, final full-gate result) plus labeled `Survivor:` / `Why kept:` lines per survivor and `Stillborn:` / `Re-planned:` lines per stillborn. One fact per landing line; no prose wall, no full mutation table in the task file.

`/al-mutate` does not flip status. See [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md) and [voice-contract.md](../../references/voice-contract.md). Emit the Gate report once at pass close, rendered box-first and passed through the pre-send checks, naming rigor proved (or not) for user-facing behaviour under test, soft spots that remain by design, and the user's call; the task-file `Closeout` mutation verdict lands alongside it.

## Next step

End by naming the concrete next move, read off the verdict:

- **Clean verdict** (no survivors and no unresolved stillborn, or every remaining item a documented equivalence) → name the slice gate: more `ready-for-implementation` tasks in the slice → `Next: /al-implement` (next task); slice-done (the slice's last technical task `done`, either slice type) → `Next: /al-code-review` per-slice — the review gate runs before the verify task is opened.
- **Reached real-gap survivor** → `Next: /al-implement` to resume TDD and write the killer test, then rerun the survivor site.
- **Unresolved stillborn** (a planned mutation the compiler rejected) → host re-plans a *compiling* operator at that site and reruns it; not a clean handoff. Only when the re-planned mutant runs and is test-caught or genuinely survives does the site close.
- **Unreached-line / missing-coverage survivor** → `Next: /al-refine` (add coverage). **Blocked** (infra-repeat, replan-class) → `Next: /al-steer`.

If state can't be read, fall back to `/al-code-review`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refactor` (the rigor step the user runs after reshape), OR standalone on legacy code before `/al-refactor` |
| **Hands off to**   | `/al-code-review` on a clean verdict (slice/feature gate); `/al-implement` for a reached real-gap survivor (resume TDD for the killer test) or for the next `ready-for-implementation` task; `/al-refine` only for unreached-line or missing-coverage cases |
| **Calls directly** | `/al-second-opinion` (cross-check non-trivial mutation plans before execution) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BaseApp behaviour for survivor classification), `/grill-me` (classification call needs the user) |
