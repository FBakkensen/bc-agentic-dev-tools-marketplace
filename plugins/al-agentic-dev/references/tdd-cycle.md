# AL TDD Cycle

Cited by `/al-implement` for the Red→Green→Refactor→Mutate sequence. Three layers of trust, three laws, five phases.

## Three Layers of TDD Trust

| Layer | What it proves | Mechanism |
|---|---|---|
| Process discipline | Tests drive production code | Three Laws of TDD |
| Coverage direction | Right scenarios in right order | ZOMBIES ordering, see `zombies-scenarios.md` |
| Behavioural proof | Assertions actually catch bugs | Mutation testing, see `mutation-operators.md` |

A passing-but-wrong-path test looks green. Branch-marker presence does not prove an assertion catches a bug, mutation testing is the proof.

## Three Laws of TDD

1. Write no production code without a failing test.
2. Write no more test than is enough to fail.
3. Write no more production code than is enough to make the failing test pass.

Violations: writing a full feature then back-filling tests; writing all tests before any production code; writing more logic than the current failing test demands.

## 5-Phase Cycle

| Phase | Exit criterion |
|---|---|
| **Scaffold** | Compilable stubs exist, build green, new test codeunit and production procedure declared but empty |
| **Red** | Test fails on an **assertion**, not a runtime error, not a compile error. Existing suite still passes. |
| **Green** | Minimal production change makes the target test pass. Full test suite still green. |
| **Refactor** | Implementation tidied; any `DEBUG-*` markers removed; full suite green. |
| **Mutate** | Targeted mutations caught by ≥ 1 failing assertion; reverted; green confirmed. |

**Red phase rule**: a compile error is not a Red. Fix compile errors first, then get to an assertion failure.

**Refactor exit gate**: a full grep for `DEBUG-` returns nothing before committing.

**TDD is not optional.** Apply to all new development, feature changes, and bug fixes. The only exception is when the user explicitly says to skip TDD ("skip TDD", "no tests", "without TDD"). "Quickly add X" does not count as skipping.

## Skills

- `/al-implement`, drives Red → Green → Refactor with `/al-build` as the gate after every phase.
- `/al-mutate`, runs the Mutate phase: inject one mutation, `/al-build`, classify, revert.
- `/al-build`, full gate. Use `/al-build -UnitTestOnly` for the AL Runner-only inner loop on Pure-tagged bullets when `unitTestApp` is configured. See `al-runner.md`.
