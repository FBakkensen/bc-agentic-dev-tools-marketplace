---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central. Sharpens BC vocabulary against CONTEXT.md, cross-references intent with the codebase, and offers domain ADRs only when a hard-to-reverse business rule earns one.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-grill-adr, Domain-aware grilling for AL/Business Central

Interview the user about domain intent, one question at a time, cross-referencing the codebase when codebase can answer. Sharpen `CONTEXT.md` until BC vocabulary is unambiguous; offer domain ADRs when constraint is hard to reverse and worth preserving. User-facing journey settlement belongs to `/al-event-model`; architectural picks belong to `/al-design`.

## Preconditions

- None hard. Run before `/al-design` to crystallise intent, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
- `CONTEXT.md` missing at repo root → materialise from `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` on first term that resolves. `docs/adr/` missing → materialise first ADR from `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` on first accept.

## What goes into CONTEXT.md and domain ADRs

Answer before walking away:

- **Which BC term in this conversation is ambiguous, overloaded, or conflicts with `CONTEXT.md` as written?** Resolve to canonical name. Standard Microsoft BC terms (`Sales Header`, `Customer`, `Posting Date`) are baseline; record only what this project narrows, extends, or names that Microsoft doesn't. Challenge every term the user uses against `CONTEXT.md` and against canonical BC vocabulary; fuzzy `Account` at grilling (Customer? G/L? Bank?) → wrong-table query at `/al-implement` → wrong-test at `/al-mutate`. Update `CONTEXT.md` inline as terms resolve; don't queue, don't couple to implementation details.
- **What concrete scenario forces boundary between two concepts to be precise?** Partial posting, prepayment, reversal, dimension inheritance, multi-company, AppSource constraint. Stress every domain relationship with specific BC scenario; user discovers their own precision when scenario forces yes-or-no.
- **Where does user's stated behaviour disagree with the code?** When codebase can answer, read the code; ask user only what code cannot tell you (intent, future direction, why constraint exists). Surface contradictions; right resolution is user's call, but conflict must be named.
- **Does any domain constraint surfaced here cross the four-of-four ADR bar?** Offer ADR inline when **all four** hold: hard to reverse (shipped data, partner integrations, behavioural contracts); surprising without context; real trade-off with genuine alternatives; domain (rule about *what the business does*, not *how the code is shaped*). "Partial posting allowed for service items only" is domain; "intercept via `OnBeforePostSalesDoc`" is architectural and belongs to `/al-design`. Three of four does not earn an ADR; inflation rots index. When a substantive question feels architectural, find the domain constraint behind it and grill that. Template: `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`. Resolve `NNNN` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md`.
- **Which BC names verified this session?** Every BC-specific term landing in `CONTEXT.md` or domain ADR: backed this session by `al-symbols-mcp` / `grep` hit, or `/al-research` citation. Recall does not satisfy. See *Citation chain in chat* below.

Question stays unanswerable → grilling not done. Keep going, or `/al-research` if gap is BC behavioural fact rather than user intent.

## Citation chain in chat

Before writing any BC-specific term into `CONTEXT.md` or a domain ADR, term either appears in `al-symbols-mcp` / `grep` result you ran this session, or cited via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Workspace lookup is empirical anchor; memory of training data or past sessions is not. Vocabulary drift between agents and codebase is what `CONTEXT.md` exists to fix; let workspace and `/al-research` settle canonical term. Research fails → keep grilling; do not write term or ADR this session. Your confidence about BC term's standard meaning is not evidence the meaning is right; BC vocabulary drifts across releases and project boundaries. See [voice-contract.md](../../references/voice-contract.md) for prose voice.

## Composition

| | |
|---|---|
| **Runs after**     | `main` (kicks off new feature) or standalone for fuzzy term |
| **Hands off to**   | `/al-event-model` (user/API-facing features) or `/al-design` (backend-only) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/grill-me` (interview the user), `/al-second-opinion` (ADR reconciliation) |
