# Architectural vocabulary

Shared language for `/al-design` and `/al-refactor`. Use these terms exactly — don't substitute "component," "service," "API," "boundary," "class," or "entity." Consistent language is the whole point. Sits alongside the BC pattern catalogue (`bc-patterns.md`) — does not replace it.

Read-only. Read in place via `${CLAUDE_SKILL_DIR}/references/LANGUAGE.md`.

## Terms

**Module**
A folder under `src/<module>/` containing a cohesive unit — codeunits, tables, pages, permissions for one bounded responsibility. Scale-agnostic: applies equally to a single codeunit, a façade-plus-subsystem cluster, or a multi-table feature slice. The whole AL app stays one shipped artifact; "module" is the in-app boundary, not the `.app` boundary.
_Avoid_: component, service, unit, package.

**Interface**
Everything a caller must know to use the module correctly: procedure signatures, invariants, ordering constraints, error modes, required setup, performance characteristics, the events the module publishes, the events the module subscribes to. Includes — but is much wider than — AL `interface` objects.
_Avoid_: API, signature, contract (too narrow — those refer only to the type-level surface). And do not equate "interface" with the AL `interface` keyword: that keyword declares one *kind* of seam; the architectural Interface is the whole knowable surface.

**Implementation**
What's inside the module — codeunit bodies, table triggers, page actions, helpers, internal codeunits. Distinct from **adapter**: a thing can be a small adapter with a large implementation (a real Web Service connector codeunit) or a large adapter with a small implementation (an in-memory test fake). Reach for "adapter" when the seam is the topic; "implementation" otherwise.
_Avoid_: internals (overloaded), guts.

**Depth**
Leverage at the interface — how much behaviour a caller (or test) can exercise per unit of interface they have to learn. **Deep** = a lot of behaviour behind a small interface. **Shallow** = the interface is nearly as complex as the implementation.
_Avoid_: ratio of implementation-lines to interface-lines (rewards padding the body). Depth here is leverage, not line count.

**Seam** _(from Michael Feathers)_
A place where behaviour can be altered without editing in place. The *location* at which a module's interface lives. Choosing where the seam goes is its own design decision, distinct from what sits behind it. In AL, seams take concrete shapes: a published `IntegrationEvent` (with optional `IsHandled`), an AL `interface` object plus an Implementer codeunit, a table-extension field, an event subscriber attaching to a publisher.
_Avoid_: boundary (overloaded with DDD's bounded context). Say **seam**, **interface**, or — when the AL construct is what's meant — **AL `interface` object**.

**Adapter**
A concrete codeunit (or implementing codeunit) that satisfies an interface at a seam. Names a *role* (which slot it fills), not substance (what's inside). A `Deposit Slip Printer` and a `Deposit Slip Printer Mock` are two adapters at the same seam.
_Avoid_: implementation (when you mean role, say adapter), driver, plugin.

**Leverage**
What callers get from depth. More capability per unit of interface they have to learn. One implementation pays back across N call sites and M tests. The reason a façade earns its place: many callers, one well-tested surface.
_Avoid_: reuse (too vague — reuse can be shallow copy-paste).

**Locality**
What maintainers get from depth. Change, bugs, knowledge, and verification concentrate at one place rather than spreading across callers. Fix once, fixed everywhere. Locality is the maintainer-side mirror of leverage.
_Avoid_: cohesion (related, but locality is about *where the change lands*, not about what belongs together).

## BC translations (state inline)

The architectural vocabulary above maps onto AL constructs — but the AL construct is never the architectural concept. Keep both labels.

| Architectural term | Common AL realisation | _Avoid_ saying |
|---|---|---|
| Module | folder under `src/<module>/` | "module" = `.app` |
| Interface | the public-by-contract surface a caller sees | "interface" = the AL `interface` keyword |
| Seam | published event, AL `interface` boundary, Implementer injection point, table-extension field | "boundary" |
| Adapter | implementing codeunit, event-subscriber codeunit, mock codeunit | "class" |
| Implementation | codeunit body, table triggers, page actions | "internals" |
| Codeunit | AL's procedure container; *plays the role of* an adapter or holds implementation | "class" — codeunits are not classes; they are object-with-procedures, no inheritance |
| Table | AL's persisted record schema; *plays the role of* an entity but with BC semantics (Insert / Modify / Delete triggers, FlowFields, FlowFilters, primary key, SystemId) | "entity" without qualification — the BC semantics matter |
| AL `interface` object | a single seam *declaration* — the contract row of an Implementer-pattern seam; never the whole architectural Interface | TS/C# `interface` keyword (different lifecycle, different runtime) |

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small parts — they just aren't part of the interface. A module has both an *external seam* (its interface, where callers cross) and *internal seams* (private to the implementation, used by its own unit tests).
- **The deletion test.** Imagine deleting the module. If complexity vanishes, the module wasn't hiding anything (it was a pass-through — delete it). If complexity reappears across N callers, the module was earning its keep. Doesn't apply when the seam is a published event with no in-tree callers — there are no N callers to surface in.
- **The two-adapter rule.** One adapter means a hypothetical seam. Two adapters means a real one. Don't introduce a port — AL `interface` object plus Implementer codeunit, or a publishable event plus its first subscriber pair — unless at least two adapters justify it (typically production + test, or two real production variants). One-adapter "interfaces for testability" are speculative bloat.
- **Two test surfaces, both first-class.** Integration / E2E tests cross the external seam — they call the module through its `Access = Public` interface, exercising R (DB reads, parameters, events) and W (Insert / Modify / Delete, telemetry, errors). Unit tests live *inside* the module — they call internal procedures directly, especially the **P** (pure process) layer of R→P→W. AL's `Access = Internal` is test-accessible from the same app; Microsoft's BaseApp tests do this throughout. Scenario test-layer choice (Pure / E2E / Both) in `architecture.md` decides which surface each scenario uses.
- **Internal seams stay private.** Don't expose them through the module's external interface just because tests use them. When unit tests have to reach past `Access = Internal`, reshape — split the responsibility into a smaller internal codeunit — rather than weaken visibility for the test's sake.
- **The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.

## Relationships

- A **module** has exactly one **interface** (the surface it presents to callers and tests).
- **Depth** is a property of a **module**, measured against its **interface**.
- A **seam** is where a **module**'s **interface** lives.
- An **adapter** sits at a **seam** and satisfies the **interface**.
- **Depth** produces **leverage** for callers and **locality** for maintainers.

## Rejected framings

- **"Class" for codeunit.** AL has no inheritance; codeunits are not classes. Say **codeunit**, or **adapter** when role is what matters.
- **"Entity" bare for table.** Tables carry BC semantics — Insert/Modify/Delete triggers, FlowFields, primary key, SystemId. "Entity" loses all of that. Say **table** or **record**.
- **TypeScript `interface` ≡ AL `interface`.** They share a name and almost nothing else. AL `interface` objects are runtime-resolved seams, declared once and Implemented by a codeunit; TS `interface` is a compile-time type. Conflating them leaks wrong intuitions about lifecycle, polymorphism, and testing.
- **"Boundary" for seam.** Overloaded with DDD's bounded context. Use **seam** or **interface**.
- **Depth as ratio of impl-lines to interface-lines.** Rewards padding the body. Use depth-as-leverage instead.
