---
name: al-refine
description: One task to numbered scenarios for AL/Business Central. Technical task → ZOMBIES-ordered Gherkin for /al-implement. Verify task → ZOMBIES-ordered user test plan for /al-user-verification. Reads architecture.html, event-model.html, CONTEXT.md, and the codebase, then writes into the task's Tests area in tasks.html.
---

# /al-refine, Task to scenarios

Fill the Tests area for one task in `tasks.html`. Branch by `data-kind`: technical tasks get Gherkin for `/al-implement`; verify tasks get a user test plan for `/al-user-verification`. Walk the codebase, draft scenarios in ZOMBIES order, watch for the eight replan triggers. One task per run.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend features).
- Spec folder holds `architecture.html`. If not, **Stop**. Run `/al-design`.
- For user/API-facing features, `event-model.html` is also present.
- Task carries `data-status="blocked"` → **Stop**. Route to `/al-steer` to clear the replan.
- Verify task (`data-kind="verify"`) but no `event-model.html` in the spec folder → contract violation, **Stop** and route to `/al-steer`. Verify tasks only exist for user/API-facing features.
- Legacy markdown spec (`tasks.md` without `tasks.html`) → **Stop**. Hand-migrate before continuing.

## Branch by data-kind

Read the task's `data-kind` attribute. Absent or `technical` → write Gherkin scenarios for `/al-implement`. `verify` → write a user test plan for `/al-user-verification`. The disciplines below split where the two branches diverge.

## Technical task: Gherkin for /al-implement

Spec how one task's behaviour is tested so `/al-implement` drives red → green per bullet without re-deriving intent. Shape per task is yours. Answer these before writing:

- **What is the task delivering?** Resolve from the task description, slice context in `architecture.html`, the user-facing journey in `event-model.html` when present, and the codebase. Scenario titles cite Roles, Business Events, and Views from `event-model.html` by their canonical names.
- **What scenarios cover it?** ZOMBIES across the task: Zero, One, Many, Boundary, Interfaces, Exception, Simple. Positive and negative where the letter admits. Simplest exercise of the seam first; complexity layered outward. Coverage is across the whole task; a `Z` at Pure satisfies the slot even when E2E has no `Z`. Edges live at the cheaper layer.
- **What is each scenario's test layer?** Pure by default; AL Runner via `/al-build -UnitTestOnly` runs Pure in seconds, so iteration cost shapes test quantity. E2E earns its place per scenario when composition or a side effect is unreproducible at Pure (posting, document flow, event chain, table triggers, install / upgrade, telemetry shape). Family-level architecture sets the default; record per-scenario overrides inside the task block. When the supported / unsupported boundary is unclear for a scenario, run `al-runner --guide` for the authoritative capability matrix.
- **What does the codebase actually expose?** Real codeunits, tables, fields, events on the boundary. Every precondition and outcome cites a symbol that exists.
- **What vocabulary names the scenarios?** Project terms from `CONTEXT.md` `Language` where the scenario touches one; BC vocabulary otherwise. `_Avoid_:` aliases forbidden. Titles positional and PascalCase (`PostSalesOrderWithItemCharge`, not `GivenBlocked_WhenPost_ThenError`); implementation names belong in the body, not the title. Body drops articles, one line per bullet, field / codeunit / table names verbatim (`**Given** Customer.Blocked = All` over `**Given** the customer has been blocked`).
- **Which BC names did you verify this session?** Every clause's BC-specific symbol (procedure, event, table, field, codeunit): backed this session by an `al-symbols-mcp` or `grep` hit, including `grep` against `architecture.html` / `event-model.html` for upstream-cited names, or a `/al-research` citation. Recall does not satisfy. See *Ground every clause in a real symbol* below.

If a question is unanswerable, you cannot write the scenario yet. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan).

## Verify task: user test plan for /al-user-verification

Spec how a human (or API consumer) confirms the slice delivers its user-facing outcome end-to-end, so `/al-user-verification` walks each scenario without re-deriving intent. The user is the test runner; the plan is what they follow. Answer these before writing:

- **Which slice does this verify?** Read `data-slice` and resolve to the `event-model.html` timeline step. Title and description quote that step's Role, Action, Business Event, View, and Status verbatim. A verify task that names AL mechanics (codeunit, event, subscriber) instead of user-facing vocabulary has confused altitudes.
- **What scenarios cover the slice?** ZOMBIES across the user-facing surface: Zero (empty / minimal state), One (the happy path), Many (multi-line / batch / repeated), Boundary (limits, off-by-ones, threshold values like credit limit exactly at threshold), Interfaces (cross-page navigation, API content negotiation, factbox / cue refresh), Exception (the user-facing failure path, error message text, posted-document rollback), Simple (any narrow simplification worth a separate confirmation). Not every letter applies to every slice; skip cleanly when the slice has no Z (e.g. a feature that only exists for non-empty state).
- **What does each scenario's body look like?** Numbered user-action steps, one step per line, present tense. Each step names a surface the user touches (`Sales Order page action "Release"`, `Pending Overrides cue on Order Processor Role Center`, `POST /api/v2.0/companies({id})/salesOrders`) and the observable outcome (`Status flips to Released`, `cue increments by 1`, `response.status = "Posted"`). The final step of each scenario is the assertion; everything before is the setup.
- **What is the exercise surface?** Page-based slices use the BC client; API-based slices use whichever client the consumer uses (curl, Postman, integration test harness). Name the surface inline so `/al-user-verification` does not have to guess; *"Exercise via: Postman collection at `tests/postman/sales-orders.json`"* or *"Exercise via: BC Web Client at `https://<sandbox-url>`"*.
- **Which `event-model.html` slots did you cite this session?** Every Role / Action / Business Event / View / Status name in a scenario step: backed this session by `grep` against `event-model.html` or an `al-symbols-mcp` hit on the underlying page / API / table. Verify-task scenarios with hallucinated Role Centers or Status values fail loudly on first walk, the gate has worked; the cheaper path is verifying before writing.

If a question is unanswerable, you cannot write the verify scenario yet. Resolve via `/al-research` (BC surface behaviour), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan; verify task likely points at the wrong slice boundary).

## Ground every clause in a real symbol

Before writing any clause into a Gherkin scenario or step into a user test plan, every BC-specific symbol it rests on (procedure, event, table, field, codeunit, page, API endpoint, Role Center, Status enum value) either appears in an `al-symbols-mcp` or `grep` result you ran this session, or is cited via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. The workspace lookup is the empirical anchor; memory of training data or past sessions is not. Names already cited by `/al-design` or `/al-event-model` upstream count when `grep` against the upstream file returns the name this session, not when you recall they're there. The scenarios stay clean; the chat carries the audit trail. Your confidence about a symbol's name, signature, or value set is not evidence any of those are right.

## Sharpen vague language inline

When a domain rule is implicit, when ZOMBIES surfaces a case the user must adjudicate (`Many` with no stated upper bound, `Boundary` between contradicting rules, `Exception` with no agreed recovery), when intent splits (*validate* as schema-check or business-rule-check), run `/grill-me`. Fuzzy language shipped to `/al-implement` becomes fuzzy code; fuzzy steps shipped to `/al-user-verification` become *"yeah looks fine"* sign-offs. The cheapest place to sharpen is before bullets exist. Inline replacement: *"the order is processed"* → *"Sales Order is posted via Codeunit 80"* (technical) / *"the user clicks Post on the Sales Order page and the Status badge flips to Released"* (verify).

## Second opinion on non-trivial scenarios

Cross-check via `/al-second-opinion`. Prompt body for technical tasks: task title + description + Gherkin bullets + `CONTEXT.md` `Language` excerpt if resolved + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the eight replan triggers? AND do scenario titles use project vocabulary from CONTEXT.md `Language` where applicable, or have they drifted to bare BC or generic terms? Return a bulleted list."* Prompt body for verify tasks: task title + slice context from `event-model.html` + scenario steps + *"what user-facing scenarios, boundaries, or exception paths are missing or wrong? AND do steps name a real surface the user can touch, or do they wave at it? AND does this surface any of the eight replan triggers? Return a bulleted list."* Reconcile each returned bullet; accept (update) or reject. Rejection rationale stays in session. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`.

## Numbering

`/al-implement` and `/al-user-verification` both traverse bullets sequentially. Pure scenarios precede E2E in technical tasks so the inner loop runs first; verify scenarios have no layer split, ZOMBIES order is the only order. The `T-NNN#K` title is the stable handle for grilling, commits, and the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]` (technical) or the step the user signs off on (verify). See [voice-contract.md](../../references/voice-contract.md) for prose voice and [html-spec-discipline.md](../../references/html-spec-discipline.md) for the surgical-edit contract.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing the first scenario into the Tests area. Scenario shape is hard to retract once `/al-implement` or `/al-user-verification` has consumed it; checking refinement reasoning here is cheaper than re-running `/al-refine`.

</claude-only>

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope` (task entry exists with `data-status="ready"` and empty Tests area) |
| **Hands off to**   | `/al-implement` for technical tasks, `/al-user-verification` for verify tasks |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/al-second-opinion` (non-trivial scenarios), `/al-grill-adr` (fuzzy domain term), `/grill-me` (fuzzy intent) |
