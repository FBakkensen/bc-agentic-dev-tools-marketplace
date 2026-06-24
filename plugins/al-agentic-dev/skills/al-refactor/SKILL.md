---
name: al-refactor
description: Reshape AL/Business Central production and test code while tests stay green, via four parallel lens subagents then serial apply with `/al-build` between. Use after `/al-implement` takes a task to green (full task diff, once per task) or standalone on legacy code.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-refactor, Improve shape while green

Reshape AL so modules that earn their keep deepen and the ones that don't dissolve. Observable behaviour does not change. 4 lenses identify; main session merges, dedupes, applies serially with `/al-build` between.

## Preconditions

- Build green. Refactor against red build is debug → belongs in `/al-implement`.
- Run after `/al-implement` takes the current task to green (the user's next step at task-done), OR standalone on legacy code.
- Branch matches `^\d{3}-` with `specs/<branch>/tasks/`, OR pure legacy reshape with no owning task. Owning task `blocked` → run `/al-steer`.
- Legacy-code mode (no covering tests): write baseline tests first. See [legacy-refactor-plan.md](references/legacy-refactor-plan.md).

## What you answer before reshape

- **What seam is being introduced, hardened, or dissolved?** Name mechanism (publisher event, AL `interface`, `Implementation` enum, internal helper) and adapters that justify it.
- **Where does R → P → W cut in this area?** R = reads / events subscribed. P = pure procedure, unit-test surface. W = effects.
- **Which names lie?** Body does a BC-specific operation under a generic name, CRUD vocabulary where a BC verb exists, or a `CONTEXT.md` term drifted out of code.
- **What crosses a published API?** Constrains rename, removal, signature change.
- **Does reshape surface new behaviour or hidden requirement?** Yes → route the discovery; do not absorb.
- **Which BC names verified this session?** Every BC-specific name a rename pulls from outside the codebase meets the evidence bar in [voice-contract.md](../../references/voice-contract.md). See *Lens 4, naming* below.

Unanswerable from the diff → area not ready. Resolve via `/al-research`, `/al-grill-adr`, or `/al-steer`.

Architectural vocabulary (Module, Interface, Implementation, Seam, Adapter, Depth, Leverage, Locality) in [LANGUAGE.md](../../references/LANGUAGE.md). Use exactly.

## Lenses

Spawn 4 lens subagents in parallel on the task diff — each with the prompt in [`subagents/al-review-lens.md`](../../references/subagents/al-review-lens.md), except lens 2 (BC best-practice) which uses [`subagents/al-review-lens-bc.md`](../../references/subagents/al-review-lens-bc.md) for its bc-code-intelligence reach (a small/fast model suffices — see the tier note in those files). Each returns reshape opportunities; the main session merges into one ordered apply queue. The spawn prompt carries only the per-lens goal below plus the task diff; the read-only posture, BC vocabulary, and findings shape live in the prompt block.

When the diff touches test code, the spawn prompt also names [test-layout.md](../../references/test-layout.md): its authoring contract is exactly what tidy passes break silently — consolidating "duplicate" integration-test library procedures violates duplicate-before-share, hoisting handlers off a test codeunit breaks the `[HandlerFunctions]` string binding, relocating a double breaks the per-app independence rule. Moving a test across the unit/integration boundary is never a lens call — that is replan, route `/al-steer`.

| # | Lens | Focused goal |
|---|---|---|
| 1 | **Simplify / dedup** *(primary)* | Duplication, dead code, redundant procedures, inline candidates. Pass-throughs dissolve; primitives carrying meaning become small records or enums. **Over-build** — an abstraction with one caller (interface with one implementation, a helper used once, config for a value that never changes), scaffolding "for later" with no current caller — is a finding too: production code that does more than the task needs (the over-build block in the agent body carries the catch and its carve-outs) |
| 2 | **BC best-practice** via bc-code-intelligence | Per [bc-code-intelligence-dispatch.md](../../references/bc-code-intelligence-dispatch.md): `find_bc_knowledge` → drop noise → `get_bc_topic`, cache within run, fetch fewer (only structural anti-patterns worth fixing this pass). Lens matches `anti_pattern_indicators` against the diff. **Platform reinvention** is in scope here — hand-rolled code where a shipped BC feature delivers (a setup table + management codeunit for what a field + flowfield does, validation code for a table relation or permission-set entry, a status pattern an enum covers); use the topic store to confirm the platform alternative exists before flagging |
| 3 | **Structural shape** | R → P → W boundary, depth over indirection, seam introduction. Disciplines below carry substance |
| 4 | **Naming** | Objects, procedures, variables, fields, parameters in BC vocabulary AND project terminology per `CONTEXT.md`, ADRs, `architecture.md`, `event-model.md` |

## Apply discipline

One reshape at a time, `/al-build` after each. Red → revert that step; recover before next.

- Renames and seam-introduction land before dedup — they touch many call sites and conflict otherwise.
- Lens 3 structural reshape lands one at a time.
- `/al-second-opinion` when apply queue is non-trivial.

## Lens 1, simplify and dedup

**Deletion test on every shallow module.** Imagine deleting the module. Complexity vanishes → pass-through; inline at call sites and remove. Complexity reappears across N callers → it earned its place; deepen it. One-line wrapper around `SalesHeader.Modify` that adds only a name is the canonical inline case.

**Delete, don't rearrange.** Prefer the reshape that removes moving pieces over the one that spreads the same complexity around. Count moving pieces before and after; fewer wins.

**Rule of Three is the brake.** Do not extract a helper on the second near-duplicate — a one-caller wrapper is exactly what the deletion test then kills. Wait for the third occurrence, or leave the duplication and note it.

**Canonical home over bespoke.** Logic with a rightful home — a BaseApp / System Application helper, an existing module's internal helper — routes there and the canonical one is reused. Code already in the wrong module is not a licence to add more there; push it toward the right module.

**Tests are first-class.** Production and tests refactor together. New tests for branches reshape uncovers must pass against *current* code first → regression signal stays honest. Unit tests on modules the refactor merges away get deleted, not layered.

## Lens 2, BC-specific via bc-code-intelligence

`find_bc_knowledge` with a BC-specific query → drop noise (`parker-pragmatic/*`, `*/recommend-*`, off-domain) → `get_bc_topic` on the top-ranked on-domain survivors → match each `anti_pattern_indicator` against the diff yourself. Fetch fewer than `/al-code-review` does: refactor acts only on structural anti-patterns worth fixing this same pass. Cache topics within one lens run, fresh fetch across invocations. Non-structural concerns the MCP surfaces (AppSource compliance, publisher/subscriber contracts beyond structural reshape) belong to `/al-code-review`; surface as out-of-scope notes in the calling task file, do not act here. `SetLoadFields` after `SetRange` is a syntactically valid call BC's query-execution order makes ineffective — connascence of execution order ([LANGUAGE.md](../../references/LANGUAGE.md)).

## Lens 3, structural shape

**R → P → W as reshape, not annotation.** Procedure mixes I/O and computation → splitting along that line *is* the refactor; P names what is testable without a real database. A procedure that both mutates a record and returns a computed value is the command/query violation (CQS, [LANGUAGE.md](../../references/LANGUAGE.md)); the split runs along the same line.

**Two adapters or no seam.** Production + an in-memory test adapter that actually exists counts as two; two deployed production transports count. "Interface for testability" with no test fake written is one. AL `interface`, `Implementation` enums, and event publishers are seam *mechanisms*; picking among them is separate from whether the seam earns its place.

**Depth over indirection.** Long procedures break into private helpers behind `Access = Internal`. Feature-envious procedures move to where data lives. Primitive obsession (`Code[20]` carrying meaning) becomes a small record or enum. The same `case` / `if` chain duplicated across procedures is an absent enum or dispatcher — connascence of meaning the type should carry, not just dup code to extract.

**Internal seams stay internal.** Unit test reaching past `Access = Internal` signals responsibility sits on the wrong codeunit, not that `Access` should widen. Split into a smaller internal codeunit so the surface tells the truth. Unit tests live alongside the implementation against `Access = Internal`.

**Introduce seams before injecting.** Order: extract internals behind new interface → ship the interface → inject the adapter. Injecting first strands existing callers with a half-built seam; build goes red and stays red. Three default seams (`IEnvironment`, `IApiRequest`, `IFinance`-family), temp-record alternative, full three-phase decoupling live in [testability.md](../../references/testability.md). Name an existing pattern before extracting a fresh one.

## Lens 4, naming

Rename when name lies. BC verbs over generic CRUD; objects `"Prefix Feature Suffix"`. Project terminology in `CONTEXT.md` (`## Language`, `## Flagged ambiguities`); multi-context repos consult `CONTEXT-MAP.md`. User/API-facing features: canonical Role / Action / Business Event / View names from `event-model.md` already live in code via `/al-refine` and `/al-implement`; preserve verbatim.

Scope: objects, procedures, parameters, variables, record vars, table fields, page actions, publishers, subscribers, captions, labels. Nothing escapes by being "small".

Rename safety: editing a test procedure name requires task-spec reconciliation — update AAA header, `Procedure:`, and `Covered By` in the same change when the task is active. Intent shift → update via `/al-refine`. `[HandlerFunctions('...')]` strings are invisible to symbol tools; grep before any test-procedure rename per [tdd.md](../../references/tdd.md).

Citation chain: a rename pulling a BC name or verb from outside the codebase meets the evidence bar in [voice-contract.md](../../references/voice-contract.md) before it lands — workspace hit or quoted fetch; conflicts escalate to `/al-research`. This is exactly where a confidently-wrong verb corrupts every downstream artifact.

## Cross-cutting

**AppSource compliance.** Never rename a shipped object, table field, page action, or procedure other extensions may bind to. Obsolete via `ObsoleteState = Pending` then `Removed`; introduce the new name alongside. No BaseApp modification. Internal-only symbols rename freely.

**Replan when reshape surfaces architectural gaps.** Missing module, pattern conflict, unnamed brownfield touchpoint, R → P → W boundary cutting across tasks, sibling task whose description the reshape invalidates → **Stop**. Code stays green; halt is on planning. Route to `/al-steer`.

**No new behaviour.** Diff leaves observable behaviour identical. New behaviour belongs to `/al-implement` (new task) or `/al-refine` (re-plan).

Emits the Gate report once at module / pattern / seam altitude (not procedure level), naming the application invariant preserved and the next step. `/al-refactor` does not edit `architecture.md` and writes no Notes by default; a task file under `tasks/` is touched only when an operational outcome demands it, per the surgical-edit contract in [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). See [voice-contract.md](../../references/voice-contract.md).

## Next step

- **Reshape complete, inside the slice cycle:** `Next: /al-mutate` — validate the tests catch the decision logic the reshape just moved through.
- **Standalone legacy reshape, no owning task:** `Next: /al-mutate` if the area carries decision logic worth pinning, else back to the user; surface any architectural gap as `Next: /al-design` or `/al-steer`.
- **Stopped on an architectural gap / new behaviour:** `Next: /al-steer`.

If state can't be read, fall back: `/al-mutate` after a behaviour-bearing reshape, `/al-steer` if anything bigger than tidy-up surfaced.

## Feed

Reshape promises shape improves and behaviour does not — a wary dev wants proof the second half held. At each moment below, hand `/al-feed` a brief (what happened, why it matters to someone who hasn't read the diff, the kind); it composes the card. Per-build apply steps stay out of the feed — only these land.

- **landing** — legacy mode, baseline tests written and passing before any reshape. Captures: old code had no guard, so behaviour-today tests went in first; any change from here trips an alarm.
- **decision** — the 4 lenses merge into the ordered apply queue. Captures: what gets reshaped and in what order (renames and seams first), with the lens behind each item.
- **verdict** — a load-bearing structural reshape lands green at behaviour parity — seam with two adapters, module deleted or inlined, R → P → W split, or a lying name corrected across call sites and handler strings. Captures: a real structural change went in, build still green, behaviour unchanged; old→new and the evidence as layers.
- **surprise** — an apply step turns the build red and the agent reverts that step. Captures: one reshape broke the build, backed out cleanly, the rest kept; never sat broken.
- **surprise** — reshape surfaces an architectural gap or new behaviour; the agent **Stops**, stays green, routes to `/al-steer`. Captures: hit something bigger than tidy-up, stopped rather than quietly change behaviour.
- **verdict** — closing Gate report, reshape complete with the full diff green at parity. Captures: reshaping done, code behaves exactly as before in a cleaner shape; invariant preserved, handoff to `/al-mutate`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-implement` took the current task to green, OR standalone on legacy code |
| **Hands off to**   | `/al-mutate` (the next rigor step), or back to the user standalone |
| **Calls directly** | `/al-research` (BC facts), `/al-build` (green between applies), `/al-second-opinion` (non-trivial apply queue) — the only skills it invokes |
| **Spawns**         | 4 review-lens subagents from [`subagents/al-review-lens.md`](../../references/subagents/al-review-lens.md) / [`al-review-lens-bc.md`](../../references/subagents/al-review-lens-bc.md) |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | bc-standard-reference (BaseApp patterns), `/al-code-review` (non-structural concerns surface as out-of-scope notes), `/al-design` (standalone-on-legacy surfacing real architecture), `/grill-me` (non-obvious trade-off needs the user) |
