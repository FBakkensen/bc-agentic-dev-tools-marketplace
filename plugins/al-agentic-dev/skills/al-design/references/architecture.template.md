## Problem

{One sentence. The user-visible gap this feature closes.}

## Solution

{One sentence. What ships, in user-visible terms.}

## Module map

| Module | Status | Pattern | Role |
|---|---|---|---|
| `src/{module-a}/` | new | Façade | {one phrase} |
| `src/{module-b}/` | extended | Generic Method | {one phrase} |

One row per module. No nested bullets. No procedure signatures.

## R → P → W

- **R** — {inputs in 1 line}
- **P** — {pure procedure(s) in 1 line, no DB, no side effects}
- **W** — {effects in 1 line: Insert/Modify/Delete, telemetry, errors}

Three lines. The boundary, not the mechanics. Pseudocode lives in `/al-implement` notes.

## Module diagram (optional — see trigger)

**When earned:** ≥4 modules involved AND at least one non-linear edge (fan-out, fan-in, layered indirection). **Skip** if Module map's Pattern + Role columns already say it. Mermaid `flowchart LR`, ≤12 lines including fences. Names match Module map exactly. Arrow labels only when the verb isn't obvious.

## Flow (optional — see trigger)

**When earned:** temporal ordering text would numerate, branch where the branch is the architectural decision, async handoff, or re-entry into a phase already executed. **Skip** if `## R → P → W` 3-line summary covers it. Mermaid `sequenceDiagram` for actor-call ordering, `flowchart TD` for data-transformation pipelines. ≤15 lines including fences.

When both diagrams earn their place, group them under one `## Diagrams` heading with `### Module diagram` and `### Flow` subsections. When neither earns its place, the section is absent — no empty slot.

## Brownfield touchpoints

| File | Action | Note |
|---|---|---|
| `Foo.Codeunit.al` | extend signature | add `SkipReseed` 5th param + 4-param overload |
| `Bar.Codeunit.al` | new procedure | `RegenerateVariantsInHierarchy(ConfigNo)` |

One row per touchpoint. No rationale.

## Test strategy

| Scenario family | Layer | Lives in |
|---|---|---|
| {family} | Pure | `FooTest.Codeunit.al` |
| {family} | E2E | `BarTest.Codeunit.al` |

ZOMBIES sequencing happens in `/al-scope` / `/al-refine`, not here.

## ADRs cited

- ADR-NNNN — {slug} — {one phrase on relevance}

Link list. Do not quote ADR content.

## Risks

- **AppSource:** {one line, only if non-trivial}
- **Breaking change:** {one line, only if any}
- **Data loss:** {one line, only if any}

Three named slots. Hard cap. No fourth slot. If a risk class doesn't fit, it isn't a risk for this doc.
