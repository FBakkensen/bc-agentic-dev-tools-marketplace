---
name: al-refine
description: One task → numbered Gherkin scenarios for AL/Business Central. Reads architecture.html, CONTEXT.md, and the codebase to spec how the behaviour is tested, runs /grill-me when intent is fuzzy, confirms the per-scenario test layer, watches for the seven replan triggers, then writes Gherkin into the task's Tests area in tasks.html. Use after /al-scope places a bare task entry. Per task, not per feature.
---

# /al-refine, Task to Gherkin

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on.

Fill the Tests area for one task in `tasks.html`. Read `architecture.html`, walk the codebase, draft Gherkin in ZOMBIES order, confirm the test layer per scenario, watch for the seven replan triggers. One task per run. `/al-implement` consumes it next.

User-facing chat shapes (Opener, Phase, Drafted scenarios, Second opinion, Replan, Close, Stop) live in `${CLAUDE_SKILL_DIR}/../../references/user-communication.md`. Read it before opening the chat.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-design`.
- Spec folder holds `architecture.html`. If not, **Stop**. Run `/al-design`.
- Task carries `data-status="blocked"` → **Stop**. Route to `/al-steer` to clear the replan.
- Legacy markdown spec (`tasks.md` without `tasks.html`) → **Stop**. Legacy specs are frozen; hand-migrate before continuing.

Read before writing to `tasks.html`:

- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`, voice rules, em-dash ban.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md`, destination map for what lives inside the task block vs commit / ADR / `.out-of-scope/`; the seven replan triggers as named patterns.
- `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md`, data-attribute contract, surgical-edit discipline.
- `${CLAUDE_SKILL_DIR}/../../references/user-communication.md`, chat output shapes.

## What goes into the Tests area

The Tests area's job: spec how one task's behaviour is tested so `/al-implement` can drive red → green per bullet without re-deriving intent. The shape that serves that job per task is yours.

What the next reader needs from you, expressed as questions you must have answers to:

- **What is the task actually delivering?** Resolve from the task block's description, the slice context in `architecture.html`, and the codebase. Wire tasks cross the slice's trigger → state path; primitive / extract / fix / refactor tasks stay at the task's own scope.
- **What scenarios cover it?** ZOMBIES across the task: Zero, One, Many, Boundary, Interfaces, Exception, Simple. Both positive and negative where the letter admits.
- **What is each scenario's test layer?** Pure by default. E2E when composition or a side effect is unreproducible at the pure layer (posting, document flow, event chain, table triggers, install / upgrade transitions, telemetry shape).
- **What does the codebase actually expose?** Real codeunits, tables, fields, events on the boundary. Every precondition and outcome cites a symbol that exists.
- **What vocabulary names the scenarios?** Project terms from `CONTEXT.md` `Language` where the scenario touches one; BC vocabulary otherwise. `CONTEXT.md` `_Avoid_:` aliases are forbidden.

If a question is unanswerable, you cannot write the scenario yet. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan).

## Disciplines

### ZOMBIES, across the task

Zero, One, Many, Boundary, Interfaces, Exception, Simple, ordered. **Why**: simplest exercise of the seam first gives `/al-implement` the cleanest starting test. Complexity layered outward keeps the TDD cycle inside one session. Coverage is across the whole task; a `Z` scenario at Pure satisfies the `Z` slot even when E2E has no `Z`. Edges belong at the cheaper layer; E2E proves wiring, not edges.

### Pure first, E2E earns its place

Pure (process layer, no DB) is the default. **Why**: Pure runs in seconds via AL Runner; iteration cost shapes test quantity. E2E earns its place per scenario when intent forces it (composition, side effect, event chain, table trigger, install / upgrade, telemetry shape). Family-level architecture set the default; per-scenario override is the exception, not the rule. When a scenario overrides the family default, record the override layer and the one-line reason inside the task block (shape per your call) so `/al-implement` reads it without re-deriving.

### Ground every clause in a real symbol

Test codeunit location, helpers, field constraints, table relations, validation triggers, BaseApp event publishers and signatures: walk the code before writing. **Why**: scenarios grounded in remembered or imagined APIs ship fiction. `/al-research` for non-trivial BC behaviour; `/bc-standard-reference` for BaseApp patterns. If you cannot point at the codeunit, table, field, or event, you cannot write the scenario.

### Project vocabulary over bare BC

When `CONTEXT.md` (or `src/<module>/CONTEXT.md` via `CONTEXT-MAP.md`) names a term the scenario touches, the title carries that term. **Why**: titles outlive code; readers map vocabulary to intent through titles, not bodies. Bare BC stands only when the operation is BC-native and `CONTEXT.md` does not name a more specific term. `_Avoid_:` aliases are forbidden in titles.

Title cadence: positional, BaseApp PascalCase, behaviour not implementation. `PostSalesOrderWithItemCharge`, not `GivenBlocked_WhenPost_ThenError`; `CloseSettlementBatchWithEntries` (CONTEXT term), not `CloseBatchWithEntries`. The implementation name (codeunit number, event name, table accessor) belongs in the body, not the title; the title survives refactors, the implementation does not.

Body cadence: drop articles, one-line per bullet. BC vocabulary is the compression. Field / codeunit / table names verbatim. `**Given** Customer.Blocked = All` over `**Given** the customer has been blocked`.

### Second opinion on non-trivial Gherkin

Cross-check via `/al-second-opinion`. **Why**: missing negatives, missing boundaries, drifted vocabulary, and replan triggers hide in the author's blind spot. Prompt body: task title + description + Gherkin bullets + `CONTEXT.md` `Language` excerpt if resolved + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the seven replan triggers? AND do scenario titles use project vocabulary from CONTEXT.md `Language` where applicable, or have they drifted to bare BC or generic terms? Return a bulleted list."* Reconcile each returned bullet; accept (update) or reject. Rejection rationale stays in session, not in Notes. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`. `/al-second-opinion` returning `Second opinion skipped: <reason>` is noted in session; proceed.

### Sharpen vague language inline

When a domain rule is implicit, when ZOMBIES surfaces a case the user must adjudicate (`Many` with no stated upper bound, `Boundary` between contradicting rules, `Exception` with no agreed recovery), when intent splits (*validate* as schema-check or business-rule-check), run `/grill-me`. **Why**: fuzzy language shipped to `/al-implement` becomes fuzzy code; the cheapest place to sharpen is before bullets exist. Inline replacement: *"the order is processed"* → *"Sales Order is posted via Codeunit 80"*.

## Seven replan triggers

Named patterns the agent learns to spot during the refinement walk. Watch all seven; verdict belongs in the session, not silent skip.

| # | Trigger | Detect |
|---|---|---|
| 1 | Task too big | `>5` scenarios, or scenarios cluster around two distinct subjects |
| 2 | Hidden pre-req | Gherkin references a table, codeunit, or permission with no covering task |
| 3 | Wrong order | Bullet references behaviour a later task introduces |
| 4 | Sibling now wrong | This task's behaviour invalidates another task's description or scenarios |
| 5 | New behaviour emerges | Scenario specifies behaviour outside any current task's intent |
| 6 | Architecture decomposition wrong | Family-level layer or module boundary cannot house this scenario cleanly |
| 7 | Goal drift | Scenarios push past the feature Goal slot |

**The intent.** When a trigger invalidates the plan as planned, flip the task's `data-status="blocked"` and route to `/al-steer`; record the trigger ID and reason inside the task block (shape per your call; destination rules in `notes-discipline.md`). When a trigger surfaces new information the plan still absorbs, note it inside the task block and continue. The agent maps trigger to mode per situation; do not pre-bind which trigger is which.

## Floor

`tasks.html` carries one surgical-edit contract: maintaining skills find a task by `data-task="T-NNN"` and flip `data-status`. Everything else is `/al-refine`'s call per task.

The Tests area inside the task block: locate (or create) it; shape per task. Whether scenarios render as a numbered list, nested `<details>` per scenario when the count gets unwieldy, Pure and E2E as separate sub-blocks or interleaved by numbering: your call. **Why this is yours**: per-task aesthetics serve per-task reading; one rigid template across all tasks costs more than it buys.

Numbering is the execution order; `/al-implement` traverses bullets sequentially. Pure scenarios precede E2E so the inner loop runs first; the title (`T-NNN#K`) is the stable handle for grilling, commits, and the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]`.

**Names are the citation.** No inline `(see: file.al:120)` in the Gherkin. Field / codeunit / table / event names ARE the citation; future readers grep, the IDE gives line numbers for free.

## Composition

- `/al-scope`, precondition. A task block with `data-task` and a description must exist.
- `/grill-me`, when intent is fuzzy. Standalone-callable mid-flow.
- `/al-grill-adr`, when a domain term is fuzzy and `CONTEXT.md` needs sharpening.
- `/al-research`, for non-trivial BC behaviour.
- `/bc-standard-reference`, for BaseApp patterns and event signatures.
- `/al-second-opinion`, gate for non-trivial Gherkin.
- `/al-steer`, replan venue when a trigger invalidates the plan.
- `/al-implement`, consumes the Gherkin next.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing the first scenario into the Tests area. Gherkin shape is hard to retract once `/al-implement` has consumed it; checking your refinement reasoning here is cheaper than re-running `/al-refine`.

</claude-only>

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `zombies-scenarios.md`, Z/O/M/B/I/E/S ordering rationale and naming examples.
- `al-runner.md`, what `/al-build -UnitTestOnly` runs against; Pure tag is intent, AL Runner verifies.
- `html-spec-discipline.md`, data-attribute contract and surgical-edit discipline.

## Out of scope

- No code edits.
- No fixture mechanics. `/al-implement` decides.
- No mutation lists. Discovered during `/al-implement`, validated in `/al-mutate`.
- No feature-level test strategy. That is `architecture.html` via `/al-design`.
- No replan mutations. That is `/al-steer`.
- No markdown-mode output. Legacy markdown specs are frozen.
