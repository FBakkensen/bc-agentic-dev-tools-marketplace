## Goal

{One paragraph in user-visible terms — what the feature delivers. Carries the grilling outcome from /al-grill-adr.}

## Module map

- **`src/{module-a}/`** — {new | extended | touched}. Pattern: {Implementer | Façade | Handled events | Variant Façade | Setup table}. Role: {one-line}.
- **`src/{module-b}/`** — ...

## R → P → W

- **R** = {inputs: records, parameters, events}
- **P** = {pure procedure(s); no DB, no side effects}
- **W** = {effects: Insert / Modify / Delete, telemetry, errors}

## Brownfield touchpoints

- `{File/Codeunit:Procedure}` — {extract | inject seam | rename | split}
- ...

## Test strategy

Likely scenario families (final ZOMBIES sequencing in `/al-scope` + `/al-refine`):

- **{family 1 — short}**: Pure
- **{family 2 — short}**: E2E
- **{family 3 — short}**: Both

## ADRs cited

- ADR-NNNN — {slug} — {one-line on relevance}

## Notes

- {one-line constraint, AppSource flag, breaking-change risk, design-twice skip reason — only when needed}
