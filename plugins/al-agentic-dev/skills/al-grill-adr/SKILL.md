---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central — sharpens BC vocabulary against CONTEXT.md, cross-references stated intent with the codebase, and offers domain ADRs only (architectural picks defer to /al-design). Use before /al-design to crystallise shared understanding, or standalone mid-feature when a fuzzy term or hidden trade-off surfaces.
---

# /al-grill-adr — Domain-aware grilling

Grill the user about a feature idea. Cross-reference stated intent with `CONTEXT.md` and the codebase. Sharpen fuzzy BC vocabulary inline. Offer ADRs only for **domain or intent** decisions that pass all four gates. Update `CONTEXT.md` and `docs/adr/` lazily as decisions crystallise. Architectural picks defer to `/al-design`.

**Resolve target paths:**
- **Repo root:** `CONTEXT.md`, `docs/adr/` — durable across features, materialised lazily on first need.
- **Templates:** `${CLAUDE_SKILL_DIR}/../al-design/references/CONTEXT.template.md`, `${CLAUDE_SKILL_DIR}/../al-design/references/adr.template.md` — owned by `/al-design`, read in place.

## Flow

Prefer parallel subagents for independent work.

1. **Read repo memory.** `CONTEXT.md` if it exists. All ADRs in `docs/adr/` touching the area.
2. **Walk the design tree.** Invoke `/grill-me` to interview the user, one branch at a time, resolving dependencies between decisions one-by-one. Provide a recommended answer for each question.
3. **Sharpen fuzzy terms.** When a term conflicts with `CONTEXT.md`, surface it: *"Your glossary defines `<term>` as X, but you seem to mean Y — which is it?"*. When a vague or overloaded term appears, propose a precise canonical term. **Run `/al-research` before disambiguating against current BC state** — verify the current state, then sharpen.
4. **Cross-reference with code.** When the user states how something works, check the code agrees. Surface contradictions: *"Your code posts the entire Sales Order, but you just said partial posting is supported — which is right?"*.
5. **Update `CONTEXT.md` inline** as terms get resolved — don't batch. **Run `/al-research` before adding any term** — verify whether a canonical Microsoft definition exists; if yes, prefer it and list the project's variant as `_Avoid_`. Materialise from template on first resolved term. **If research fails, do not write the term this session** — continue grilling ephemerally; record next session.
6. **Offer an ADR** when the decision passes all four gates — see *ADR offer criteria*. **Run `/al-research` before offering** — verify the BC facts the ADR will cite (regulatory references, AppSource constraints, table/field names underpinning the rule). On accept: materialise from `${CLAUDE_SKILL_DIR}/../al-design/references/adr.template.md` into `docs/adr/NNNN-<slug>.md`; `NNNN` = next free 4-digit number. **If research fails, do not write the ADR this session.**
7. **Stop.** Hand off to `/al-design` once shared understanding is reached.

## When design surfaces

Design questions feel substantive but are out of scope.

- **Convert if you can.** Find the domain constraint behind the design question. *"Façade or direct calls?"* usually masks *"why does this module need a stable seam?"* — grill the constraint; the constraint is the ADR candidate, not the choice.
- **Defer otherwise.** Genuine architectural pick (mechanism, module shape, pattern, seam placement, test layer)? State once: *"That's `/al-design`'s call."* Do not engage further. Do not write it down.

`/al-grill-adr` captures the WHY that constrains design. `/al-design` picks the WHAT.

## ADR offer criteria

Offer only when **all four** are true:

1. **Hard to reverse** — cost of changing later is meaningful.
2. **Surprising without context** — a future reader will look at the code and wonder *why*.
3. **Real trade-off** — genuine alternatives, picked one for specific reasons.
4. **Constrains design, doesn't pick.** The decision restricts the design space (business rule, customer policy, regulatory choice, hard-to-reverse domain commitment) — it does not select a point inside it. Architectural picks (mechanism, module shape, pattern, seam placement, test layer) belong to `/al-design`.

If any gate fails, skip. Easy-to-reverse decisions get reversed; non-surprising ones aren't worth recording; absent a real alternative there's nothing to remember; if it picks a design point, defer.

Format per `${CLAUDE_SKILL_DIR}/../al-design/references/adr.template.md` — 1–3 sentence lead, optional sections gated.

| Qualifies (domain ADR) | Defers to `/al-design` (architectural) |
|---|---|
| *"Partial posting allowed for service items only — inventory items must post in full."* | *"Intercept via `OnBeforePostSalesDoc`."* |
| *"Setup must be runtime-configurable per company — compile-time enums unacceptable."* | *"Singleton table vs enum."* |
| *"This module's public interface is a stable contract for partner customisations."* | *"Façade with one Implementer."* |

## CONTEXT.md discipline

- **One sentence per term.** Define what it IS, not what it does.
- **Be opinionated.** Pick the canonical word; list the others as aliases to avoid.
- **Flag conflicts explicitly.** Ambiguous use → call it out under "Flagged ambiguities" with a clear resolution.
- **Show relationships.** Express cardinality where it matters.
- **Project-specific only.** Standard Microsoft BC terms (Sales Header, Customer, Posting Date) are the canonical baseline — record only what this project narrows, extends, or names that Microsoft doesn't.

Materialise `CONTEXT.md` lazily from the template on first resolved term — don't ask first.

## Durable writes

Plugin-wide rule applies: **no inline citations in `CONTEXT.md` or `docs/adr/`** — verify before adding; the conversation transcript carries the trail; names are the citation. AL/BC training data is thin and stale — treat your own prior AL knowledge as untrusted until corroborated. A confidently-wrong term in `CONTEXT.md` poisons every future feature.

## Naming and vocabulary (state inline)

- **BC verbs:** Insert / Modify / Delete (records — not Create/Update/Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` — suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

`/grill-me` is the interview engine; this skill wraps it with domain awareness. `/al-research` mandatory at flow steps 3 (fuzziness disambiguation), 5 (term entry), 6 (ADR offer). `/bc-standard-reference` reachable directly when the question is purely BaseApp behaviour. `/al-design` consumes the resulting `CONTEXT.md` + ADRs.

## Out of scope

- No code edits.
- No design decisions — mechanism, module shape, pattern, seam placement, test layer all belong to `/al-design`. Convert design questions to their underlying domain constraint, or defer; never pick.
- No architectural ADRs — only domain ADRs that pass all four gates.
- No architecture writing (`/al-design`), task breakdown (`/al-scope`), branch creation (`/al-design`), or mutations (`/al-mutate`).
