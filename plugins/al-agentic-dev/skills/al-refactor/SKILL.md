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
- **Which BC names verified this session?** Every BC-specific name a rename pulls from outside codebase (verb picked because "Insert is right for Customer", BaseApp subscriber signature, System Application call) meets the evidence bar in [voice-contract.md](../../references/voice-contract.md). See *Lens 4, naming* below.

Unanswerable from the diff → area not ready. Resolve via `/al-research`, `/al-grill-adr`, or `/al-steer`.

Architectural vocabulary (Module, Interface, Implementation, Seam, Adapter, Depth, Leverage, Locality) in [LANGUAGE.md](../../references/LANGUAGE.md). Use exactly.

## Lenses

Spawn 4 lens sub-agents in parallel on the task diff. Each returns reshape opportunities; main session merges into one ordered apply queue.

Sub-agents inherit neither hooks nor `CLAUDE.md`. Every lens spawn prompt carries the **BC vocabulary** line from [voice-contract.md](../../references/voice-contract.md) verbatim — a lens that quotes or proposes names without the vocabulary in its own context repairs naming with the generic verbs the repair exists to remove. When the diff touches test code, the spawn prompt also names [test-layout.md](../../references/test-layout.md): its authoring contract is exactly what tidy passes break silently — consolidating "duplicate" integration-test library procedures violates duplicate-before-share, hoisting handlers off a test codeunit breaks the `[HandlerFunctions]` string binding, relocating a double breaks the per-app independence rule. Moving a test across the unit/integration boundary is never a lens call — that is replan, route `/al-steer`.

After lens outputs are collected and merged, close the completed lens sub-agent threads. Do not leave completed lens agents open as passive state.

| # | Lens | Focused goal |
|---|---|---|
| 1 | **Simplify / dedup** *(primary)* | Duplication, dead code, redundant procedures, simplification, inline candidates. Pass-throughs dissolve; primitives carrying meaning become small records or enums |
| 2 | **BC best-practice** via bc-code-intelligence | Per [bc-code-intelligence-dispatch.md](../../references/bc-code-intelligence-dispatch.md): `find_bc_knowledge` → drop noise → `get_bc_topic`, cache within run, fetch fewer (only structural anti-patterns worth fixing this pass). MCP ranks topics; lens matches `anti_pattern_indicators` against the diff |
| 3 | **Structural shape** | R → P → W boundary, depth over indirection, seam introduction. Disciplines below carry substance |
| 4 | **Naming** | Objects, procedures, variables, fields, parameters in BC vocabulary AND project terminology per `CONTEXT.md`, ADRs, `architecture.md`, `event-model.md` |

Lens 1 typically dominates queue; Lens 2 surfaces small number of high-value BC fixes; Lens 3 reshapes are fewer but load-bearing; Lens 4 finds renames the others miss because they read code without the BC-vocabulary lens.

## Apply discipline

One reshape at a time, `/al-build` after each. Red → revert that step; recover before next. Renames and seam-introduction land before dedup (touch many call sites, conflict otherwise). Lens 1 dead-code removal usually batches safely; Lens 3 structural reshape lands one at a time. `/al-second-opinion` when apply queue is non-trivial.

## Lens 1, simplify and dedup

**Deletion test on every shallow module.** Imagine deleting the module. Complexity vanishes → module was pass-through; inline at call sites and remove. Complexity reappears across N callers → module earned its place; deepen it. One-line wrapper around `SalesHeader.Modify` that adds only a name is the canonical case for inline.

**Delete, don't rearrange.** The bias runs deeper than removing pass-throughs: prefer the reshape that removes moving pieces over the one that merely spreads the same complexity around. Look for the *code judo* move — a restructuring that uses the existing architecture to make whole branches vanish, not a new abstraction layered on top. Reject a merely cleaner version of the same messy idea when a simpler idea is in reach. Count moving pieces before and after; fewer wins.

**Rule of Three is the brake.** The deletion test removes shallow abstractions; the Rule of Three stops you minting them. Do not extract a helper on the second near-duplicate — two may be coincidence, and a one-caller wrapper is exactly what the deletion test then kills. Wait for the third occurrence, or leave the duplication and note it.

**Canonical home over bespoke.** Logic with a rightful home — a BaseApp / System Application helper, an existing module's internal helper — gets routed there and the canonical one reused, not a near-duplicate minted. Do not normalize architectural drift: code already sitting in the wrong module is not a licence to add more there; push it toward the right module.

**Tests are first-class.** Production and tests refactor together. Tests survive internal refactors because they assert on observable outcomes through the interface, not internal state. New tests for branches reshape uncovers must pass against *current* code first → regression signal stays honest. Unit tests on modules the refactor merges away get deleted, not layered.

## Lens 2, BC-specific via bc-code-intelligence

`find_bc_knowledge` with a BC-specific query → drop noise (`parker-pragmatic/*`, `*/recommend-*`, off-domain) → `get_bc_topic` on the top-ranked on-domain survivors → match each `anti_pattern_indicator` against the diff yourself. Fetch fewer than `/al-code-review` does: refactor acts only on structural anti-patterns worth fixing this same pass, which keeps cost per TDD cycle low. Cache topics within one lens run, fresh fetch across invocations. Non-structural concerns the MCP surfaces (AppSource compliance, publisher/subscriber contracts beyond structural reshape) belong to `/al-code-review`; surface as out-of-scope notes in calling task block, do not act here. Vanilla cannot replace this: `SetLoadFields` after `SetRange` is a syntactically valid call that BC's query-execution order makes ineffective — connascence of execution order ([LANGUAGE.md](../../references/LANGUAGE.md)).

## Lens 3, structural shape

**R → P → W as reshape, not annotation.** Procedure mixes I/O and computation → splitting along that line *is* the refactor. P is the most load-bearing line: it names what is testable without a real database. Annotating without splitting changes nothing. A procedure that both mutates a record and returns a computed value is the command/query violation (CQS, [LANGUAGE.md](../../references/LANGUAGE.md)); the split runs along the same line.

**Two adapters or no seam.** Seam with one adapter is tautology; codeunit only pretends to be flexible. Production + in-memory test adapter that actually exists counts as two. Two real production transports already deployed counts. "Interface for testability" with no test fake written is one. AL `interface`, `Implementation` enums, and event publishers are seam *mechanisms*; picking among them is separate from whether seam earns its place.

**Depth over indirection.** Deep module hides much behaviour behind small interface. Long procedures break into private helpers behind `Access = Internal`. Feature-envious procedures move to where data lives. Primitive obsession (`Code[20]` carrying meaning) becomes small record or enum. Repeated conditionals signal a missing model: the same `case` / `if` chain duplicated across procedures is an absent enum or dispatcher, not just dup code to extract — connascence of meaning the type should carry.

**Internal seams stay internal.** Unit test reaching past `Access = Internal` signals responsibility sits on wrong codeunit, not that `Access` should widen. Split into smaller internal codeunit so surface tells the truth. E2E crosses `Access = Public` and survives internal refactor; unit tests live alongside the implementation against `Access = Internal`.

**Introduce seams before injecting.** Order: extract internals behind new interface → ship the interface → inject the adapter. Injecting first strands existing callers with half-built seam; build goes red and stays red. Three default seams (`IEnvironment`, `IApiRequest`, `IFinance`-family), temp-record alternative, full three-phase decoupling live in [testability.md](../../references/testability.md). Name an existing pattern before extracting a fresh one.

## Lens 4, naming

Rename when name lies. BC verbs over generic CRUD; objects `"Prefix Feature Suffix"`. Project terminology in `CONTEXT.md` (`## Language`, `## Flagged ambiguities`); multi-context repos consult `CONTEXT-MAP.md`. User/API-facing features: canonical Role / Action / Business Event / View names from `event-model.md` already live in code via `/al-refine` and `/al-implement`; preserve verbatim.

Scope: objects, procedures, parameters, variables, record vars, table fields, page actions, publishers, subscribers, captions, labels. Nothing escapes by being "small".

Rename safety: editing a test procedure name requires task-spec reconciliation: update AAA header, `Procedure:`, and `Covered By` in the same change when the task is active. Intent shift → update via `/al-refine`. `[HandlerFunctions('...')]` strings are invisible to symbol tools; grep before any test-procedure rename per [tdd.md](../../references/tdd.md).

Citation chain: when a rename pulls a BC name or verb from outside the codebase, the evidence bar in [voice-contract.md](../../references/voice-contract.md) applies before the rename lands — workspace hit or quoted fetch; conflicts escalate to `/al-research`. This is exactly where a confidently-wrong verb corrupts every downstream artifact.

## Cross-cutting

**Comments earn their place.** Comment lands only when *why* is non-obvious from BC vocabulary and surrounding code; restating what code already says rots the moment behaviour drifts.

| | Comment |
|---|---|
| _Avoid_ | `// Insert the customer record` before `Customer.Insert(true);` |
| Use | `// BaseApp Codeunit 80 fires OnAfterPostSalesDoc twice for partial shipments, guard against double-post` |

**AppSource compliance.** Never rename a shipped object, table field, page action, or procedure other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce new name alongside. No BaseApp modification. Internal-only symbols rename freely.

**Replan when reshape surfaces architectural gaps.** Missing module, pattern conflict, unnamed brownfield touchpoint, R → P → W boundary cutting across tasks, sibling task whose description the reshape invalidates → **Stop**. Code stays green; halt is on planning. Route to `/al-steer`.

**No new behaviour.** Diff leaves observable behaviour identical. New behaviour belongs to `/al-implement` (new task) or `/al-refine` (re-plan).

Standalone mode emits Gate report once at module / pattern / seam altitude (not procedure level), naming application invariant preserved and user's call; inside `/al-implement`, findings fold into the task Gate report. `/al-refactor` does not edit `architecture.md` and writes no Notes by default; `tasks.md` touched only when an operational outcome demands it, surgical-edit contract is the comment-line `task=` + `status=` keys per [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). See [voice-contract.md](../../references/voice-contract.md).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-implement` green on current task, OR standalone on legacy code |
| **Hands off to**   | `/al-mutate` (inside `/al-implement` loop), or back to caller standalone |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/bc-standard-reference` (BaseApp patterns), `/al-code-review` (non-structural concerns surface as out-of-scope notes), `/al-design` (standalone-on-legacy surfacing real architecture), `/grill-me` (non-obvious trade-off needs the user) |
