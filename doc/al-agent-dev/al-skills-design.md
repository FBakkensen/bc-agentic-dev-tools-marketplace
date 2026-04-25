# Agentic AL Development — Skills Design

**Status:** Design — high-level specification for the skill set described below.
**Supersedes:** [`al-tdd-plan.md`](./al-tdd-plan.md)
**Target:** Claude Code on Windows, BC AL projects.

## Goal

A small set of composable Claude Code skills for AL/Business Central development. Replaces a workflow that grew too complex (6 skills + 10 agents, multi-layer gates, append-only audit trails) with **6 top-level skills**, each doing one thing, sharing a single living document (`tasks.md`), calling each other when needed.

## Cross-cutting principles

- **KISS / YAGNI.** Add nothing the next task doesn't need.
- **Standard dev terms, no over-explanation.** Gherkin, ZOMBIES, test doubles, Read → Process → Write, red-green-refactor, mutation testing — name them, do not explain. Models know these terms.
- **Explicit over implicit.** Every skill states its principles in its own SKILL.md. Do not rely on `CLAUDE.md` — it may be missing or different in another repo.
- **BC vocabulary in names** — apply everywhere (code, tests, `tasks.md`):
  - Insert / Modify / Delete (records — not Create / Update / Remove)
  - Post (not Submit) — Validate (not Check) — Get / Find (not Fetch)
  - Ledger Entry (not Transaction) — No. (not ID) — Procedure (not Method)
  - Object naming: `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`
  - Procedures: PascalCase, verb-first. Events: `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`
- **Codebase-first, then research.** Workspace exploration is always step one. `/al-research` handles what the workspace doesn't answer.
- **Prior AL/BC knowledge is untrusted until corroborated.** AL/BC training data is thin and stale.
- **Research mandatory for non-trivial tasks.**
- **Mutation testing mandatory for non-trivial tasks.** The agent flow's safety rail is the test suite. Mutation testing proves the rail isn't decorative.
- **Trivial =** renaming, comments, formatting, obvious one-liners. Anything touching BC standard surfaces, posting, events, dimensions, ledger entries, posting setup, transaction isolation, permissions, or AppSource compliance is **non-trivial**.

## Living document: `tasks.md`

One file at the repo root: `./tasks.md`. No `.plans/` folder, no per-feature plan documents, no archive.

### Format

````markdown
# tasks.md

## Goal
One paragraph: what we're building, why. Updated as understanding evolves.

## Tasks

### [ ] T-001 — Post sales order with blocked customer is rejected
A blocked customer must not allow posting; the posting routine needs a guard.

**Tests**
- Given Customer.Blocked = All, When posting, Then a clear error is raised
- Given Customer.Blocked = Invoice, When posting, Then shipment is allowed, invoice is blocked
- Given Customer.Blocked = " ", When posting, Then proceeds normally

**Notes**
- Existing OnBeforePostSalesDoc subscriber already checks Blocked for ship-to — reuse pattern

### [~] T-002 — Post sales order updates customer ledger entry
…

### [x] T-000 — Scaffold sales-posting test codeunit
````

### Conventions

- **Status:** `[ ]` ready, `[~]` in progress, `[x]` done.
- **Numbering:** `T-001`, `T-002`, … monotonic, **never reused**. On split: original is removed, new tasks get the next available numbers. Git history preserves the old content.
- **Tests in Gherkin bullets** — Given / When / Then, plain English. `/al-implement` transcribes each into an AL test procedure with `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` body comments.
- **Test naming in code:** short PascalCase, BC BaseApp style (e.g. `PostSalesOrderWithBlockedCustomer`) — not `GivenX_WhenY_ThenZ`.
- **Optional sections — include only when they carry information:** `**Mutations**`, `**Notes**`, `**Depends on:** T-003, T-005`.
- **Not present:** assignees, dates, estimates, effort, status states beyond ready / in-progress / done.

### Who writes what

| Skill | Allowed edits in `tasks.md` |
|---|---|
| `/al-steer` | Anything — but only after explicit user acknowledgement |
| `/al-refine` | Restructuring, splits, goal rewrites, new tasks |
| `/al-implement` | Mark task status, append discovered sub-tasks, append mutation results |

## Top-level skills

Six new skills. All user-invoked with `/`.

### `/al-steer` — Coach / navigator

Read `tasks.md`, the goal, the codebase, and recent commits. Tell the user what's next, what's blocked, what's drifting. Run `/grill-me` when intent is unclear. Recommend a handoff — but do not force one.

**Power model**
- Read anything in the workspace and `tasks.md`.
- Write anything in `tasks.md`, but only after explicit user acknowledgement. Never silent.
- Cannot edit code.
- Default scope: current task + current code. Going beyond requires explicit user instruction + acknowledgement.
- Pushes back or runs `/grill-me` when the user's request looks off-target.

**Identifies state**
- Ready tasks vs stalled `[~]` tasks across sessions.
- Goal drift — does the goal paragraph still describe what `tasks.md` is delivering?
- Notes lines flagging open questions, blockers, missing scenarios.
- Cross-task issues — broken `Depends-on`, redundancy, gaps.

**Recommends (the menu — pick what fits, never force)**
- Implementable task → `/al-implement <T-NNN>`
- Underspecified task → `/al-refine <T-NNN>`
- Code lacks coverage → `/al-mutate <area>`
- Code shape is wrong, tests green → `/al-refactor <area>`
- "How does X work in BC?" → `/al-research <topic>`
- User uncertain → `/grill-me` first
- Sometimes the answer is "you have clarity — go do the thing." No handoff.

**Composition:** `/grill-me`, `/al-research` (when answering BC questions inside a session).

**Out of scope:** code edits, mutation runs, `/al-build` invocations, silent `tasks.md` restructuring, forcing handoffs.

### `/al-refine` — Idea → `tasks.md`

Turn an idea, issue, or vague task into concrete tasks in `tasks.md`. Use `/grill-me` to extract requirements until each task is implementable. Output goes ONLY to `tasks.md` — no code edits.

**Decomposition**
- One task = one demonstrable behaviour. If it can't be stated in one imperative sentence, split it.
- Apply ZOMBIES order: Zero, One, Many, Boundaries, Interfaces, Exceptions, Simple scenarios. Start trivial, walk outward.
- Both positive AND negative cases for every behaviour. Boundaries when ranges, thresholds, or guards exist.
- Prefer tests against the pure Process layer (Read → Process → Write) over integration tests when the behaviour can be expressed in isolation.

**Tests in `tasks.md`**
- Each test is a Gherkin bullet: `Given <preconditions>, When <action>, Then <expected outcome>`. Plain English, plain Markdown, no AL code.
- The bullet is the contract. `/al-implement` transcribes it into an AL test procedure with `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` body comments.

**Grilling**
- `/grill-me` when intent is ambiguous, when the goal admits multiple solutions, or when domain rules aren't explicit.
- **Do not invent business rules.** If grilling can't resolve a question, leave a Notes line flagging it; the task is not ready.

**`tasks.md` hygiene**
- Numbering rules per the format above.
- On split: replace the original; update `Depends-on` cross-references in other tasks.
- Keep Goal aligned with the tasks; update Goal when it has drifted.
- Keep the file scannable — no empty section stubs, no boilerplate.

**Composition:** `/grill-me`, `/al-research`, `/bc-standard-reference`.

**Out of scope:** code edits, mutation lists (mutations are discovered during `/al-implement`), assignees, dates, estimates.

### `/al-implement` — Pick a task, run TDD

Pick the next ready task from `tasks.md`. Run TDD. Update `tasks.md`.

**Flow**

1. Pick task from `tasks.md`.
2. Codebase exploration; `/al-research` if non-trivial.
3. `/grill-me` to re-refine — may add tests, split the task, or kick to `/al-refine`.
4. **Red** — failing test that compiles. Add only the scaffold needed to compile; the test must fail on **behaviour**, not on missing types or syntax.
5. **Green** — smallest production change that turns the test green. No speculative code.
6. **`/al-refactor`** — improve shape; may add tests when uncovered branches surface.
7. **Mutation discovery** — list the mutations to verify; append to the task's `**Mutations**` section.
8. **`/al-mutate`** — mandatory if non-trivial.
9. Mark task `[x]`. Stop. One task, one session.

**Tests (when transcribing Gherkin bullets to AL)**
- Test naming: short PascalCase, BC BaseApp style (e.g. `PostSalesOrderWithBlockedCustomer`). Not `GivenX_WhenY_ThenZ`.
- Body comments: `// [FEATURE]` in `OnRun()`, `// [SCENARIO]` / `// [GIVEN]` / `// [WHEN]` / `// [THEN]` inside each test.
- Each test calls a local `Initialize()` as its first statement.
- Both positive AND negative cases. Boundaries when relevant.

**Naming and vocabulary** — apply the BC vocabulary list from Cross-cutting principles. Restate; do not rely on `CLAUDE.md`.

**When to stop early**
- Task is wrong or too large → leave a Notes line, recommend `/al-refine`. Do not silently expand.
- Discovered sub-task → append to `tasks.md` (new T-NNN), continue the original.

**Composition:** `/grill-me`, `/al-research`, `/al-build`, `/bc-standard-reference`, `/al-debug-logging` (only when tests can't reveal execution path), `/al-refactor`, `/al-mutate`.

### `/al-refactor` — Improve shape while green

Refactor production and test code while keeping tests green. Use `/al-build` between meaningful changes. Stop if a green test goes red.

**Architecture**
- **Testable by construction:** extract interfaces for external dependencies (DB I/O, time, HTTP, environment). Inject via overload pattern to preserve back-compat. Use interfaces as the standard tool for clean, testable design.
- **Read → Process → Write.** Read inputs first (DB, services, parameters), pass them as records-by-value or DTOs into a pure procedure, write outputs last. **The middle has no DB calls and no external calls** — unit-testable in isolation.
- Prefer standard BC patterns over clever abstractions. If a pattern needs explaining, it's probably wrong for AL.

**Naming and vocabulary** — apply the BC vocabulary list from Cross-cutting principles. Restate in the SKILL.md; do not rely on `CLAUDE.md`.

**Simplification (lives inside `/al-refactor`)**
- Remove dead code, redundant guards, unused variables, dead branches.
- Collapse equivalent test scenarios via shared setup or parameterised data — without losing the `[SCENARIO]` intent comment.
- Rename when the name lies. Prefer the BC term over a generic programming term.

**Discipline**
- Run `/al-build` after every meaningful change. Tests stay green throughout.
- Refactor production AND test code together — both are first-class.
- May add new tests when refactoring reveals uncovered branches.
- If a refactor reveals a hidden requirement or design flaw → stop, Notes line in `tasks.md`, recommend `/al-refine`. No silent scope expansion.

**Composition:** `/al-build`, `/bc-standard-reference`, `/al-research`, `/grill-me`.

**Out of scope:** new behaviour. Anything that changes what the system *does* belongs in `/al-implement` (new task) or `/al-refine` (re-plan).

### `/al-mutate` — Validate test rigor

Inject mutations into production code; verify at least one test fails per mutation. **Mandatory for non-trivial tasks.** Also runnable standalone on legacy code.

**Preflight (non-negotiable — abort if any fails)**
- Working tree clean.
- Baseline tests green via `/al-build`.
- Target is production code, not test code.
- Mutation discovery list exists (provided by `/al-implement`, or built fresh on standalone use by reading the target code).

**Mutation loop (one at a time)**
- Apply one mutation → `/al-build` with tests → classify → revert → verify revert restored baseline → record. Then next mutation.
- Classify:
  - **killed** — at least one test failed; record which.
  - **survived** — all tests pass; gap or equivalent — flag for decision.
  - **build failure** — code didn't compile; skip, not useful signal.

**Operator priority** (signal-per-minute, top-down)
- Comparison flips (`<` ↔ `<=`, `=` ↔ `<>`)
- Boolean flips (`true` ↔ `false`, `and` ↔ `or`)
- Condition negation (remove a `not`, swap if/else branches)
- Arithmetic swaps (`+` ↔ `-`, `*` ↔ `/`)
- Guard removal (delete an early `exit` / `Error`)

**BC-specific safety**
- Revert RDLC / generated files after every iteration — they regenerate noisily and pollute diffs.
- Docker recovery is `/al-build`'s responsibility (see `/al-build` below).
- If revert fails, abort and report. **Never leave the workspace half-mutated.**

**Survivors (the whole point)**
- Real gap → write a new test that catches it.
- Equivalent mutation → record a specific reason. "Looks equivalent" is not a reason.
- `/grill-me` when classification is unclear.

**Output**
- `.output/mutation-report/<YYYYMMDD-HHMMSS>.md` — summary, surviving mutants (actionable), killed mutants table.
- One-line mutation result appended to the calling task in `tasks.md` (e.g. `**Mutations:** 12 killed, 1 equivalent (reason: …), 0 survivors`).

**Composition:** `/al-build`, `/grill-me`.

**Out of scope:** code changes outside the mutation/revert cycle, `tasks.md` restructuring, preflight skipping.

### `/al-research` — Verify BC specifics

Research BC and AL specifics from authoritative sources before acting. Models are trained on limited, outdated AL/BC data — verify before trusting prior knowledge. **Mandatory for non-trivial tasks.**

**Precondition:** caller has already explored the current workspace. `/al-research` handles what the codebase doesn't answer.

**When to research**
- Mandatory for non-trivial tasks.
- Before refining or implementing anything touching: events, posting routines, dimensions, ledger entries, posting setup, transaction isolation, permission sets, AppSource compliance, or any BaseApp object you haven't directly inspected.
- When `/grill-me` surfaces a domain term not grounded in current evidence.
- When prior knowledge feels uncertain — default to verifying.

**Source priority (top-down — stop at the first source that answers definitively)**
1. **AL symbols** (`mcp__al-symbols-mcp`: `al_search_objects`, `al_get_object_definition`, `al_find_references`, `al_search_object_members`, `al_packages`) — definitions, references, package contents in dependencies you can't open directly.
2. **`/bc-standard-reference`** — BaseApp behaviour, standard events, reference patterns.
3. **bc-knowledge MCP** (`find_bc_knowledge`, `ask_bc_expert`, `get_bc_topic`) — internal BC knowledge graph and curated topics.
4. **Microsoft Learn** (`microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search`) — official, version-current documentation.
5. **context7** — external library / SDK documentation.
6. **Web search** — last resort. Treat with suspicion. AL/BC web content is often outdated.

**Discipline**
- Verify, do not paraphrase. Quote or link the canonical source for any claim of behaviour.
- Cite source path or URL alongside each finding.
- Stop when actionable. Don't browse.
- If sources disagree, surface the conflict — don't pick silently.
- Treat your own prior AL knowledge as untrusted until corroborated.

**Output**
- Short findings note: question asked, what was found, where, one-line citations.
- No edits to code or `tasks.md`. The caller decides what to persist.

**Composition:** `/grill-me`, `/bc-standard-reference`, MCP tools.

## Composable existing skills

Already in this repo. Reused, not redesigned.

### `/al-build` — Build, run tests, container recovery

Used by `/al-implement` (red/green builds), `/al-refactor` (build between changes), `/al-mutate` (per-iteration build).

**Container recovery ladder** — apply on Docker-related failures (test runs and mutation iterations alike):

1. **Retry once** — transient flakes are common.
2. **Restart the container**, retry.
3. **Delete the container**, retry — it auto-creates on next run.
4. Still fails after step 3 → abort and report. Environment is broken, not the code.

### `/al-debug-logging` — Execution-path observability

Telemetry probes via `DEBUG-*` markers. Used by `/al-implement` only when execution path is unclear and tests cannot reveal it. Not a default step — use sparingly.

### `/bc-standard-reference` — BaseApp pattern lookup

Locate canonical BC behaviour: events, event publishers, codeunits, tables / fields, tests, pages, APIs. Called by `/al-research` as source #2 and directly by `/al-implement` and `/al-refactor` when reaching for a BC pattern.

### `/grill-me` — Interview the user

Stress-test plans, walk decision trees one branch at a time, recommend an answer for each question. Called by every other skill when intent is ambiguous or a design choice needs the user.

## Workflow shapes

The user-facing entry points. **No forced sequence — pick what fits.**

| Situation | Entry point |
|---|---|
| "I have an idea or issue" | `/al-refine` → `/al-implement` (per task) |
| "What's next? I'm uncertain." | `/al-steer` → handoff or grill |
| "Validate this code's tests" | `/al-mutate` (standalone) |
| "Clean this up while it's green" | `/al-refactor` (standalone) |
| "How does X work in BC?" | `/al-research` (standalone) |

## Inventory summary

**Six new top-level skills**
- `/al-steer` — coach / navigator
- `/al-refine` — idea → `tasks.md`
- `/al-implement` — pick task, run TDD
- `/al-refactor` — improve shape while green
- `/al-mutate` — validate test rigor
- `/al-research` — verify BC specifics

**Four existing skills, reused**
- `/al-build` (with Docker recovery ladder)
- `/al-debug-logging`
- `/bc-standard-reference`
- `/grill-me`

**One living document**
- `./tasks.md`

## Supersedes

This document supersedes [`al-tdd-plan.md`](./al-tdd-plan.md). The 6 skills + 10 agents in that plan are replaced by 6 top-level skills with no separate agent layer; multi-layer review gates, append-only audit trails, Gherkin-7-group pre-specs, mutation killing-layer prediction, and per-feature plan documents are dropped.

The Proof-of-Concepts under [`Proof-of-Concepts/`](./Proof-of-Concepts/) are project-specific operational procedures, marked as historical context.
