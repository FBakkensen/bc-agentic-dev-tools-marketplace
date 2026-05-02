---
name: al-design
description: Idea → feature architecture for AL/Business Central. Names modules under src/, picks one BC pattern per module, draws the R → P → W boundary, lists brownfield touchpoints, decides test layer per scenario family, runs parallel design-twice for non-trivial calls, then creates the branch and writes architecture.md. Use after /al-grill-adr, before /al-scope. Per feature, not per task.
---

# /al-design — Idea → feature architecture

Turn a sharpened idea into a feature-level architecture. Name **modules**, pick one BC **pattern** per module, draw R → P → W, list brownfield touchpoints, decide the test layer. Run parallel design-twice for non-trivial calls. Create the branch + spec folder. Write `architecture.md` as a map, not a memoir. Stop — `/al-scope` consumes it next.

This skill produces a slot-fill `architecture.md` whose load-bearing decisions are: which **modules** earn rows, where their **seams** sit, which **adapters** justify each seam, and which test surface each scenario family crosses. Vocabulary is fixed — see *Architectural vocabulary* below and `references/LANGUAGE.md` in full.

**Resolve target paths:**
- **Repo root** — `CONTEXT.md`, `docs/adr/`. Durable across features.
- **Spec folder** — `specs/<NNN>-<slug>/architecture.md`. Created here.
- **Templates** — `${CLAUDE_SKILL_DIR}/references/*.template.md`. Read-only; materialised lazily into the target repo on first need.

## Flow

Prefer parallel sub-agents for independent work and output-heavy steps.

1. **Precondition.** `/al-grill-adr` must have run for this idea. No exception. If not, `Stop.` and run it first. The grilling outcome (sharpened intent + `CONTEXT.md` / domain ADR side-effects) feeds step 2.
2. **Repo memory.** Read `CONTEXT.md` (materialise from template if missing). Read every ADR in `docs/adr/` touching the area. Use the project's domain language throughout the rest of this flow; respect the ADRs.
3. **Module map.** A **module** is a folder under `src/<module>/` containing the cohesive unit. List modules added / extended / touched. **Apply the deletion test** to every candidate row before writing it: imagine deleting the module — if complexity vanishes, it's a pass-through (don't add it); if complexity reappears across N callers, it earns its row. Use **CONTEXT.md vocabulary** for the role — *the `Settlement intake` module*, never *the `FooBarHandler`*. Every new table / page / codeunit will need an AppSource permission-set entry and an ID from the registered range — note this against the row, but the assignment happens in `/al-implement`.
4. **Pattern per module.** Run `/al-research` first to verify against current BaseApp examples and AppSource rules. Pick one pattern from `references/bc-patterns.md`. **Apply the two-adapter rule** to every pattern that implies a seam — Event Bridge, Template Method, Command Queue, AL `interface`-based Façade: name both adapters now (typically production + test, or two real production variants), or change the pattern. One adapter means a hypothetical seam — don't introduce it. If a pattern needs explaining, the module shape is wrong — reshape, don't rename.
5. **R → P → W boundary** at feature level. Run `/al-research` first to verify any BaseApp procedure or event signature on the boundary. **R** = inputs (records, parameters, events subscribed to). **P** = pure procedure(s) — no DB, no side effects; this is the unit-testable surface. **W** = effects (Insert / Modify / Delete, telemetry, errors, events published).
6. **Brownfield touchpoints.** Run `/al-research` first to verify exact procedure / event / table-field names and signatures — stale memory turns the touchpoint list into fiction. List every existing object / procedure to extract, inject seam into, rename, or split. Shipped fields and objects are never removed or renamed in place — `ObsoleteState`: `Pending` → `Removed` over the deprecation window, scheduled in `/al-implement`.
7. **Test layer per scenario family.** Pure (P-layer, no DB) by default — drawing the R → P → W boundary is what makes Pure available. E2E when the behaviour is composition or a side effect that can't be reproduced at the pure layer (event wiring, table triggers, telemetry shape, install/upgrade transitions). `Both` only when intent splits cleanly across layers. ZOMBIES sequencing happens in `/al-scope` / `/al-refine`, not here.
8. **Parallel design-twice (gate)** — mandatory for non-trivial. See *Parallel design-twice*.
9. **AppSource compliance sanity.** Two design-time risks: BaseApp modification (intercept via published events, table extensions, or AL `interface` implementations — never edit in place), and design choices that force a shipped-field rename or removal. Both are reshape triggers. The full compliance block — IDs, permission sets, `DataClassification`, captions, install / upgrade — lives in `/al-implement`, where it bites per task.
10. **ADR offers.** Architectural picks (mechanism, seam placement, pattern, test layer) surface here — see *ADR offer criteria*. If a fresh **domain** rule surfaces, pause and recommend re-running `/al-grill-adr`; do not write a domain ADR inline.
11. **Branch + folder + write.** Already on `^\d{3}-`?
Stop.
Must run from `main` / `master`. Scan `specs/` for `^\d{3}-`, take `max + 1`, zero-pad (`001` if none). Derive a 2–4-word kebab-case slug; do not ask. Announce the branch name and slug, then create branch `<NNN>-<slug>` and `specs/<NNN>-<slug>/`. Branch exists locally or remotely?
Stop.
User resolves. Write `architecture.md` from `references/architecture.template.md`. Slot-fill the gates. Names are the citation.
Stop.

## Output — architecture.md

Use `references/architecture.template.md`. Required sections in order: `## Goal`, `## Problem`, `## Solution`, `## Module map`, `## R → P → W`, `## Brownfield touchpoints`, `## Test strategy`, `## ADRs cited`, `## Risks`. Optional after `## R → P → W`: `## Module diagram` and / or `## Flow` — gated per template triggers, max one of each.

**Map, not memoir.** No inline citations (`(see: file.al:120)` is forbidden — names are the citation). No rationale paragraphs. No `Notes` dumping ground. No future-roadmap sketches. Rationale lives in ADRs (when load-bearing) or in the conversation transcript that produced this doc.

**Sharpness gates, not length caps.** The template states `_When earned:_` / `_Skip when:_` for each section. Slot-fill earns its place by passing the gate; padding to hit a length and stripping to hit a length both miss the point. One paragraph per slot — if a slot needs more, the slot likely splits.

## Parallel design-twice (gate)

Non-trivial = multi-module, brownfield refactor, or novel pattern selection. Spawn 3 sub-agents via the Agent tool with divergent constraints:

| Agent | Constraint |
|---|---|
| 1 | Minimise the **interface** — 1–3 entry points, maximise leverage per entry. |
| 2 | Maximise flexibility — many use cases, easy extension. |
| 3 | Optimise the most common caller — default case trivial. |

Each sub-agent runs its own `/al-research` for any AL/BC behavioural claim. Each receives a brief that includes BC vocabulary from `CONTEXT.md` and architectural vocabulary from `references/LANGUAGE.md`, so all three name things consistently.

**Output contract:** module map + per-module interface, named adapters at every seam, and the one trade-off line that distinguishes this design from the others.

Reconcile: present all three sequentially so the user can absorb each. Then compare in prose along three axes — **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**. Recommend one design — or a hybrid — with reasoning. Be opinionated; the user wants a strong read, not a menu. Run `/grill-me` when judgement needs the user. **No silent skip.**

Skip when single-module addition, well-known pattern, no brownfield seams. Record the skip reason in the conversation, not the doc.

## ADR offer criteria

Offer only when **all four** are true:

1. **Hard to reverse** — cost of changing later is meaningful.
2. **Surprising without context** — a future reader will wonder why.
3. **Real trade-off** — genuine alternatives, picked one for specific reasons.
4. **Architectural — picks a point in the design space.** Mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`.

Format: `references/adr.template.md` — short body, optional sections gated.

## Architectural vocabulary

Full discipline in `references/LANGUAGE.md`.

- **Module** — a folder under `src/<module>/` containing a cohesive unit. _Avoid_: component, service, unit.
- **Interface** — everything a caller must know: signatures, invariants, ordering, error modes, required setup, performance characteristics. Includes — but is much wider than — AL `interface` objects. _Avoid_: API, signature; do not equate the architectural Interface with the AL `interface` keyword.
- **Implementation** — what's inside: codeunit bodies, table triggers, helpers.
- **Seam** — where behaviour can be altered without editing in place. In AL: published events (`OnBefore*` / `OnAfter*` with optional `IsHandled`), AL `interface` boundaries, Implementer codeunit injection points, table-extension fields. _Avoid_: boundary.
- **Adapter** — a concrete codeunit (or implementing codeunit) satisfying an interface at a seam. Names a role, not substance. _Avoid_: class.
- **Depth** — leverage at the interface. Deep = a lot of behaviour behind a small interface; shallow = interface as complex as the implementation.
- **Leverage** / **Locality** — what callers and maintainers respectively get from depth. **Depth produces leverage and locality.**

**Deletion test, two-adapter rule.** Cited in flow steps 3 and 4 above. Both apply at design time: don't add a module that fails the deletion test; don't introduce a seam that doesn't justify two adapters.

## Lazy template materialisation

| Source (read-only) | Target (writable) | Trigger |
|---|---|---|
| `references/CONTEXT.template.md` | `CONTEXT.md` (repo root) | step 2, if missing |
| `references/adr.template.md` | `docs/adr/NNNN-<slug>.md` | step 10, on ADR accept; `NNNN` = next free 4-digit number |
| `references/architecture.template.md` | `specs/<NNN>-<slug>/architecture.md` | step 11 |

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records — not Create / Update / Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"` — suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

- `/al-grill-adr` — precondition.
- `/al-research` — mandatory at flow steps 4, 5, 6, and inside every design-twice sub-agent.
- `/bc-standard-reference` — reachable directly when the question is purely BaseApp behaviour.
- `/grill-me` — for ADR offers and design-twice reconciliation.
- `/al-scope` — consumes `architecture.md` next.
- `/al-steer` — replan venue if a flow gate hard-halts.

## Out of scope

- No code edits, no interface extraction (`/al-refactor`), no Gherkin (`/al-refine`), no mutations (`/al-mutate`).
- No per-task architecture (`/al-implement` step 2).
- No replan gates beyond the precondition (`/al-steer`).
- No domain ADRs inline — those belong to `/al-grill-adr`.
