---
name: al-refactor
description: Reshape AL/Business Central production and test code while tests stay green, via four parallel lens sub-agents then serial apply with `/al-build` between. Use after green inside `/al-implement` (full task diff, once per task) or standalone on legacy code.
---

# /al-refactor, Improve shape while green

Reshape AL so modules that earn their keep deepen and the ones that don't dissolve. Observable behaviour does not change. The 4 lenses identify; the main session merges, dedupes, applies serially with `/al-build` between.

## Preconditions

- Build is green. Refactor against a red build is debug, and belongs in `/al-implement`.
- Called from `/al-implement` after green on the current task, OR standalone on legacy code.
- Standalone: branch matches `^\d{3}-` with `specs/<branch>/tasks.html`, OR pure legacy reshape with no calling task. Calling task `blocked`, run `/al-steer`.
- Legacy spec folder (`tasks.md` without `tasks.html`): frozen.
- Legacy-code mode (no covering tests): write baseline tests first; a reshape without a regression signal is speculation. See [legacy-refactor-plan.md](references/legacy-refactor-plan.md).

## What you answer before reshape

- **What seam is being introduced, hardened, or dissolved?** Name the mechanism (publisher event, AL `interface`, `Implementation` enum, internal helper) and the adapters that justify it.
- **Where does R → P → W cut in this area?** R = reads / events subscribed. P = pure procedure, the unit-test surface. W = effects.
- **Which names lie?** A name lies when it describes a generic operation while the body does a BC-specific one, when it uses CRUD vocabulary where the BC verb exists, when the project's `CONTEXT.md` term has drifted out of the code.
- **What crosses a published API?** Constrains rename, removal, signature change.
- **Does reshape surface new behaviour or a hidden requirement?** If yes, route the discovery; do not absorb.
- **Which BC names did you verify this session?** Every BC-specific name a rename pulls from outside the codebase (a verb picked because "Insert is right for Customer", a BaseApp subscriber signature, a System Application call): backed this session by an `al-symbols-mcp` or `grep` hit, or a `/al-research` citation. Recall does not satisfy. See *Lens 4 citation chain* below.

Unanswerable from the diff, the area is not ready. Resolve via `/al-research`, `/al-grill-adr`, or `/al-steer`.

Architectural vocabulary (Module, Interface, Implementation, Seam, Adapter, Depth, Leverage, Locality) in [LANGUAGE.md](../../references/LANGUAGE.md). Use exactly.

## Lenses

Spawn 4 lens sub-agents in parallel on the task diff. Each returns reshape opportunities; the main session merges into one ordered apply queue.

| # | Lens | Focused goal |
|---|---|---|
| 1 | **Simplify / dedup** *(primary)* | Duplication, dead code, redundant procedures, simplification, inline candidates. Pass-throughs dissolve; primitives carrying meaning become small records or enums |
| 2 | **BC best-practice** via bc-knowledge | Per [bc-knowledge-dispatch.md](../../references/bc-knowledge-dispatch.md): `ask_bc_expert(autonomous_mode=false)` per touched file, threshold `>= 70`, cache `get_bc_topic` within the run. MCP names topics; lens applies `anti_pattern_indicators` |
| 3 | **Structural shape** | R → P → W boundary, depth over indirection, seam introduction. Disciplines below carry the substance |
| 4 | **Naming** | Objects, procedures, variables, fields, parameters in BC vocabulary AND project terminology per `CONTEXT.md`, ADRs, `architecture.html`, `event-model.html` |

Lens 1 typically dominates the queue; Lens 2 surfaces a small number of high-value BC fixes; Lens 3 reshapes are fewer but load-bearing; Lens 4 finds renames the others miss because they read code without the BC-vocabulary lens.

## Apply discipline

One reshape at a time, `/al-build` after each. Red, revert that step; recover before the next. Renames and seam-introduction land before dedup (touch many call sites, conflict otherwise). Lens 1 dead-code removal usually batches safely; Lens 3 structural reshape lands one at a time. `/al-second-opinion` when the apply queue is non-trivial.

## Lens 1, simplify and dedup

**Deletion test on every shallow module.** Imagine deleting the module. Complexity vanishes, the module was a pass-through; inline at call sites and remove. Complexity reappears across N callers, the module earned its place; deepen it. A one-line wrapper around `SalesHeader.Modify` that adds only a name is the canonical case for inline.

**Tests are first-class.** Production and tests refactor together. Tests survive internal refactors because they assert on observable outcomes through the interface, not internal state. New tests for branches reshape uncovers must pass against the *current* code first, so the regression signal stays honest. Unit tests on modules the refactor merges away get deleted, not layered.

## Lens 2, BC-specific via bc-knowledge

`autonomous_mode=false` always: mode returns persona + topic recs, sub-agent applies. Threshold `>= 70` keeps cost per TDD cycle low. Cache topics within one lens run, fresh fetch across invocations. Non-structural concerns the MCP surfaces (AppSource compliance, publisher/subscriber contracts beyond structural reshape) belong to `/al-code-review`; surface as out-of-scope notes in the calling task block, do not act here. Vanilla cannot replace this: `SetLoadFields` after `SetRange` is a syntactically valid call that BC's query-execution order makes ineffective.

## Lens 3, structural shape

**R → P → W as reshape, not annotation.** When a procedure mixes I/O and computation, splitting along that line *is* the refactor. P is the most load-bearing line: it names what is testable without a real database. Annotating without splitting changes nothing.

**Two adapters or no seam.** A seam with one adapter is a tautology; the codeunit only pretends to be flexible. Production + an in-memory test adapter that actually exists counts as two. Two real production transports already deployed counts. "Interface for testability" with no test fake written is one. AL `interface`, `Implementation` enums, and event publishers are seam *mechanisms*; picking among them is separate from whether the seam earns its place.

**Depth over indirection.** A deep module hides much behaviour behind a small interface. Long procedures break into private helpers behind `Access = Internal`. Feature-envious procedures move to where the data lives. Primitive obsession (`Code[20]` carrying meaning) becomes a small record or enum.

**Internal seams stay internal.** A unit test reaching past `Access = Internal` signals the responsibility sits on the wrong codeunit, not that `Access` should widen. Split into a smaller internal codeunit so the surface tells the truth. E2E crosses `Access = Public` and survives internal refactor; unit tests live alongside the implementation against `Access = Internal`.

**Introduce seams before injecting.** Order: extract internals behind a new interface → ship the interface → inject the adapter. Injecting first strands existing callers with a half-built seam; the build goes red and stays red. Three default seams (`IEnvironment`, `IApiRequest`, `IFinance`-family), the temp-record alternative, and the full three-phase decoupling live in [testability.md](../../references/testability.md). Name an existing pattern before extracting a fresh one.

## Lens 4, naming

Rename when the name lies. BC verbs over generic CRUD; objects `"Prefix Feature Suffix"`. Project terminology in `CONTEXT.md` (`## Language`, `## Flagged ambiguities`); multi-context repos consult `CONTEXT-MAP.md`. For user/API-facing features, canonical Role / Action / Business Event / View names from `event-model.html` already live in code via `/al-refine` and `/al-implement`; preserve verbatim.

Scope: objects, procedures, parameters, variables, record vars, table fields, page actions, publishers, subscribers, captions, labels. Nothing escapes by being "small".

Rename safety: editing a test name or `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` triggers Gherkin re-verification; intent shift, update via `/al-refine` in the same change. `[HandlerFunctions('...')]` strings are invisible to symbol tools; grep before any test-procedure rename per [tdd.md](../../references/tdd.md).

Citation chain: when a rename pulls a BC name from outside the codebase (a verb picked because "Insert is right for Customer", a BaseApp subscriber signature, a System Application call), the name either appears in an `al-symbols-mcp` or `grep` result you ran this session, or is cited via `/al-research`: `Researched: <name> → <source>` before the rename lands. The workspace lookup is the empirical anchor; memory of training data or past sessions is not. Your confidence about whether "Insert" or "Create" is the BC-correct verb is not evidence either is right. This is exactly where a confidently-wrong verb corrupts every downstream artifact.

## Cross-cutting

**Comments earn their place.** A comment lands only when the *why* is non-obvious from BC vocabulary and surrounding code; restating what code already says rots the moment behaviour drifts.

| | Comment |
|---|---|
| _Avoid_ | `// Insert the customer record` before `Customer.Insert(true);` |
| Use | `// BaseApp Codeunit 80 fires OnAfterPostSalesDoc twice for partial shipments, guard against double-post` |

**AppSource compliance.** Never rename a shipped object, table field, page action, or procedure other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce the new name alongside. No BaseApp modification. Internal-only symbols rename freely.

**Replan when reshape surfaces architectural gaps.** Missing module, pattern conflict, unnamed brownfield touchpoint, R → P → W boundary cutting across tasks, sibling task whose description the reshape invalidates: **Stop**. Code stays green; the halt is on planning. Route to `/al-steer`.

**No new behaviour.** The diff leaves observable behaviour identical. New behaviour belongs to `/al-implement` (new task) or `/al-refine` (re-plan).

Standalone mode emits a Gate report once at module / pattern / seam altitude (not procedure level), naming the application invariant preserved and the user's call; inside `/al-implement`, findings fold into the scenario's Gate report. `/al-refactor` does not edit `architecture.html` and writes no Notes by default; `tasks.html` touched only when an operational outcome demands it, surgical-edit contract is `data-task` + `data-status` per [html-spec-discipline.md](../../references/html-spec-discipline.md). See [voice-contract.md](../../references/voice-contract.md).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-implement` green on the current task, OR standalone on legacy code |
| **Hands off to**   | `/al-mutate` (inside `/al-implement` loop), or back to caller standalone |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/bc-standard-reference` (BaseApp patterns), `/al-code-review` (non-structural concerns surface as out-of-scope notes), `/al-design` (standalone-on-legacy surfacing real architecture), `/grill-me` (non-obvious trade-off needs the user) |
