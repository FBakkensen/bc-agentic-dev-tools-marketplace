# Full TDD for Business Central AL — Skill & Agent Plan

**Status:** Draft for user review
**Date:** 2026-04-18
**Author:** Claude Code (Opus 4.7 1M context), under `/loop`-style coordination with the user
**Working dir:** `C:\Users\FlemmingBK\.claude\plans\al-tdd-plan.md`

---

## 0. Executive Summary

This plan designs a **6-skill + 10-agent bundle** that delivers end-to-end Test-Driven Development for Business Central AL, aligned with:

- the user's conference learnings (Days of Knowledge Nordic 2026, 35 slides analysed),
- the user's actual TDD workflow reconstructed from ~1,100 Claude Code sessions across AL projects,
- the existing `al-build` skill (untouched) and the principles in the `writing-al-tests` POC (to be deleted),
- the user's global `CLAUDE.md` preferences (AL naming conventions, coordinator-first workflow, PowerShell 7, never auto-commit).

The bundle lives under `~/.claude/skills/` and `~/.claude/agents/` (personal scope first, packageable into a plugin later) and composes with the existing MCP servers: `al-symbols-mcp` (dependency/package symbols only), `al-object-id-ninja`, `bc-knowledge`, `microsoft-docs`, `context7`, plus the built-in `LSP` tool backed by the AL language server (current-project symbol navigation). All compile, publish, and test-run operations go exclusively through the existing `al-build` skill — no MCP tool, CLI, or direct `alc.exe` invocation may perform these. The bundle's only external-skill dependencies are **`al-build`** (compile/publish/test gate) and **`bc-standard-reference`** (BC-specific research lookups). No other skill in the user's environment is assumed present. BC event-subscriber probe patterns and similar BC-technical research topics are handled by the agents via `bc-standard-reference` / `mcp__bc-knowledge__*` / `mcp__al-symbols-mcp__*`, not bundle-shipped skill content.

**Core design moves:**
1. The 5-phase cycle **Scaffold → Red → Green → Refactor → Mutate** from the conference is the primary workflow. `writing-al-tests`' Execution Markers (`DEBUG-*` FeatureTelemetry, logged to `.output/TestResults/telemetry.jsonl`) are carried forward as a **normal debug-logging pattern** (§4.3) — injected when an agent needs to confirm which branch ran during a stuck test, when characterising legacy, or when probing BC standard behaviour. They are **not** a mandatory TDD invariant. Mutation testing (§4.6) replaces the earlier "execution proof" framing — it actually validates that assertions catch bugs, whereas markers only confirm a branch was reached (a passing-but-wrong-path test still fires its markers).
2. Refinement is a **first-class phase with its own committed artifact** — `.plans/<timestamp>-tdd-<slug>.md`. `al-tdd-refine` iterates draft → `al-scenario-plan-reviewer` critique → **structured `AskUserQuestion` turn** (triage / scope / reviewer-gated verdict) → revise, until the user selects `Approve` and the doc's `status` flips to `approved`. `/al-tdd` reads its input argument (scenario, issue reference, plan-doc path) and invokes `al-tdd-refine` internally when the input is ambiguous or needs refinement; for trivial clear inputs it proceeds directly. The plan doc stays committed as PR context and team-review input — including both `## Review` and `## Decisions` audit sections.
3. Phase state is tracked via Claude Code's **native `TaskCreate` / `TodoWrite`** — session-scoped, reconstructible from the plan doc + last `tdd:` commit on re-entry. The earlier draft proposed `bc-knowledge workflow_*`, rejected after POC confirmed it cannot host custom workflows.

---

## 1. Research Inputs (Pointers)

| Source | Location | Key insight |
|---|---|---|
| Conference slides (35 JPG) | `C:\Users\FlemmingBK\Downloads\Photos-3-001\` | 5-phase cycle, 7 pillars, speaker's own agent inventory (`al-test-writer`, `al-test-coverage-enforcer`, `al-test-coverage-validator`, `al-test-validator`, `al-mock-generator`, `al-code-quality-reviewer`) |
| Claude Code history | `C:\Users\FlemmingBK\.claude\projects\` (1,100+ sessions, ~350 MB) | Validated patterns: parallel sub-agent scenario planning, Gherkin-in-markdown, sentinel 999 discovery; pain points: `-Force` build bug, forgotten DEBUG cleanup, "assert all details" correction, publisher mismatch silent failures |
| `al-build` SKILL | `plugins/cache/bc-agentic-dev-tools/al-build/2.1.2/…/SKILL.md` | Invoked as the gate in Scaffold/Red/Green/Mutate phases. `pwsh "<skill>/scripts/test.ps1" [-TestCodeunit <id>] [-Force]`. Outputs `.output/TestResults/last.xml` + `telemetry.jsonl` |
| `writing-al-tests` POC | `plugins/cache/bc-agentic-dev-tools/writing-al-tests/1.1.0/` | Source of the Execution Markers pattern, TestTemplate.Codeunit.al, transaction-model guidance, BC event-subscriber probe pattern — all migrated into new skills, then POC deleted |
| Vjeko Babić — testability trilogy | [Testing, testability, and all things test](https://vjeko.com/2023/11/02/testing-testability-and-all-things-test/) · [Directions EMEA 2023 demo — decoupling base app](https://vjeko.com/2023/11/02/directions-emea-2023-demo-decoupling-base-app/) · [Testing in isolation](https://vjeko.com/2023/12/09/testing-in-isolation/) · demo repo [`vjekob/emea2023`](https://github.com/vjekob/emea2023) | Concrete AL patterns for decoupling: 3-phase refactoring (extract internal procedures → define interface → inject via overload), Test Double taxonomy (Dummy/Mock/Spy), unit-vs-integration framing, 10s speed budget for unit suites, "BaseApp is YOUR dependency" mindset, 100%-of-interesting-code / 0%-of-infrastructure coverage philosophy |
| Finn Pedersen — Environment Interface series | [Part 1 — System Environment](https://www.finnpedersenfrance.com/programming/2025/06/26/environment-interface-part-1.html) · [Part 2 — External API](https://www.finnpedersenfrance.com/programming/2025/06/26/environment-interface-part-2.html) · [Part 3 — Standard Application](https://www.finnpedersenfrance.com/programming/2025/06/26/environment-interface-part-3.html) | Three default decoupling seams for AL: **System environment** (sandbox/production/company/eval detection via `IEnvironment`), **External APIs** (HttpClient via `IApiRequest`), **Standard Application** (BaseApp calls — Finance posting, number series — via `IFinance` etc.). Naming convention: `I<Thing>` interface, `"App <Thing>"` production impl (in production app), `"Stub <Thing>"` test impl (in **test app only**). Setup-then-return pattern for stubs (`SetupResponse(...)` → `Send(...)` returns the configured value). London/xUnit double taxonomy (Stub = fixed data, Mock = verifies calls). Worked safety example: `ApplicationState` enum + licensee match auto-disables copied companies via a company-copy event subscriber. |
| Luc van Vugt — *Automated Testing in Microsoft Dynamics 365 Business Central* (Packt, 2022, 2nd ed). | Book reference | Canonical BC-testing-community baseline — predates Vjeko/Pedersen; origin of `// [SCENARIO]` / `// [GIVEN]` Gherkin-in-markdown comment shape used in Microsoft BaseApp. |
| James Pearson — AL Test Runner VS Code extension | [`jamespearson.al-test-runner`](https://marketplace.visualstudio.com/items?itemName=jamespearson.al-test-runner) | De facto community test runner; code coverage + perf profile + page scripting. The bundle does not depend on this (al-build is the gate), but it is the community reference point. |
| Pedersen — Temporary Tables in Tests | [finnpedersenfrance.com/.../temporary-tables-in-tests](https://www.finnpedersenfrance.com/programming/2025/06/26/temporary-tables-in-tests.html) | Companion post to the Environment Interface series. Temporary record variables as an alternative decoupling-from-DB lever — cheaper than interface extraction when the only coupling is to a table. |
| BC 2025 Wave 1 — Interface Collections (runtime 15.0) | [Microsoft Learn — Interfaces in AL](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-interfaces-in-al) | `List of [Interface I…]`, `Dictionary of [Text, Interface I…]`. Pattern-enabler for strategy maps and pluggable test fixtures. |
| BC 2024 Wave 2 — Interface `extends` | [Microsoft Learn — Interfaces in AL](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-interfaces-in-al) | ISV-to-ISV interface evolution. Relevant for `al-test-double-generator` handling extended interfaces. |

---

## 2. Design Principles

### 2.1 The 5-Phase Cycle (authoritative workflow)

| # | Phase | Exit criterion |
|---|---|---|
| 1 | **Scaffold** | Compilable stubs exist, build is green, new test codeunit and production procedure declared but empty |
| 2 | **Red** | Test fails on an **assertion**, not a runtime/compile error. Existing suite still passes |
| 3 | **Green** | Minimal production change makes the target test pass. Full test suite still green |
| 4 | **Refactor** | Implementation tidied; any `DEBUG-*` debug logging injected during the cycle removed; full suite green |
| 5 | **Mutate** | Targeted mutations (flip boolean, swap `+`/`-`, comment out a line, change comparator) are caught by at least one failing assertion; revert and re-verify green |

### 2.2 The 7 Pillars of Agent-Friendly Code

From slide 12 (IMG20260417114125). These are the testability invariants the skills defend:

1. **Separation of concerns** — decision logic separated from side-effect invocation
2. **Explicit contracts** — signatures, interfaces, enums — "if not in code, it doesn't exist"
3. **Testability** — inputs, outputs, dependencies all visible
4. **Consistency** — the codebase *is* the agent's primary prompt
5. **Appropriate abstraction** — neither too flat nor too deep
6. **Intent preservation** — the WHY survives agent rewrites (structure, comments, tests, CLAUDE.md)
7. **Reviewability** — structural, not cosmetic ("can I efficiently verify the agent did the right thing?")

### 2.3 Three Layers of TDD Trust

| Layer | Proves | Mechanism |
|---|---|---|
| Process discipline | Tests drive production code | Three Laws of TDD (enforced by `al-tdd` phase gating) |
| Coverage direction | Right scenarios in right order | ZOMBIES ordering (applied in `al-tdd-refine`) |
| Behavioural proof | Assertions actually catch bugs | Mutation testing (`al-mutation-testing` — the conference addition) |

Execution Markers (`DEBUG-*` FeatureTelemetry logged to `.output/TestResults/telemetry.jsonl`) are **not a layer of TDD trust** in this bundle. A passing-but-wrong-path test still fires the expected branch marker, so marker verification does not prove the assertion catches bugs — mutation testing is the proper mechanism for that role. Markers are demoted to a **normal debug-logging pattern** (§4.3): inject when an agent needs to confirm which branch ran during a stuck test, when characterising legacy code, or when probing BC standard behaviour; sweep at cycle end. Not mandatory in Red/Green/Refactor.

### 2.4 AL Testability Axioms (from Vjeko's trilogy)

These are AL-specific applications of pillars 1–3 (Separation / Contracts / Testability) with direct operational consequences for the skills:

1. **BaseApp is YOUR dependency.** If a unit test needs to insert into `Currency Exchange Rate`, `Customer`, or any BaseApp table just to run, that's coupling failure — not a test requirement. `al-testability-reviewer` flags this.
2. **Don't test the database.** `Record.Get`, `Modify`, `Insert` are Microsoft-tested twice (SQL team + BC team). Tests assert business logic, not that `Modify()` writes.
3. **Three-phase decoupling refactor** (Vjeko's canonical sequence):
   1. Extract internal procedures: split mixed code into `Find*`, `Edit*` (pure business logic), `Modify*` (data write), and external-call wrappers.
   2. Define an interface containing only procedures you'd want to mock/test indirectly.
   3. Inject via an overload: new signature takes `Interface I…`; original signature calls the new one with `This` as default — preserves back-compat.
4. **Test Double taxonomy (London / xUnit — five kinds `al-test-double-generator` produces).** Both Vjeko's demo repo (`StubConverter.Codeunit.al`, `SpyConverter.Codeunit.al`, `MockPurchInvHeaderEdit.Codeunit.al`) and Finn Pedersen's Environment Interface Part 2 enumerate the London/xUnit roles — Dummy / Stub / Fake / Spy / Mock — with canonical definitions. The bundle adopts the same names.
   - **Dummy** — satisfies the interface contract, does nothing, no state. For parameters a test doesn't care about.
   - **Stub** — returns pre-configured fixed data. Setup-then-return pattern (`SetupResponse(...)` then `Send(...)` returns the configured value). Default double for Environment Interfaces (§2.4.9).
   - **Fake** — simplified but working implementation (e.g., an in-memory dictionary standing in for a table). For tests that need a real-behaving dependency without the real one's cost.
   - **Mock** — verifies how it was called. Pre-configured expectations; the test fails if the interaction pattern doesn't match.
   - **Spy** — records invocations for post-hoc assertion (`IsInvoked`, `InvocationCount`, `LastArguments`) — no pre-configured expectations.
5. **Coverage target: 100% of interesting code, 0% of infrastructure code.** Vjeko's 65% line-coverage ran 100% of business logic. `al-test-quality-auditor` (scope=suite) classifies uncovered branches into those two buckets.
6. **Speed budget.** Unit suite target <10s total; <100ms per test. Integration tests explicitly labelled as such and isolated from the fast-feedback loop. `al-tdd` surfaces a soft warning when the unit-suite wall-clock exceeds budget.
7. **Bundle opinion: prefer interfaces over handled events for decoupling.** The "Handled" event pattern works for extensibility but conflates decoupling with extensibility. Interfaces beat events for testability; events remain the right tool for extensibility across apps. Not a community axiom — bundle guidance.
8. **Unit test shape is Assemble-Act-Assert** (AAA) — record variables in memory, call business logic, assert field values. **Integration test shape is Given-When-Then** (BC test library + TestRunner). `al-test-authoring` distinguishes both.
9. **Environment Interface boundaries — three default decoupling seams** (from Finn Pedersen's series). When the 3-phase refactor in axiom #3 is about to declare an interface, the seam is almost always one of three categories — and each has a named, ready-made pattern:
   - **(a) System environment** — `IEnvironment` hides sandbox/production/company/evaluation detection and related ambient state (company name, licensee match, evaluation-company flag). Enables the `ApplicationState` enum (Test / Production / Disabled) pattern and the company-copy auto-disable safety.
   - **(b) External APIs** — `IApiRequest` (or per-integration `I<System>Api`) hides `HttpClient`, HMAC signing, header management, and response parsing. Stubs return canned response payloads covering success, error, and edge-case shapes — decoder logic gets full coverage without network calls.
   - **(c) Standard Application** — Pedersen Part 3 ships one worked example: `IFinance` with two procedures, and hedges explicitly ("you might say this is cheating") with no running tests. The bundle extrapolates the same `I<Thing>` naming and injection pattern to other BaseApp seams. Bundle-proposed (not Pedersen's): `IPosting`, `ISales`, etc. — hiding BaseApp calls like `.Validate()` / `.Insert(true)` on `Gen. Journal Line`, number-series allocation, posting-setup reads. Stubs store/return records in memory without DB writes — no G/L accounts, no bank accounts, no posting setup required to run a unit test.

   Naming convention (bundled in `al-naming-rules.md`): interface `I<Thing>`, production impl `"Prefix App <Thing>"` (shipped in the production app), stub impl `"Prefix Stub <Thing>"` (shipped in the **test app**, never in production). Stub implementations live under `test/src/Stubs/<Interface>/`. `al-testability-reviewer` recommends these by category name; `al-test-double-generator` defaults to `stub` kind when the target interface matches one of the three categories.

### 2.5 Package Self-Containment

The bundle must be installable by **any** BC/AL developer — not bound to this user's personal `~/.claude/CLAUDE.md` or memory. Packaging rules:

- **No runtime dependency on user-specific config.** Conventions discovered from the plan author's preferences during research are authored directly into the skills' SKILL.md bodies and bundled references — not loaded from the user's `CLAUDE.md` at runtime.
- **Decisions ship as skill defaults.** al-tdd commits opportunistically at Refactor-end when mutation is about to run and tree state permits; skill asks when the choice is non-obvious. No flags, no env vars. Nothing in the bundle emits or patches any `CLAUDE.md` file.
- **AL naming & BC vocabulary are shared references inside the bundle.** Two authored reference docs ship with `al-test-authoring` and are cross-referenced by every code-generating skill/agent:
  - `al-naming-rules.md` — objects (`"Prefix Feature Suffix"`, suffixes `Impl`/`Card`/`List`/`Ext`/`Test`), procedures (PascalCase verb-first; events `OnBefore…` / `OnAfter…`), tests (short PascalCase scenario — §8.1), variables (PascalCase; record vars match table name), fields (`"No."`, `"Posting Date"`, `Balance`), **environment interfaces (`I<Thing>` — e.g. `IEnvironment`, `IApiRequest`, `IFinance`), production impls (`"Prefix App <Thing>"` — shipped in the production app), stub impls (`"Prefix Stub <Thing>"` — shipped in the test app only, under `test/src/Stubs/<Interface>/`)**.
  - `al-bc-vocabulary.md` — use Insert / Modify / Delete (not Create / Update / Remove), Post (not Submit), Validate (not Check), Get/Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method).
- **Test comment style is a skill rule, not a user preference.** `al-test-authoring` mandates AAA (`// [ASSEMBLE]` / `// [ACT]` / `// [ASSERT]`) for unit tests and Gherkin (`// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]`) for integration tests. Every `[Test]` in the integration suite calls a local `Initialize()` as its first statement.
- **Environmental assumptions are declared per skill, not globally.** `al-tdd` invokes the existing `al-build` skill's PowerShell 7 script (`pwsh "<al-build>/scripts/test.ps1"`); if the user's `al-build` skill changes, the call point updates in one place.

### 2.6 Agent-Burdening Rules We Do **Not** Carry Forward

From slides 5–11: stop burdening agents with cosmetic rules (whitespace, indentation, one-exit-point, abbreviation taboo, line counts). Replace with **structural** rules (explicit contracts, testability). Skill bodies stay under 500 lines precisely because SKILL.md is prompt-carrying context.

---

## 3. Architecture Overview

### 3.1 Roles

- **Skills** are progressive-disclosure prompt templates. Their frontmatter description triggers them; their body and `references/` guide Claude through the *how*.
- **Agents** are invokable subagents — bounded, parallelizable units of work with a clean output contract. Used for: parallelizable research, context-isolating verification, noisy loops (mutation), and work the coordinator wants to hand off and trust.
- **State** is tracked via **Claude Code's native task tools** (`TaskCreate` / `TodoWrite`) — one task per phase of the 5-phase cycle, sub-tasks per scenario. Session-scoped by design: if the user interrupts mid-cycle, the plan doc (`.plans/YYYY-MM-DD-HHmm-tdd-<slug>.md`) records scenarios + ZOMBIES order, and the last `tdd: <scenario>` commit anchors what's been done. Re-entering `al-tdd` against the same plan doc rebuilds the task list from those two sources. **No MCP workflow dependency, no cross-session state file.** The earlier draft proposed `bc-knowledge workflow_*` — rejected after POC confirmed it doesn't support custom workflows.

### 3.2 Interaction flow

```
          User invokes /al-tdd-refine <issue-or-feature>
                          │
                          ▼
          ┌──────────────────────────────────────┐
          │  al-tdd-refine (skill)               │
          │  iterative plan-doc authoring        │
          │  draft → review → AskUserQuestion    │
          │   (triage/scope/verdict) → revise …  │
          └──────────────────────────────────────┘
                          │
             ┌────────────┴────────────┐
             ▼                         ▼
   al-test-scenario-        al-scenario-plan-
   planner (×N parallel)    reviewer (critique)
                          │
                          ▼
                 .plans/<ts>-tdd-<slug>.md
                 status: approved ✓
                          │
           User invokes /al-tdd <plan-path>
                          │
                          ▼
                ┌──────────────────────┐
                │   al-tdd (skill)     │   ← phase state via TaskCreate / TodoWrite
                │   phase orchestrator │
                └──────────────────────┘
                          │
       ┌──────────┬───────┼───────┬──────────┐
       ▼          ▼       ▼       ▼          ▼
  ┌────────┐ ┌───────┐ ┌─────┐ ┌───────┐ ┌────────┐
  │Scaffold│ │  Red  │ │Green│ │Refactr│ │ Mutate │
  └────────┘ └───────┘ └─────┘ └───────┘ └────────┘
       │         │        │        │         │
       ▼         ▼        ▼        ▼         ▼
  al-build  test-writer test-   debug-    al-mutation-
  (direct)  + al-build   writer  marker-   testing skill
            gate        + test-  ops       + al-mutation-
                        ability (hygiene- tester agent
                        reviewer sweep —
                        + al-    no-op
                        build    when no
                        gate     markers
                                 injected)
                                 + al-code-
                                 simplifier
                                 + al-test-
                                 quality-
                                 auditor
                                 + al-build
                                   gate
                          │
                          ▼
                 "Ready to push" gate —
               user invokes /commit-push-pr
```

Parallel sub-agent teams (validated user pattern) are used in Refine and Legacy-Characterization modes.

### 3.3 Skill-vs-Agent Decision Heuristic

| It's a **skill** when… | It's an **agent** when… |
|---|---|
| Output is "Claude does X differently for the rest of this turn" | Output is a concrete artifact or report the coordinator reads |
| The guidance is stable prose (template, procedure, references) | The work is parallelizable or context-hungry |
| It can be invoked via slash command and stand alone | It's invoked mid-task by another skill/agent |
| Multiple future tasks will need the same knowledge | Each run has a distinct input + structured output |

### 3.4 Important clarification — how skills hand off to other skills

Claude Code skills are prompt overlays, not callable functions: there is no deterministic `SkillA() → SkillB()` invocation. But a SKILL.md *can* instruct Claude to invoke another skill, and that handoff is reliable when the instruction is explicit and the target is pre-approved. `al-tdd` uses three handoff mechanisms, in this order of preference:

1. **Explicit sub-skill invocation** — the SKILL.md body issues an imperative ("now invoke `/al-execution-markers`" or "use the `al-test-authoring` skill"), and Claude executes it via the `Skill` tool or `SlashCommand`. To make this deterministic, `al-tdd`'s frontmatter pre-approves the sub-skills it hands off to via `allowed-tools` (e.g. `Skill(al-tdd-refine) Skill(al-execution-markers) Skill(al-test-authoring) Skill(al-simplify) Skill(al-mutation-testing) SlashCommand`). This is the right move when the user should *stay in the current turn* and Claude should swap prompt overlays.
2. **`Agent` tool delegation** — for parallelizable, context-hungry, or report-producing work, `al-tdd` spawns one of the 7 agents in its `Agent(…)` allowlist (see §5.0). The agent runs in its own context window and returns a structured artifact. This is the right move when the work would otherwise pollute the coordinator's context (e.g. mutation runs, scenario expansion, test triage).
3. **"See also" prose** — for genuinely optional handoffs the user might want (e.g. a pointer to a reference skill or doc), the SKILL.md mentions the sibling skill as inert prose and lets Claude decide. This is the *weakest* form and is reserved for non-load-bearing pointers — it must not be relied on for workflow steps.

The trap to avoid is **(3) where (1) is needed**: writing "see also `/al-execution-markers`" when the workflow actually requires Claude to invoke it. Treat that as a bug — promote it to an explicit imperative in the body and add the `Skill(...)` pre-approval to frontmatter. Every skill's SKILL.md spells out which mechanism it uses for each handoff so the orchestration is auditable.

### 3.5 Skill & agent design conventions for this bundle

These conventions standardize the 6 skills + 10 agents below so they compose cleanly and stay portable for later plugin conversion. They derive from current Claude Code mechanics ([skills](https://code.claude.com/docs/en/skills.md), [sub-agents](https://code.claude.com/docs/en/sub-agents.md), [plugins](https://code.claude.com/docs/en/plugins.md)).

#### 3.5.1 Frontmatter standards

| Field | Orchestrator (`al-tdd`) | Sub-skills (`al-tdd-refine`, `al-execution-markers`, `al-test-authoring`, `al-simplify`, `al-mutation-testing`) |
|---|---|---|
| `name` | `al-tdd` | `al-tdd-refine`, etc. — `al-` prefix on every name so they namespace cleanly when packaged later as `/<plugin>:al-tdd-refine`. |
| `description` | One sentence with distinct keywords ("scaffold and run the TDD cycle for BC AL"). | One sentence, **orthogonal** to siblings — e.g. "refine AL test code for readability", "add DEBUG telemetry checkpoints", "author or expand test scenarios", "AL-aware tactical simplification of changed code", "run mutation testing to find weak tests". With 6 skills in the same domain, overlapping descriptions cause Claude to pick arbitrarily on auto-trigger. |
| `disable-model-invocation` | `true` — `/al-tdd` is user-invoked only; auto-triggering a multi-phase workflow is destructive. | `false` (default) — orchestrator must be able to invoke them via the `Skill` tool. If set `true`, sub-skills become unreachable from `al-tdd`. |
| `allowed-tools` | Pre-approve the sub-skills and tools handed off to. Verify exact syntax in current docs (parameterized form like `Skill(al-tdd-refine)` is the agent's recommendation; fallback is to allow `Skill` and `SlashCommand` unparameterized). Plus the `pwsh` invocations needed for `al-build`. | Approve only the tools that skill body uses. |
| `model` | Inherit from session unless there is a specific reason to lock. | Inherit. |

#### 3.5.2 The `context: fork` decision — **fork `al-tdd`, do not fork `al-tdd-refine`**

The bundle is split into two phases by design: an **interactive planning phase** (`/al-tdd-refine`) where the user iterates a plan doc with the planner + reviewer until `status: approved`, and a **headless execution phase** (`/al-tdd <plan>`) that runs the entire Scaffold/Red/Green/Refactor/Mutate cycle to a "Ready to push" decision point. The precondition gate in §4.1 enforces this: `/al-tdd` will not start without an approved plan doc. All interactive checkpoints happen *before* `/al-tdd` is invoked, not during.

That two-phase architecture maps onto `context: fork` cleanly:

- **`/al-tdd-refine` — do NOT fork.** It is multi-turn and user-interactive by design: planner proposes scenarios, reviewer pushes back, skill emits structured `AskUserQuestion` bundles (triage / scope / verdict) that drive the next revision, planner re-runs on the delta. Each turn's selections feed the next turn's decisions, so the main-session context must persist across turns. Forking would break the back-and-forth.
- **`/al-tdd` — DO fork (`context: fork`).** Once the plan is approved, the cycle runs headlessly through five phases. Forking keeps the main session's context window clean of build output, intermediate test diffs, mutation reports, and scaffolding noise — all of which are operationally necessary inside the cycle but useless to the user once the cycle completes. The forked subagent's tool calls (TaskCreate/TodoWrite progress, file edits, `al-build` runs, agent spawns) remain visible in the UI as they happen — they just do not accumulate in the parent's context. The forked subagent's final return message carries the "Ready to push" prompt; the user replies in the main session and drives the commit/push manually.

Sub-skills invoked from inside the forked `/al-tdd` (`al-execution-markers`, `al-test-authoring`, `al-simplify`, `al-mutation-testing`) run inline in the subagent's context — they do **not** need their own `context: fork` (a fork-within-a-fork compounds isolation without benefit). The specialist agents in §5 continue to be spawned via the `Agent` tool from inside the forked subagent and continue to provide their own per-task context isolation.

A direct implication for `/al-tdd`'s SKILL.md: write the body as a *task description for the forked subagent* (imperative, step-by-step phase runbook), not as user-facing prose. The user never reads the SKILL.md content during a run — the subagent does.

#### 3.5.3 Agent parallelism — invoke in a single message

The `Agent` tool runs in parallel only when multiple `Agent` calls are emitted in a single assistant message. Sequentially-issued `Agent` calls run serially. Where the plan calls for parallel work — scenario expansion across N test files, parallel mutation operator runs, side-by-side test authoring + plan review — `al-tdd`'s SKILL.md must explicitly say "spawn these agents in a single message". This is a built-in Claude Code mechanic; agent teams are heavier and not needed at this bundle's scale.

#### 3.5.4 Agent ↔ skill binding via preloading

A custom agent's definition can declare a `skills:` field to preload a skill into its context at startup. **Every agent in this bundle preloads exactly one skill** — see the §5.0 design matrix for the full pairing list. This removes one source of "agent forgot the convention" failures and means specialist agents always have the right naming, vocabulary, and template references in scope without an extra lookup turn.

#### 3.5.5 Plugin-portable paths

The bundle ships standalone in `~/.claude/skills/` and `~/.claude/agents/` first, plugin later. To make the conversion mechanical:

- **No absolute paths** in skill bodies, scripts, or templates. Use the documented portable env var for the bundled directory once packaged (verify exact name — likely `${CLAUDE_PLUGIN_ROOT}`) or relative paths from the SKILL.md location.
- **Consistent `al-` prefix** on every skill, agent, and slash-command name — survives the plugin namespace transition (`/<plugin>:al-tdd-refine`).
- **Bundle-root `README.md`** with installation + invocation docs from day one — needed for plugin distribution anyway.

#### 3.5.6 Hook & MCP interaction

- **Hooks fire in forked subagent contexts the same as the main session.** When a hook fires inside a subagent, the JSON input includes `agent_id` and `agent_type` fields so the hook can distinguish. A custom save-time AL formatter hook WILL run on files produced during a `/al-tdd` cycle. This is either an intentional enforcement gate (linters, formatters, commit prep) or, if undesirable, the user should disable the hook for TDD cycles.
- **MCP servers and the built-in `LSP` tool are inherited by sub-agents and forked contexts.** No extra wiring needed for `mcp__al-symbols-mcp`, `mcp__al-object-id-ninja`, `mcp__bc-knowledge`, `mcp__microsoft-docs`, `mcp__context7`, or the `LSP` tool from any sub-skill or agent in the bundle.
- **Current project vs. dependencies — the symbol-navigation split.** `LSP` (AL language server) sees **only the current project's source**. `mcp__al-symbols-mcp__*` sees **only dependency packages** (base app, system app, referenced `.app` files) and **does not see current-project source**. They are complementary, not redundant — agents that analyze current-project code must use `LSP`; agents that look up dependency types must use `al-symbols-mcp`; agents that do both carry both.

---

## 4. Skills Inventory (6)

Each section: **Purpose · Trigger · Responsibilities · Body outline · Bundled references · Invokes · Why not folded into another skill**.

### 4.1 `al-tdd` — Master Orchestrator

- **Purpose.** Drive the full 5-phase cycle for a single feature or bug. Hold phase state. Make the right sub-skill or agent the obvious next move at every step.
- **Trigger (description).** "Drive full Red-Green-Refactor-Mutate TDD on Business Central AL. Invoked as `/al-tdd <input>` where `<input>` is a scenario description, issue reference, or path to an approved `.plans/<ts>-tdd-<slug>.md`. Always required for new production code under `app/src/` or `test/src/`."
- **Responsibilities.**
  1. **Precondition gate.** Read the input argument. If the input is a scenario or already-clear spec, proceed to cycle. If the input is an issue reference or ambiguous description, invoke `al-tdd-refine` internally first. If the skill cannot determine which path is appropriate, use `AskUserQuestion` to ask the user whether to refine or proceed directly. No flag required.
  2. **Build task list via `TaskCreate` / `TodoWrite`.** Parent tasks: Scaffold, Red, Green, Refactor, Mutate. Under Red/Green/Refactor, create one sub-task per scenario from the plan doc (in ZOMBIES order). Update task status as phases progress. Tasks are session-scoped — if interrupted, re-running `/al-tdd` against the same plan doc reconstructs the list from the plan + the most recent `tdd: <scenario>` commit.
  3. Enforce Three Laws of TDD: no production code without a failing test; no more test than is enough to fail; no more production than is enough to pass.
  4. Make the correct next call at each phase transition (agent, sub-skill, or `al-build`).
  5. Default **`al-build` full-suite invocations to `-Force`** (ItemConfigurator short-circuit bug, documented in history — user otherwise sees false greens).
  6. Monitor **unit-suite speed budget** (<10s total, <100ms per test — Vjeko). Surface a soft warning (not a gate) when the unit suite exceeds budget, pointing the user at `al-testability-reviewer` on the slowest file.
  7. At end of Refactor, run the substep sequence in this exact order — the order matters because each step's input depends on the previous step's output:
     1. **`al-debug-marker-ops` (mode=hygiene-sweep)** — sweep any `DEBUG-*` debug logging that was injected opportunistically during the cycle. Runs unconditionally but is a no-op when no markers were used (the common case); when markers were used, it runs first so the simplifier sees clean production code.
     2. **`al-code-simplifier`** (always — no opt-out) — applies AL-aware tactical simplifications across both prod and test code. May rename test procedures when the name no longer matches the test's behaviour (intent-preservation pillar) and may collapse or restructure tests. ZOMBIES granularity is a dev-time framework, not a runtime invariant — collapsing two scenarios into one parametrised test is acceptable when target branches and assertions are equivalent. **Expected side effect:** the committed plan doc's scenario count may no longer match the suite's procedure count after a collapse — this is by design; the plan doc is a historical artifact, not a maintained mirror.
     3. **`al-test-quality-auditor` (scope=test)** — runs on the *final* test shape (after simplifier renames/collapses), so its findings reflect what's actually in the suite, not a stale pre-simplification view.
     4. **`al-build -Force`** on the full suite — validates the simplified code, including any renamed test procedures, against everything else.
     5. Then perform a local `git commit -m "tdd: <scenario>"` **only when the skill judges the next step (Mutate) will need a revert anchor AND the working tree state makes the commit non-destructive**. If the tree has unrelated uncommitted changes, skill uses `AskUserQuestion` to ask whether to stash, commit, or abort mutation. The `al-mutation-tester` agent runs in `isolation: worktree` which already provides revert safety — the commit is opportunistic, not mandatory. If a `/commit` or `/commit-push-pr` skill is installed, the user may invoke it manually afterwards; al-tdd does not call external commit skills.
  8. Never `git push`. After Mutate, surface a "Ready to push" prompt — user pushes explicitly via their own commit/push workflow. If Mutate surfaces gap scenarios that require another cycle, the next cycle's commit accumulates on top; the user decides when/how to squash before pushing.
- **Body outline.** Precondition gate. Task list construction from plan doc. Phase-by-phase runbook, one section per phase, each with: goal, exit criterion, allowed sub-skills/agents, common pitfalls. End with "Ready to push" checklist.
- **References.** `references/three-laws.md`, `references/phase-runbook.md`, `references/build-force-rationale.md`, `references/task-list-template.md`.
- **Invokes.** `/al-tdd-refine` (when input is an issue reference or ambiguous description, or on request for mid-cycle re-planning), `/al-execution-markers`, `/al-test-authoring`, `/al-simplify`, `/al-mutation-testing`; agents: `al-test-writer`, `al-testability-reviewer`, `al-test-quality-auditor`, `al-test-double-generator`, `al-debug-marker-ops`, `al-mutation-tester`, `al-code-simplifier`. Tools: `pwsh <al-build>/scripts/test.ps1`, `TaskCreate`, `TodoWrite`, `AskUserQuestion`.
- **Why standalone.** The whole point is phase state. Any other skill can offload to it when the user says "do this properly"; it can't be folded into one of them.

### 4.2 `al-tdd-refine` — Issue → Reviewed, Iterated Plan Doc

- **Purpose.** Translate a GitHub issue, user story, or bug report into a prioritised, ZOMBIES-ordered list of atomic test scenarios captured in a **committed plan document**, iterated with a reviewer agent and the user, **before** any code is written. This is a first-class phase with a durable artifact and an explicit approval gate — not a one-shot pre-TDD step. Replaces the missing `/refine-issue-for-automated-tests` referenced by the old `writing-al-tests` skill.
- **Trigger.** "Refine a BC AL issue/feature into a ZOMBIES-ordered, reviewed test scenario plan before implementation. Produces `.plans/<timestamp>-tdd-<slug>.md` iteratively via a reviewer agent and user feedback. Use for new features, non-trivial bug fixes, or when `/al-tdd` is about to start and no approved plan doc exists. Required entry point for any non-trivial TDD cycle."
- **Plan document contract.**
  - **Location:** `.plans/` — repo-relative, **committed alongside code**. Intentionally visible to teammates, reviewable in PR, searchable in `git log`. Not gitignored.
  - **Filename format:** `YYYY-MM-DD-HHmm-tdd-<slug>.md`. Timestamp = agent run time (local). Slug auto-derived by the agent from issue title (via `gh issue view`) or user-supplied feature name — lowercase, hyphen-separated, max 60 chars. Never prompts the user for a filename.
  - **Frontmatter:** `status: draft | under-review | approved`, `issue: <url-or-id-or-none>`, `created: <ISO-8601>`, `last-reviewed: <ISO-8601>`, `author: <gh-user>`.
  - **Body sections:** Feature summary · Scope & non-goals · ZOMBIES-ordered scenario list (each scenario: PascalCase test name, target codeunit, Given/When/Then bullets, ZOMBIES category tag) · Open questions · Review & decisions log (append-only audit trail: one `## Review (<ts>)` section per reviewer pass; one `## Decisions (<ts>)` section per user-turn capturing the `AskUserQuestion` prompts posed and the selections made — never overwritten; history is part of the artifact).
- **Responsibilities.**
  1. Read the issue (via `gh issue view`) and related code context (current project via `LSP` + `Read`/`Grep`; dependency packages via `al-symbols-mcp`; BC domain via `bc-knowledge`).
  2. Generate the plan doc filename (timestamped, slugified) under `.plans/`. Create the file with `status: draft`.
  2.5. **On-demand pre-draft clarification.** If the issue text leaves scope or intent genuinely unresolved (ambiguous object name, unclear inclusion/exclusion of a code path, missing acceptance criterion), emit 1–4 `AskUserQuestion`s before dispatching planners. Skip on clear issues — no mandatory pre-draft bundle. Answers are appended to the plan doc's Decisions log before step 3.
  3. Dispatch parallel `al-test-scenario-planner` agents — one per sub-area / phase of the feature — the validated user pattern. Merge their outputs into the scenario list (ZOMBIES-ordered: **Z**ero, **O**ne, **M**any, **B**oundary, **I**nterface, **E**xceptional, **S**imple-scenarios).
  4. Invoke `al-scenario-plan-reviewer` agent to critique the draft. Reviewer appends a `## Review (<timestamp>)` section to the plan doc with findings tagged blocker / should-fix / nice-to-have plus an overall verdict (`approve-recommended` / `revisions-required`). Flip `status: under-review`.
  5. **Structured-question iteration turn.** After each reviewer pass, emit 1–4 `AskUserQuestion`s covering the open decisions:
     - **Reviewer-findings triage** (`multiSelect: true`) — options are the findings themselves, tagged blocker / should-fix / nice-to-have. User picks which to address in the next revision.
     - **Scope / approach choices** (single-select) — use `preview` content for naming style, `TransactionModel`, scenario-shape snippets where a concrete side-by-side comparison helps the decision.
     - **Verdict.** Options are **gated on latest reviewer verdict**: if `approve-recommended`, options are [Approve / One-more-pass / Revise-scope]; otherwise [Request-new-review / Revise-scope / Cancel]. Prevents approving over unresolved blockers.

     When more than 4 decisions are open, **chain a second `AskUserQuestion` call in the same turn** (the user-confirmed overflow strategy). `Other` is the free-form escape hatch on every option. Direct `.md` edits by the user remain supported as an out-of-band channel — skill re-reads the doc on the next turn; no structured-question round is forced when the user has just edited the file. Apply the selections (re-run scenario-planner(s) on the delta, drop/add scenarios, adjust scope) then re-invoke the reviewer if any substantive change landed. Append a `## Decisions (<timestamp>)` block to the plan doc capturing questions posed + user selections — **never overwritten**; the decision trail ships with the committed plan doc alongside the review log.
  6. Loop draft → review → structured-question turn → revise until the user selects the `Approve` verdict (only available when the latest reviewer pass returned `approve-recommended`). On approval: set `status: approved`, update `last-reviewed`, commit the plan doc (`docs: tdd plan for <slug>`) so it's durable before implementation begins. The commit captures the full decision trail — review sections **and** decisions sections — not just the final scenarios.
  7. Hand off: user invokes `/al-tdd <plan-path>`. `al-tdd` refuses to start unless frontmatter `status: approved`.
- **Body outline.** Plan-doc filename and frontmatter spec. What ZOMBIES means for AL (concrete examples: Zero = empty record, One = single ledger entry, Many = full batch posting, Boundary = period cutoff, Interface = implementer substitution, Exceptional = error paths). Structured-question iteration protocol: draft → reviewer → 1–4 `AskUserQuestion`s per turn (triage / scope / verdict) → revise, chain a second call when >4 decisions, on-demand pre-draft clarification only. Reviewer-gated verdict (`Approve` available only after `approve-recommended`). Append-only review + decisions log. Commit. Handoff to `al-tdd`. Legacy-mode fork (→ `al-legacy-characterization-planner`).
- **References.** `references/zombies-for-al.md`, `references/plan-doc-template.md` (new — the full frontmatter + section skeleton, including `## Review` + `## Decisions` block formats), `references/scenario-template.md`, `references/gherkin-style.md`, `references/iteration-protocol.md` (new — structured-question templates for reviewer-findings triage / scope & approach / verdict, reviewer-gated verdict option table, chain-on-overflow rule, Decisions-log entry format capturing questions and user selections, rules for re-running planners on deltas).
- **Invokes.** Agents: `al-test-scenario-planner` (parallelisable), `al-scenario-plan-reviewer` (after every substantive edit), `al-legacy-characterization-planner` (existing-code mode). Tools: `AskUserQuestion` (structured-iteration spine — 1–4 per turn, chained on overflow, with `preview` content where concrete comparison helps), `gh`, `bc-knowledge find_bc_knowledge`, `LSP` (current-project symbols), `mcp__al-symbols-mcp__al_search_objects` (dependency symbols), direct file ops in `.plans/`, `git add` + `git commit` (plan doc only, at approval).
- **Why standalone.** Refinement has its own artifact (committed plan doc), its own review loop, its own approval gate, and its own human-in-the-loop iteration pattern — a first-class phase, not a subroutine of `al-tdd`. The committed plan also doubles as PR context and team review input, surviving well beyond the TDD cycle itself.

### 4.3 `al-execution-markers` — DEBUG-* Debug Logging Pattern + Preflight

- **Purpose.** How to inject, verify, and remove `DEBUG-*` FeatureTelemetry.LogUsage debug logging that gets written to `.output/TestResults/telemetry.jsonl`. **Not a mandatory TDD primitive** — a debug-logging pattern used opportunistically when an agent needs to confirm which code path was reached during a specific run. Adds a **same-publisher preflight** to catch the silent-failure mode from history.
- **Trigger.** "Inject, verify, or remove `DEBUG-*` FeatureTelemetry debug logging to confirm which code path an AL test exercised. Use when a test is stuck and the agent needs to see which branch ran, when characterising legacy behaviour, or when probing BC standard code. Not required for routine TDD cycles. ALWAYS run the same-publisher preflight before injecting."
- **Responsibilities.**
  1. **Preflight:** compare `app/app.json` and `test/app.json` `publisher` fields; abort with a clear message if mismatched. (Silent failure root cause #1 in history — `FeatureTelemetry.LogUsage` only routes across same-publisher apps, so a mismatch silently drops every marker.)
  2. Explain the lifecycle: inject → run → verify in `.output/TestResults/telemetry.jsonl` → remove.
  3. Marker taxonomy: `DEBUG-TEST-START` (tag which test is running), `DEBUG-BRANCH-<name>` (tag which branch was hit), `DEBUG-BC-<subsystem>-<event>` (for BC event-subscriber probes).
  4. Point to `al-debug-marker-ops` agent (mode=verify-fired for post-run analysis, mode=hygiene-sweep for removal once markers have been used).
  5. For probing standard BC code where markers can't be injected directly, research event-subscriber probe patterns via `bc-standard-reference` / `mcp__bc-knowledge__*` / `mcp__al-symbols-mcp__*` on demand — no bundle-shipped skill for this.
- **Body outline.** Debug-logging framing (not a layer of TDD trust; mutation testing plays that role). When to reach for this (stuck tests, legacy characterisation, BC probing — not every cycle). Preflight. Inject. Verify. Cleanup. Pitfalls (same-publisher mismatch, forgotten cleanup, wrong event IDs, over-instrumentation).
- **References.** Carry forward from old skill: `telemetry-workflow.md` (updated with preflight section and opt-in framing). `transaction-model.md` and BC event-subscriber probe patterns are researchable via `bc-standard-reference` and `mcp__bc-knowledge__*` rather than shipped as bundle references. Template `TestTemplate.Codeunit.al` moves to `al-test-authoring`.
- **Invokes.** Agent: `al-debug-marker-ops` (mode=verify-fired for read-only telemetry analysis, mode=hygiene-sweep for stray-marker scan). Tools: `LSP` `documentSymbol` / `workspaceSymbol` (to find decision points in current-project AL source), direct file ops on `app/app.json`, `test/app.json`, `.output/TestResults/telemetry.jsonl`.
- **Why standalone.** The debug-logging pattern is useful across several workflows — stuck TDD tests, legacy characterisation, ad-hoc BC debugging. Keeping it a reusable skill lets each workflow pick it up when needed without `al-tdd` having to mandate it.

### 4.4 `al-test-authoring` — Test Codeunit Structure Rules

- **Purpose.** The "how to shape a test codeunit" reference: template, naming, `Initialize()`, `TransactionModel` decisions, Gherkin/AAA comment style, assertion library choice (`Library Assert`, never `Error()` / `Message()`), object ID allocation, **unit-vs-integration classification and speed budget.**
- **Trigger.** "Write or modify BC AL test codeunits with the correct structure, naming, Initialize() pattern, transaction model, and test-shape comments. Use whenever `test/src/` is being touched."
- **Responsibilities.**
  1. **Classify the test up front: unit or integration.** Unit = no DB, no BaseApp fixtures, asserts business logic against in-memory record variables + injected doubles. Integration = uses TestRunner, BaseApp libraries, actual posting. Reject "unit tests" that require BaseApp setup — route them back through `al-testability-reviewer`.
  2. Enforce the skill's authored test-naming rule — **short PascalCase scenario names** (`PostSalesOrderWithItemCharge`) rather than `GivenX_WhenY_ThenZ`. Rule shipped in `al-naming-rules.md`; aligns with Microsoft BaseApp conventions. See §8.1 for the open decision locking this default.
  3. Comment style depends on kind: **Unit tests** use `// [ASSEMBLE]` / `// [ACT]` / `// [ASSERT]` (Vjeko's AAA shape). **Integration tests** use `// [FEATURE]` in `OnRun()` and `// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]` inside each `[Test]`. Every `[Test]` calls a local `Initialize()` as its first statement (integration only — unit tests usually don't need one).
  4. Default: no `[TransactionModel]`. Only add with explicit reason (see `transaction-model.md`).
  5. Library Assert only — never Error/Message for verification.
  6. Allocate object IDs via `mcp__al-object-id-ninja__ninja_assignObjectId` (reserve), unassign if the test codeunit isn't created.
  7. Folder conventions: `test/src/Unit/<Feature>/<Feature>Test.Codeunit.al` for unit tests, `test/src/Integration/<Feature>/…` for integration, `test/src/Stubs/<Interface>/Stub<Thing>.Codeunit.al` for environment-interface stubs (e.g. `test/src/Stubs/IFinance/StubFinance.Codeunit.al`) — never in production `app/src/`. Three root folders: two test suites (with separate speed budgets) plus a shared stubs area consumed by both.
  8. Speed budget signal: include a comment at top of each unit codeunit with target `< 100ms per test`. Flag if observed runtime exceeds budget.
- **Body outline.** Unit vs integration decision tree. Naming rules + rationale. Two template walkthroughs (unit + integration). Initialize() guard pattern. TransactionModel decision table. Speed budgets. Object ID allocation. Folder layout.
- **References.** `TestTemplate.Unit.Codeunit.al` + `TestTemplate.Integration.Codeunit.al` (two templates — PascalCase procedure names + AAA / Gherkin comments respectively), `unit-vs-integration-al.md` (Vjeko's framing distilled), **`al-naming-rules.md`**, **`al-bc-vocabulary.md`** (both shared across the whole bundle — §2.5), `library-assert-patterns.md`, **`environment-interfaces.md`** (Finn Pedersen's three seams — System / External API / Standard App — with `I<Thing>` / `"App <Thing>"` / `"Stub <Thing>"` naming, "stubs live in the test app only" rule, and the setup-then-return stub pattern; cross-linked from §2.4.9 and used by `al-testability-reviewer` + `al-test-double-generator`). Agents research non-default `TransactionModel` use, `[HandlerFunctions]` discipline, and event-subscriber wiring via `bc-standard-reference` + `mcp__bc-knowledge__*` when a test genuinely needs them.

**BC-technical patterns are not bundled.** `[HandlerFunctions]` usage, event-subscriber wiring, specific TransactionModel quirks, posting-engine internals — these are researchable via `bc-standard-reference`, `mcp__bc-knowledge__*`, `mcp__microsoft-docs__*`, and the AL language server. Agents reach for them when a test genuinely needs one, rather than the bundle reshipping Microsoft documentation.
- **Invokes.** Agent: `al-test-writer` (when a single procedure needs authoring). Tools: `mcp__al-object-id-ninja__*`, `LSP` (current-project navigation), `mcp__al-symbols-mcp__al_search_objects` (dependency lookups).
- **Why standalone.** These rules apply to any test, regardless of whether we're in TDD mode. A reviewer or ad-hoc test-addition session needs them without the phase machinery.

### 4.5 `al-simplify` — AL-Aware Tactical Simplification

- **Purpose.** Apply tactical, AL-aware code simplifications across production and test code: remove redundant guards, eliminate dead variables, enforce BC vocabulary, recognise and rename test procedures whose names no longer match their behaviour, collapse equivalent test scenarios into parametrised forms, and flag (not auto-fix) architectural issues that belong to `al-testability-reviewer`. Bundle-native counterpart to Claude Code's generic `/simplify` — built specifically because the bundle's correctness depends on AL/BC conventions that a generic simplifier doesn't know.
- **Trigger.** "Apply AL-aware tactical simplifications to changed Business Central AL code (production and test) — enforce BC vocabulary, remove redundant guards, rename misnamed test procedures, collapse equivalent scenarios. Use during TDD Refactor phase or as an ad-hoc cleanup pass before code review. Always invoked at end of `/al-tdd` Refactor; user-invokable as `/al-simplify [path]`."
- **Default invocation target (standalone use).** `/al-simplify` with no argument operates on the **current uncommitted diff** (matches `/simplify` semantics — keeps the focus on what just changed). `/al-simplify <path>` scopes to a file or directory. Whole-project scope is rare; if requested, the skill uses `AskUserQuestion` to confirm before running that wide. Inside `al-tdd`, the orchestrator always passes the cycle's changed paths.
- **Iteration mode.** **One-shot** — single pass, report what changed, stop. The TDD cycle itself provides natural iteration; converging loops eat tokens and obscure intent.
- **Responsibilities.**
  1. **Catch what generic `/simplify` won't:**
     - **BC vocabulary violations** — `CreateCustomer` → `InsertCustomer`, `UpdateBalance` → `ModifyBalance`, `FetchLedgerEntry` → `GetLedgerEntry`, `id` → `No.`, `MyMethod` → `MyProcedure`, etc., per `al-bc-vocabulary.md`.
     - **AL idioms** — `FILTERGROUP` manipulation that should be `SetCurrentKey`; `Variant` abuse where a typed parameter fits; inappropriate `Codeunit.Run` boundaries (transaction isolation matters); repeated `Record.Get` then field check that could be a field-level filter.
     - **Naming-rule violations** — object names without prefix, test object names without `Test` suffix, stub names without `Stub` prefix, record variable names that don't match the table name. Per `al-naming-rules.md`.
     - **Hidden ambient state** — Setup table reads inside a "pure" procedure; flag pillar-4 violation. If structural, route to `al-testability-reviewer`; do not attempt the architectural fix here.
     - **>100ms unit tests that hit the database** — flag for stub extraction (route to `al-testability-reviewer` and `al-test-double-generator`); do not attempt the extraction itself.
  2. **Test-code simplifications (in scope — no opt-out).**
     - **Rename test procedures whose names no longer match the test's behaviour.** Intent-preservation pillar (#6) — a wrong-named test rots forever. **Safety guard:** before renaming, run `LSP findReferences` on the procedure name AND `Grep` for the literal string in `[HandlerFunctions(...)]` attributes (which take procedure names as strings, not symbols — silent breakage if missed). If external references exist (CI scripts, docs), surface as a warning but proceed with the rename.
     - **Collapse equivalent scenarios.** When two `[Test]` procedures exercise the same target branch with equivalent assertions and differ only in input data, collapse into one parametrised test. ZOMBIES is a dev-time framework, not a runtime invariant — collapsing is acceptable when target branches and assertions are equivalent. Do NOT collapse tests that exercise different branches just because they share Setup.
     - **Helper extraction.** Be more conservative than generic `/simplify` — extracting test setup to a Library codeunit creates a new dependency, new object ID, AppSource concerns. Prefer in-codeunit local procedures over new shared codeunits.
  3. **Honour the framework-invariants no-touch list** (`al-framework-invariants.md`):
     - Never touch `[Test]`, `Subtype = Test`, `TestPermissions`, `[TransactionModel]` attributes.
     - Never touch `[HandlerFunctions]` references (if a procedure name they reference changes via test rename, propagate the rename here too — but never alter the attribute structure).
     - Never remove `Initialize()` calls in test procedures (load-bearing even when "unused").
     - Never replace `Library Assert` calls with anything else (mandated; see `al-test-authoring`).
     - Never auto-rename procedures with `[EventSubscriber]` callers without `LSP findReferences` confirming impact (silent breakage if missed).
  4. **Re-validation contract.** Always re-run `al-build -Force` on the affected scope after edits land — caught implicitly when invoked from `al-tdd` (the Refactor gate runs build after simplifier), explicit instruction in standalone mode (the SKILL.md body tells Claude to run the build after applying changes).
  5. **Report what changed.** Output a structured summary: files touched, simplifications applied (per-category count: BC vocabulary, AL idiom, naming, test rename, scenario collapse, etc.), warnings raised (external references found during rename, architectural issues routed to reviewer).
- **Body outline.** When to reach for this. Default invocation target. Pattern catalogue (referenced from `al-simplification-patterns.md`). Test-rename safety procedure (`LSP findReferences` + `Grep` for `[HandlerFunctions]` strings). Framework-invariants no-touch list. Re-validation contract. Standalone vs. inside-`al-tdd` invocation differences. Plan-doc drift expectation (collapsing tests will desync the historical plan-doc scenario count — by design).
- **References.**
  - `al-simplification-patterns.md` (NEW) — the pattern catalogue: BC vocabulary mappings, AL-idiom rewrites, naming-rule fixes, test-rename triggers, scenario-collapse criteria. Drawn from Vjeko's trilogy (BaseApp coupling, "don't test the database"), Finn Pedersen's series (env-interface category recognition), conference slide material (7 pillars actionable items), and validated user history.
  - `al-framework-invariants.md` (NEW) — explicit no-touch list with rationale per item: `[Test]`, `Subtype = Test`, `TestPermissions`, `[TransactionModel]`, `[HandlerFunctions]` strings, `Initialize()`, `Library Assert`, `[EventSubscriber]`-called procedures (rename-only with findReferences guard).
  - `al-naming-rules.md` (shared — ships with `al-test-authoring`, referenced here).
  - `al-bc-vocabulary.md` (shared — ships with `al-test-authoring`, referenced here).
- **Invokes.** Agent: `al-code-simplifier` (the doer — applies the edits in an isolated context). Tools: `LSP` `findReferences` (rename safety), `Grep` (`[HandlerFunctions]` string scan), `Read`, `Edit`, `Bash` (for `al-build` re-validation in standalone mode).
- **Why standalone.** Three reasons. (1) **Reusable outside TDD** — ad-hoc "tidy this file before code review" is a real workflow that doesn't warrant the full `/al-tdd` cycle. (2) **Distinct discipline from review** — `al-testability-reviewer` is architectural analysis (the *plan*); `al-simplify` is tactical action (the *edits*). Mixing review-only and edit-capable in one place muddies the contract. (3) **Reference docs warrant their own home** — the AL-idiom catalogue, BC-vocabulary mapping table, and framework-invariants no-touch list are non-trivial reference material that doesn't naturally belong inside `al-tdd` (orchestration) or `al-test-authoring` (test-shape rules).

### 4.6 `al-mutation-testing` — Mutate Phase Reference

- **Purpose.** The conference's fifth TDD phase (slide 33). Given a passing suite, inject targeted mutations into the code under test and confirm at least one test fails. If all mutations survive, the suite is coincidentally passing.
- **Trigger.** "Run mutation testing on AL production code once tests are green. Use at the end of Red-Green-Refactor to prove tests catch bugs. Always required before declaring a TDD cycle complete."
- **Responsibilities.**
  1. Mutation operator catalogue for AL: flip `if` condition (`=` ↔ `<>`), swap `+`/`-`, swap `>` / `<` / `>=` / `<=`, comment out one assignment, replace literal (`1` → `0`, `true` → `false`), early-return insertion, skip `Validate()`.
  2. Target selection heuristic: only mutate code paths the current cycle introduced (else mutation is prohibitively expensive on a 1,200-test suite).
  3. Hands the loop to `al-mutation-tester` agent — the noisy compile-run-revert cycle stays out of main context. **Revert mechanism is `git checkout -- <file>`** against the Refactor-end commit (see §4.1 responsibility 5) — deterministic, crash-safe, no in-memory state tracking.
  4. Precondition guard: abort if the working tree is dirty before the loop starts. A dirty tree means the Refactor commit was skipped and `git checkout` would clobber user edits.
  5. Report back: mutations applied, mutations caught, mutations survived (these are the specification holes).
- **Body outline.** Rationale (false-positive detection, coincidental passes). Operator catalogue. Target selection. Selection rubric (operator-to-code matching, risk prioritization, equivalence skip, reachability check, coverage-of-classes guarantee, stop conditions, pre-flight self-report). Loop spec. Result interpretation.
- **References.** `references/mutation-operators-al.md`, `references/mutation-selection-heuristics.md`, `references/survivor-interpretation.md`.
- **Selection rubric (authored into `references/mutation-selection-heuristics.md`).** Replaces a numeric budget — the agent decides what to mutate and when to stop using these rules:
  1. **Operator-to-code matching.** Build the (operator × site) candidate list from the diff first; that *is* the universe. Don't apply `+`/`-` swaps where there's no arithmetic, don't flip booleans where there are none.
  2. **Risk-weighted prioritization.** Mutate in order: (i) conditionals & comparators on changed lines, (ii) assignments to record fields / return values / error paths, (iii) `Validate()` skips and locking calls, (iv) defer constants where only sign/non-zero matters.
  3. **Equivalence skip.** Recognize semantically equivalent mutations (e.g., `x >= 1` ↔ `x > 0` for integers; flipping a `Validate()` with no test-observable effect) and skip with a note. Survivor-but-not-a-hole.
  4. **Reachability check.** Before mutating a line, confirm at least one test in the affected suite executes it (use `LSP` `findReferences` on the enclosing procedure or last test-run coverage). Unreachable lines → flag as "untested", don't waste a mutation.
  5. **Coverage-of-classes guarantee.** Every applicable operator class mutates at least one site on the diff before any class mutates a second site. Prevents "30 boolean flips, 0 comparator swaps."
  6. **Stop conditions (agent decides).** Stop when every behavioral line in the diff has been mutated by ≥1 landing operator AND new survivors are duplicates of prior survivors (same operator, equivalent context). Agent can extend if user requested "thorough."
  7. **Pre-flight self-report.** Before the loop, post a one-line plan: *"Diff: N changed lines, M behavioral. Planning ~K mutations across J operator classes. Skipping P lines as unreachable."* User can interrupt if absurd.
- **Invokes.** Agent: `al-mutation-tester`. Tools: `al-build` via `pwsh`, direct file edits.
- **Why standalone.** Mutation is a separate mental model from Red-Green-Refactor and requires dedicated reference material. Folding into `al-tdd` would bloat it.

---

## 5. Agents Inventory (10)

Each section: **Purpose · When invoked · Inputs · Outputs · Why not folded into another agent**, plus a YAML frontmatter block specifying model, effort, preloaded skill, and tool allowlist. The matrix in §5.0 is the at-a-glance overview; the per-agent frontmatter blocks are the canonical specifications.

### 5.0 Agent design matrix — model, tools, preloaded skills

**Tool grant philosophy.** The `tools:` field is a hard allowlist; omitting it inherits all tools from the parent. Every agent in this bundle declares an explicit list — over-granting is preferred (a missing tool fails the run; an unused tool costs nothing). **None** of the 10 specialist agents receive the `Agent` tool — only the `al-tdd` orchestrator skill spawns agents, preventing recursion.

**Model selection.** Opus 4.7 + `effort: xhigh` for heavy reasoning and deep critique; Sonnet 4.6 + `effort: high` for code generation and structured review; Haiku 4.5 + `effort: medium` for read-only parsing and deterministic file ops. **Distribution: 3 Opus / 6 Sonnet / 1 Haiku.** Opus picks (`al-test-scenario-planner`, `al-testability-reviewer`, `al-legacy-characterization-planner`) are reserved for genuinely opus-class reasoning — ZOMBIES decomposition, 7-pillar architectural review, and 2000+ line codeunit characterisation.

| # | Agent | Model | Effort | Preloaded skill | Code-writing | Notes |
|---|---|---|---|---|---|---|
| 5.1 | `al-test-scenario-planner` | opus | xhigh | `al-tdd-refine` | no | parallel-safe per sub-area |
| 5.2 | `al-test-writer` | sonnet | high | `al-test-authoring` | yes | core test emission |
| 5.3 | `al-testability-reviewer` | opus | xhigh | `al-test-authoring` | no | 7-pillar + Vjeko 3-phase review |
| 5.4 | `al-test-quality-auditor` | sonnet | high | `al-test-authoring` | no | scope=test (assertion completeness) \| scope=suite (interesting-branch coverage) |
| 5.5 | `al-test-double-generator` | sonnet | high | `al-test-authoring` | yes | Dummy/Stub/Fake/Mock/Spy (London taxonomy) + env-interface stubs |
| 5.6 | `al-debug-marker-ops` | haiku | medium | `al-execution-markers` | Edit (sweep) | mode=verify-fired (JSONL parse) \| mode=hygiene-sweep (DEBUG-* removal gate) |
| 5.7 | `al-mutation-tester` | sonnet | high | `al-mutation-testing` | yes (revert via git) | **`isolation: worktree`** |
| 5.8 | `al-legacy-characterization-planner` | opus | xhigh | `al-tdd-refine` | no | 2000+ line codeunit survey |
| 5.9 | `al-scenario-plan-reviewer` | sonnet | high | `al-tdd-refine` | append-only Edit | independent plan critique |
| 5.10 | `al-code-simplifier` | sonnet | high | `al-simplify` | yes (incl. test renames) | LSP findReferences + `[HandlerFunctions]` Grep guard before any rename |

**The `al-tdd` orchestrator skill (not an agent).** `al-tdd` is a skill that runs as a forked subagent (per §3.5.2). Its SKILL.md frontmatter declares which sub-skills and agents it may invoke:

```yaml
allowed-tools: Skill(al-tdd-refine), Skill(al-execution-markers), Skill(al-test-authoring), Skill(al-simplify), Skill(al-mutation-testing), Agent(al-test-writer, al-testability-reviewer, al-test-quality-auditor, al-test-double-generator, al-debug-marker-ops, al-mutation-tester, al-code-simplifier), Bash, Read, Edit, Grep, Glob, TaskCreate, TaskUpdate, TodoWrite
```

The `Agent(name1, name2, …)` parameterised form restricts which sub-agents `al-tdd` can spawn. `al-test-scenario-planner`, `al-legacy-characterization-planner`, and `al-scenario-plan-reviewer` are intentionally absent from this list — they are spawned by the `al-tdd-refine` sub-skill during the planning phase, not during the cycle execution.

**Open verification points.**

- **MCP tool syntax in `tools:`** — the `mcp__<server>__<tool>` literal pattern is the canonical Claude Code naming. Official sub-agents docs show only built-in tool names in examples; if MCP literals fail at runtime, the verified fallback is to omit `tools:` entirely (inherits all tools from parent). Acceptable for personal-scope; tighten before plugin packaging.
- **`effort` field values** — `low / medium / high / xhigh / max` per Claude Code's model-config docs. Verify the accepted set during scaffolding.
- **`isolation: worktree`** for `al-mutation-tester` — chosen because the destructive edit-run-revert loop should not depend on the anchor-commit assumption holding. Worktree auto-cleans if the agent makes no changes.
- **`gh` access** — implicit via `Bash`; only `al-test-scenario-planner` and the `al-tdd` orchestrator reach for it. No special restriction.

---

### 5.1 `al-test-scenario-planner`

- **Purpose.** Decompose a feature/issue into ZOMBIES-ordered scenarios. Parallelisable (multiple instances cover multiple sub-areas). Pairs with `al-scenario-plan-reviewer` (§5.9) — planner generates, reviewer critiques; they never share context.
- **When invoked.** By `al-tdd-refine` — on initial draft (parallel fan-out, one per sub-area) and on each user-driven revision where the delta is substantial enough to warrant re-planning (e.g., scope change, new sub-area).
- **Inputs.** Feature description or issue body; scope (sub-area / phase); existing code context paths; any prior plan-doc content for revision context (so the planner doesn't duplicate scenarios already present).
- **Outputs.** Markdown scenario block for insertion into the plan doc's scenario list section — each scenario with PascalCase test name, target codeunit, Given/When/Then bullets, ZOMBIES category tag, suggested implementation order. Does **not** write to the plan doc directly; `al-tdd-refine` merges.
- **Why standalone.** Parallelisable research with high context draw; the coordinator wants clean merged output, not the full survey noise.
- **Frontmatter.**
  ```yaml
  ---
  name: al-test-scenario-planner
  description: Decompose a feature or issue into ZOMBIES-ordered atomic test scenarios; parallel-safe per sub-area.
  model: opus
  effort: xhigh
  skills: al-tdd-refine
  tools: Read, Grep, Glob, Bash, LSP, mcp__al-symbols-mcp__al_packages, mcp__al-symbols-mcp__al_search_objects, mcp__al-symbols-mcp__al_get_object_summary, mcp__al-symbols-mcp__al_get_object_definition, mcp__al-symbols-mcp__al_search_object_members, mcp__al-symbols-mcp__al_find_references, mcp__bc-knowledge__find_bc_knowledge, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__get_bc_topic, mcp__bc-knowledge__list_specialists, mcp__bc-knowledge__list_prompts, mcp__bc-knowledge__workflow_list, mcp__bc-knowledge__workflow_start, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_search, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_fetch, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_code_sample_search
  ---
  ```

### 5.2 `al-test-writer`

- **Purpose.** Author **one** test procedure at a time. Given a scenario name, Given/When/Then spec, and target SUT, emit a compilable test procedure that fails for the right reason.
- **When invoked.** By `al-tdd` during Red phase; by `al-test-authoring` for ad-hoc test addition.
- **Inputs.** Scenario (name + Given/When/Then), target codeunit/function, allocated object ID (if new codeunit).
- **Outputs.** File edit to `test/src/...` with new `[Test]` procedure — `Initialize()` call (integration) or inline setup (unit), AAA or Gherkin comments per `al-test-authoring` rules, Library Assert usage. Reports compile result. No `DEBUG-*` marker by default — markers are opt-in per §4.3 and injected only when a specific scenario needs execution-path visibility.
- **Why standalone.** Contained, repeatable, easy to benchmark with evals. Matches conference speaker's `al-test-writer` agent.
- **Frontmatter.**
  ```yaml
  ---
  name: al-test-writer
  description: Author one AL test procedure at a time from a scenario spec; emit a compilable test that fails for the right reason.
  model: sonnet
  effort: high
  skills: al-test-authoring
  tools: Read, Write, Edit, Grep, Glob, Bash, LSP, mcp__al-symbols-mcp__al_packages, mcp__al-symbols-mcp__al_search_objects, mcp__al-symbols-mcp__al_get_object_summary, mcp__al-symbols-mcp__al_get_object_definition, mcp__al-symbols-mcp__al_search_object_members, mcp__al-symbols-mcp__al_find_references, mcp__al-object-id-ninja__ninja_assignObjectId, mcp__al-object-id-ninja__ninja_unassignObjectId, mcp__bc-knowledge__find_bc_knowledge, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__get_bc_topic, mcp__bc-knowledge__analyze_al_code, mcp__bc-knowledge__list_prompts, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_search, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_fetch, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_code_sample_search
  ---
  ```

### 5.3 `al-testability-reviewer`

- **Purpose.** Audit a chunk of production AL code against the 7 pillars and Vjeko's decoupling playbook. Outputs a concrete, actionable refactor plan — not abstract critique. Runs *before* Green phase on the code about to be implemented, or *during* Refactor for incremental improvement.
- **When invoked.** By `al-tdd` at Green-entry (early warning) and Refactor-entry (cleanup candidates); standalone when the user says "is this testable?".
- **Inputs.** File paths or procedure names to review.
- **Outputs.** Per-issue report keyed to **Vjeko's 3-phase refactor** plus pillar mapping:
  - **Phase-1 findings (Extract):** procedures that mix business logic with data access / external calls — with suggested splits (`Find*`, `Edit*`, `Modify*`, `Run*`).
  - **Phase-2 findings (Interface):** which extracted procedures deserve an interface contract; what the interface should contain (only mockable operations).
  - **Phase-3 findings (Inject):** overload pattern suggestions — new signature accepting `Interface I…`, original signature calling it with `This` as default to preserve back-compat.
  - **Environment-interface classification (Finn Pedersen's three categories — §2.4.9).** When a Phase-2 interface extraction matches one of the three default seams, name it explicitly so `al-test-double-generator` picks up the canonical naming and stub shape: (a) **System environment** (`IEnvironment` — sandbox/production/company/eval detection), (b) **External API** (`IApiRequest` or `I<System>Api` — HttpClient, outbound integrations), (c) **Standard Application** (`IFinance`, `IPosting`, `ISales` etc. — BaseApp calls: posting, number series, setup reads). Recommend `stub` kind (setup-then-return) as the default double type for all three; flag when the existing code assumes a BaseApp-tested code path as its own logic (the "don't test the database" axiom).
  - **BaseApp-coupling flags:** any test fixture need on `Currency Exchange Rate`, `Customer`, posting setup tables, etc. — signals decoupling is missing. Usually resolves to env-interface category (c).
  - **Severity:** blocker (code can't be unit-tested at all), should-fix (possible but awkward), nice-to-have (already unit-testable, small polish).
- **Why standalone.** The 7-pillar + 3-phase analysis is broader than assertion completeness or path coverage. Matches conference speaker's `al-code-quality-reviewer`.
- **Frontmatter.**
  ```yaml
  ---
  name: al-testability-reviewer
  description: Audit production AL code against the 7 testability pillars and Vjeko's 3-phase decoupling playbook; emit an actionable refactor plan keyed to Extract / Interface / Inject.
  model: opus
  effort: xhigh
  skills: al-test-authoring
  tools: Read, Grep, Glob, LSP, mcp__al-symbols-mcp__al_packages, mcp__al-symbols-mcp__al_search_objects, mcp__al-symbols-mcp__al_get_object_summary, mcp__al-symbols-mcp__al_get_object_definition, mcp__al-symbols-mcp__al_search_object_members, mcp__al-symbols-mcp__al_find_references, mcp__bc-knowledge__analyze_al_code, mcp__bc-knowledge__find_bc_knowledge, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__get_bc_topic, mcp__bc-knowledge__workflow_list, mcp__bc-knowledge__workflow_start, mcp__bc-knowledge__workflow_next, mcp__bc-knowledge__workflow_progress, mcp__bc-knowledge__workflow_status, mcp__bc-knowledge__workflow_complete, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_search, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_fetch, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_code_sample_search
  ---
  ```

### 5.4 `al-test-quality-auditor`

- **Purpose.** Combined single-pass analysis of target code emits scope-appropriate report. Two scopes:
  - **`scope=test` — per-test assertion completeness.** Given a target procedure and a test procedure, enumerate observable state mutations (fields written, counters incremented, errors thrown, ledger entries created) and flag mutations the test does not assert.
  - **`scope=suite` — per-suite interesting-branch coverage.** Given a target codeunit and a test suite, enumerate branches / decision points / error paths, **classify each as `interesting` (business logic) or `infrastructure` (data access, external calls, framework plumbing)** per Vjeko's 100%/0% coverage framing, and report uncovered interesting paths.
- **When invoked.** By `al-tdd` in Refactor (scope=test per scenario) and at Ready-to-commit gate (scope=suite); by `al-tdd-refine` for gap analysis (scope=suite); standalone by user.
- **Inputs.** `scope`; target procedure/codeunit/file; test procedure/suite location.
- **Outputs.**
  - scope=test: table of each observable mutation × asserted? Paste-ready `Library Assert` lines for missing assertions. Directly addresses the user's verbatim correction from memory-worthy history: *"we are creating characteristics tests, and we should test all characteristics, not assume anything"*.
  - scope=suite: coverage matrix of branch → `interesting` / `infrastructure` × covering test(s) or `UNCOVERED`. Gate: every `interesting` branch must be covered; `infrastructure` branches are explicitly allowed to be uncovered. Suggested next scenarios for uncovered interesting paths (feeds back into `al-tdd-refine`). Report also flags the overall line-coverage ratio as diagnostic, not target — a 65% ratio with 100% interesting coverage is healthier than 95% with half of that being trivial data-access plumbing.
- **Why merged, not two agents.** Assertion completeness WITHIN a test and branch coverage ACROSS tests are related but distinct outputs — both require analysing the same target code. A single agent loads the target once and emits the scope-appropriate report, rather than duplicating target-code analysis across two agents.
- **Frontmatter.**
  ```yaml
  ---
  name: al-test-quality-auditor
  description: Per-test assertion-completeness audit (scope=test) or per-suite interesting-branch coverage (scope=suite). Single-pass analysis of target code emits scope-appropriate report with paste-ready Library Assert lines for missing assertions and suggested scenarios for uncovered interesting paths.
  model: sonnet
  effort: high
  skills: al-test-authoring
  tools: Read, Grep, Glob, LSP, mcp__al-symbols-mcp__al_packages, mcp__al-symbols-mcp__al_search_objects, mcp__al-symbols-mcp__al_get_object_summary, mcp__al-symbols-mcp__al_get_object_definition, mcp__al-symbols-mcp__al_search_object_members, mcp__al-symbols-mcp__al_find_references, mcp__bc-knowledge__find_bc_knowledge, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__analyze_al_code
  ---
  ```

### 5.5 `al-test-double-generator`

- **Purpose.** Given a codeunit or interface being depended on, generate a Test Double in the test project. Supports the full London/xUnit taxonomy (§2.4.4), not just mocks — the rename from the conference speaker's `al-mock-generator` reflects that the agent produces five kinds, and that **Stub** (not Mock) is the default for Environment Interfaces:
  - **Dummy** — satisfies the interface contract, does nothing. For parameters a test doesn't care about.
  - **Stub** — returns pre-configured fixed data using the setup-then-return pattern (`SetupResponse(...)` then `Send(...)` returns the configured value). The default kind for Environment Interfaces (§2.4.9) — System / External API / Standard App.
  - **Fake** — simplified but working implementation (e.g., an in-memory dictionary standing in for a table).
  - **Mock** — verifies how it was called (pre-configured expectations, fails if the interaction pattern doesn't match).
  - **Spy** — records invocations for post-hoc assertion (`IsInvoked`, `InvocationCount`, `LastArguments`).
- **When invoked.** By `al-testability-reviewer` when it recommends interface extraction — defaults to `stub` kind when the reviewer classified the interface into an env-interface category (§2.4.9). By `al-tdd` in Green when a unit test needs a double. Standalone when the user asks.
- **Inputs.** Target codeunit/interface; kind (`dummy` / `stub` / `fake` / `mock` / `spy` / `hybrid`); intended test codeunit that will use it; optional env-interface category (`System` / `ExternalApi` / `StandardApp`) so naming + folder follow Finn Pedersen's convention.
- **Outputs.** New codeunit file:
  - **Env-interface stubs:** `test/src/Stubs/<Interface>/Stub<Thing>.Codeunit.al`; object name `"Prefix Stub <Thing>"`; `implements <Interface>`; setup-then-return helpers (`SetupResponse`, `SetupNext…`, `Reset`). Ships in the **test app only**, never in production.
  - **Generic doubles (dummy / fake / mock / spy):** `test/src/Doubles/<Interface>/`; `implements <Interface>`; state fields for configured returns (mock) or invocation log (spy); helper procedures: `SetReturnValue…`, `IsInvoked`, `InvocationCount`, `LastArguments`, `Reset`.
  - `Access = Internal` by default; object ID allocated via `ninja_assignObjectId`.
- **Why standalone.** Matches the conference speaker's `al-mock-generator` with a broader taxonomy. Small but distinct responsibility — conflating with `al-test-writer` would muddy its contract. Load-bearing for the bundle's decoupling story: Vjeko's testability discipline *and* Finn Pedersen's environment-interface discipline both depend on it — extracting an interface without a double generator is half a refactor.
- **Frontmatter.**
  ```yaml
  ---
  name: al-test-double-generator
  description: Generate Dummy/Stub/Fake/Mock/Spy test doubles (London/xUnit taxonomy) for an AL codeunit or interface, with object ID allocation, environment-interface naming (I<Thing>, App <Thing>, Stub <Thing>), and setup-then-return helpers for stubs.
  model: sonnet
  effort: high
  skills: al-test-authoring
  tools: Read, Write, Edit, Bash, Grep, Glob, LSP, mcp__al-symbols-mcp__al_packages, mcp__al-symbols-mcp__al_search_objects, mcp__al-symbols-mcp__al_get_object_summary, mcp__al-symbols-mcp__al_get_object_definition, mcp__al-symbols-mcp__al_search_object_members, mcp__al-symbols-mcp__al_find_references, mcp__al-object-id-ninja__ninja_assignObjectId, mcp__al-object-id-ninja__ninja_unassignObjectId, mcp__bc-knowledge__get_bc_topic, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__analyze_al_code, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_search, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_fetch, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_code_sample_search
  ---
  ```

### 5.6 `al-debug-marker-ops`

- **Purpose.** Combined Haiku-class mechanical operations on `DEBUG-*` debug-logging markers. Two modes:
  - **`mode=verify-fired`** — read `.output/TestResults/telemetry.jsonl` and cross-reference against expected `DEBUG-*` markers for a test scope; report marker × test → fired / missing / misfired matrix. Used opportunistically when markers have been injected during a cycle — typically to diagnose a stuck test or confirm which branch ran.
  - **`mode=hygiene-sweep`** — scan `app/src/` and `test/src/` for `DEBUG-*` FeatureTelemetry calls; report every occurrence; optionally perform removal. Runs in the Refactor substep as a safety net; no-op when no markers were injected during the cycle.
- **When invoked.** By `al-tdd` during Refactor (mode=hygiene-sweep, always — no-ops when no markers present); by `al-tdd` opportunistically (mode=verify-fired) when a test failure or passing-but-wrong-path suspicion warrants it; by the `al-execution-markers` skill on demand.
- **Inputs.**
  - mode=verify-fired: expected marker list (event IDs + test procedure names); path to telemetry.jsonl.
  - mode=hygiene-sweep: project root; optional allow-list (rare: intentional long-lived debug).
- **Outputs.**
  - mode=verify-fired: matrix of marker × test → fired/missing/misfired.
  - mode=hygiene-sweep: list of files/lines with `DEBUG-*`, count; removal patch preview. Reports stray markers and removes them when invoked to sweep-and-clean; not a hard gate.
- **Why merged, not two agents.** Both are read-only / mechanical and Haiku-class; they share the same `DEBUG-*` taxonomy and file layout knowledge; merging halves the agent count without compromising either role. Parallel-safe in either mode.
- **Why standalone from `al-execution-markers`.** The skill holds reference prose; the agent holds bounded mechanical operations. When markers are used, the agent is the reliable way to verify and sweep them without relying on humans or other agents noticing.
- **Frontmatter.**
  ```yaml
  ---
  name: al-debug-marker-ops
  description: Verify expected DEBUG-* markers fired in telemetry.jsonl (mode=verify-fired) or scan source for stray DEBUG-* FeatureTelemetry calls and sweep them (mode=hygiene-sweep). Haiku-class mechanical operations; parallel-safe.
  model: haiku
  effort: medium
  skills: al-execution-markers
  tools: Read, Grep, Glob, Edit, Bash
  ---
  ```

### 5.7 `al-mutation-tester`

- **Purpose.** Run the mutation loop: apply one mutation, run `al-build` on affected tests, record result, `git checkout -- <file>` to revert, repeat. Contained loop — the coordinator doesn't see build noise.
- **When invoked.** By `al-mutation-testing` skill during Mutate phase.
- **Inputs.** Target file(s), operator set (defaults to safe set), time/count budget, anchor commit SHA (defaults to `HEAD`).
- **Preconditions.** `git status` must be clean. If not, abort with a message pointing to the missing Refactor-end commit.
- **Outputs.** Mutation report: (operator, location) × (caught? surviving? build-broken?). Survivors are the specification holes — reported with suggested tests to close them. On exit, tree is guaranteed clean (final `git checkout .` and verify).
- **Why standalone.** The inner loop is destructive (edit-run-revert) and noisy. Delegating protects the main context. Because revert is `git checkout`, worktree isolation is optional — the anchor commit makes the main tree safe. **However, this plan mandates `isolation: worktree`** (see §5.0 open verification points): the destructive loop should not depend on the anchor-commit assumption holding, and the worktree auto-cleans if no changes survive.
- **Frontmatter.**
  ```yaml
  ---
  name: al-mutation-tester
  description: Apply one AL code mutation, run al-build, record result, revert via git checkout — repeat across an operator set within a budget. Reports surviving mutations as specification holes.
  model: sonnet
  effort: high
  isolation: worktree
  skills: al-mutation-testing
  tools: Read, Edit, Bash, Grep, Glob, LSP, mcp__al-symbols-mcp__al_find_references, mcp__al-symbols-mcp__al_get_object_summary, mcp__bc-knowledge__workflow_start, mcp__bc-knowledge__workflow_next, mcp__bc-knowledge__workflow_progress, mcp__bc-knowledge__workflow_batch, mcp__bc-knowledge__workflow_complete, mcp__bc-knowledge__workflow_status, mcp__bc-knowledge__analyze_al_code
  ---
  ```

### 5.8 `al-legacy-characterization-planner`

- **Purpose.** Address the validated user pattern for legacy codebases (JobManager 2,635-line codeunits, ItemConfigurator 1,182-test suites). Survey an existing codeunit, identify behavioural observables (output records, counters, error paths), propose a characterization test plan that captures current behaviour *as the specification for future refactors*.
- **When invoked.** By `al-tdd-refine` in legacy-characterization mode, or standalone when the user says "I'm taking on codeunit X."
- **Inputs.** Target codeunit/procedure, existing test coverage summary.
- **Outputs.** Phased characterization plan (Phase 1, 2, 3…), each with scenarios keyed to observable outputs; list of "sentinel 999" discovery candidates; shared-fixture suggestions; estimated effort per phase.
- **Why standalone.** Legacy characterization is a mode of TDD with different constraints (unknown truth vs. specified truth). Its planning heuristics differ from greenfield `al-test-scenario-planner`. User history shows this is a significant fraction of real work.
- **Frontmatter.**
  ```yaml
  ---
  name: al-legacy-characterization-planner
  description: Survey an existing 2000+ line codeunit and propose a phased characterization test plan capturing current behaviour as the spec for future refactors. Identifies sentinel-999 discovery candidates and shared-fixture suggestions.
  model: opus
  effort: xhigh
  skills: al-tdd-refine
  tools: Read, Grep, Glob, Bash, LSP, mcp__al-symbols-mcp__al_packages, mcp__al-symbols-mcp__al_search_objects, mcp__al-symbols-mcp__al_get_object_summary, mcp__al-symbols-mcp__al_get_object_definition, mcp__al-symbols-mcp__al_search_object_members, mcp__al-symbols-mcp__al_find_references, mcp__bc-knowledge__find_bc_knowledge, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__get_bc_topic, mcp__bc-knowledge__analyze_al_code, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_search, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_fetch, mcp__plugin_microsoft-docs_microsoft-learn__microsoft_code_sample_search
  ---
  ```

### 5.9 `al-scenario-plan-reviewer`

- **Purpose.** Independent critique of a scenario plan doc produced by `al-tdd-refine`. Grades ZOMBIES coverage, validates names against `al-naming-rules.md` and `al-bc-vocabulary.md`, spots missing edge cases, flags testability red flags (BaseApp coupling signals, untestable dependencies, implicit ambient state), surfaces decomposition issues (too-coarse scenarios that hide multiple assertions, too-fine scenarios that fragment a single behaviour), calls out scope creep beyond the issue. Logically pairs with §5.1 — planner drafts, reviewer grades; they never share context.
- **When invoked.** By `al-tdd-refine` after every planner draft and after every substantive user edit to the plan doc. On demand from the user (`/al-tdd-refine review <plan-path>`) for a fresh opinion mid-iteration.
- **Inputs.** Plan doc path (e.g. `.plans/2026-04-18-1423-tdd-issue-27-calcemployee-onlyipc.md`). The reviewer reads the full doc including prior review log so it can build on — or challenge — earlier reviews rather than duplicating them.
- **Outputs.** A new `## Review (YYYY-MM-DD HHmm)` section **appended** to the plan doc (never edits existing content — review history is part of the artifact). Inside: findings grouped by category (coverage gaps · naming · testability · decomposition · scope), each tagged severity — **blocker** (must fix before approval) / **should-fix** (address or justify) / **nice-to-have** (suggestion). Final line: overall verdict — `approve-recommended` or `revisions-required`.
- **Why standalone.** Independent voice — planner agents can't grade their own work. Keeping critique separate from generation matches the Plan-mode discipline of "propose vs. review" and gives the user a second perspective to anchor iteration on. Appending rather than overwriting keeps the plan doc's evolution auditable in the commit history.
- **Frontmatter.**
  ```yaml
  ---
  name: al-scenario-plan-reviewer
  description: Independent critique of a scenario plan doc — grade ZOMBIES coverage, validate names against al-naming-rules and al-bc-vocabulary, flag testability red flags and scope creep, append a Review section to the plan doc.
  model: sonnet
  effort: high
  skills: al-tdd-refine
  tools: Read, Edit, Grep, Glob, LSP, mcp__bc-knowledge__find_bc_knowledge, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__analyze_al_code, mcp__al-symbols-mcp__al_search_objects
  ---
  ```

### 5.10 `al-code-simplifier`

- **Purpose.** Apply the AL-aware tactical simplifications enumerated in `al-simplify`'s pattern catalogue: BC-vocabulary fixes, AL-idiom rewrites, naming-rule adjustments, redundant-guard removal, dead-variable elimination, test-procedure renames (intent-preservation), and equivalent-scenario collapses. Bounded edit-and-report doer; sibling of `al-debug-marker-ops` and `al-mutation-tester` in the "doer agent paired with a reference-bearing skill" pattern.
- **When invoked.** By `al-tdd` during Refactor phase (always — no opt-out), as substep 2 in the §4.1 step-7 sequence (between `al-debug-marker-ops` hygiene sweep and `al-test-quality-auditor`). By `/al-simplify` for ad-hoc cleanup (default-diff mode, explicit-path mode, or confirmed whole-project mode). Standalone when the user says "tidy this".
- **Inputs.** Target paths (file, directory, or diff scope); optional flag indicating the call is part of an `al-tdd` cycle (so the agent can skip the standalone-mode build re-validation, which `al-tdd`'s gate handles).
- **Outputs.** File edits in place; a structured per-run report listing: files touched, simplifications applied per category (BC vocabulary, AL idiom, naming, redundant-guard removal, test rename, scenario collapse), warnings raised (external references found during a rename — surface as a warning but proceed), architectural issues *not* fixed but routed to `al-testability-reviewer` for the next cycle (e.g., "this procedure mixes business logic with HttpClient calls — recommend env-interface extraction"). Exit-clean: re-runs `al-build` in standalone mode and aborts/reverts on failure; relies on `al-tdd`'s gate in cycle mode.
- **Rename-safety procedure (load-bearing).** Before renaming any procedure (test or production):
  1. `LSP findReferences` on the procedure name within the current project.
  2. `Grep` the project for the procedure name as a literal string — catches `[HandlerFunctions(...)]` attributes (which take procedure names as strings, invisible to symbol-aware tools) and any AL-side reflection.
  3. If references exist outside the immediate test codeunit being edited, log a warning in the report (file + line) but proceed with the rename, propagating to all found locations. The alternative — leaving wrong-named tests rotting — violates intent-preservation.
- **Why standalone.** Two reasons. (1) **Bounded destructive work** — file edits across multiple files in one run; running in an agent context gives clean reverts on failure and keeps edit noise out of the orchestrator's context. (2) **Distinct contract from `al-testability-reviewer`** — reviewer outputs a refactor *plan* without edits (architectural); simplifier outputs *edits* without architectural restructuring (tactical). Splitting them keeps the review/action contract clean.
- **Frontmatter.**
  ```yaml
  ---
  name: al-code-simplifier
  description: Apply AL-aware tactical simplifications to changed BC AL code (production and test) — BC vocabulary, AL idioms, naming rules, redundant guards, test-procedure renames with LSP findReferences + [HandlerFunctions] string-scan safety, and equivalent-scenario collapse. Honours the framework-invariants no-touch list.
  model: sonnet
  effort: high
  skills: al-simplify
  tools: Read, Edit, Grep, Glob, Bash, LSP, mcp__al-symbols-mcp__al_find_references, mcp__al-symbols-mcp__al_get_object_summary, mcp__al-symbols-mcp__al_search_object_members, mcp__bc-knowledge__analyze_al_code, mcp__bc-knowledge__find_bc_knowledge, mcp__bc-knowledge__ask_bc_expert, mcp__bc-knowledge__get_bc_topic
  ---
  ```

**Agent count: 10.** `al-legacy-characterization-planner` is kept separate from §5.1 because the framing — "capture current, unknown behaviour" vs. "specify new behaviour" — drives different decisions (sentinel 999 discovery, phase-breakdown for 2,600-line codeunits, fixture sharing across the characterization suite). `al-scenario-plan-reviewer` is kept separate from §5.1 because generation and critique must have independent context; merging them would defeat the purpose of the review loop. `al-code-simplifier` is kept separate from `al-testability-reviewer` (§5.3) because they are paired across a clean review/action split — reviewer produces an architectural plan (no edits), simplifier produces tactical edits (no architectural restructuring); merging them would muddy the contract and conflate "what should change" (architectural judgement) with "what just changed safely" (tactical mechanics).

---

## 6. End-to-End Workflow Walkthrough

Concrete trace for a typical day — "Implement issue #27 in JobManager: cover CalcEmployee OnlyIPC branch."

1. **User:** "`/al-tdd-refine 27`"
2. **`al-tdd-refine`** reads issue #27 via `gh issue view`. Issue is clear — skips the on-demand pre-draft clarification pass. Generates filename `.plans/2026-04-18-1423-tdd-issue-27-calcemployee-onlyipc.md` (timestamp = now, slug = issue title), writes draft with `status: draft`. Spawns three `al-test-scenario-planner` agents in parallel (one for OnlyIPC happy path, one for validation errors, one for boundary dates). Merges ZOMBIES-ordered scenario blocks into the plan doc. Invokes `al-scenario-plan-reviewer` — reviewer appends `## Review (2026-04-18 1427)` noting two `should-fix` items (missing OnlyIPC-with-zero-hours scenario, ambiguous PascalCase name on scenario 3) and verdict `revisions-required`. Skill flips `status: under-review`.
3. **`al-tdd-refine` emits a two-question `AskUserQuestion` bundle**: (1) `multiSelect` triage over the reviewer's two findings; (2) verdict — options [Request-new-review / Revise-scope / Cancel] (`Approve` not offered; reviewer verdict is `revisions-required`). **User** selects only the first finding (rejects the naming critique) and picks Revise-scope; under Other on the scope field types "add one permission-denied scenario." Skill appends `## Decisions (2026-04-18 1432)` to the plan doc capturing prompts + selections, re-runs the planner on the delta, appends the new scenario, re-invokes the reviewer — appends `## Review (2026-04-18 1439)` with verdict `approve-recommended`. Skill emits the next verdict question; `Approve` is now available. User picks Approve. Skill flips `status: approved`, sets `last-reviewed`, commits `docs: tdd plan for issue-27-calcemployee-onlyipc` (the commit captures both Review and Decisions sections as the full trail).
4. **User:** "`/al-tdd .plans/2026-04-18-1423-tdd-issue-27-calcemployee-onlyipc.md`"
5. **`al-tdd`** validates the plan doc has `status: approved`. Builds a task list via `TaskCreate` — parent tasks Scaffold/Red/Green/Refactor/Mutate; sub-tasks under Red/Green/Refactor one per scenario (ZOMBIES order). Phase=Scaffold. Runs `pwsh al-build/scripts/test.ps1 -Force` — green. Scaffolds empty test procedure + production stub via `al-test-writer` + object ID allocator. Build still green. Transitions to Red (`TodoWrite` marks Scaffold complete, first Red sub-task in_progress).
6. **Red.** `al-test-writer` writes the first scenario's `[Test]`. `al-build -TestCodeunit <id>` — fails on assertion (not compile). `TodoWrite` marks this sub-task complete. Transitions to Green.
7. **Green.** Before implementing, `al-tdd` spawns `al-testability-reviewer` on the target procedure. It flags one pillar-4 violation (hidden ambient state from Setup table). User decides to accept for now. `al-tdd` hands to `al-test-writer` or directly drafts the minimal implementation. `al-build -TestCodeunit <id>` — green. Transitions to Refactor. (Execution markers are available — a `DEBUG-BRANCH-*` could be injected here if the passing test left uncertainty about which branch actually ran — but this cycle is straightforward, so none are used. Mutation in step 9 validates that the assertion catches bugs.)
8. **Refactor.** Substep order matters — each step's input depends on the previous step's output. (a) `al-debug-marker-ops` (mode=hygiene-sweep) runs on the cycle's changed paths — reports zero stray markers (no markers were injected this cycle, so the sweep is a no-op). (b) `al-code-simplifier` runs on the cycle's changed paths: notices the test procedure was originally named `OnlyIpcWrongJobNoFails` (vague — "fails how?") and the assertion is on inserted-error-record count + an error-record field, so renames to `OnlyIpcWrongJobNoInsertsError` (intent-preservation; `LSP findReferences` + `Grep` for `[HandlerFunctions]` strings clear); also rewrites `CreateJobLine` → `InsertJobLine` in production code (BC vocabulary). (c) `al-test-quality-auditor` (scope=test) runs on the FINAL test shape (after rename) and finds the test asserts the error count but not the error message text. User adds the missing assertion. (d) Full suite via `al-build -Force` — green. (e) **`al-tdd` judges that Mutate is about to run and the tree permits, so it performs `git commit -m "tdd: OnlyIpcWrongJobNoInsertsError"` as a revert anchor — local commit, no push.** This is the mutation-tester's anchor (though `isolation: worktree` already provides revert safety, so the commit is opportunistic).
9. **Mutate.** `al-mutation-testing` hands off to `al-mutation-tester` (budget: 6 operators × target file). Each mutation: edit → `al-build` → `git checkout -- <file>`. 5 caught, 1 survived (a `>=` → `>` boundary). Survivor is the gap — `al-test-quality-auditor` (scope=suite) is invoked, identifies no test at the exact boundary date. User decides to re-refine: `/al-tdd-refine` re-enters on the same plan doc, runs a structured-question turn (triage of the auditor finding, scope question offering "add boundary-date scenario" vs Other, verdict), appends the new scenario and fresh `## Decisions` entry, re-invokes the reviewer, emits the final verdict question — user picks Approve. Back to `/al-tdd` — new cycle starts; its Refactor-end commit stacks on top of the first.
10. Once all mutations caught and `al-test-quality-auditor` (scope=suite) shows green: **Ready to push.** User squashes the TDD cycle commits if desired (`git rebase -i`) and pushes explicitly. The plan doc stays committed as PR context.
11. Throughout, the auto-memory system captures any fresh user corrections (e.g., "always assert the message text for error tests") into `~/.claude/memory/feedback_*.md`.

---

## 7. Dependencies & Integrations

### 7.1 Existing skills reused (unchanged)

| Skill | How used |
|---|---|
| `al-build` | The gate. Invoked at Scaffold, Red, Green, Refactor, Mutate. Default to `-Force` on full-suite runs. |
| `bc-standard-reference` | Find canonical BC behaviour for event subscribers, test patterns. Used by `al-tdd-refine` and by agents researching BC-specific patterns on demand (including event-subscriber probes for standard BC code). |

### 7.2 MCP tools (hot path)

| MCP tool | Used by | For |
|---|---|---|
| `LSP` (AL language server, built-in tool) | All symbol-navigation agents (`al-test-scenario-planner`, `al-test-writer`, `al-testability-reviewer`, `al-test-quality-auditor`, `al-test-double-generator`, `al-mutation-tester`, `al-legacy-characterization-planner`, `al-scenario-plan-reviewer`, `al-code-simplifier`) | Navigate the **current project's** AL source: `goToDefinition`, `findReferences`, `hover`, `documentSymbol`, `workspaceSymbol`, `goToImplementation`, call hierarchy. **The LSP tool does not expose compile diagnostics** — any compile check goes through `al-build`. |
| `mcp__al-symbols-mcp__*` | Same set of agents | Navigate **dependency packages only** (base app, system app, referenced `.app` symbols). **Does not see current-project source** — that is LSP's job. Complements `LSP`, not redundant. |
| `mcp__al-object-id-ninja__ninja_assignObjectId`, `unassignObjectId` | `al-test-authoring`, `al-test-writer`, `al-test-double-generator` | Reserve/release IDs safely |
| `TaskCreate`, `TodoWrite` (native Claude Code) | `al-tdd` | 5-phase state — one parent task per phase, sub-tasks per scenario. Session-scoped; reconstructed from plan doc + last `tdd:` commit on re-entry. |
| `mcp__bc-knowledge__ask_bc_expert`, `find_bc_knowledge`, `get_bc_topic`, `analyze_al_code` | `al-testability-reviewer`, `al-tdd-refine`, any agent researching BC-specific patterns | BC domain questions (transaction isolation, posting quirks, event-subscriber probes, etc.) |
| `mcp__plugin_microsoft-docs_microsoft-learn__*` | `al-tdd-refine`, `al-test-authoring`, any agent needing MS Learn depth | Official BC documentation; MS Learn lookups when BC Standard mirror isn't enough. |
| `mcp__context7__*` | Agents needing library docs for utility packages | Library docs for non-BC dependencies. |

### 7.3 Memory integration

- TDD-specific feedback lands in `~/.claude/memory/feedback_tdd.md` (one file), new project quirks in `~/.claude/memory/project_<proj>_tdd.md`.
- Specifically captured from history already: forbid auto-commit, require `-Force` for ItemConfigurator, "assert all details" rule.
- No new memory infrastructure needed — uses the existing auto-memory system.

---

## 8. Open Design Decisions (need user sign-off before authoring)

| # | Decision | Options | Recommendation |
|---|---|---|---|
| 1 | **Test naming convention (authored into `al-naming-rules.md`).** The skill must ship one default — this is not a user preference, it's the rule packaged with the bundle. Research surfaced divergence: Microsoft BaseApp convention is PascalCase scenario (`PostSalesOrderWithItemCharge`); much practitioner code uses `GivenX_WhenY_ThenZ` (e.g., `GivenOnlyIpcWrongJobNo_WhenCalcEmployee_ThenErrorRecordInserted`). | (a) PascalCase scenario (BaseApp style); (b) Given/When/Then; (c) Hybrid: short PascalCase procedure name + `[SCENARIO]` comment body | **Resolved: (a).** Matches Microsoft BaseApp and the "intent preservation" pillar (procedure name = intent, body comments = scenario steps). Given/When/Then gets the body (AAA for unit, Gherkin for integration per §4.4). |
| 2 | ~~**State backbone: `bc-knowledge workflow_*` vs. plain JSON.**~~ **RESOLVED.** POC confirmed `bc-knowledge` MCP workflow tools don't support custom workflows; cannot be used. Use Claude Code's native `TaskCreate` / `TodoWrite` instead — session-scoped, no MCP dependency, tasks reconstruct from the committed plan doc + last `tdd:` commit on re-entry. | — | — |
| 3 | **Personal `~/.claude/` layout.** Should each skill live at `~/.claude/skills/<name>/SKILL.md` directly (user-scope), or bundle them into a mini-plugin folder for future publishing? | (a) Flat user-scope; (b) Pre-structure as a plugin | **Resolved: (a).** Flat user-scope to start; migrate to plugin when ready to publish externally. Plugin-portable conventions in §3.5.5 make the later conversion mechanical. |
| 4 | **Force as default on `al-build` full-suite runs.** Should `al-tdd` always pass `-Force` on full-suite runs, or detect the short-circuit symptom and retry? | (a) Always `-Force`; (b) Detect + retry; (c) User-opt-in flag | **Resolved: (a).** Seconds of rebuild beat hours of false-green diagnosis, and history shows the symptom is frequent enough. |
| 5 | **Mutation selection (replaces "budget").** A fixed cap doesn't fit varying surface (4-line vs. 200-line cycles), and time caps are hardware-dependent. How does the Mutate phase decide what to mutate and when to stop? | (a) Fixed cap; (b) User-configurable cap; (c) Adaptive count; (d) Time-boxed; (e) Agent-evaluated selection driven by documented heuristics | **Resolved: (e).** No numeric budget. The agent prioritizes by risk, matches operators to code shape, skips equivalent/unreachable mutations, guarantees coverage across operator classes, and decides stop conditions per the rubric in `references/mutation-selection-heuristics.md` (see §4.6). Pre-flight self-report lets the user interrupt if the plan looks absurd. |
| 6 | **Disposition of `writing-al-tests`.** | — | **Resolved: out of scope.** The user will delete `writing-al-tests` manually, outside this plan. The new skill bundle assumes `writing-al-tests` is gone and does not need to coexist with it. No deprecation pointer, no migration window, no description-collision concerns. |
| 7 | **TDD commit message format.** `al-tdd`'s Refactor-end commit needs a recognisable, greppable prefix so users can find/squash them before push. | (a) `tdd: <scenario>`; (b) `test: <scenario>` (conventional-commits style); (c) `wip(tdd): <scenario>` (stresses local/temporary) | **Resolved: (a).** Short, distinct from `test:`/`feat:` which the user reserves for final intent. Easy `git log --grep="^tdd:"` for squashing. |

---

## 9. Delivery Scope

**Single-delivery bundle.** The full bundle ships as one unit — no staged rollout, no MVP, no deferred components. `writing-al-tests` is deleted by the user before authoring begins (§8.6); the new bundle replaces it outright and does not have to coexist with it at any point.

### 9.1 Skills shipped (6)

| Skill | Purpose (one-liner) |
|---|---|
| `al-tdd` (§4.1) | Master orchestrator for the 5-phase cycle; forks into a subagent on invocation. |
| `al-tdd-refine` (§4.2) | Iterative plan-doc authoring (`.plans/<ts>-tdd-<slug>.md`), draft → review → structured `AskUserQuestion` turn (triage / scope / reviewer-gated verdict) → revise until user selects Approve. |
| `al-execution-markers` (§4.3) | Opt-in `DEBUG-*` FeatureTelemetry debug-logging pattern for stuck tests, legacy characterisation, and BC probing; same-publisher preflight. Not a mandatory TDD primitive — mutation testing plays the "assertions catch bugs" role. |
| `al-test-authoring` (§4.4) | Test file / procedure scaffolding; ships the shared `al-naming-rules.md` and `al-bc-vocabulary.md` references used across the bundle. |
| `al-simplify` (§4.5) | AL-aware tactical simplification of changed prod + test code: BC vocabulary, AL idioms, naming rules, test-procedure renames (with `LSP findReferences` + `[HandlerFunctions]` Grep guard) and equivalent-scenario collapses. Honours the framework-invariants no-touch list. User-invokable as `/al-simplify [path]`. |
| `al-mutation-testing` (§4.6) | Drive the Mutate phase; decides operator selection and stop conditions via documented heuristics. |

### 9.2 Agents shipped (10)

| Agent | Paired skill (preloaded) |
|---|---|
| `al-test-scenario-planner` (§5.1) | `al-tdd-refine` |
| `al-test-writer` (§5.2) | `al-test-authoring` |
| `al-testability-reviewer` (§5.3) | `al-test-authoring` |
| `al-test-quality-auditor` (§5.4) | `al-test-authoring` |
| `al-test-double-generator` (§5.5) | `al-test-authoring` |
| `al-debug-marker-ops` (§5.6) | `al-execution-markers` |
| `al-mutation-tester` (§5.7) | `al-mutation-testing` |
| `al-legacy-characterization-planner` (§5.8) | `al-tdd-refine` |
| `al-scenario-plan-reviewer` (§5.9) | `al-tdd-refine` |
| `al-code-simplifier` (§5.10) | `al-simplify` |

### 9.3 Shared reference docs shipped with the bundle

- `al-naming-rules.md` (ships with `al-test-authoring`; referenced by all code-generating skills/agents — including `al-simplify`)
- `al-bc-vocabulary.md` (ditto)
- `al-simplification-patterns.md` (ships with `al-simplify`; the AL-aware pattern catalogue: BC-vocabulary mappings, AL-idiom rewrites, naming-rule fixes, test-rename triggers, scenario-collapse criteria)
- `al-framework-invariants.md` (ships with `al-simplify`; the explicit no-touch list — `[Test]`, `Subtype = Test`, `TestPermissions`, `[TransactionModel]`, `[HandlerFunctions]` strings, `Initialize()`, `Library Assert`, `[EventSubscriber]`-called procedures)
- Per-skill `references/` directories as enumerated in each §4.x section

### 9.4 Installation invariants

- **Zero user config edits required.** `al-tdd`'s commit policy is self-contained in its SKILL.md — commits opportunistically when mutation needs a revert anchor and the tree permits; asks via `AskUserQuestion` when the choice is non-obvious. No `CLAUDE.md` changes. No memory writes. No settings mutations. Installable as-is by any BC/AL developer.
- **`writing-al-tests` is gone before authoring begins** (per §8.6). The new bundle does not deprecate, migrate from, or coexist with it.
- **Pain points closed in a single delivery:**
  - forgotten DEBUG cleanup (when markers injected opportunistically) → `al-debug-marker-ops` (mode=hygiene-sweep) runs unconditionally in Refactor; no-ops when no markers were used
  - incomplete assertions → `al-test-quality-auditor` (scope=test)
  - silent-publisher failure → preflight in `al-execution-markers`
  - false greens on full suite → `-Force` default in `al-tdd`
  - specification gaps → Mutate phase via `al-mutation-testing` + `al-mutation-tester`
  - untestable production code → `al-testability-reviewer` + `al-test-double-generator` (Vjeko 3-phase refactor, Finn Pedersen environment-interface seams)
  - legacy 2,000+ line codeunits → `al-legacy-characterization-planner`
  - tactical AL-idiom drift / BC-vocabulary violations / wrong-named tests → `al-simplify` + `al-code-simplifier` (Refactor-phase always-on; user-invokable as `/al-simplify` for ad-hoc cleanup)
  - probing standard BC behaviour (pricing, posting, warehouse) → researchable on-demand via `bc-standard-reference` + `mcp__bc-knowledge__*` + `mcp__al-symbols-mcp__*`

---

## 10. Non-Goals (explicit scope discipline)

So we don't drift:

- **`al-build` is the exclusive path for compile, publish, and test-run operations.** No other tool — including any MCP server tool, `dotnet`, the `AL Language` extension CLI, or direct `alc.exe` invocation — may perform these operations in any skill or agent of this bundle. Invoke via `pwsh "<al-build>/scripts/test.ps1"`. Future contributors must not re-introduce an `al` MCP server or equivalent shortcut.
- **No** one-shot agent that writes a whole test codeunit. All authoring is test-by-test.
- **No** skill for CI/CD integration (separate concern; user uses AL-Go).
- **No** automatic commits or pushes (user preference).
- **No** AppSource publishing automation (out of scope).
- **No** change to `bc-standard-reference`, `release-notes`, `video-to-issue` — they compose with the new bundle as-is.
- **No BC-technical reference content shipped in the bundle.** Event-subscriber patterns, `[HandlerFunctions]` usage, TransactionModel internals, posting-engine behaviour, etc. are researchable via `bc-standard-reference`, `mcp__bc-knowledge__*`, `mcp__microsoft-docs__*`, and the AL language server. Agents reach for them when needed; the bundle does not reship Microsoft documentation.

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Mutation tester edits code while user is looking at it | Run in worktree isolation (`isolation: worktree` on the Agent call) |
| Skill bodies exceed 500-line guideline | Move detail to `references/*.md`, keep SKILL.md to orchestration + signposts |
| `al-test-authoring`'s PascalCase-test-name rule (§8.1) collides with Given/When/Then examples the user encounters in the wild | Have `al-test-authoring` references show both styles side-by-side with rationale |
| Full bundle feels heavier than `writing-al-tests` for one-off bug fixes | `al-tdd` judges whether refinement is needed from the input; trivial one-scenario inputs skip refinement without flags |
| User interrupts mid-TDD cycle and session ends; tasks are session-scoped | `al-tdd` reconstructs state on re-entry from the committed plan doc (scenarios + ZOMBIES order) + last `tdd: <scenario>` commit (what's been done) — both are durable outside the session |
| Plan doc iteration loop drags on without converging | Reviewer's `approve-recommended` verdict signals user it's OK to approve; skill can also proceed directly for trivial clear inputs without refinement |
| Conflicts with existing `/loop`-style autonomous sessions | `al-tdd` uses `TaskCreate` / `TodoWrite` — standard Claude Code primitives that `/loop` already understands |
| `al-code-simplifier` renames a procedure with `[EventSubscriber]` callers — silent breakage at runtime | Mandatory `LSP findReferences` + literal-string `Grep` for `[HandlerFunctions(...)]` attributes (which take procedure names as strings, invisible to symbol-aware tools) before any rename; documented in `al-framework-invariants.md`. External references logged as warnings but the rename proceeds — leaving wrong-named tests rotting violates intent-preservation. |
| `al-code-simplifier` collapses two ZOMBIES scenarios; plan-doc scenario count no longer matches the suite | By design — plan doc is a historical artifact, not a maintained mirror. Documented in §4.1 step 7 and §4.5 as expected behaviour so users don't treat it as a bug. |
| `al-code-simplifier`'s edits silently break tests and the failure isn't caught until much later | Always re-runs `al-build -Force` on the affected scope (caught implicitly in `al-tdd` Refactor-gate ordering; explicit instruction in standalone `/al-simplify` mode); aborts/reverts on failure. |

---

## 12. Approval Checklist

Before authoring begins, please confirm:

- [ ] Plan shape (6 skills + 10 agents, single-delivery bundle) is acceptable
- [ ] `al-tdd-refine`'s plan-doc flow (§4.2) — `.plans/<ts>-tdd-<slug>.md`, committed, iterative draft → review → structured `AskUserQuestion` turn (reviewer-findings triage as `multiSelect`, scope/approach with `preview`, reviewer-gated verdict; chain a second call when >4 decisions; pre-draft clarification only when genuinely ambiguous; append-only `## Review` + `## Decisions` audit log) → revise loop — is what you want (al-tdd invokes al-tdd-refine internally when input needs it; asks via `AskUserQuestion` when ambiguous)
- [x] ~~§8.1 test-naming~~ — resolved: (a) PascalCase scenario (BaseApp style)
- [x] ~~§8.2 state backbone~~ — resolved: `TaskCreate` / `TodoWrite`, no MCP workflow
- [x] ~~§8.3 layout~~ — resolved: (a) flat user-scope; migrate to plugin when ready to publish externally
- [x] ~~§8.4 `-Force` default~~ — resolved: (a) always `-Force` on full-suite runs
- [x] ~~§8.5 mutation selection~~ — resolved: (e) agent-evaluated heuristics, no numeric budget
- [x] ~~§8.6 `writing-al-tests` disposition~~ — resolved: out of scope, user deletes manually
- [x] ~~§8.7 TDD commit prefix~~ — resolved: (a) `tdd: <scenario>`
- [ ] Full bundle scope (all 6 skills + 10 agents in §9, no user config changes required) is what you want shipped
- [ ] Non-goals in §10 are correct

Anything you want added, removed, or re-scoped — mark it up directly in this file and we'll iterate.
