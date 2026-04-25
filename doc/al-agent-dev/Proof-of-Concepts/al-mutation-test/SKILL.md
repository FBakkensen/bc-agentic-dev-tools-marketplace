<!-- Historical: project-specific PoC. See ../../al-skills-design.md for the current design. -->
---
name: al-mutation-test
description: Empirically audit the quality of an AL (Business Central) test suite by mutation testing — apply small semantic mutations to production code, run the tests, and report which mutations survive (revealing weak or missing tests) vs get killed (genuine coverage). Use whenever the user wants to validate characterization tests before a refactor, audit test effectiveness, check for false positives in a test suite, find coverage gaps, prove tests actually exercise a specific code path, or asks questions like "are these tests any good", "do the tests catch X", "which tests are load-bearing", or "find test gaps". Especially valuable before rewriting a BC codeunit, since a high mutation score on the baseline suite is stronger evidence of parity than line coverage.
---

# AL Mutation Testing

## Why this exists

AL has no mutation-testing framework. Tests may pass for the wrong reasons — asserting on test-framework state, depending on shared committed data from a prior test, or using assertions so loose they trivially hold. A green suite is only as trustworthy as its ability to fail when production breaks. This skill measures that ability directly: break production in a small, semantic way; if no test fails, the suite has a gap there.

The workflow is deterministic enough for Claude to run it manually: **edit production → run tests → parse result → revert → record**, repeated N times. Each mutation is chosen by hand so each one represents a *semantic* change — something a correct test really ought to catch.

## When to use

- The user wants to validate their test suite before a refactor (parity is the deliverable)
- The user suspects some tests are "false positives" (pass for wrong reasons)
- The user asks which code paths are actually covered, or where the gaps are
- The user is finishing a characterization test batch and wants an objective quality check
- Someone proposed deleting a test as "redundant" — mutation testing tells you if it's load-bearing

## When NOT to use

- Exploratory work on production code (you want coverage, not a green suite yet)
- Tests are already known to be failing (fix them first — mutation testing needs a green baseline)
- The target is test code itself (mutating tests doesn't validate anything)

## Preflight (non-negotiable)

Before any mutation, confirm all of these:

1. **Working tree clean.** Run `git diff --quiet && git diff --cached --quiet`. If either reports changes, stop and ask the user to commit or stash. A dirty tree makes revert unsafe — you cannot distinguish mutation artifacts from pre-existing edits.

2. **Baseline green.** Run the full suite once with no mutation applied. If any test already fails, the campaign is meaningless — every mutation will trivially "kill" (surviving tests won't, but you can't tell the real signal from the noise). Ask the user to fix the failing tests first.

3. **Test runner reachable.** Confirm the `al-build` skill's `scripts/test.ps1` exists at its expected path. Typical location: `~/.claude/plugins/cache/<marketplace>/al-build/<version>/skills/al-build/scripts/test.ps1`. Find with `Get-ChildItem ~/.claude -Recurse -Filter test.ps1 -ErrorAction SilentlyContinue | Where-Object FullName -like '*al-build*'`.

4. **Target file is production code.** Test files under `test/` or `*.Test.al` are off-limits.

If any preflight fails, do **not** proceed silently. State what failed and stop.

## Mutation plan — pick by hand, not by script

A mutation is **(file, line, operator, before, after)**. Claude selects mutations by reading the target range and choosing changes that are:

- **Semantic** — the behavior actually changes (not an equivalent mutant like `i + 0`)
- **Plausible** — a real refactor could introduce this error
- **Localized** — one line, one operator, reverts cleanly via `git checkout -- <file>`

Default budget is 15 mutations unless the user specifies otherwise. Budgets above 30 get expensive (each mutation costs one full test run — ~2–3 min on a typical AL repo, so 30 mutations ≈ 60–90 min). Prefer quality over quantity.

### Operator catalog

Ordered by signal-per-minute. Start at the top of the list and pick representative mutations from each operator before dropping to the next.

| # | Operator | Example before → after | When it pays |
|---|----------|------------------------|--------------|
| 1 | Comparison flip | `<=` → `<`, `>=` → `>`, `=` → `<>`, `<>` → `=` | Boundary-sensitive logic: time windows, count thresholds, date ranges |
| 2 | Boolean literal flip | `exit(true)` → `exit(false)`, `HasErrors := true` → `HasErrors := false` | Gate/guard procedures, TryFunction returns |
| 3 | Early exit injection | Insert `exit;` (or `exit(true)` / `exit(false)`) at procedure entry | Verifies callers rely on the procedure's side effects, not just on it not erroring |
| 4 | Condition negation | `if X then` → `if not X then` | Branch selection |
| 5 | Constant tweak | `0` → `1`, `'PROD-RUN'` → `'PROD-RUND'`, `WaitMinTime` literal → doubled | Magic-number / literal dependency |
| 6 | Filter removal | Comment out a `SetFilter`/`SetRange` line | Tests of correctness-by-filter; often catches under-asserted record iteration |
| 7 | Field write swap | `Rec.A := X` → `Rec.B := X` (same type) | Field-write correctness |
| 8 | Arithmetic flip | `A + B` → `A - B`, `* 2` → `/ 2` | Numeric aggregation paths |

Operators 7 and 8 are lower-priority because they risk build failure (type mismatch) more often than the others.

### How to target

If the user names a procedure (`HandleTriggerSchedule`) or a line range, scope mutations to that range. If the user points at a file without a range, ask for one — a whole file is too broad for 15 mutations to meaningfully cover.

Prefer mutations in code paths the user explicitly cares about. For instance, if auditing trigger-schedule tests, prioritize mutations inside the trigger-switching logic over mutations in unrelated sibling branches.

Before starting the campaign, present the mutation plan — the list of (file:line, operator, before → after) — and have the user confirm or adjust. This is the one place where upfront alignment beats iteration, because the mutation plan determines what the campaign can say.

## The per-mutation loop

For each planned mutation, in order:

1. **Apply** via `Edit` — exactly one `old_string` / `new_string` change. Minimal diff. No whitespace-only changes unless explicitly intended.

2. **Build + test**. Run the full suite:
   ```powershell
   pwsh -File <path-to-al-build>/scripts/test.ps1
   ```
   Do not pass `-TestCodeunit`. Full-suite runs add only ~10–20s vs a single codeunit but catch cross-codeunit kills — crucial when the mutation's real coverage lives in a test codeunit you didn't predict.

3. **Classify outcome** by reading `.output/TestResults/last.xml` (JUnit):
   - **build-failure** — compile/publish failed. Mutation was invalid (likely a type error). Record and move on. Not a coverage signal.
   - **killed** — at least one test failed. The suite caught the mutation. Extract the failing-test names from the `<testcase>` / `<failure>` elements in the XML. Record them.
   - **survived** — all tests passed. **This is the actionable finding** — either the mutation is semantically equivalent (and you should note why), or the suite has a gap at that code path.

4. **Revert** with `git checkout -- <file>`. Then verify: `git diff --quiet -- <file>` must succeed. If not, abort the entire campaign — something unexpected happened (maybe an editor added a trailing newline, maybe a hook modified the file). You cannot safely continue without human review.

5. **Also revert RDL/RDLC.** AL compile sometimes rewrites layout files. Run `git checkout -- 'JobManager/Layout/*.rd*' 'JobManager/Layout/*.rdl' 'JobManager/Layout/*.rdlc'` (or the equivalent glob for the repo) after each iteration. If none exist, the command is a no-op.

6. **Record** the outcome inline — keep a running markdown table in conversation so you can write the final report without re-parsing XML.

### Abort conditions

Stop the campaign immediately if any of these hold:

- **Revert failed** (working tree dirty after `git checkout`). Report where.
- **Three consecutive build failures.** Signals the mutation plan isn't producing valid AL — re-plan rather than burn time.
- **Test runner crashes** (exit code non-zero from infrastructure, not test failures). Infrastructure problem, not a mutation signal.
- **Baseline drift.** If a test that passed in the baseline run fails on a mutation run for reasons clearly unrelated to the mutation (e.g. a timeout, a flake), re-run once. If it happens twice, stop — the suite has non-determinism that will corrupt your report.

## Parsing `last.xml`

The file is JUnit XML. A minimal-but-correct read:

```powershell
[xml]$junit = Get-Content .output/TestResults/last.xml
$failed = $junit.SelectNodes("//testcase[failure or error]")
$total = $junit.SelectNodes("//testcase").Count
$passed = $total - $failed.Count
```

Each failing `<testcase>` has `name` and `classname` attributes — use both to identify the killing test unambiguously (two codeunits can have identically-named procedures).

If the XML is missing or malformed, treat as build-failure.

## Report format

Write to `.output/mutation-report/<YYYYMMDD-HHMMSS>.md`. The report is the durable deliverable.

```markdown
# AL Mutation Test Campaign — <timestamp>

## Summary
- Target: `<file>` lines `<start>`–`<end>` (procedure `<name>` if applicable)
- Budget: 15 mutations
- Killed: 12
- Survived: 2
- Build failures: 1
- **Mutation score: 12 / 14 = 86%** (excluding build failures)

## Surviving mutants (coverage gaps)

Each of these passed the entire test suite despite a semantic change to production code. Review each to decide: genuine gap → write a test; equivalent mutation → note and move on.

### S1 — `CalcEmployee.Codeunit.al:1208`
- Operator: comparison flip
- Before: `if (A - B - C) <= JobManSetup.WaitMinTime then`
- After:  `if (A - B - C) < JobManSetup.WaitMinTime then`
- Why it's interesting: the boundary case (exactly equal to WaitMinTime) is not tested. A boundary test (B-class) would kill this.

### S2 — ...

## Killed mutants (genuine coverage)

| # | file:line | operator | before → after | killing test(s) |
|---|-----------|----------|----------------|-----------------|
| K1 | CalcEmployee.al:922 | bool flip | `exit(true)` → `exit(false)` | GivenTriggerJobStamp_...ThenTriggerScheduleUsed |
| ... | | | | |

## Build failures (skipped)

| # | file:line | operator | error |
|---|-----------|----------|-------|
| B1 | ... | ... | AL0132: type mismatch |

## Notes on equivalent mutants

Mention any surviving mutants that are likely equivalent (no behavioral change possible), so the reader doesn't chase phantom gaps.

## Recommendations

1. Write test for boundary of `WaitMinTime` (kills S1)
2. ...
```

The **surviving mutants section is the point.** Everything else is context. If all mutants are killed, the report is short and the suite is validated.

## Examples

**Example 1 — audit trigger-schedule tests in a specific repo:**

```
User: Run mutation testing on CU 6182780 procedure HandleTriggerSchedule, budget 15
```

Workflow:
1. Preflight: git clean, baseline green, test.ps1 found.
2. Read HandleTriggerSchedule, plan 15 mutations across comparison flips, boolean flips, condition negations.
3. Present plan, confirm.
4. Loop: apply → test → classify → revert → next.
5. Write `.output/mutation-report/20260421-143000.md`.
6. Highlight 2 surviving mutants with a recommendation for each.

**Example 2 — user has a vague worry:**

```
User: I'm not sure if my wait-job tests actually catch anything. Can you check?
```

Workflow:
1. Find the wait-job code (`grep` the production codeunit).
2. Ask: do you have a specific procedure to target, or should I plan mutations across the whole wait-job insertion block?
3. Proceed as Example 1.

## Safety invariants — summary

Re-stated here as a checklist you can skim at the start of a campaign:

- [ ] Working tree clean before start
- [ ] Baseline green before start
- [ ] Every iteration ends with `git diff --quiet -- <target>` passing
- [ ] RDL/RDLC files reverted at end of every iteration
- [ ] Never mutate test code
- [ ] Abort on 3 consecutive build failures
- [ ] Abort on any failed revert
- [ ] Don't commit, push, or open PRs from within the campaign — the report is the deliverable

## Repo-specific notes

The skill is repo-agnostic, but each AL repo has quirks worth remembering. Record them in the repo's `CLAUDE.md`, not here. Examples worth capturing per repo:
- Typical build+test time (so you can estimate campaign duration)
- Which layout files get auto-touched on compile (so the revert glob is correct)
- Any tests known to be flaky (so you can factor them out of "killed" classifications)
