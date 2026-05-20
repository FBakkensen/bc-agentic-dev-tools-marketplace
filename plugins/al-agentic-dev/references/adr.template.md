# ADR template

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, and so on.

Create the `docs/adr/` directory lazily, only when the first ADR is needed.

## Short ADR (default)

Title plus one paragraph. Most ADRs land here.

```md
# {Short title, the decision, not the topic}

{The decision and the hinge of why. One paragraph recording why the choice was made. Linkify inline ADR references as `[ADR-NNNN](NNNN-slug.md)`.}
```

**Yes/No.**

- No: *"After considering several options including a synchronous call from `Sales-Post` directly into the bank-file emitter, a queued job approach, and an event-driven approach, we ultimately decided that the event-driven approach was the most appropriate given the requirement that a failed emit must not be allowed to roll back the underlying posting transaction, which would have been the case had we chosen the synchronous call. The queued job approach was also considered but rejected because..."*
- Yes: *"Posting flow publishes `OnAfterPostSalesDoc` and the bank-file emitter subscribes, chosen over a synchronous call so a failed emit cannot roll back the posting."*

DO NOT add a Status / Date / Supersedes / Superseded-by metadata block. DO NOT add a `docs/adr/README.md` index page. Both are intentional omissions.

## Longer ADR (Considered Options + Consequences)

When the decision earns more structure, lay it out in this order:

```md
# {Short title, the decision, not the topic}

{Decision paragraph(s). Linkify inline ADR references.}

---

## Considered Options

| Option | Verdict | Reason |
|---|---|---|
| {Full option statement} | rejected | {Why this lost} |
| {Full option statement} | accepted | {Why this won} |

## Consequences

{Paragraph or bullets covering the downstream effect downstream skills must surface. Linkify inline ADR references.}

## Related

- [ADR-NNNN](NNNN-slug.md), one-line on why this ADR matters here.
```

## Optional sections, gated

Each section earns its place. The default short shape is correct most of the time.

**Considered Options**: rendered as a 3-column table when earned.

_When earned:_ a future reader will re-litigate the decision without seeing the alternatives, and the rejected options carry load-bearing reasons.
_Skip when:_ the alternatives are obvious or the rejection reason is self-evident from the decision.

When earned, render as a table (Option / Verdict / Reason). Apply even when there is one option in the table; do not invent rejected options to fill rows.

**Consequences**.

_When earned:_ a non-obvious downstream effect that `/al-design` must surface in a slot of `architecture.html` (Module map, Brownfield touchpoints, R→P→W, Test strategy) so downstream skills meet the constraint without re-reading the ADR. Examples: an AppSource compliance constraint, a migration step, an event-registration rule ("every new posting routine must register its events on the bridge").
_Skip when:_ the consequence just paraphrases the lead.

**Related**.

_When earned:_ the ADR body cites other ADRs (`[ADR-NNNN](NNNN-slug.md)` inline). Each bullet quotes the citation plus one phrase on why it matters here.
_Skip when:_ no other ADRs are referenced in the body. Omit the section entirely.

## Supersession

When an ADR is superseded, the new ADR (`ADR-0009`) carries normally. The superseded ADR (`ADR-0003`) gains a `> [!CAUTION]` callout at the very top, before the title-derived prose:

```md
# {Original short title}

> [!CAUTION]
> Superseded by [ADR-0009](0009-slug.md). {One phrase on what changed.}

{The original decision paragraph stays unchanged below.}
```

The callout is the supersession marker. There is no Status block, no Date, no Supersedes/Superseded-by frontmatter. The CAUTION callout is loud enough that a reader landing here from a code citation will not act on stale guidance.

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one. Zero-pad to four digits (`0007`, not `7`).

## When to offer an ADR

All four must hold:

1. **Hard to reverse**: the cost of changing your mind later is meaningful.
2. **Surprising without context**: a future reader will look at the code or `architecture.html` and wonder *"why on earth did they do it this way?"*
3. **Result of a real trade-off**: there were genuine alternatives and you picked one for specific reasons.
4. **Architectural, picks a point in the design space**: mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`.

If a decision is easy to reverse, skip it; you will just reverse it. If it is not surprising, nobody will wonder why. If there was no real alternative, there is nothing to record beyond *"we did the obvious thing."*

### What qualifies (architectural)

- **Architectural shape.** *"This module fronts the subsystem with a Façade; callers must never reach past `Access = Public`."*
- **Pattern selection.** *"Posting flow uses Generic Method, not Template Method, because the posting steps do not share a stable skeleton across documents."*
- **Seam placement.** *"The seam lives at the AL `interface` `IPostingStrategy`, not at a published event, because we need synchronous return values."*
- **Test-layer split.** *"The validation family is Pure-tested through the P layer; E2E only covers the posting wiring."*
- **Brownfield boundaries.** *"We extend `Sales-Post` via `OnAfterInsertSalesInvoiceHeader`; we do not subclass or copy."*
- **Deliberate deviations from the obvious path.** Anything where a reasonable reader would assume the opposite. Stops the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** *"AppSource: cannot persist a new flowfield on `Customer` because the BaseApp ships its own; we use a side table."* *"Performance: posting must finish under 200ms because the partner API contract."*
- **Rejected alternatives when the rejection is non-obvious.** If you considered the Variant Façade and picked plain Façade for subtle reasons, record it. Otherwise someone will suggest Variant Façade again in six months.

### What does not qualify

- **Domain rules**: those are `/al-grill-adr`'s territory; they live as terms in `CONTEXT.md` and as domain ADRs offered by that skill.
- **Library or naming choices that are easy to reverse.**
- **Decisions that only restate a BC pattern's contract**: the pattern entry in `bc-patterns.md` is the citation.
