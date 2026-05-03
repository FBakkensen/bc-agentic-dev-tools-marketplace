# {App / Project name}

{One or two sentences: what this AL extension is and why it exists. Plain prose — this is the only narrative section.}

## Language

Project-specific BC vocabulary that goes beyond Microsoft's standard terminology. Standard BC terms (Sales Header, Customer, Posting Date, Ledger Entry, etc.) are the canonical baseline — only record terms here when this project narrows, extends, renames, or names something Microsoft doesn't.

For each term: what it IS, then the aliases to avoid. **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under `_Avoid_:`.

**{Term}**:
{One sentence. What it is, not what it does.}
_Avoid_: {alias 1}, {alias 2}

**{Term}**:
{One sentence.}
_Avoid_: {alias}

**{Term}**:
{One sentence. Define against the BC baseline if this term narrows or extends a Microsoft concept — e.g. *"A **Settlement Batch** is a `Cust. Ledger Entry` selection finalised for export; not the same as a posting batch."*}

## Relationships

Cardinality between project terms. Use bold names. Standard BC relationships (Customer → Sales Header → Sales Line) need not be restated.

- A **{Term A}** produces one or more **{Term B}**.
- A **{Term B}** belongs to exactly one **{Term C}**.
- A **{Term D}** is **closed** when {one phrase}; cannot transition back.

## Example dialogue

A short conversation between a developer and a domain expert that demonstrates how the terms interact and clarifies boundaries between related concepts. The dialogue earns its place when it disambiguates two terms a reader could conflate. Keep it to a handful of turns.

> **Dev:** "When a **{Term A}** is closed, do we automatically create the **{Term B}**?"
> **Domain expert:** "No — a **{Term B}** is only created once a **{Term C}** is confirmed, even if the **{Term A}** is already closed."
> **Dev:** "So a closed **{Term A}** with no **{Term C}** has no **{Term B}** at all?"
> **Domain expert:** "Right — and that's a valid steady state, not an error."

## Flagged ambiguities

Terms used to mean two things, with a stated resolution. Each entry is a one-line *was-conflated → resolved* record.

- *"account"* was used to mean both **Customer** and **G/L Account** — resolved: **Customer** in the sales context, **G/L Account** in the posting context; never bare *"account"*.
- *"batch"* was used to mean both **Settlement Batch** and **Journal Batch** — resolved: distinct concepts; always qualify.

## Notes

- AppSource prefix: `{PRX}` — used on every shipped object.
- Object ID range: `{50100}–{50199}` (or whichever AppSource range is registered).
- Target BC version: {25.0+}.

## Rules

- **Define what it IS, not what it does.** Behaviour belongs in code; the term defines a name.
- **Only project-specific terms.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them. Standard BC terms (Sales Header, Posting Date) don't belong unless this project narrows or extends them. Before adding a term, ask: is this a concept unique to this project's BC overlay, or a general programming / standard-BC concept? Only the former belongs.
- **Group under subheadings** when natural clusters emerge (`### Settlement`, `### Reconciliation`). If all terms belong to a single cohesive area, a flat list is fine.
- **`_Avoid_:` is structural, not optional.** Every term that has plausible synonyms in BC English (or in developer English) gets an `_Avoid_:` line. The aliases are the point — they stop the next contributor from drifting into "transaction" when the project says **Ledger Entry**.
- **Flag conflicts explicitly.** If a term gets used ambiguously in conversation or in the codebase, call it out under `## Flagged ambiguities` with a stated resolution.
- **Show relationships.** Use bold term names and cardinality where obvious.

## Single vs multi-context repos

**Single context (most AL repos):** one `CONTEXT.md` at the repo root.

**Multiple contexts** (e.g. an extension that ships independent features with disjoint vocabulary): a `CONTEXT-MAP.md` at the repo root lists the contexts, where they live, and how they relate.

```md
# Context Map

## Contexts

- [Settlement](./src/settlement/CONTEXT.md) — closes settlement batches and exports to bank file
- [Reconciliation](./src/reconciliation/CONTEXT.md) — matches bank statements against ledger entries

## Relationships

- **Settlement → Reconciliation**: Settlement emits `OnAfterPostSettlement`; Reconciliation consumes it to seed candidates
- **Settlement ↔ Reconciliation**: shared **Settlement No.** identity
```

If `CONTEXT-MAP.md` exists, the skill reads it to find contexts. If only a root `CONTEXT.md` exists, single context. If neither exists, create a root `CONTEXT.md` lazily when the first term is resolved. When multiple contexts exist, infer which one the current topic belongs to; if unclear, ask.
