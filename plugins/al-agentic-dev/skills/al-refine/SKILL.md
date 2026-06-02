---
name: al-refine
description: One task to a Test Specification or Verification Plan for AL/Business Central. Technical task -> Expected Behaviors or Decision Matrix + AAA cases. Verify task -> Journey Examples, Contract Examples, and Exploration Charters. Reads architecture.md, event-model.md, CONTEXT.md, and the codebase, then writes into tasks.md.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-refine, Task to Test Specification / Verification Plan

Fill one task in `tasks.md`. Branch by `kind=` on the comment-anchor line: `technical` → `Test Specification`; `verify` → `Verification Plan`. Walk codebase, ground symbols, sharpen intent, write the task block. One task per run.

**Layer.** Authors the `Test Specification` / `Verification Plan` each pyramid layer verifies (see [`test-strategy.md`](../../references/test-strategy.md)) using the grammar in [`test-specification.md`](../../references/test-specification.md). Technical tasks feed `/al-implement`; verify tasks feed `/al-page-script` and `/al-user-verification`.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only).
- Spec folder holds `architecture.md`. Missing → **Stop**, run `/al-design`.
- User/API-facing features: `event-model.md` also present.
- Task `status=blocked`: technical task → **Stop**, route to `/al-steer`; verify task with empty `Verification Plan` and completed technical dependencies → write the plan and leave status `blocked` for `/al-code-review`; verify task with a recorded failure/replan note → **Stop**, route to `/al-steer`.
- Verify task (`kind=verify`) but no `event-model.md` → contract violation, **Stop**, route to `/al-steer`. Verify tasks only exist for user/API-facing features.
- Read [`test-specification.md`](../../references/test-specification.md), [`test-strategy.md`](../../references/test-strategy.md), [`voice-contract.md`](../../references/voice-contract.md), and [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md) before writing.

## Branch by task kind

Read task's `kind=` value. `technical` writes a `Test Specification`. `verify` writes a `Verification Plan`.

## Technical task: Test Specification

Spec how one technical task's behaviour is proved so `/al-implement` can drive red → green without re-deriving intent. Answer before writing:

- **What is the task delivering?** Resolve from task description, slice context in `architecture.md`, `event-model.md` when present, `CONTEXT.md`, and codebase.
- **Is there meaningful branching?** No branching → `Expected Behaviors` with `B#` IDs. Branching rule, policy, calculation, status combination → `Decision Matrix` with `R#` IDs. Multiple unrelated groups → split or route to `/al-steer`.
- **What is each AAA case's scope?** `Unit` for AL-Runner decision proof; `Integration` for container, database, event, TestPage, posting, install, permission, or wiring proof. `/al-refine` proposes scope. `/al-implement` may change it and must reconcile `tasks.md`.
- **What procedure names should exist?** Propose short PascalCase AL test procedure names. These populate `Covered By`, AAA headers, and `Procedure:`.
- **What order?** AAA cases list `Unit` first, then `Integration`; within each scope, coverage ID order.
- **What does codebase actually expose?** Real codeunits, tables, fields, pages, procedures, events, and APIs on the boundary. Every exact name rests on current evidence.
- **What vocabulary names the coverage?** Project terms from `CONTEXT.md` first, then BC display labels, then exact AL names only when traceability or ambiguity requires them.

Unanswerable → cannot write the spec yet. Resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan).

## Verify task: Verification Plan

Spec how the slice is checked through its user/API-facing surface. Write only subsections that apply:

- `Journey Examples` for `Scope: E2E`. `/al-page-script` records these only.
- `Contract Examples` for `Scope: Contract`. Name the client or harness.
- `Exploration Charters` for `Scope: Exploration`. Charter plus 2-4 prompts; no exact click script.

Answer before writing:

- **Which slice does this verify?** Read `slice=` on the task's comment-anchor line, resolve to `event-model.md` timeline step. Title + description quote that step's Role, Action, Business Event, View, Status vocabulary.
- **Which surface is exercised?** BC Web Client, API endpoint, Postman collection, curl, integration harness, or another named client. Name the surface inline so downstream skills do not guess.
- **Which examples cover checkable outcomes?** UI workflow → at least one `E2E` journey. API/client slice → at least one `Contract` example. Each has action bullets and observable-check bullets.
- **Which exploration is useful?** Add charters for new workflows, major workflow changes, and error/user-guidance changes. Exploration findings become tasks unless a functional failure is observed.
- **Which `event-model.md` slots are cited?** Every Role / Action / Business Event / View / Status name in a verify example is backed by `grep` against `event-model.md` or workspace lookup on the underlying BC surface.

Unanswerable → cannot write `Verification Plan` yet. Resolve via `/al-research` (BC surface), `/grill-me` (intent), or `/al-steer` (wrong slice boundary or missing prerequisite).

## Ground exact names

Before writing any exact BC-specific symbol into a `Test Specification` or `Verification Plan`, the symbol either appears in `al-symbols-mcp` / `grep` result you ran this session, or is cited via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Workspace lookup is empirical anchor; memory of past sessions or training data is not. Names already cited by `/al-design` or `/al-event-model` count only when `grep` against those upstream files returns the name this session.

Artifacts stay clean. Chat carries audit trail.

## Sharpen vague language inline

When a domain rule is implicit, when edge discovery surfaces a case the user must adjudicate, when an upper bound is missing, when a boundary contradicts another rule, or when intent splits (`validate` as schema check vs. business rule check) → run `/grill-me`. Fuzzy language shipped to `/al-implement` becomes fuzzy code; fuzzy verification becomes weak sign-off.

Inline replacement examples:

- Technical vague: "order is processed" → "Sales Order is posted via Codeunit 80"
- Verify vague: "user checks result" → "Order Processor opens Sales Order Card and Sales Order Status is `Released`"

## Second opinion on non-trivial plans

Cross-check via `/al-second-opinion`. Prompt body for technical tasks: task title + description + proposed `Test Specification` + `CONTEXT.md` language excerpt if resolved + "what behaviours, decision rows, negatives, boundaries, scopes, or procedure mappings are missing or wrong? AND does this surface any of the eight replan triggers? AND does wording use project vocabulary where applicable? Return a bulleted list." Prompt body for verify tasks: task title + slice context from `event-model.md` + proposed `Verification Plan` + "what user-facing journeys, contract checks, exploration prompts, boundaries, or exception paths are missing or wrong? AND do examples name real surfaces? AND does this surface any of the eight replan triggers? Return a bulleted list."

Reconcile each returned bullet; accept by updating or reject with session rationale. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`.

## Numbering and handles

Technical coverage IDs are `B#` for `Expected Behaviors` and `R#` for `Decision Matrix`. Verify IDs are `V#` for `E2E`, `C#` for `Contract`, and `X#` for `Exploration`.

Stable handles:

- Technical: AL test procedure name in `Covered By` / `Procedure`.
- Verify: example ID + title, e.g. `V1 BlocksReleaseFromSalesOrderPage`.

Write telegraphic; drop articles, padding, hedges; fragments fine. Follow surgical-edit contract from [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md).

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing the first `Test Specification` or `Verification Plan` into `tasks.md`. Shape is hard to retract once downstream skills consume it.

</claude-only>

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope` (technical task `status=ready` with empty `Test Specification`) or slice technical completion (dependency-blocked verify task with empty `Verification Plan`) |
| **Hands off to**   | `/al-implement` for technical tasks, `/al-page-script` for verify tasks with `Journey Examples`, `/al-user-verification` after verify recordings/checks are ready |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/al-second-opinion` (non-trivial `Test Specification` / `Verification Plan`), `/al-grill-adr` (fuzzy domain term), `/grill-me` (fuzzy intent) |
