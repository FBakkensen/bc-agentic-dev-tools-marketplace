---
name: al-refine
description: One `status: ready` task to a fresh Test Specification or Verification Plan for AL/Business Central. Technical task -> ready-for-implementation. Verify task -> ready-for-verification.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-refine, Task to Test Specification / Verification Plan

Fill one named `status: ready` task in the `tasks/` folder. Branch by `kind:` in the task file's frontmatter: `technical` → fresh `Test Specification`; `verify` → fresh `Verification Plan`. Existing proof content is untrusted; regenerate from current app/tests, ground symbols, sharpen intent, write the task body. One task per run.

**Layer.** Authors the `Test Specification` / `Verification Plan` each pyramid layer verifies (see [`test-strategy.md`](../../references/test-strategy.md)) using the grammar in [`test-specification.md`](../../references/test-specification.md). Technical tasks feed `/al-implement`; verify tasks feed `/al-page-script` and `/al-user-verification`.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only).
- Spec folder holds `architecture.md`. Missing → **Stop**, run `/al-design`.
- User/API-facing features: `event-model.md` also present.
- Target task is named and has `status: ready`. `ready` means context exists for `/al-refine` only.
- Any other status is not a refine target: `blocked` with all `depends_on:` `done` and no replan flag in the body → the upstream close just didn't flip it; open it `ready` here and proceed, no `/al-steer` bounce. `blocked` on an unsatisfied edge or a replan flag → `/al-steer`. `ready-for-implementation` → `/al-implement`; `ready-for-verification` → `/al-page-script` or `/al-user-verification` after `/al-code-review`; `done` → downstream evidence exists, reopen only through `/al-steer`.
- Verify task (`kind: verify`) but no `event-model.md` → contract violation, **Stop**, route to `/al-steer`. Verify tasks only exist for user/API-facing features.
- Read [`test-specification.md`](../../references/test-specification.md), [`test-strategy.md`](../../references/test-strategy.md), [`test-layout.md`](../../references/test-layout.md) (the Unit-vs-Integration scope call is the placement rule there — a case whose codepath needs real BaseApp behaviour cannot be scoped `Unit`), [`voice-contract.md`](../../references/voice-contract.md), and [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md) before writing.

## Branch by task kind

Read task's `kind:` value. `technical` writes a `Test Specification` and flips `ready` → `ready-for-implementation`. `verify` writes a `Verification Plan` and flips `ready` → `ready-for-verification`.

`kind: provision` or `kind: breaking-change` → **not a refine target**. These ops tasks carry no proof artifact; they run a script and flip status. Write nothing, leave `status: ready`, notify: *"ops task → run `/al-provision`"* (`kind: provision`) or *"ops task → run `/al-validate-breaking-changes`"* (`kind: breaking-change`).

## Regenerate proof

Preserve scope-time context: title, description, the `depends_on:` / `refactors:` / `fixes:` frontmatter edges, `slice:`, constraints, risks, source context, acceptance intent. Rewrite the proof section whole. Do not preserve stale `Test Specification`, `Verification Plan`, AAA cases, coverage tables, examples, or charters because they existed in the task body.

## Technical task: Test Specification

Spec how one technical task's behaviour is proved so `/al-implement` can drive red → green without re-deriving intent. Answer before writing:

- **What is the task delivering?** Resolve from task description, slice context in `architecture.md`, `event-model.md` when present, `CONTEXT.md`, and codebase.
- **Is there meaningful branching?** No branching → `Expected Behaviors` with `B#` IDs. Branching rule, policy, calculation, status combination → `Decision Matrix` with `R#` IDs. Multiple unrelated groups → split or route to `/al-steer`.
- **What is each AAA case's scope?** `Unit` for AL-Runner decision proof; `Integration` for container, database, event, TestPage, posting, install, permission, or wiring proof. `/al-refine` proposes scope. `/al-implement` may change it and must reconcile the task file.
- **What procedure names should exist?** Propose short PascalCase AL test procedure names. These populate `Covered By`, AAA headers, and `Procedure:`.
- **What order?** AAA cases list `Unit` first, then `Integration`; within each scope, coverage ID order.
- **What does codebase actually expose?** Real codeunits, tables, fields, pages, procedures, events, and APIs on the boundary. Every exact name rests on current evidence.
- **Which objects and signatures does the task land?** Write `New and Modified Objects` per the grammar in [`test-specification.md`](../../references/test-specification.md); `/al-implement` consumes these signatures instead of minting names mid-TDD. Seed `New:` vs `Modified:` from `architecture.md`'s `new` / `extends` markers, then override by workspace state at refine time — an object an earlier task already landed is `Modified:` regardless of its design-time marker. Architecture silent on a needed object → mint it when it serves a listed slice slot; a missing slot is trigger #6, route `/al-steer`.
- **What vocabulary names the coverage?** Project terms from `CONTEXT.md` first, then BC display labels, then exact AL names only when traceability or ambiguity requires them.

Unanswerable → cannot write the spec yet. Flip or keep `status: blocked` and resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan).

## Verify task: Verification Plan

Spec how the slice is checked through its user/API-facing surface. Write only subsections that apply:

- `Journey Examples` for `Scope: E2E`. `/al-page-script` records these only.
- `Contract Examples` for `Scope: Contract`. Name the client or harness.
- `Exploration Charters` for `Scope: Exploration`. Charter plus 2-4 prompts; no exact click script.

Answer before writing:

- **Which slice does this verify?** Read `slice:` in the task file's frontmatter, resolve to `event-model.md` timeline step. Title + description quote that step's Role, Action, Business Event, View, Status vocabulary.
- **Which surface is exercised?** BC Web Client, API endpoint, Postman collection, curl, integration harness, or another named client. Name the surface inline so downstream skills do not guess.
- **Which examples cover checkable outcomes?** UI workflow → at least one `E2E` journey. API/client slice → at least one `Contract` example. Each has action bullets and observable-check bullets.
- **Which exploration is useful?** Add charters for new workflows, major workflow changes, and error/user-guidance changes. Exploration findings become tasks unless a functional failure is observed.
- **Which `event-model.md` slots are cited?** Every Role / Action / Business Event / View / Status name in a verify example is backed by `grep` against `event-model.md` or workspace lookup on the underlying BC surface.

Unanswerable → cannot write `Verification Plan` yet. Flip or keep `status: blocked` and resolve via `/al-research` (BC surface), `/grill-me` (intent), or `/al-steer` (wrong slice boundary or missing prerequisite).

## Ground exact names

Every exact BC-specific symbol in a `Test Specification` or `Verification Plan` meets the evidence bar in [voice-contract.md](../../references/voice-contract.md): workspace hit this session or quoted fetch; conflicts and design-artifact facts escalate to `/al-research`. Names already cited by `/al-design` or `/al-event-model` count only when `grep` against those upstream files returns the name this session.

Minted names in `New and Modified Objects` meet the bar's minted-name clause in [voice-contract.md](../../references/voice-contract.md).

Artifacts stay clean; chat carries the citation. `Researched:` bullets land in `Contract notes` — refine's at write, `/al-implement`'s at reconcile.

## Sharpen vague language inline

When a domain rule is implicit, when edge discovery surfaces a case the user must adjudicate, when an upper bound is missing, when a boundary contradicts another rule, or when intent splits (`validate` as schema check vs. business rule check) → run `/grill-me`. Fuzzy language shipped to `/al-implement` becomes fuzzy code; fuzzy verification becomes weak sign-off.

Inline replacement examples:

- Technical vague: "order is processed" → "Sales Order is posted via Codeunit 80"
- Verify vague: "user checks result" → "Order Processor opens Sales Order Card and Sales Order Status is `Released`"

## Second opinion on non-trivial plans

Cross-check via `/al-second-opinion`. Prompt body for technical tasks: task title + description + proposed `Test Specification` + `CONTEXT.md` language excerpt if resolved + "what behaviours, decision rows, negatives, boundaries, scopes, procedure mappings, or object/signature landings are missing or wrong? AND does this surface any of the eight replan triggers? AND does wording use project vocabulary where applicable? Return a bulleted list." Prompt body for verify tasks: task title + slice context from `event-model.md` + proposed `Verification Plan` + "what user-facing journeys, contract checks, exploration prompts, boundaries, or exception paths are missing or wrong? AND do examples name real surfaces? AND does this surface any of the eight replan triggers? Return a bulleted list."

Reconcile each returned bullet; accept by updating or reject with session rationale. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`.

## Numbering and handles

Technical coverage IDs are `B#` for `Expected Behaviors` and `R#` for `Decision Matrix`. Verify IDs are `V#` for `E2E`, `C#` for `Contract`, and `X#` for `Exploration`.

Stable handles:

- Technical: AL test procedure name in `Covered By` / `Procedure`.
- Verify: example ID + title, e.g. `V1 BlocksReleaseFromSalesOrderPage`.

Write telegraphic per line; drop articles, padding, hedges; fragments fine. Concision compresses each line, never the line count: multi-fact content splits one fact per landing line — a `;`-spliced multi-fact paragraph is density, not concision. Follow surgical-edit contract from [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md).

## Document verification

After writing the fresh `Test Specification` or `Verification Plan`, run `/al-doc-verify` before flipping `status:`:

```text
/al-doc-verify --producer al-refine --artifacts specs/<NNN>-<slug>/tasks/ --task T-NNN --slice <slice> --handoff al-implement|al-code-review
```

`verdict=fail` blocks the `ready-for-implementation` / `ready-for-verification` flip; fix the structural/boundary issue or route to `/al-steer`. `verdict=warn` does not block; include the warning in the handoff. This gate checks document integrity only, not whether the planned proof is sufficient.

## Status flip

After writing and reconciling the fresh proof section, locate the task file by its `T-MMM` filename and flip its `status:` frontmatter line only:

```markdown
technical: status: ready → status: ready-for-implementation
verify:    status: ready → status: ready-for-verification
```

No `in-progress` state. The task is now executable-ready, but still not `done`.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing the first `Test Specification` or `Verification Plan` into the task file. Shape is hard to retract once downstream skills consume it.

</claude-only>

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope` or dependency restoration opened one named task to `status: ready` |
| **Hands off to**   | `/al-implement` for `ready-for-implementation` technical tasks; `/al-code-review` then `/al-page-script` or `/al-user-verification` for `ready-for-verification` verify tasks |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/al-second-opinion` (non-trivial `Test Specification` / `Verification Plan`), `/al-grill-adr` (fuzzy domain term), `/grill-me` (fuzzy intent) |
