---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central. Sharpens BC vocabulary against CONTEXT.md, cross-references intent with the codebase, and offers domain ADRs only when a hard-to-reverse business rule earns one.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-grill-adr, Domain-aware grilling for AL/Business Central

Interview the user about domain intent, one question at a time, reading the codebase when it can answer. Sharpen `CONTEXT.md` until BC vocabulary is unambiguous; offer domain ADRs when a constraint is hard to reverse and worth preserving.

## Artifact boundary

Writes only `CONTEXT.md` and accepted domain ADRs under `docs/adr/`.

May read implementation, app, test, and code artifacts to expose domain conflicts. Never edit them. Never write `event-model.md`, `architecture.md`, or the `tasks/` folder.

Journey pressure hands off to `/al-event-model`; architecture, object responsibility, task, proof, or implementation pressure to `/al-design` or the downstream owning skill.

## Preconditions

- None hard. Run before `/al-design` to crystallise intent, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
- `CONTEXT.md` missing at repo root → materialise from `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` on first term that resolves. `docs/adr/` missing → materialise first ADR from `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` on first accept.

## What goes into CONTEXT.md and domain ADRs

Answer before walking away:

- **Which BC term here is ambiguous, overloaded, or conflicts with `CONTEXT.md`?** Resolve to a canonical name. Standard Microsoft terms are baseline; record only what this project narrows, extends, or names that Microsoft doesn't. Update `CONTEXT.md` inline as terms resolve; don't couple to implementation details.
- **What concrete BC scenario forces a boundary between two concepts to be precise?** Partial posting, reversal, dimension inheritance, multi-company, AppSource constraint — the user finds their own precision when a scenario forces yes-or-no.
- **Where does the user's stated behaviour disagree with the code?** Read the code when it can answer; ask the user only what code cannot tell (intent, future direction, why a constraint exists). Name the conflict; resolution is the user's call.
- **Does any domain constraint cross the four-of-four ADR bar?** Offer an ADR inline only when **all four** hold: hard to reverse (shipped data, partner integrations, behavioural contracts); surprising without context; real trade-off with genuine alternatives; domain (a rule about *what the business does*, not *how the code is shaped*). Three of four does not earn one — inflation rots the index. When a question feels architectural, grill the domain constraint behind it. Template: `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`; resolve `NNNN` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md`.
- **Which BC names are verified this session?** Every BC-specific term landing in `CONTEXT.md` or a domain ADR meets the evidence bar in [voice-contract.md](../../references/voice-contract.md). See *Citation chain in chat* below.

A question stays unanswerable → grilling is not done. Keep going, or run `/al-research` if the gap is a BC behavioural fact rather than user intent.

## Citation chain in chat

Evidence bar per [voice-contract.md](../../references/voice-contract.md). `CONTEXT.md` and domain ADRs are durable design artifacts, so terms the workspace cannot settle route through `/al-research`, mandatory. Research fails → keep grilling; do not write the term or ADR this session.

## Document verification

After writing `CONTEXT.md` or a domain ADR, run the document-integrity check yourself, inline (no subagent), before handing off — verify the artifact against [`doc-integrity.md`](../../references/doc-integrity.md): structure, link integrity, and sibling consistency for `CONTEXT.md` / ADR profiles.

A **fail** (structural or boundary blocker) blocks handoff; fix it or route to `/al-steer`. A **warn** does not block; carry it in the handoff note. This gate checks document integrity only, not whether the domain rule is right.

## Next step

Idea grilled, `CONTEXT.md` (and any ADR) written and integrity-checked. `Next: /al-event-model` for a user/API-facing feature, or `/al-design` (backend-only) — whichever the feature's surface calls for. Term still unsettled or a behavioural conflict unresolved → `Next: /al-research` (BC fact) or `/al-steer` (decision).

## Composition

| | |
|---|---|
| **Runs after**     | `main` (kicks off new feature) or standalone for fuzzy term |
| **Hands off to**   | `/al-event-model` (user/API-facing features) or `/al-design` (backend-only) |
| **Replan venue**   | `/al-steer` |
| **Calls directly** | `/al-research` (BC facts), `/al-second-opinion` (ADR reconciliation) — the only skills it invokes |
| **Sidebands**      | `/grill-me` (interview the user) |
