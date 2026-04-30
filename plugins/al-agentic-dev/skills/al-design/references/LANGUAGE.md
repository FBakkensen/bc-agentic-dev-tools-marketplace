# Architectural vocabulary

Universal architectural terms used by `/al-design` and `/al-refactor`. Sits alongside BC patterns (Implementer, Façade, Handled events, Variant Façade, Setup table) — does not replace them.

Read-only. Never modified. Read in place via `${CLAUDE_SKILL_DIR}/references/LANGUAGE.md`.

## Terms

**Module**
A folder under `src/<module>/` containing a cohesive unit — codeunits, tables, pages, permissions for one bounded responsibility. The whole AL app stays one shipped artifact; "module" is the in-app boundary, not the `.app` boundary.

**Interface**
Everything a caller must know to use the module correctly: procedure signatures, invariants, ordering constraints, error modes, required setup, performance characteristics. Includes — but is not limited to — AL `interface` objects.

**Implementation**
What's inside a module — its codeunits' bodies, table triggers, etc. Distinct from **adapter**: a thing can be a small adapter with a large implementation, or vice versa.

**Seam**
A place where behaviour can be altered without editing in place. In AL: published events (`OnBefore*` / `OnAfter*`), AL `interface` boundaries, Implementer codeunit injection points, table-extension fields.

**Adapter**
A concrete codeunit satisfying an interface at a seam. Names a role (what slot it fills), not substance (what's inside).

**Depth**
Leverage at the interface — how much behaviour a caller (or test) can exercise per unit of interface they have to learn. Deep = lot of behaviour behind a small interface. Shallow = interface as complex as the implementation.

**Leverage**
What callers get from depth. More capability per unit of interface. One implementation pays back across N call sites and M tests.

**Locality**
What maintainers get from depth. Change, bugs, knowledge concentrate at one place rather than spreading across callers. Fix once, fixed everywhere.

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small parts — they just aren't part of the interface. A module has both an *external seam* (its interface, where callers cross) and *internal seams* (private to the implementation, used by its own unit tests).
- **Two test surfaces, both first-class.**
  - **Integration / E2E tests** cross the external seam — they call the module through its `Access = Public` interface, exercising composition with R (DB reads, parameters, events) and W (Insert / Modify / Delete, telemetry, errors). These survive internal refactors.
  - **Unit tests** live *inside* the module — they call internal procedures directly, especially the **P** (pure process) layer of R→P→W. Pure-layer tests are the whole point of drawing the boundary: you can verify computation without standing up DB state. AL's `Access = Internal` codeunits are test-accessible from the same app — Microsoft's BaseApp tests do this throughout.
  - Scenario test-layer choice (Pure / E2E / Both) in `architecture.md` decides which surface each scenario uses.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through (delete it). If complexity reappears across N callers, it was earning its keep. **Doesn't apply when the seam is a published event with no in-tree callers** — the publisher just stops firing the subscriber; "complexity" doesn't have N callers to surface in.
- **One adapter = hypothetical seam. Two adapters = real seam.** Don't introduce a port unless at least two adapters justify it (typically production + test). One-adapter "interfaces for testability" are speculative bloat.
- **Internal seams stay private.** Don't expose them through the module's external interface just because tests use them. Internal unit tests are still inside the module — they share the same app and can reach `Access = Internal` directly.
- **When unit tests have to reach past `Access = Internal` boundaries** (e.g. you find yourself wanting to test a procedure that's currently `local`), reshape rather than weaken visibility. The "wanting to test past the interface usually means the module is the wrong shape" rule applies here — split the responsibility into a smaller internal codeunit instead of widening visibility for the test's sake.

## Relationships

- A **module** has exactly one **interface** (the surface it presents to callers and tests).
- **Depth** is a property of a module, measured against its interface.
- A **seam** is where a module's interface lives.
- An **adapter** sits at a seam and satisfies the interface.
- **Depth** produces **leverage** for callers and **locality** for maintainers.
