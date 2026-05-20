---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central, sharpens BC vocabulary against CONTEXT.md, cross-references stated intent with the codebase, and offers domain ADRs only. Use before /al-design to crystallise shared understanding, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
---

# /al-grill-adr, Domain-aware grilling for AL/Business Central

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-partial-posting-policy.md
│       └── 0002-no-direct-g-l-writes.md
└── app/
```

Create files lazily, only when you have something to write. If no `CONTEXT.md` exists, materialise it from `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` when the first term resolves. If no `docs/adr/` exists, materialise the first ADR from `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` when one is needed. Templates are plugin-level shared resources; reference them, do not edit them here.

Voice contract for everything this skill writes to `CONTEXT.md` and ADRs: `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. Read it before writing.

Run `/al-research` before naming any BC term, before disambiguating against current BaseApp behaviour, and before writing an ADR that cites BC facts. AL/BC training data is thin and stale; verify first. If research fails, keep grilling, do not write the term or the ADR this session.

## During the session

### Challenge against the glossary

When I use a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. *"Your glossary defines `Posting` as the G/L commit step, but you seem to mean document release, which is it?"*

### Sharpen fuzzy language

When I use vague or overloaded BC terms, propose a precise canonical term. *"You're saying `Account`, do you mean the Customer, the G/L Account, or the Bank Account? Those are different tables."*

Use BC vocabulary, not generic programming terms, `Post` not `Submit`, `Ledger Entry` not `Transaction`. Full canonical list at `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`.

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios, partial posting, prepayment, reversal, dimension inheritance, multi-company, AppSource constraint. Force me to be precise about the boundaries between concepts.

### Cross-reference with code

When I state how something works, check whether the code agrees. If you find a contradiction, surface it: *"Your code posts the entire Sales Header, but you just said partial posting is supported per line, which is right?"*

### Update CONTEXT.md inline

Update `CONTEXT.md` inline when a term resolves; don't queue. Use the format at `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md`.

Don't couple `CONTEXT.md` to implementation details. Standard Microsoft BC terms (`Sales Header`, `Customer`, `Posting Date`) are the canonical baseline, record only what this project narrows, extends, or names that Microsoft doesn't.

No inline citations in `CONTEXT.md`. Names are the citation; the conversation transcript carries the trail.

### Sharpen the slice

Before signaling the grilling done, ensure the trigger (page action, subscribed event, API call, install/upgrade hook, Job Queue), command, state change, and confirming view are clear enough that `/al-design` can fill an **Event Modeling slice** (Adam Dymitruk, eventmodeling.org), *trigger → command → event → state → view*, without guessing. If any of those is fuzzy, keep grilling. The slice itself is `/al-design`'s output; this skill's job is to ensure the inputs exist. The trigger source decides the slice pattern (Command / Automation / Translation / View), see `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` *Slice* entry.

### Offer ADRs sparingly

Only offer to create an ADR when **all three** are true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful.
2. **Surprising without context**: a future reader will wonder *"why did they do it this way?"*
3. **Real trade-off**: there were genuine alternatives and you picked one for specific reasons.

If any gate fails, skip. Use the format at `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`. Resolve `NNNN` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` (the cross-branch scan, not a local-only scan of `docs/adr/`).

| Qualifies (domain ADR) | Defers to `/al-design` (architectural) |
|---|---|
| *"Partial posting allowed for service items only, inventory items must post in full."* | *"Intercept via `OnBeforePostSalesDoc`."* |
| *"Setup must be runtime-configurable per company, compile-time enums unacceptable."* | *"Singleton table vs enum."* |
| *"This module's public interface is a stable contract for partner customisations."* | *"Façade with one Implementer."* |

When a design question feels substantive, find the domain constraint behind it and grill that, the constraint is the ADR candidate, not the choice. If the question is a genuine architectural pick, state once: *"That's `/al-design`'s call."* Do not engage further.

## Composition

`/grill-me` is the interview engine; this skill wraps it with BC domain awareness. `/al-research` mandatory before naming a BC term, disambiguating, or writing an ADR. `/bc-standard-reference` reachable directly when the question is purely BaseApp behaviour. `/al-design` consumes the resulting `CONTEXT.md` + ADRs and picks the architecture.

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `testability-pillars.md`, 7 pillars of agent-friendly code; useful when triaging "is this a domain rule or an architecture/testability concern?", testability concerns route to `/al-design`, not a domain ADR.
- `cross-branch-numbering.md`, source-of-truth for picking `NNNN` (ADRs) across parallel branches.

## Out of scope

- No code edits.
- No design picks, mechanism, module shape, pattern, seam placement, test layer all belong to `/al-design`.
- No architectural ADRs, only domain ADRs that pass all three gates. Architectural picks (mechanism, module shape, pattern, seam placement, test layer) defer to `/al-design`; the routing table above shows the split.
- No architecture writing (`/al-design`), task breakdown (`/al-scope`), branch creation (`/al-design`), or mutations (`/al-mutate`).

</supporting-info>
