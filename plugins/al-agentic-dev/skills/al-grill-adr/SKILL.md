---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central. Sharpens BC vocabulary against CONTEXT.md, cross-references intent with the codebase, and offers domain ADRs only when a hard-to-reverse business rule earns one.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-grill-adr, Domain-aware grilling for AL/Business Central

Interview the user about domain intent, one question at a time, cross-referencing the codebase when codebase can answer. Sharpen `CONTEXT.md` until BC vocabulary is unambiguous; offer domain ADRs when constraint is hard to reverse and worth preserving. User-facing journey settlement belongs to `/al-event-model`; architectural picks belong to `/al-design`.

## Artifact boundary

Writes only `CONTEXT.md` and accepted domain ADRs under `docs/adr/`.

May read implementation, app, test, and code artifacts to expose domain conflicts. Never edit them. Never write `event-model.md`, `architecture.md`, or the `tasks/` folder.

Journey pressure → hand off to `/al-event-model`. Architecture, object responsibility, task, proof, or implementation pressure → hand off to `/al-design` or the downstream owning skill.

## Preconditions

- None hard. Run before `/al-design` to crystallise intent, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
- `CONTEXT.md` missing at repo root → materialise from `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` on first term that resolves. `docs/adr/` missing → materialise first ADR from `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` on first accept.

## What goes into CONTEXT.md and domain ADRs

Answer before walking away:

- **Which BC term in this conversation is ambiguous, overloaded, or conflicts with `CONTEXT.md` as written?** Resolve to canonical name. Standard Microsoft BC terms (`Sales Header`, `Customer`, `Posting Date`) are baseline; record only what this project narrows, extends, or names that Microsoft doesn't. Challenge every term the user uses against `CONTEXT.md` and against canonical BC vocabulary; fuzzy `Account` at grilling (Customer? G/L? Bank?) → wrong-table query at `/al-implement` → wrong-test at `/al-mutate`. Update `CONTEXT.md` inline as terms resolve; don't queue, don't couple to implementation details.
- **What concrete scenario forces boundary between two concepts to be precise?** Partial posting, prepayment, reversal, dimension inheritance, multi-company, AppSource constraint. Stress every domain relationship with specific BC scenario; user discovers their own precision when scenario forces yes-or-no.
- **Where does user's stated behaviour disagree with the code?** When codebase can answer, read the code; ask user only what code cannot tell you (intent, future direction, why constraint exists). Surface contradictions; right resolution is user's call, but conflict must be named.
- **Does any domain constraint surfaced here cross the four-of-four ADR bar?** Offer ADR inline when **all four** hold: hard to reverse (shipped data, partner integrations, behavioural contracts); surprising without context; real trade-off with genuine alternatives; domain (rule about *what the business does*, not *how the code is shaped*). "Partial posting allowed for service items only" is domain; "intercept via `OnBeforePostSalesDoc`" is architectural and belongs to `/al-design`. Three of four does not earn an ADR; inflation rots index. When a substantive question feels architectural, find the domain constraint behind it and grill that. Template: `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`. Resolve `NNNN` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md`.
- **Which BC names verified this session?** Every BC-specific term landing in `CONTEXT.md` or domain ADR meets the evidence bar in [voice-contract.md](../../references/voice-contract.md). See *Citation chain in chat* below.

Question stays unanswerable → grilling not done. Keep going, or `/al-research` if gap is BC behavioural fact rather than user intent.

## Citation chain in chat

Evidence bar per [voice-contract.md](../../references/voice-contract.md). `CONTEXT.md` and domain ADRs are durable design artifacts: terms the workspace cannot settle route through `/al-research`, mandatory — vocabulary drift between agents and codebase is what `CONTEXT.md` exists to fix. Research fails → keep grilling; do not write the term or ADR this session.

## Document verification

After writing `CONTEXT.md` or a domain ADR, run `/al-doc-verify` before handing off:

```text
/al-doc-verify --producer al-grill-adr --artifacts CONTEXT.md[,docs/adr/NNNN-slug.md] --handoff al-event-model|al-design
```

`verdict=fail` blocks handoff; fix the structural/boundary issue or route to `/al-steer`. `verdict=warn` does not block; carry the warning in the handoff note. This gate checks document integrity only, not whether the domain rule is right.

## Composition

| | |
|---|---|
| **Runs after**     | `main` (kicks off new feature) or standalone for fuzzy term |
| **Hands off to**   | `/al-event-model` (user/API-facing features) or `/al-design` (backend-only) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/grill-me` (interview the user), `/al-second-opinion` (ADR reconciliation) |
