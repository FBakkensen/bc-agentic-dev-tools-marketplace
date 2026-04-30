---
name: al-grill-adr
description: Domain-aware grilling for AL/Business Central. Sharpens BC vocabulary against CONTEXT.md, cross-references stated intent with the codebase, and offers ADRs for hard-to-reverse domain or intent decisions — never design picks. Mechanism, module shape, pattern, seam placement, and test layer belong to /al-design. Run before /al-design to crystallise shared understanding. Also standalone-callable mid-feature when a fuzzy term or hidden trade-off surfaces.
---

# /al-grill-adr — Domain-aware grilling

Grill the user about a feature idea. Cross-reference stated intent with `CONTEXT.md` and the codebase. Sharpen fuzzy BC vocabulary inline. Offer ADRs for **domain or intent** decisions that pass all four gates (hard to reverse, surprising without context, real trade-off, constrains design without picking). Update `CONTEXT.md` and `docs/adr/` lazily as decisions crystallise. Architectural picks defer to `/al-design`.

**Resolve target paths:**
- **Repo root:** `CONTEXT.md`, `docs/adr/` — durable across features. Created lazily on first need.
- **Templates:** `${CLAUDE_SKILL_DIR}/../al-design/references/CONTEXT.template.md`, `${CLAUDE_SKILL_DIR}/../al-design/references/adr.template.md` — canonical templates owned by `/al-design`, read in place.

## Flow

**Prefer parallel subagents for independent work.**

1. **Read repo memory.** `CONTEXT.md` if it exists. All ADRs in `docs/adr/` touching the area in question.
2. **Walk the design tree.** Invoke `/grill-me` to interview the user. One branch at a time. Resolve dependencies between decisions one-by-one. For each question, provide a recommended answer.
3. **Sharpen fuzzy terms.** When the user uses a term that conflicts with `CONTEXT.md`, call it out: *"Your glossary defines `<term>` as X, but you seem to mean Y — which is it?"* When a vague or overloaded term appears, propose a precise canonical term: *"You said `account` — do you mean Customer or User?"*
4. **Cross-reference with code.** When the user states how something works, check the code agrees. Surface contradictions: *"Your code posts the entire Sales Order, but you just said partial posting is supported — which is right?"* **Run `/al-research` whenever grilling exposes a fuzzy term against current BC behaviour** — verify the current state before sharpening.
5. **Update `CONTEXT.md` inline** as terms get resolved. Don't batch. **Run `/al-research` before adding any term** — verify whether the term has a canonical Microsoft definition. If yes, prefer the canonical wording and list the project's variant as `_Avoid_`. If no, document as project-specific.
   - If `CONTEXT.md` doesn't exist, materialise from `${CLAUDE_SKILL_DIR}/../al-design/references/CONTEXT.template.md` lazily on first resolved term.
   - **If research fails, do not write the term this session.** Continue grilling ephemerally; the term gets recorded next session when research is available. Don't write unverified terms into a durable doc.
6. **Offer an ADR** when a decision passes all four gates. See *ADR offer criteria*. **Run `/al-research` before offering** — verify the BC facts the ADR will cite (regulatory references, AppSource constraints, table/field names underpinning the rule). An ADR claiming *"posting must remain reversible per <jurisdiction>"* needs the rule verified before being written.
   - On accept: materialise from `${CLAUDE_SKILL_DIR}/../al-design/references/adr.template.md` into `docs/adr/NNNN-<slug>.md`. `NNNN` = next free 4-digit number; scan `docs/adr/` for highest existing.
   - **If research fails, do not write the ADR this session.** Same rule as terms.
7. **Stop.** Hand off to `/al-design` once shared understanding is reached.

## When design surfaces

Design questions surface during grilling — they're tempting because they feel substantive. They're out of scope.

1. **Convert if you can.** Find the domain constraint behind the design question. *"Façade or direct calls?"* usually masks *"why does this module need a stable seam?"*. Grill the constraint; the constraint is the ADR candidate, not the choice.
2. **Defer otherwise.** Genuinely architectural pick (mechanism, module shape, pattern, seam placement, test layer)? State once: *"That's `/al-design`'s call."* Do not engage further. Do not write it down.

`/al-grill-adr` captures the WHY that constrains design. `/al-design` picks the WHAT.

## ADR offer criteria

Offer to record an ADR only when **all four** are true:

1. **Hard to reverse** — cost of changing later is meaningful.
2. **Surprising without context** — a future reader will look at the code and wonder *why*.
3. **Real trade-off** — there were genuine alternatives and you picked one for specific reasons.
4. **Constrains design, doesn't pick.** The decision restricts the design space (a business rule, customer policy, regulatory choice, hard-to-reverse domain commitment) — it does not select a point inside it. Architectural picks (mechanism, module shape, pattern, seam placement, test layer) belong to `/al-design`.

If any of the four is missing, skip. Easy-to-reverse decisions get reversed; non-surprising ones aren't worth recording; if there was no real alternative, there's nothing to remember; if it picks a design point, defer to `/al-design`.

**Format**: `# <Short title>` + 1–3 sentences (context, decision, why). Optional: Status / Considered Options / Consequences when they add genuine value. Most ADRs won't need them.

**Examples that qualify (domain ADRs):**
- *"Partial posting is allowed for service items only — inventory items must post in full."* (business rule; constrains how al-design draws the posting flow without naming a mechanism)
- *"Setup must be runtime-configurable per company — compile-time enums are unacceptable."* (customer policy; constrains data shape al-design picks without naming singleton vs enum)
- *"This module's public interface is a stable contract for partner customisations."* (commitment; constrains seam policy without naming Façade)

Counter-cases that defer to `/al-design`: mechanism (e.g. *"intercept via `OnBeforePostSalesDoc`"*), pattern (e.g. *"Façade with one Implementer"*), data shape (e.g. *"singleton vs enum"*).

## `/al-research` discipline

AL/BC training data is thin and stale — agent prior knowledge is untrusted by default. `/al-research` is **mandatory** before three durable side-effects in this skill: adding a term to `CONTEXT.md` (step 5), offering an ADR (step 6), and grounding a fuzziness disambiguation against current BC state (step 4).

- **No inline citations in `CONTEXT.md` or `docs/adr/`.** Both are durable, read-cold-by-future-engineers documents — citations every line make them unreadable. The discipline is *verify before adding*, not *document where you verified*. Conversation transcript carries the trail.
- **Research failure halts the durable write, not the conversation.** If MCP servers are down or no source has the answer, continue grilling — the user can still sharpen intent — but skip the durable artifact this session. Re-invoke when research is available.
- **Treat your own prior AL knowledge as untrusted** until corroborated. Especially dangerous here: a confidently-wrong term in `CONTEXT.md` poisons every future feature.

## CONTEXT.md discipline

- **Be opinionated.** When multiple words exist for the same concept, pick the canonical one and list the others as aliases to avoid.
- **Flag conflicts explicitly.** If a term is used ambiguously, call it out under "Flagged ambiguities" with a clear resolution.
- **Keep definitions tight.** One sentence max. Define what it IS, not what it does.
- **Show relationships.** Express cardinality where it matters.
- **Project-specific only.** Standard Microsoft BC terms (Sales Header, Customer, Posting Date) are the canonical baseline — only record terms here when this project narrows, extends, or names something Microsoft doesn't.

If `CONTEXT.md` doesn't exist when the first term resolves, create it lazily from the template — don't ask first.

## Naming and vocabulary (state explicitly — do not rely on CLAUDE.md)

- **BC vocabulary:** Insert / Modify / Delete (records — not Create/Update/Remove), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Record variables** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures:** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

- `/grill-me` — the interview engine; this skill wraps it with domain awareness.
- `/al-research` — mandatory before durable writes (step 5: term entry; step 6: ADR offer) and on fuzziness (step 4). See *`/al-research` discipline* above.
- `/bc-standard-reference` — typically reached via `/al-research`; can be invoked directly when the question is purely "what does BaseApp do here?".
- `/al-design` consumes the resulting `CONTEXT.md` + ADRs.

## Out of scope

- No code edits.
- **No design decisions — mechanism, module shape, pattern, seam placement, and test layer all belong to `/al-design`.** When a design question surfaces, convert to its underlying domain constraint or defer; never pick.
- **No architectural ADRs.** Only domain ADRs that pass all four gates. Architectural ADRs surface in `/al-design`.
- No architecture writing — `/al-design`.
- No task breakdown — `/al-scope`.
- No branch creation — `/al-design` does that, after grilling settles.
- No mutations.
