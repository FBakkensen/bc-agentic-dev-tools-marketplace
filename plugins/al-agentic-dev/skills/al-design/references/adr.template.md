# ADR template

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, …

Create the `docs/adr/` directory lazily — only when the first ADR is needed.

## Template

```md
# {Short title — the decision, not the topic}

{The decision and the hinge of why — recording why the choice was made.}
```

That's it. An ADR can be a single paragraph. The cost to skip is far higher than the cost to write — but the cost to pad is also real.

**Yes/No.**

- No: *"After considering several options including a synchronous call from `Sales-Post` directly into the bank-file emitter, a queued job approach, and an event-driven approach, we ultimately decided that the event-driven approach was the most appropriate given the requirement that a failed emit must not be allowed to roll back the underlying posting transaction, which would have been the case had we chosen the synchronous call. The queued job approach was also considered but rejected because…"*
- Yes: *"Posting flow publishes `OnAfterPostSalesDoc` and the bank-file emitter subscribes — chosen over a synchronous call so a failed emit cannot roll back the posting."*

## Optional sections

Only include these when they earn their place. Most ADRs won't.

**Status** — frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`).
_When earned:_ the decision has been revisited, deprecated, or superseded. Default state needs no line.

**Considered Options** — _When earned:_ a future reader will re-litigate the decision without seeing the alternatives, and the rejected options carry load-bearing reasons. One bullet per option, lead with the option then the reason it lost. _Skip when:_ the alternatives are obvious or the rejection reason is self-evident from the decision.

**Consequences** — _When earned:_ a non-obvious downstream effect exists — typically a `/al-implement` discipline rule the ADR creates ("every new posting routine must register its events on the bridge"), an AppSource compliance constraint, or a migration step. _Skip when:_ the consequence just paraphrases the lead.

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one. Zero-pad to four digits (`0007`, not `7`).

## When to offer an ADR

All four must hold:

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will look at the code or `architecture.md` and wonder *"why on earth did they do it this way?"*
3. **Result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons.
4. **Architectural — picks a point in the design space.** Mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`.

If a decision is easy to reverse, skip it — you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond *"we did the obvious thing."*

### What qualifies (architectural)

- **Architectural shape.** *"This module fronts the subsystem with a Façade — callers must never reach past `Access = Public`."*
- **Pattern selection.** *"Posting flow uses Generic Method, not Template Method, because the posting steps don't share a stable skeleton across documents."*
- **Seam placement.** *"The seam lives at the AL `interface` `IPostingStrategy`, not at a published event, because we need synchronous return values."*
- **Test-layer split.** *"The validation family is Pure-tested through the P layer; E2E only covers the posting wiring."*
- **Brownfield boundaries.** *"We extend `Sales-Post` via `OnAfterInsertSalesInvoiceHeader`; we do not subclass or copy."*
- **Deliberate deviations from the obvious path.** Anything where a reasonable reader would assume the opposite. Stops the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** *"AppSource: cannot persist a new flowfield on `Customer` because the BaseApp ships its own; we use a side table."* *"Performance: posting must finish under 200ms because the partner API contract."*
- **Rejected alternatives when the rejection is non-obvious.** If you considered the Variant Façade and picked plain Façade for subtle reasons, record it — otherwise someone will suggest Variant Façade again in six months.

### What does not qualify

- **Domain rules** — those are `/al-grill-adr`'s territory; they live as terms in `CONTEXT.md` and as domain ADRs offered by that skill.
- **Library or naming choices that are easy to reverse.**
- **Decisions that only restate a BC pattern's contract** — the pattern entry in `bc-patterns.md` is the citation.
