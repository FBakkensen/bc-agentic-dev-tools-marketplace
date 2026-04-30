---
name: al-design
description: Idea → feature architecture for AL/Business Central. Names modules under src/, picks one BC pattern per module, draws the R → P → W boundary, lists brownfield touchpoints, decides test layer per scenario family, runs parallel design-twice for non-trivial calls, then creates the branch and writes architecture.md. Use after /al-grill-adr, before /al-scope. Per feature, not per task.
---

# /al-design — Idea → feature architecture

Turn a sharpened idea into a feature-level architecture. Name modules, pick a BC pattern per module, draw R → P → W, list brownfield touchpoints, decide the test layer. Run design-twice for non-trivial calls. Create the branch + spec folder. Write `architecture.md` as a map, not a memoir. Stop — `/al-scope` consumes it next.

**Resolve target paths:**
- **Repo root:** `CONTEXT.md`, `docs/adr/` — durable across features.
- **Spec folder:** `specs/<NNN>-<slug>/architecture.md` — created here.
- **Templates:** `${CLAUDE_SKILL_DIR}/references/*.template.md` — read-only, materialised lazily into the target repo on first need.

## Flow

Prefer parallel subagents for independent work and output-heavy steps.

1. **Precondition.** `/al-grill-adr` must have run for this idea. No exception. If not, `Stop.` and run it first. Grilling outcome (sharpened intent + `CONTEXT.md`/ADR side-effects) feeds step 2.
2. **Repo memory.** Read `CONTEXT.md` (materialise from template if missing). Read all ADRs in `docs/adr/` touching the area.
3. **Module map.** A module is a folder under `src/<module>/` containing the cohesive unit. List modules added/extended/touched.
4. **Pattern per module.** Run `/al-research` first to verify against current BaseApp examples and AppSource rules; pick one pattern from `references/bc-patterns.md`. If a pattern needs explaining, the module shape is wrong — reshape, don't rename.
5. **R → P → W boundary** at feature level. Run `/al-research` first to verify any BaseApp procedure or event signature on the boundary. R = inputs (records, parameters, events). P = pure procedure(s), no DB, no side effects. W = effects (Insert/Modify/Delete, telemetry, errors).
6. **Brownfield touchpoints.** Run `/al-research` first to verify exact procedure / event / table-field names and signatures — stale memory turns the touchpoint list into fiction. List every existing object/procedure to extract, inject seam into, rename, or split.
7. **Test layer per scenario family.** Pure (process layer, no DB) by default. E2E when behaviour is composition or side effect that can't be reproduced at the pure layer. Both only when intent splits cleanly across layers. ZOMBIES sequencing happens in `/al-scope` / `/al-refine`, not here.
8. **Parallel design-twice (gate)** — mandatory for non-trivial. See *Parallel design-twice*.
9. **AppSource compliance check.** Reshape before writing if violated.
10. **ADR offers.** Architectural picks (mechanism, seam placement, pattern, test layer) surface here — see *ADR offer criteria*. If a fresh **domain** rule surfaces, pause and recommend re-running `/al-grill-adr`; do not write a domain ADR inline.
11. **Branch + folder + write.** Already on `^\d{3}-`? `Stop.` — must run from `main`/`master`. Scan `specs/` for `^\d{3}-`, take `max + 1`, zero-pad (`001` if none). Derive a 2–4-word kebab-case slug; do not ask. Announce, then create branch `<NNN>-<slug>` and `specs/<NNN>-<slug>/`. Branch exists locally or remotely? `Stop.` — user resolves. Write `architecture.md` from the template exactly. `Stop.`

## Output — architecture.md

Use `references/architecture.template.md`. Required sections in order: `## Problem`, `## Solution`, `## Module map`, `## R → P → W`, `## Brownfield touchpoints`, `## Test strategy`, `## ADRs cited`, `## Risks`. Optional after `## R → P → W`: `## Module diagram` and/or `## Flow` — gated per template triggers, max 2. **Map, not memoir** — no inline citations, no rationale paragraphs, no `Notes` dumping ground, no future-roadmap sketches. Names are the citation. Rationale lives in ADRs (when load-bearing) or conversation transcript.

## Parallel design-twice (gate)

Non-trivial = multi-module, brownfield refactor, or novel pattern selection. Spawn 3 sub-agents via Agent with divergent constraints:

| Agent | Constraint |
|---|---|
| 1 | Minimise the interface — 1–3 entry points, maximise leverage per entry. |
| 2 | Maximise flexibility — many use cases, easy extension. |
| 3 | Optimise the most common caller — default case trivial. |

Each sub-agent runs its own `/al-research` for any AL/BC behavioural claim. Each outputs: module map + interface per module, usage example, what's hidden behind each seam, trade-offs.

Reconcile: present all three. Compare on depth (leverage at the interface), locality (where change concentrates), seam placement. Recommend one — or a hybrid — with reasoning. Run `/grill-me` when judgement needs the user. **No silent skip.**

Skip when single-module addition, well-known pattern, no brownfield seams. Record the skip reason in the conversation, not the doc.

## ADR offer criteria

Offer only when **all four** are true:

1. **Hard to reverse** — cost of changing later is meaningful.
2. **Surprising without context** — a future reader will wonder why.
3. **Real trade-off** — genuine alternatives, picked one for specific reasons.
4. **Architectural — picks a point in the design space.** Mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`.

Format: `references/adr.template.md` — 1–3 sentence lead, optional sections gated.

## AppSource compliance (state inline)

- No BaseApp modification — intercept via published events, table extensions, or interface implementations.
- Object IDs in registered AppSource range — use `mcp__al-object-id-ninja__ninja_assignObjectId` for new IDs.
- Table-extension fields declare `DataClassification`; never remove or rename a shipped field (obsolete: `Pending` → `Removed`). New table/page/codeunit needs a permission set entry. Every `Caption` ships translatable. Schema migrations live in install/upgrade codeunits.

## Architectural vocabulary (state inline)

Full discipline in `references/LANGUAGE.md`.

- **Module** — folder under `src/<module>/` containing a cohesive unit.
- **Interface** — everything a caller must know: signatures, invariants, ordering, error modes, required setup. Includes but is not limited to AL `interface` objects.
- **Seam** — place where behaviour can be altered without editing in place. Publisher event, AL `interface` boundary, Implementer injection point.
- **Adapter** — concrete codeunit satisfying an interface at a seam. **Two adapters = real seam** — one adapter is hypothetical; don't introduce a port unless production + test justify it.
- **Depth** — leverage at the interface. Deep = a lot of behaviour behind a small interface.

## Lazy template materialisation

| Source (read-only) | Target (writable) | Trigger |
|---|---|---|
| `references/CONTEXT.template.md` | `CONTEXT.md` (repo root) | step 2, if missing |
| `references/adr.template.md` | `docs/adr/NNNN-<slug>.md` | step 10, on ADR accept; `NNNN` = next free 4-digit number |
| `references/architecture.template.md` | `specs/<NNN>-<slug>/architecture.md` | step 11 |

## Naming and vocabulary (state inline)

- **BC verbs:** Insert / Modify / Delete (records — not Create/Update/Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` — suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

`/al-grill-adr` precondition. `/al-research` mandatory at flow steps 4, 5, 6 and inside every design-twice sub-agent. `/bc-standard-reference` reachable directly when the question is purely BaseApp behaviour. `/grill-me` for ADR offers and design-twice reconciliation. `/al-scope` consumes `architecture.md` next.

## Out of scope

- No code edits, no interface extraction (`/al-refactor`), no Gherkin (`/al-refine`), no mutations (`/al-mutate`).
- No per-task architecture (`/al-implement` step 2). No replan gates (`/al-steer`).
