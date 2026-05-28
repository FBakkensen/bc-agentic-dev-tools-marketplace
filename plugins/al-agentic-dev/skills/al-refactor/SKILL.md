---
name: al-refactor
description: Reshape AL/Business Central production and test code while tests stay green, via four parallel lens sub-agents then serial apply with `/al-build` between. Use after green inside `/al-implement` (full task diff, once per task) or standalone on legacy code.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-refactor, Improve shape while green

Reshape AL so modules that earn their keep deepen and the ones that don't dissolve. Observable behaviour does not change. 4 lenses identify; main session merges, dedupes, applies serially with `/al-build` between.

## Preconditions

- Build green. Refactor against red build is debug → belongs in `/al-implement`.
- Called from `/al-implement` after green on current task, OR standalone on legacy code.
- Standalone: branch matches `^\d{3}-` with `specs/<branch>/tasks.md`, OR pure legacy reshape with no calling task. Calling task `blocked` → run `/al-steer`.
- Legacy-code mode (no covering tests): write baseline tests first; reshape without regression signal is speculation. See [legacy-refactor-plan.md](references/legacy-refactor-plan.md).

## What you answer before reshape

- **What seam is being introduced, hardened, or dissolved?** Name mechanism (publisher event, AL `interface`, `Implementation` enum, internal helper) and adapters that justify it.
- **Where does R → P → W cut in this area?** R = reads / events subscribed. P = pure procedure, unit-test surface. W = effects.
- **Which names lie?** Name lies when it describes generic operation while body does BC-specific one, when it uses CRUD vocabulary where BC verb exists, when project's `CONTEXT.md` term has drifted out of code.
- **What crosses a published API?** Constrains rename, removal, signature change.
- **Does reshape surface new behaviour or hidden requirement?** Yes → route the discovery; do not absorb.
- **Which BC names verified this session?** Every BC-specific name a rename pulls from outside codebase (verb picked because "Insert is right for Customer", BaseApp subscriber signature, System Application call): backed this session by `al-symbols-mcp` / `grep` hit, or `/al-research` citation. Recall does not satisfy. See *Lens 4 citation chain* below.

Unanswerable from the diff → area not ready. Resolve via `/al-research`, `/al-grill-adr`, or `/al-steer`.

Architectural vocabulary (Module, Interface, Implementation, Seam, Adapter, Depth, Leverage, Locality) in [LANGUAGE.md](../../references/LANGUAGE.md). Use exactly.

## Lenses

Spawn 4 lens sub-agents in parallel on the task diff. Each returns reshape opportunities; main session merges into one ordered apply queue.

| # | Lens | Focused goal |
|---|---|---|
| 1 | **Simplify / dedup** *(primary)* | Duplication, dead code, redundant procedures, simplification, inline candidates. Pass-throughs dissolve; primitives carrying meaning become small records or enums |
| 2 | **BC best-practice** via bc-knowledge | Per [bc-knowledge-dispatch.md](../../references/bc-knowledge-dispatch.md): `ask_bc_expert(autonomous_mode=false)` per touched file, threshold `>= 70`, cache `get_bc_topic` within run. MCP names topics; lens applies `anti_pattern_indicators` |
| 3 | **Structural shape** | R → P → W boundary, depth over indirection, seam introduction. Disciplines below carry substance |
| 4 | **Naming** | Objects, procedures, variables, fields, parameters in BC vocabulary AND project terminology per `CONTEXT.md`, ADRs, `architecture.md`, `event-model.md` |

Lens 1 typically dominates queue; Lens 2 surfaces small number of high-value BC fixes; Lens 3 reshapes are fewer but load-bearing; Lens 4 finds renames the others miss because they read code without the BC-vocabulary lens.

## Apply discipline

One reshape at a time, `/al-build` after each. Red → revert that step; recover before next. Renames and seam-introduction land before dedup (touch many call sites, conflict otherwise). Lens 1 dead-code removal usually batches safely; Lens 3 structural reshape lands one at a time. `/al-second-opinion` when apply queue is non-trivial.

## Lens 1, simplify and dedup

**Deletion test on every shallow module.** Imagine deleting the module. Complexity vanishes → module was pass-through; inline at call sites and remove. Complexity reappears across N callers → module earned its place; deepen it. One-line wrapper around `SalesHeader.Modify` that adds only a name is the canonical case for inline.

**Tests are first-class.** Production and tests refactor together. Tests survive internal refactors because they assert on observable outcomes through the interface, not internal state. New tests for branches reshape uncovers must pass against *current* code first → regression signal stays honest. Unit tests on modules the refactor merges away get deleted, not layered.

## Lens 2, BC-specific via bc-knowledge

`autonomous_mode=false` always: mode returns persona + topic recs, sub-agent applies. Threshold `>= 70` keeps cost per TDD cycle low. Cache topics within one lens run, fresh fetch across invocations. Non-structural concerns the MCP surfaces (AppSource compliance, publisher/subscriber contracts beyond structural reshape) belong to `/al-code-review`; surface as out-of-scope notes in calling task block, do not act here. Vanilla cannot replace this: `SetLoadFields` after `SetRange` is syntactically valid call that BC's query-execution order makes ineffective.

## Lens 3, structural shape

**R → P → W as reshape, not annotation.** Procedure mixes I/O and computation → splitting along that line *is* the refactor. P is the most load-bearing line: it names what is testable without a real database. Annotating without splitting changes nothing.

**Two adapters or no seam.** Seam with one adapter is tautology; codeunit only pretends to be flexible. Production + in-memory test adapter that actually exists counts as two. Two real production transports already deployed counts. "Interface for testability" with no test fake written is one. AL `interface`, `Implementation` enums, and event publishers are seam *mechanisms*; picking among them is separate from whether seam earns its place.

**Depth over indirection.** Deep module hides much behaviour behind small interface. Long procedures break into private helpers behind `Access = Internal`. Feature-envious procedures move to where data lives. Primitive obsession (`Code[20]` carrying meaning) becomes small record or enum.

**Internal seams stay internal.** Unit test reaching past `Access = Internal` signals responsibility sits on wrong codeunit, not that `Access` should widen. Split into smaller internal codeunit so surface tells the truth. E2E crosses `Access = Public` and survives internal refactor; unit tests live alongside the implementation against `Access = Internal`.

**Introduce seams before injecting.** Order: extract internals behind new interface → ship the interface → inject the adapter. Injecting first strands existing callers with half-built seam; build goes red and stays red. Three default seams (`IEnvironment`, `IApiRequest`, `IFinance`-family), temp-record alternative, full three-phase decoupling live in [testability.md](../../references/testability.md). Name an existing pattern before extracting a fresh one.

## Lens 4, naming

Rename when name lies. BC verbs over generic CRUD; objects `"Prefix Feature Suffix"`. Project terminology in `CONTEXT.md` (`## Language`, `## Flagged ambiguities`); multi-context repos consult `CONTEXT-MAP.md`. User/API-facing features: canonical Role / Action / Business Event / View names from `event-model.md` already live in code via `/al-refine` and `/al-implement`; preserve verbatim.

Scope: objects, procedures, parameters, variables, record vars, table fields, page actions, publishers, subscribers, captions, labels. Nothing escapes by being "small".

Rename safety: editing a test name or `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` triggers Gherkin re-verification; intent shift → update via `/al-refine` in the same change. `[HandlerFunctions('...')]` strings are invisible to symbol tools; grep before any test-procedure rename per [tdd.md](../../references/tdd.md).

Citation chain: when rename pulls a BC name from outside codebase (verb picked because "Insert is right for Customer", BaseApp subscriber signature, System Application call), name either appears in `al-symbols-mcp` / `grep` result you ran this session, or cited via `/al-research`: `Researched: <name> → <source>` before rename lands. Workspace lookup is empirical anchor; memory of training data or past sessions is not. Your confidence about whether "Insert" or "Create" is the BC-correct verb is not evidence either is right. This is exactly where confidently-wrong verb corrupts every downstream artifact.

## Cross-cutting

**Comments earn their place.** Comment lands only when *why* is non-obvious from BC vocabulary and surrounding code; restating what code already says rots the moment behaviour drifts.

| | Comment |
|---|---|
| _Avoid_ | `// Insert the customer record` before `Customer.Insert(true);` |
| Use | `// BaseApp Codeunit 80 fires OnAfterPostSalesDoc twice for partial shipments, guard against double-post` |

**AppSource compliance.** Never rename a shipped object, table field, page action, or procedure other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce new name alongside. No BaseApp modification. Internal-only symbols rename freely.

**Replan when reshape surfaces architectural gaps.** Missing module, pattern conflict, unnamed brownfield touchpoint, R → P → W boundary cutting across tasks, sibling task whose description the reshape invalidates → **Stop**. Code stays green; halt is on planning. Route to `/al-steer`.

**No new behaviour.** Diff leaves observable behaviour identical. New behaviour belongs to `/al-implement` (new task) or `/al-refine` (re-plan).

Standalone mode emits Gate report once at module / pattern / seam altitude (not procedure level), naming application invariant preserved and user's call; inside `/al-implement`, findings fold into the scenario's Gate report. `/al-refactor` does not edit `architecture.md` and writes no Notes by default; `tasks.md` touched only when an operational outcome demands it, surgical-edit contract is the comment-line `task=` + `status=` keys per [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). See [voice-contract.md](../../references/voice-contract.md).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-implement` green on current task, OR standalone on legacy code |
| **Hands off to**   | `/al-mutate` (inside `/al-implement` loop), or back to caller standalone |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/bc-standard-reference` (BaseApp patterns), `/al-code-review` (non-structural concerns surface as out-of-scope notes), `/al-design` (standalone-on-legacy surfacing real architecture), `/grill-me` (non-obvious trade-off needs the user) |
