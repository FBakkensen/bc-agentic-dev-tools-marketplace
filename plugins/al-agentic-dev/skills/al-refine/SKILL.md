---
name: al-refine
description: One task to numbered Gherkin scenarios for AL/Business Central. Reads architecture.html, CONTEXT.md, and the codebase, then writes ZOMBIES-ordered Gherkin into the task's Tests area in tasks.html for /al-implement to consume.
---

# /al-refine, Task to Gherkin

Fill the Tests area for one task in `tasks.html`. Walk the codebase, draft Gherkin in ZOMBIES order, confirm the test layer per scenario, watch for the seven replan triggers. One task per run.

## Preconditions

- Branch matches `^\d{3}-`. If not, **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend features).
- Spec folder holds `architecture.html`. If not, **Stop**. Run `/al-design`.
- For user/API-facing features, `event-model.html` is also present.
- Task carries `data-status="blocked"` → **Stop**. Route to `/al-steer` to clear the replan.
- Legacy markdown spec (`tasks.md` without `tasks.html`) → **Stop**. Hand-migrate before continuing.

## What goes into the Tests area

Spec how one task's behaviour is tested so `/al-implement` drives red → green per bullet without re-deriving intent. Shape per task is yours. Answer these before writing:

- **What is the task delivering?** Resolve from the task description, slice context in `architecture.html`, the user-facing journey in `event-model.html` when present, and the codebase. Scenario titles cite Roles, Business Events, and Views from `event-model.html` by their canonical names.
- **What scenarios cover it?** ZOMBIES across the task: Zero, One, Many, Boundary, Interfaces, Exception, Simple. Positive and negative where the letter admits. Simplest exercise of the seam first; complexity layered outward. Coverage is across the whole task; a `Z` at Pure satisfies the slot even when E2E has no `Z`. Edges live at the cheaper layer.
- **What is each scenario's test layer?** Pure by default; AL Runner via `/al-build -UnitTestOnly` runs Pure in seconds, so iteration cost shapes test quantity. E2E earns its place per scenario when composition or a side effect is unreproducible at Pure (posting, document flow, event chain, table triggers, install / upgrade, telemetry shape). Family-level architecture sets the default; record per-scenario overrides inside the task block. When the supported / unsupported boundary is unclear for a scenario, run `al-runner --guide` for the authoritative capability matrix.
- **What does the codebase actually expose?** Real codeunits, tables, fields, events on the boundary. Every precondition and outcome cites a symbol that exists.
- **What vocabulary names the scenarios?** Project terms from `CONTEXT.md` `Language` where the scenario touches one; BC vocabulary otherwise. `_Avoid_:` aliases forbidden. Titles positional and PascalCase (`PostSalesOrderWithItemCharge`, not `GivenBlocked_WhenPost_ThenError`); implementation names belong in the body, not the title. Body drops articles, one line per bullet, field / codeunit / table names verbatim (`**Given** Customer.Blocked = All` over `**Given** the customer has been blocked`).

If a question is unanswerable, you cannot write the scenario yet. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan).

## Ground every clause in a real symbol

Before writing any clause into a Gherkin scenario, declare each BC-specific symbol it rests on (procedure, event, table, field, codeunit) via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Names already cited by `/al-design` upstream in `architecture.html` do not re-verify. The Gherkin stays clean; the chat carries the audit trail.

## Sharpen vague language inline

When a domain rule is implicit, when ZOMBIES surfaces a case the user must adjudicate (`Many` with no stated upper bound, `Boundary` between contradicting rules, `Exception` with no agreed recovery), when intent splits (*validate* as schema-check or business-rule-check), run `/grill-me`. Fuzzy language shipped to `/al-implement` becomes fuzzy code; the cheapest place to sharpen is before bullets exist. Inline replacement: *"the order is processed"* → *"Sales Order is posted via Codeunit 80"*.

## Second opinion on non-trivial Gherkin

Cross-check via `/al-second-opinion`. Prompt body: task title + description + Gherkin bullets + `CONTEXT.md` `Language` excerpt if resolved + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the seven replan triggers? AND do scenario titles use project vocabulary from CONTEXT.md `Language` where applicable, or have they drifted to bare BC or generic terms? Return a bulleted list."* Reconcile each returned bullet; accept (update) or reject. Rejection rationale stays in session. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`.

## Numbering

`/al-implement` traverses bullets sequentially. Pure scenarios precede E2E so the inner loop runs first; the `T-NNN#K` title is the stable handle for grilling, commits, and the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]`. See [voice-contract.md](../../references/voice-contract.md) for prose voice and [html-spec-discipline.md](../../references/html-spec-discipline.md) for the surgical-edit contract.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing the first scenario into the Tests area. Gherkin shape is hard to retract once `/al-implement` has consumed it; checking refinement reasoning here is cheaper than re-running `/al-refine`.

</claude-only>

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope` (task entry exists with `data-status="ready"` and empty Tests area) |
| **Hands off to**   | `/al-implement` (Tests area filled) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/al-second-opinion` (non-trivial Gherkin), `/al-grill-adr` (fuzzy domain term), `/grill-me` (fuzzy intent) |
