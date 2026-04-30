---
name: al-design
description: Turn a feature idea into a feature-level architecture for AL/Business Central. Names modules under src/, picks BC patterns, draws the Read → Process → Write boundary, lists brownfield touchpoints, decides test strategy per scenario family, runs parallel design-twice for non-trivial calls, then creates the branch and writes architecture.md. Always preceded by /al-grill-adr. Run before /al-scope. Use per feature, not per task.
---

# /al-design — Idea → feature architecture

Turn a sharpened feature idea into a feature-level architecture document. Read `CONTEXT.md` and any ADRs touching the area. Name modules under `src/<module>/`, pick BC patterns, draw the Read → Process → Write boundary at feature level, list brownfield touchpoints, decide the test layer per likely scenario family. Run parallel design-twice for non-trivial calls. Create the branch + spec folder. Write `architecture.md`. Stop — `/al-scope` consumes it next.

**Resolve target paths:**
- **Repo root:** `CONTEXT.md`, `docs/adr/`, `.out-of-scope/` — durable across features.
- **Spec folder:** `specs/<NNN>-<slug>/architecture.md` — created here.
- **Templates:** `${CLAUDE_SKILL_DIR}/references/*.template.md` — read-only, materialised lazily into the target repo on first need.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Precondition: `/al-grill-adr` must run first.** Every `/al-design` session is preceded by a domain-aware grilling session for the current idea — there is no "trivial enough to skip" exception. Read prior conversation. If `/al-grill-adr` has not run for this idea, stop and run it first. The grilling outcome (sharpened intent + any `CONTEXT.md` / ADR side-effects) is the input to step 2.
2. **Repo memory.** Read `CONTEXT.md` (if missing, materialise from template — see *Lazy template materialisation*). Read all ADRs in `docs/adr/` touching the affected area.
3. **Module map.** A module is a folder under `src/<module>/` containing the complete cohesive unit (codeunits, tables, pages, permissions, etc.). List modules added / extended / touched. Use the architectural vocabulary stated below.
4. **Pattern per module.** **Run `/al-research` first** — verify the candidate pattern against current BaseApp examples and confirm any BC-specific constraints (event signatures, AppSource rules) before naming it. Pick one pattern per module from `${CLAUDE_SKILL_DIR}/references/bc-patterns.md`. Common at feature level: Façade, Event Bridge, Generic Method, Template Method, Error Handling. Specialised: API Register Fieldset, Delegate API Operation, Command Queue, No. Series. If a pattern needs explaining, it's wrong for AL — pick a different one or reshape the module.
5. **R → P → W boundary** at feature level. **Run `/al-research` first** for any BaseApp procedure or event you intend to position on the boundary — verify the signature, ordering, and side effects before drawing R / P / W. R = inputs (records, parameters, events). P = pure procedure(s) that don't touch DB or side effects. W = effects (Insert / Modify / Delete, telemetry, errors).
6. **Brownfield touchpoints.** **Run `/al-research` first** to verify exact procedure / event / table-field names and signatures for every existing object you plan to extract, seam, rename, or split. Stale memory of a procedure name turns the touchpoint list into fiction. List every existing object/procedure needing extract / inject seam / rename / split.
7. **Test strategy per likely scenario family.** Pure (process layer, no DB) by default; E2E when behaviour is composition or side effect that can't be reproduced at the pure layer; Both only when the same intent splits cleanly across layers. Final ZOMBIES sequencing happens later in `/al-scope` + `/al-refine`.
8. **Parallel design-twice (gate)** — mandatory for non-trivial. See *Parallel design-twice* below.
9. **AppSource compliance check** — see *AppSource compliance* below. Reshape before writing if violated.
10. **ADR offers.** Domain ADRs came from `/al-grill-adr`. This is where **architectural** ADRs surface — design-twice often exposes a fresh hard-to-reverse pick (mechanism, seam placement, pattern). Offer ADR creation — see *ADR offer criteria*. If a fresh **domain** constraint surfaces during design-twice (a business rule the user hadn't named), pause and recommend re-running `/al-grill-adr` to capture it; do not write a domain ADR inline.
11. **Branch & folder.**
    - Already on a branch matching `^\d{3}-`? → stop: `/al-design` must run from `main`/`master` or an unscoped branch.
    - Determine next sequence: scan `specs/` for folders matching `^\d{3}-`, take `max + 1`, zero-pad (`001` if none).
    - Derive a concise kebab-case slug (2–4 words) from the design. Do not ask — name from context.
    - Announce: "Creating branch `<NNN>-<slug>` and `specs/<NNN>-<slug>/architecture.md`."
    - If the branch exists locally or remotely → stop: user must resolve.
    - Create and switch to branch `<NNN>-<slug>`. Dirty working tree is fine.
    - Create folder `specs/<NNN>-<slug>/`.
12. **Write** `specs/<NNN>-<slug>/architecture.md` using `${CLAUDE_SKILL_DIR}/references/architecture.template.md` as the structure. Every behavioural AL/BC claim — event signature, BaseApp procedure, codeunit name, AppSource rule — carries an inline citation `(see: <source>)` from the `/al-research` findings. General design language doesn't need citations; AL/BC facts do. Stop.

## architecture.md structure

See `${CLAUDE_SKILL_DIR}/references/architecture.template.md` for the canonical shape. Sections: `## Goal`, `## Module map`, `## R → P → W`, `## Brownfield touchpoints`, `## Test strategy`, `## ADRs cited`, `## Notes`.

## Pattern catalogue

See `${CLAUDE_SKILL_DIR}/references/bc-patterns.md` for the nine canonical BC/AL patterns: Façade, Event Bridge, Generic Method, Template Method, Error Handling, API Register Fieldset, Delegate API Operation, Command Queue, No. Series. Pick one per module. If the module's responsibility doesn't match any pattern, the module shape is probably wrong — reshape before naming a pattern.

## `/al-research` discipline

AL/BC training data is thin and stale — agent prior knowledge is untrusted by default. `/al-research` is **mandatory** at three decision points in this skill (steps 4, 5, 6 above) and **inherited by every parallel design-twice sub-agent**.

- **What to research per call:** the focused question for that step. Pattern choice → BaseApp examples + AppSource rules. R→P→W → procedure / event signatures and side effects on the boundary. Brownfield touchpoints → exact names and signatures of every object you plan to touch.
- **Source priority** (from `/al-research`): AL symbols → `/bc-standard-reference` → bc-knowledge MCP → Microsoft Learn → context7 → web. Stop at the first source that answers definitively.
- **Cite every behavioural AL/BC claim** in `architecture.md` inline `(see: <source>)`. Skip citations for general design language.
- **Treat your own prior AL knowledge as untrusted** until corroborated. The whole point of this discipline is catching the things you would have confidently written down without checking.

## Parallel design-twice (gate)

For non-trivial calls (multi-module, brownfield refactor, novel pattern selection), spawn 3 sub-agents in parallel via the Agent tool with divergent design constraints:

- **Agent 1**: minimise the interface — 1–3 entry points max, maximise leverage per entry.
- **Agent 2**: maximise flexibility — many use cases, easy extension.
- **Agent 3**: optimise for the most common caller — default case trivial.

**Each sub-agent runs its own `/al-research` for any AL/BC behavioural claim it makes** — sub-agents inherit the same stale-knowledge problem. Their output cites sources for AL/BC facts, same as the main thread.

Each sub-agent outputs: module map + interface per module, usage example, what the implementation hides behind each seam, trade-offs.

**Reconcile:** present all three. Compare on depth (leverage at the interface), locality (where change concentrates), seam placement. Recommend one — or a hybrid — with reasoning. **No silent skip.** Run `/grill-me` when judgement needs the user.

**Skip when:** single-module addition, well-known pattern, no brownfield seams. Record `Design-twice skipped: <reason>` in `architecture.md` Notes.

## Architectural vocabulary (state inline)

Use these terms exactly. Full discipline in `${CLAUDE_SKILL_DIR}/references/LANGUAGE.md`.

- **Module** — a folder under `src/<module>/` containing a cohesive unit. The whole feature lives inside the same AL app.
- **Interface** — everything a caller must know: signatures, invariants, ordering, error modes, required setup. Includes but is not limited to AL `interface` objects.
- **Seam** — a place where behaviour can be altered without editing in place. Publisher event, AL `interface` boundary, Implementer injection point.
- **Adapter** — a concrete codeunit satisfying an interface at a seam.
- **Depth** — leverage at the interface. Deep = a lot of behaviour behind a small interface. Shallow = interface as complex as the implementation.
- **Deletion test** — imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep. Doesn't apply when the seam is a published event with no in-tree callers.
- **Two test surfaces.** External seam (`Access = Public`) for integration / E2E tests; internal procedures for unit tests, especially the P (pure process) layer of R→P→W. Tests inside the module are first-class, not a smell — Microsoft's BaseApp tests reach into internals routinely.
- **Two adapters = real seam.** One adapter is a hypothetical seam — don't introduce a port unless at least two adapters justify it (typically production + test).

## ADR offer criteria

Offer to record an ADR only when **all four** are true:
1. **Hard to reverse** — cost of changing later is meaningful.
2. **Surprising without context** — a future reader will wonder why.
3. **Real trade-off** — genuine alternatives, picked one for specific reasons.
4. **Architectural — picks a point in the design space.** Mechanism, module shape, pattern, seam placement, test layer. Domain rules (business rules, customer policy, regulatory choice) belong to `/al-grill-adr` — pause and recommend re-running it instead of writing inline.

If any is missing, skip. Format: `# <Short title>` + 1–3 sentences (context, decision, why). Template: `${CLAUDE_SKILL_DIR}/references/adr.template.md`.

## AppSource compliance (state inline — applies to design)

- No BaseApp modification — intercept via published events, table extensions, or interface implementations.
- Object IDs must be in the registered AppSource range — use `mcp__al-object-id-ninja__ninja_assignObjectId` when assigning new IDs; never collide.
- Table-extension fields declare `DataClassification`; never plan to remove or rename a shipped field — obsolete via `ObsoleteState = Pending` then `Removed`.
- Every new table/page/codeunit needs a permission set entry.
- Every `Caption` ships translatable.
- Schema migrations live in install/upgrade codeunits — flag if the design implies one.

If the design violates any of the above, reshape before writing `architecture.md`. Flag breaking-change risk and data-loss risk in the Notes section.

## Lazy template materialisation

On first need, copy templates from `${CLAUDE_SKILL_DIR}/references/` into the target repo:

| Source (read-only) | Target (writable) | Trigger |
|---|---|---|
| `references/CONTEXT.template.md` | `CONTEXT.md` (repo root) | step 2, if missing |
| `references/adr.template.md` | `docs/adr/NNNN-<slug>.md` (repo root) | step 10, on ADR accept; `NNNN` = next free 4-digit number |
| `references/architecture.template.md` | `specs/<NNN>-<slug>/architecture.md` | step 12 |

Tool-agnostic: use Bash, PowerShell, or Write — whichever fits the platform. `${CLAUDE_SKILL_DIR}` resolves to this skill's folder.

## Naming and vocabulary (state explicitly — do not rely on CLAUDE.md)

- **BC vocabulary:** Insert / Modify / Delete (records — not Create/Update/Remove), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Record variables** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures:** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

- `/al-grill-adr` — required precondition (CONTEXT.md and ADRs from the grilling).
- `/al-research` — mandatory at steps 4, 5, 6 and inside every design-twice sub-agent. See *`/al-research` discipline* above.
- `/bc-standard-reference` — typically reached via `/al-research`; can be invoked directly when the question is purely "what does BaseApp do here?".
- `/grill-me` for ADR offers and design-twice reconciliation.
- `/al-scope` consumes `architecture.md` next.

## Out of scope

- No code edits.
- No interface extraction yet — `/al-refactor`.
- No Gherkin or scenario detail — `/al-refine`.
- No mutations.
- No per-task architecture — that's absorbed into `/al-implement` step 2.
- No replan gates — replan venue is `/al-steer`. Per-task replan gates fire later, in `/al-refine`, `/al-implement`, `/al-refactor`.
