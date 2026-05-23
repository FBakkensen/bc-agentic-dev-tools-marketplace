---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central, sharpens BC vocabulary against CONTEXT.md, cross-references stated intent with the codebase, and offers domain ADRs only. Use before /al-event-model (or before /al-design for pure-backend features) to crystallise shared understanding, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
---

# /al-grill-adr, Domain-aware grilling for AL/Business Central

Interview the user about domain intent, one question at a time, cross-referencing the codebase when the codebase can answer. The artifact's job: sharpen `CONTEXT.md` until BC vocabulary is unambiguous and offer domain ADRs when the constraint behind a choice is hard to reverse and worth preserving. User-facing journey settlement belongs to `/al-event-model`; architectural picks belong to `/al-design`; this skill stays in the domain.

`/al-event-model` reads the resulting `CONTEXT.md` and `docs/adr/` next (or `/al-design` directly for pure-backend features).

## Preconditions

- None hard. Run before `/al-design` to crystallise intent, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
- If `CONTEXT.md` is missing at the repo root, materialise it from `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` on first term that resolves. If `docs/adr/` is missing, materialise the first ADR from `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` on first accept. Templates are read, not edited here.

## What goes into CONTEXT.md and domain ADRs

What the durable artifacts need from you, expressed as questions you must have answers to before walking away:

- **Which BC term in this conversation is ambiguous, overloaded, or conflicts with `CONTEXT.md` as written?** Resolve to a canonical name. Standard Microsoft BC terms (`Sales Header`, `Customer`, `Posting Date`) are the baseline; record only what this project narrows, extends, or names that Microsoft doesn't.
- **What concrete scenario forces the boundary between two concepts to be precise?** Partial posting, prepayment, reversal, dimension inheritance, multi-company, AppSource constraint. Stress the relationship until the user is precise about where one concept ends and the next begins.
- **Where does the user's stated behaviour disagree with the code?** Surface the contradiction; do not paper over it. The right resolution is the user's call, but the conflict must be named.
- **Does any domain constraint surfaced here cross the four-of-four ADR bar?** If yes, offer the ADR inline.

If a question stays unanswerable, the grilling is not done. Keep going, or `/al-research` if the gap is BC behavioural fact rather than user intent.

## Disciplines

### BC vocabulary alignment with `CONTEXT.md`

Every term the user uses gets challenged against `CONTEXT.md` and against canonical BC vocabulary. **Why**: domain confusion compounds. A fuzzy `Account` (Customer? G/L? Bank?) at grilling becomes a wrong-table query at `/al-implement`, then a wrong-test at `/al-mutate`. Resolve at the cheapest point. BC verbs (`Post` not `Submit`, `Ledger Entry` not `Transaction`); full canonical list in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`. Update `CONTEXT.md` inline as terms resolve; don't queue. Don't couple `CONTEXT.md` to implementation details.

### Codebase as the answer when it can be

When a question can be answered by reading the code, read the code. **Why**: the user's stated model and the running code drift over time; the grilling's value is in surfacing that drift, not in asking the user to re-derive what already exists. Ask the user only what the code cannot tell you (intent, future direction, why a constraint exists).

### Concrete scenarios over abstract definitions

Stress every domain relationship with a specific BC scenario, not a hypothetical. **Why**: BC's surface area (posting, prepayment, dimensions, multi-company, intercompany, AppSource) is the territory where abstract domain models break. The user discovers their own precision when the scenario forces a yes-or-no.

### `/al-research` before naming any BC term

Before writing a BC term into `CONTEXT.md` or citing BC behaviour in an ADR, verify against current BaseApp. **Why**: AL/BC training data is thin and stale. A renamed event, a removed procedure, a drifted signature lands in `CONTEXT.md` and corrupts every downstream skill that reads it. If research fails, keep grilling, do not write the term or the ADR this session.

### Domain ADR offer criteria

Offer a domain ADR when **all four** are true:

1. **Hard to reverse**: cost of changing the rule later is meaningful (shipped data, partner integrations, behavioural contracts).
2. **Surprising without context**: a future reader will wonder why.
3. **Real trade-off**: genuine alternatives, one picked for specific reasons.
4. **Domain**: it is a rule about *what the business does*, not about *how the code is shaped*. "Partial posting allowed for service items only" is domain; "intercept via `OnBeforePostSalesDoc`" is architectural and belongs to `/al-design`. "Setup must be runtime-configurable per company" is domain; "singleton table vs enum" is architectural.

Three of four does not earn an ADR. **Why**: ADR inflation rots the index; every reader pays the cost of scanning past low-value entries. The Domain criterion is the discriminator from `/al-design`'s otherwise-identical bar. When a substantive question feels architectural, find the domain constraint behind it and grill that, the constraint is the ADR candidate, not the choice. If the question is a genuine architectural pick, say so once and route to `/al-design`.

Template: `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`. Resolve `NNNN` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` (cross-branch scan, not a local-only scan of `docs/adr/`).

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).

Full vocabulary in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`. **Names are the citation.** No inline `(see: file.al:120)` in `CONTEXT.md` or ADRs; the conversation transcript carries the trail.

## Voice contract

Voice for everything written to `CONTEXT.md` and ADRs: `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. Read it before writing.

## Composition

- `/grill-me`, the interview engine this skill wraps with BC domain awareness.
- `/al-research`, mandatory before naming a BC term, disambiguating against BaseApp, or writing an ADR that cites BC facts.
- `/bc-standard-reference`, when the question is purely BaseApp behaviour.
- `/al-event-model`, consumes the resulting `CONTEXT.md` + ADRs next for user/API-facing features.
- `/al-design`, consumes the resulting `CONTEXT.md` + ADRs next for pure-backend features (or after `/al-event-model` for others).
- `${CLAUDE_SKILL_DIR}/../../references/testability-pillars.md`, useful when triaging "is this a domain rule or an architecture/testability concern?" Testability concerns route to `/al-design`, not a domain ADR.

## Out of scope

- No code edits.
- No user-facing journey settlement (Role, Action, Business Event, View, Status). All `/al-event-model`.
- No design picks. Mechanism, module shape, pattern, seam placement, test layer all belong to `/al-design`.
- No architectural ADRs. Only domain ADRs that pass all four gates.
- No architecture writing (`/al-design`), event-model writing (`/al-event-model`), task breakdown (`/al-scope`), branch creation, or mutations (`/al-mutate`).
