---
name: al-refine
description: One `status: ready` task to a fresh Test Specification or Verification Plan for AL/Business Central. Technical task -> ready-for-implementation. Verify task -> ready-for-verification.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-refine, Task to Test Specification / Verification Plan

Fill one named `status: ready` task in the `tasks/` folder. Existing proof content is untrusted; regenerate from current app/tests, ground symbols, sharpen intent, write the task body. One task per run.

Branch by `kind:` in the task file's frontmatter:

- `technical` → fresh `Test Specification`, flip `ready` → `ready-for-implementation`.
- `verify` → fresh `Verification Plan`, flip `ready` → `ready-for-verification`.
- `provision` / `breaking-change` → **not a refine target**: no proof artifact, leave `status: ready`, notify *"ops task → run `/al-provision`"* or *"ops task → run `/al-validate-breaking-changes`"*.

**Layer.** Authors the `Test Specification` / `Verification Plan` each pyramid layer verifies (see [`test-strategy.md`](../../references/test-strategy.md)) using the grammar in [`test-specification.md`](../../references/test-specification.md).

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for backend-only).
- Spec folder holds `architecture.md`. Missing → **Stop**, run `/al-design`.
- User/API-facing features: `event-model.md` also present.
- Target task is named and has `status: ready` (context exists for `/al-refine` only). One nuance, **`kind: technical` only**: a technical task `blocked` with all `depends_on:` `done` and no replan flag in the body → the upstream close just didn't flip it; open it `ready` here and proceed, no `/al-steer` bounce. A **`kind: verify`** task gets no self-open — it reaches `ready` only when `/al-code-review` opens it on a clean per-slice review (carrying `review: clean`). A `blocked` verify task with all technical deps `done` and no `review: clean` is **slice-done owing its first code review** → **Stop**, `Next: /al-code-review T-NNN`; do not self-open and write the plan, or the review gate is skipped. `blocked` on an unsatisfied edge or a replan flag → `/al-steer`. A `done` task carries downstream evidence; reopen only through `/al-steer`.
- Verify task (`kind: verify`) but no `event-model.md` → contract violation, **Stop**, route to `/al-steer`. Verify tasks only exist for user/API-facing features.
- Read [`test-specification.md`](../../references/test-specification.md), [`test-strategy.md`](../../references/test-strategy.md), [`test-layout.md`](../../references/test-layout.md) (the Unit-vs-Integration scope call is the placement rule there — a case whose codepath needs real BaseApp behaviour cannot be scoped `Unit`), [`voice-contract.md`](../../references/voice-contract.md), and [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md) before writing.

## Regenerate proof

Preserve scope-time context: title, description, the `depends_on:` / `refactors:` / `fixes:` frontmatter edges, `slice:`, constraints, risks, source context, acceptance intent. Rewrite the proof section whole. Do not preserve stale `Test Specification`, `Verification Plan`, AAA cases, coverage tables, examples, or charters because they existed in the task body.

## Technical task: Test Specification

Spec how one technical task's behaviour is proved so `/al-implement` can drive red → green without re-deriving intent. Answer before writing:

- **What is the task delivering?** Resolve from task description, slice context in `architecture.md`, `event-model.md` when present, `CONTEXT.md`, and codebase.
- **Is there meaningful branching?** No branching → `Expected Behaviors` with `B#` IDs. Branching rule, policy, calculation, status combination → `Decision Matrix` with `R#` IDs. Multiple unrelated groups → split or route to `/al-steer`.
- **What is each AAA case's scope?** `Unit` for AL-Runner decision proof; `Integration` for container, database, event, TestPage, posting, install, permission, or wiring proof. `/al-refine` proposes scope. `/al-implement` may change it and must reconcile the task file. Every `Integration` case is a push-up from `Unit` — see *Surface push-ups*.
- **What procedure names should exist?** Propose short PascalCase AL test procedure names. These populate `Covered By`, AAA headers, and `Procedure:`.
- **What order?** AAA cases list `Unit` first, then `Integration`; within each scope, coverage ID order.
- **What does codebase actually expose?** Real codeunits, tables, fields, pages, procedures, events, and APIs on the boundary. Every exact name rests on current evidence.
- **Which objects and signatures does the task land?** Write `New and Modified Objects` per the grammar in [`test-specification.md`](../../references/test-specification.md); `/al-implement` consumes these signatures instead of minting names mid-TDD. Seed `New:` vs `Modified:` from `architecture.md`'s `new` / `extends` markers, then override by workspace state at refine time — an object an earlier task already landed is `Modified:` regardless of its design-time marker. Architecture silent on a needed object → mint it when it serves a listed slice slot; a missing slot is trigger #6, route `/al-steer`.
- **What vocabulary names the coverage?** Project terms from `CONTEXT.md` first, then BC display labels, then exact AL names only when traceability or ambiguity requires them.

Unanswerable → cannot write the spec yet. Flip or keep `status: blocked` and resolve via `/al-research` (BC behaviour), `/al-grill-adr` (domain rule), `/grill-me` (intent the user must adjudicate), or `/al-steer` (replan).

## Verify task: Verification Plan

Spec how the slice is checked through its user/API-facing surface. Write only subsections that apply:

- `Journey Examples` for `Scope: E2E`, each marked `Record: yes` or `Record: no` (see below). `/al-page-script` records the `Record: yes` set; `/al-user-verification` walks the `Record: no` set.
- `Contract Examples` for `Scope: Contract`. Name the client or harness.
- `Exploration Charters` for `Scope: Exploration`. Charter plus 2-4 prompts; no exact click script.

Answer before writing:

- **Which slice does this verify?** Read `slice:` in the task file's frontmatter, resolve to `event-model.md` timeline step. Title + description quote that step's Role, Action, Business Event, View, Status vocabulary.
- **Which surface is exercised?** BC Web Client, API endpoint, Postman collection, curl, integration harness, or another named client. Name the surface inline so downstream skills do not guess.
- **Which examples cover checkable outcomes?** UI workflow → at least one `E2E` journey. API/client slice → at least one `Contract` example. Each has action bullets and observable-check bullets.
- **Which E2E journeys need a recording?** Mark each `E2E` example `Record: yes` only when **no AL test layer can automate the behaviour** (control add-in, canvas, web-client-only behaviour) — the generation-time push-down call (see [`test-strategy.md`](../../references/test-strategy.md)). Behaviour a Unit or Integration test already pins (or that a technical task in this slice should pin — push it down via `/al-steer` rather than record it) is `Record: no`: walked for acceptance, never recorded, because a recording that doubles a lower test is pure cost. Most examples are `Record: no`; a slice with zero `Record: yes` skips `/al-page-script`.
- **Which exploration is useful?** Add charters for new workflows, major workflow changes, and error/user-guidance changes. Exploration findings become tasks unless a functional failure is observed.
- **Which `event-model.md` slots are cited?** Every Role / Action / Business Event / View / Status name in a verify example is backed by `grep` against `event-model.md` or workspace lookup on the underlying BC surface.

Unanswerable → cannot write `Verification Plan` yet. Flip or keep `status: blocked` and resolve via `/al-research` (BC surface), `/grill-me` (intent), or `/al-steer` (wrong slice boundary or missing prerequisite).

## Surface push-ups, commit nothing

A test scoped above the deepest layer that could check the behaviour is a **push-up** (see [`test-strategy.md`](../../references/test-strategy.md)): every `Integration` case, every `Record: yes` E2E, every `Contract` example. For each, record a `Contract notes` line — why the layer below cannot hold it + the named seam from [`testability.md`](../../references/testability.md) that would reach it, or the wall — and emit the **Push-up report** ([`voice-contract.md`](../../references/voice-contract.md)) as its own chat section. `/al-refine` only *proposes*: nothing is written but the task file, so this surfaces the tax without gating — the handoff stop is the user's review point, and `/al-implement` is where a push-up is actually committed. `Record: no` E2E (already pushed down) and `Exploration` (no checkable floor) are not push-ups and carry no justification.

## Ground exact names

Every exact BC-specific symbol in a `Test Specification` or `Verification Plan` meets the evidence bar in [voice-contract.md](../../references/voice-contract.md): workspace hit this session or quoted fetch; conflicts and design-artifact facts escalate to `/al-research`. Names already cited by `/al-design` or `/al-event-model` count only when `grep` against those upstream files returns the name this session.

Minted names in `New and Modified Objects` meet the bar's minted-name clause in [voice-contract.md](../../references/voice-contract.md).

Artifacts stay clean; chat carries the citation. `Researched:` bullets land in `Contract notes` — refine's at write, `/al-implement`'s at reconcile.

## Sharpen vague language inline

When a domain rule is implicit, when edge discovery surfaces a case the user must adjudicate, when an upper bound is missing, when a boundary contradicts another rule, or when intent splits (`validate` as schema check vs. business rule check) → run `/grill-me`. Fuzzy language shipped to `/al-implement` becomes fuzzy code; fuzzy verification becomes weak sign-off. Replace vague phrasing with exact object + procedure + status names inline.

## Second opinion on non-trivial plans

Cross-check via `/al-second-opinion`. Prompt body for technical tasks: task title + description + proposed `Test Specification` + `CONTEXT.md` language excerpt if resolved + "what behaviours, decision rows, negatives, boundaries, scopes, procedure mappings, or object/signature landings are missing or wrong? AND does this surface any of the eight replan triggers? AND does wording use project vocabulary where applicable? Return a bulleted list." Prompt body for verify tasks: task title + slice context from `event-model.md` + proposed `Verification Plan` + "what user-facing journeys, contract checks, exploration prompts, boundaries, or exception paths are missing or wrong? AND do examples name real surfaces? AND does this surface any of the eight replan triggers? Return a bulleted list."

Reconcile each returned bullet; accept by updating or reject with session rationale. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`.

## Numbering and handles

Technical coverage IDs are `B#` for `Expected Behaviors` and `R#` for `Decision Matrix`. Verify IDs are `V#` for `E2E`, `C#` for `Contract`, and `X#` for `Exploration`.

Stable handles:

- Technical: AL test procedure name in `Covered By` / `Procedure`.
- Verify: example ID + title, e.g. `V1 BlocksReleaseFromSalesOrderPage`.

## Document verification

After writing the fresh `Test Specification` or `Verification Plan`, run the document-integrity check yourself, inline (no subagent), before flipping `status:` — verify the task file against [`doc-integrity.md`](../../references/doc-integrity.md), scoped to this `T-NNN`: the proof-section check (a populated `Test Specification` needs a `New and Modified Objects` block) and, for a verify task, the E2E `Record:` flag check.

A **fail** (structural or boundary blocker) blocks the `ready-for-implementation` / `ready-for-verification` flip; fix it or route to `/al-steer`. A **warn** does not block; include it in the handoff. This gate checks document integrity only, not whether the planned proof is sufficient.

## Status flip

After writing and reconciling the fresh proof section, locate the task file by its `T-MMM` filename and flip its `status:` frontmatter line only:

```markdown
technical: status: ready → status: ready-for-implementation
verify:    status: ready → status: ready-for-verification
```

No `in-progress` state.

**Advisor checkpoint.** Before writing the first `Test Specification` or `Verification Plan` into the task file, do a final shape check — coverage, the New/Modified split, the push-up set. For non-trivial proof, `/al-second-opinion` gives an independent cross-family read; the shape is hard to retract once downstream skills consume it.

## Next step

Read off the flipped task:

- **Technical task → `ready-for-implementation`:** `Next: /al-implement T-NNN` — drive the `Test Specification` red→green.
- **Verify task → `ready-for-verification`:** the verify task arrived carrying `review: clean` (`/al-code-review` ran at slice-done and opened it); the `status:`-only flip preserves it. `Next:` state-conditional on the slice's recordings — `/al-page-script T-NNN` (a `Record: yes` Journey Example's recording missing) or `/al-user-verification T-NNN` (all present, or no `Record: yes` example). The review already ran — do not route back through `/al-code-review`.
- **Stayed/flipped `blocked`:** `Next: /al-research` (BC fact), `/al-grill-adr` (domain term), or `/al-steer` (replan) per why it would not ground.

If state can't be read, fall back to `/al-implement` for a technical task; for a verify task (which reached `/al-refine` only because `/al-code-review` already ran) → `/al-user-verification`, or `/al-steer` when unsure — never back through `/al-code-review`.

## Feed

Three moments narrate to the branch feed. At each, hand `/al-feed` a brief — what happened, why it matters to someone who hasn't read the proof, the kind — and `/al-feed` composes the punchline and layers and appends the card. Fire only on these; the per-question grounding and inline grilling stay silent.

- **decision** — proof structure committed: `Expected Behaviors` vs `Decision Matrix`, `New:` vs `Modified:` objects settled, and the push-up set surfaced.
- **surprise** — unanswerable exit: a needed answer won't ground (or the inline document-integrity check returns a **fail**), so the task stays/flips `blocked` and routes out rather than ship fuzzy proof.
- **landing** — the status flip `ready → ready-for-implementation` / `ready-for-verification`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-scope` or dependency restoration opened one named task to `status: ready` |
| **Hands off to**   | `/al-implement` for `ready-for-implementation` technical tasks; for `ready-for-verification` verify tasks, state-conditional on the slice's recordings — `/al-page-script` (a `Record: yes` recording missing) else `/al-user-verification` (`/al-code-review` already ran at slice-done; the verify task arrives carrying `review: clean`) |
| **Calls directly** | `/al-research` (BC facts), `/al-second-opinion` (non-trivial `Test Specification` / `Verification Plan`) — the only skills it invokes |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-grill-adr` (fuzzy domain term), `/grill-me` (fuzzy intent) |
