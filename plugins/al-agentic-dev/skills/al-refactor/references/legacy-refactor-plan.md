# Legacy AL refactor plan

Phased process for legacy AL code that ships **without sufficient tests**. Use when there is no calling task and no `architecture.md`. Companion to `/al-refactor`; does not replace its inline discipline (which assumes tests already exist).

## Preconditions

- Code version-controlled, `/al-build` works.
- Write the baseline tests before changing behaviour. No green baseline means no regression signal; write it first.

## Dependency categories

Classify each dependency the candidate module reaches for — the category determines whether a port is justified at the seam.

**1. In-process.** Pure computation, no I/O (rounding, discount math, validation predicates). Test through the deepened interface directly. No port.

**2. Local-substitutable.** Stand-ins exist inside the BC test runtime: tables (test isolation gives transactional rollback), `Library*` helpers, `LibraryRandom`. Seam stays internal; no port at the external interface.

**3. Remote but owned.** Your own services across a network/async boundary (API pages you publish, integration codeunits, queues you own). Port at the seam.

**4. True external.** Third-party services you do not control (Stripe, Twilio, external rate APIs). Injected port; tests provide a mock asserting the contract observed in production. Schema drift on the external side is a replan, not a refactor.

Categories 3 and 4 justify a port (AL `interface`) at the seam: production adapter implements transport, test adapter is an in-memory codeunit on the same interface. **Two adapters or no port** — a single-adapter seam is indirection. A deep codeunit can also have internal seams (private helpers tested against `Access = Internal`) alongside its external interface; do not widen `Access` because tests use them.

## Phasing

Three passes, build green and tests re-run after each. The SKILL's inline disciplines (deletion test, R→P→W split, naming, depth) apply throughout — this file adds only the legacy-specific ordering.

1. **Rename and tighten locality.** No behaviour change. BC vocabulary, internal helpers behind `Access = Internal`.
2. **Reshape along R→P→W.** Split tangled procedures; merge or delete pass-throughs per the deletion test.
3. **Modernise APIs and define seams.** BC-specific upgrades carrying real platform cost: `Find('-')` → `FindSet()`, `SetLoadFields` for performance, BC v24+ `NoSeriesManagement` → `codeunit "No. Series"`. Define ports for category-3/4 dependencies. `Message()` → `Error()` flips a previously-silent branch into an error case — a behaviour change; update its assertions in the same change.

Replace, do not layer: delete unit tests on modules the refactor merged away; new tests assert observable outcomes at the deepened module's interface.

A hidden requirement or design flaw surfacing mid-phase halts to `/al-design` or `/al-refine` via `/al-steer`. **No silent scope expansion.**
