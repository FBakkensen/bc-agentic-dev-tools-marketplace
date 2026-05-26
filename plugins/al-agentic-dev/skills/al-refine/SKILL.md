---
name: al-refine
description: One task to numbered scenarios for AL/Business Central. Technical task → ZOMBIES-ordered Gherkin for /al-implement. Verify task → ZOMBIES-ordered user test plan for /al-user-verification. Reads architecture.md, event-model.md, CONTEXT.md, and the codebase, then writes into the task's Tests area in tasks.md.
---

**Style:** Drop articles, filler, hedging. Fragments OK. Arrows for causality. Technical terms exact, code unchanged, errors quoted exact. **Exception**: shift to prose where clarity or safety would be hurt.

# /al-refine, Task to scenarios

Fill Tests area for one task in `tasks.md`. Branch by the task's `kind=` key: technical → Gherkin for `/al-implement`; verify → user test plan for `/al-user-verification`. Walk codebase, draft scenarios ZOMBIES order, watch the eight replan triggers. One task per run.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend).
- Spec folder holds `architecture.md`. Missing → **Stop**, run `/al-design`.
- User/API-facing features: `event-model.md` also present.
- Task `status=blocked` → **Stop**, route to `/al-steer` to clear replan.
- Verify task (`kind=verify`) but no `event-model.md` → contract violation, **Stop**, route to `/al-steer`. Verify tasks only exist for user/API-facing features.

## Branch by task kind

Read task's `kind=` value on its comment-anchor line. `technical` → write Gherkin scenarios for `/al-implement`. `verify` → write user test plan for `/al-user-verification`. Disciplines below split where branches diverge.

## Technical task: Gherkin for /al-implement

Spec how one task's behaviour is tested so `/al-implement` drives red → green per bullet without re-deriving intent. Shape per task is yours. Answer before writing:

- **What is the task delivering?** Resolve from task description, slice context in `architecture.md`, user-facing journey in `event-model.md` when present, codebase. Scenario titles cite Roles, Business Events, Views from `event-model.md` by canonical names.
- **What scenarios cover it?** ZOMBIES across the task: Zero, One, Many, Boundary, Interfaces, Exception, Simple. Positive and negative where the letter admits. Simplest exercise of seam first; complexity layered outward. Coverage is across whole task; a `Z` at Pure satisfies the slot even when E2E has no `Z`. Edges live at cheaper layer.
- **What is each scenario's test layer?** Pure by default; AL Runner via `/al-build -UnitTestOnly` runs Pure in seconds → iteration cost shapes test quantity. E2E earns its place per scenario when composition or side effect unreproducible at Pure (posting, document flow, event chain, table triggers, install / upgrade, telemetry shape). Family-level architecture sets default; record per-scenario overrides inside task block. When supported / unsupported boundary unclear → `al-runner --guide`.
- **What does codebase actually expose?** Real codeunits, tables, fields, events on boundary. Every precondition and outcome cites a symbol that exists.
- **What vocabulary names the scenarios?** Project terms from `CONTEXT.md` `Language` where scenario touches one; BC vocabulary otherwise. `_Avoid_:` aliases forbidden. Titles positional + PascalCase (`PostSalesOrderWithItemCharge`, not `GivenBlocked_WhenPost_ThenError`); implementation names belong in body, not title. Body drops articles, one line per bullet, field / codeunit / table names verbatim (`**Given** Customer.Blocked = All` over `**Given** the customer has been blocked`).
- **Which BC names verified this session?** Every clause's BC-specific symbol (procedure, event, table, field, codeunit): backed this session by `al-symbols-mcp` / `grep` hit, including `grep` against `architecture.md` / `event-model.md` for upstream-cited names, or `/al-research` citation. Recall does not satisfy. See *Ground every clause in a real symbol* below.

Unanswerable → cannot write scenario yet. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan).

## Verify task: user test plan for /al-user-verification

Spec how a human (or API consumer) confirms slice delivers its user-facing outcome end-to-end, so `/al-user-verification` walks each scenario without re-deriving intent. User is test runner; plan is what they follow. Answer before writing:

- **Which slice does this verify?** Read `slice=` on the task's comment-anchor line, resolve to `event-model.md` timeline step. Title + description quote that step's Role, Action, Business Event, View, Status verbatim. Verify task naming AL mechanics (codeunit, event, subscriber) instead of user-facing vocab → confused altitudes.
- **What scenarios cover the slice?** ZOMBIES across user-facing surface: Zero (empty / minimal state), One (happy path), Many (multi-line / batch / repeated), Boundary (limits, off-by-ones, threshold values like credit limit exactly at threshold), Interfaces (cross-page navigation, API content negotiation, factbox / cue refresh), Exception (user-facing failure path, error message text, posted-document rollback), Simple (any narrow simplification worth separate confirmation). Skip cleanly when slice has no Z (e.g. feature that only exists for non-empty state).
- **What does each scenario's body look like?** Numbered user-action steps, one step per line, present tense. Each step names a surface the user touches (`Sales Order page action "Release"`, `Pending Overrides cue on Order Processor Role Center`, `POST /api/v2.0/companies({id})/salesOrders`) and observable outcome (`Status flips to Released`, `cue increments by 1`, `response.status = "Posted"`). Final step of each scenario is the assertion; everything before is setup.
- **What is the exercise surface?** Page-based slices → BC client; API-based → whichever client the consumer uses (curl, Postman, integration test harness). Name surface inline so `/al-user-verification` does not guess; *"Exercise via: Postman collection at `tests/postman/sales-orders.json`"* or *"Exercise via: BC Web Client at `https://<sandbox-url>`"*.
- **Which `event-model.md` slots cited this session?** Every Role / Action / Business Event / View / Status name in a scenario step: backed this session by `grep` against `event-model.md` or `al-symbols-mcp` hit on underlying page / API / table. Verify-task scenarios with hallucinated Role Centers or Status values fail loudly on first walk; gate has worked but cheaper path is verifying before writing.

Unanswerable → cannot write verify scenario yet. Resolve via `/al-research` (BC surface), `/grill-me` (intent), or `/al-steer` (replan; verify task likely points at wrong slice boundary).

## Ground every clause in a real symbol

Before writing any clause into a Gherkin scenario or step into a user test plan, every BC-specific symbol it rests on (procedure, event, table, field, codeunit, page, API endpoint, Role Center, Status enum value) either appears in `al-symbols-mcp` / `grep` result you ran this session, or cited via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Workspace lookup is empirical anchor; memory of training data or past sessions is not. Names already cited by `/al-design` or `/al-event-model` upstream count when `grep` against upstream file returns the name this session, not when you recall they're there. Scenarios stay clean; chat carries audit trail. Your confidence about a symbol's name, signature, or value set is not evidence any are right.

## Sharpen vague language inline

When a domain rule is implicit, when ZOMBIES surfaces a case the user must adjudicate (`Many` with no stated upper bound, `Boundary` between contradicting rules, `Exception` with no agreed recovery), when intent splits (*validate* as schema-check or business-rule-check) → run `/grill-me`. Fuzzy language shipped to `/al-implement` → fuzzy code; fuzzy steps shipped to `/al-user-verification` → *"yeah looks fine"* sign-offs. Cheapest place to sharpen is before bullets exist. Inline replacement: *"the order is processed"* → *"Sales Order is posted via Codeunit 80"* (technical) / *"the user clicks Post on the Sales Order page and the Status badge flips to Released"* (verify).

## Second opinion on non-trivial scenarios

Cross-check via `/al-second-opinion`. Prompt body for technical tasks: task title + description + Gherkin bullets + `CONTEXT.md` `Language` excerpt if resolved + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the eight replan triggers? AND do scenario titles use project vocabulary from CONTEXT.md `Language` where applicable, or have they drifted to bare BC or generic terms? Return a bulleted list."* Prompt body for verify tasks: task title + slice context from `event-model.md` + scenario steps + *"what user-facing scenarios, boundaries, or exception paths are missing or wrong? AND do steps name a real surface the user can touch, or do they wave at it? AND does this surface any of the eight replan triggers? Return a bulleted list."* Reconcile each returned bullet; accept (update) or reject. Rejection rationale stays in session. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`.

## Numbering

`/al-implement` and `/al-user-verification` both traverse bullets sequentially. Pure scenarios precede E2E in technical tasks so inner loop runs first; verify scenarios have no layer split, ZOMBIES order is the only order. The `T-NNN#K` title is the stable handle for grilling, commits, the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]` (technical), or the step the user signs off on (verify). See [voice-contract.md](../../references/voice-contract.md) for prose voice and [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md) for surgical-edit contract. Write telegraphic; drop articles, padding, hedges; fragments fine. Gherkin step content keeps `Given/When/Then` sentence shape; numbered user-action steps in verify tasks keep imperative sentence shape.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing first scenario into Tests area. Scenario shape is hard to retract once `/al-implement` or `/al-user-verification` has consumed it; checking refinement reasoning here is cheaper than re-running `/al-refine`.

</claude-only>

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope` (task entry exists with `status=ready` and empty Tests area) |
| **Hands off to**   | `/al-implement` for technical tasks, `/al-user-verification` for verify tasks |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/al-second-opinion` (non-trivial scenarios), `/al-grill-adr` (fuzzy domain term), `/grill-me` (fuzzy intent) |
