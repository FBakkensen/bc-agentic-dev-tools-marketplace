# ADR template

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, and so on. Create the `docs/adr/` directory lazily, only when the first ADR is needed.

## Short ADR (default)

Title plus one paragraph. Most ADRs land here.

```md
# {Short title, the decision, not the topic}

{The decision and the hinge of why. One paragraph. Linkify inline ADR references as `[ADR-NNNN](NNNN-slug.md)`.}
```

DO NOT add a Status / Date / Supersedes / Superseded-by metadata block. DO NOT add a `docs/adr/README.md` index page. Both omissions are intentional.

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

- [ADR-NNNN](NNNN-slug.md): one-line on why this ADR matters here.
```

## Supersession

When an ADR is superseded, the new ADR carries normally. The superseded ADR gains a `> [!CAUTION]` callout at the very top:

```md
# {Original short title}

> [!CAUTION]
> Superseded by [ADR-0009](0009-slug.md). {One phrase on what changed.}

{The original decision paragraph stays unchanged below.}
```

The callout is the supersession marker. No Status block, no Date, no frontmatter.

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one. Zero-pad to four digits (`0007`, not `7`).
