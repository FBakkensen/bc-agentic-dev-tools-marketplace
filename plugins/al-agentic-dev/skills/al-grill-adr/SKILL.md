---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central. Sharpens BC vocabulary against CONTEXT.md, cross-references intent with the codebase, and offers domain ADRs only when a hard-to-reverse business rule earns one.
---

# /al-grill-adr, Domain-aware grilling for AL/Business Central

Interview the user about domain intent, one question at a time, cross-referencing the codebase when the codebase can answer. Sharpen `CONTEXT.md` until BC vocabulary is unambiguous; offer domain ADRs when the constraint is hard to reverse and worth preserving. User-facing journey settlement belongs to `/al-event-model`; architectural picks belong to `/al-design`.

## Preconditions

- None hard. Run before `/al-design` to crystallise intent, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
- If `CONTEXT.md` is missing at the repo root, materialise it from `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` on first term that resolves. If `docs/adr/` is missing, materialise the first ADR from `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` on first accept.

## What goes into CONTEXT.md and domain ADRs

Answer these before walking away:

- **Which BC term in this conversation is ambiguous, overloaded, or conflicts with `CONTEXT.md` as written?** Resolve to a canonical name. Standard Microsoft BC terms (`Sales Header`, `Customer`, `Posting Date`) are the baseline; record only what this project narrows, extends, or names that Microsoft doesn't. Challenge every term the user uses against `CONTEXT.md` and against canonical BC vocabulary; a fuzzy `Account` at grilling (Customer? G/L? Bank?) becomes a wrong-table query at `/al-implement`, then a wrong-test at `/al-mutate`. Update `CONTEXT.md` inline as terms resolve; don't queue, don't couple to implementation details.
- **What concrete scenario forces the boundary between two concepts to be precise?** Partial posting, prepayment, reversal, dimension inheritance, multi-company, AppSource constraint. Stress every domain relationship with a specific BC scenario; the user discovers their own precision when the scenario forces a yes-or-no.
- **Where does the user's stated behaviour disagree with the code?** When the codebase can answer, read the code; ask the user only what the code cannot tell you (intent, future direction, why a constraint exists). Surface contradictions; the right resolution is the user's call, but the conflict must be named.
- **Does any domain constraint surfaced here cross the four-of-four ADR bar?** Offer the ADR inline when **all four** hold: hard to reverse (shipped data, partner integrations, behavioural contracts); surprising without context; real trade-off with genuine alternatives; domain (a rule about *what the business does*, not *how the code is shaped*). "Partial posting allowed for service items only" is domain; "intercept via `OnBeforePostSalesDoc`" is architectural and belongs to `/al-design`. Three of four does not earn an ADR; inflation rots the index. When a substantive question feels architectural, find the domain constraint behind it and grill that. Template: `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`. Resolve `NNNN` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md`.
- **Which BC names did you verify this session?** Every BC-specific term landing in `CONTEXT.md` or a domain ADR: backed this session by an `al-symbols-mcp` or `grep` hit, or a `/al-research` citation. Recall does not satisfy. See *Citation chain in chat* below.

If a question stays unanswerable, the grilling is not done. Keep going, or `/al-research` if the gap is BC behavioural fact rather than user intent.

## Citation chain in chat

Before writing any BC-specific term into `CONTEXT.md` or a domain ADR, the term either appears in an `al-symbols-mcp` or `grep` result you ran this session, or is cited via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. The workspace lookup is the empirical anchor; memory of training data or past sessions is not. Vocabulary drift between agents and codebase is what `CONTEXT.md` exists to fix; let the workspace and `/al-research` settle the canonical term. If research fails, keep grilling; do not write the term or the ADR this session. Your confidence about a BC term's standard meaning is not evidence the meaning is right; BC vocabulary drifts across releases and project boundaries. See [voice-contract.md](../../references/voice-contract.md) for prose voice.

## Composition

| | |
|---|---|
| **Runs after**     | `main` (kicks off a new feature) or standalone for a fuzzy term |
| **Hands off to**   | `/al-event-model` (user/API-facing features) or `/al-design` (pure-backend) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/grill-me` (interview the user), `/al-second-opinion` (ADR reconciliation) |
