# Architectural vocabulary

Shared language for `/al-design` and `/al-refactor`. Use these terms exactly, don't substitute "component," "service," "API," "boundary," "class," or "entity." Consistent language is the whole point. Sits alongside the BC pattern catalogue (`bc-patterns.md`), does not replace it.

Read-only. Read in place via `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`.

**Provenance.** Structural terms below come from Ousterhout (*A Philosophy of Software Design*, Module, Depth, Leverage) and Feathers (*Working Effectively with Legacy Code*, Seam). Behavioural-decomposition terms come from Event Modeling (Adam Dymitruk, eventmodeling.org, Slice and its four patterns). Citation matters: a sourced term has an external definition the project can't quietly redefine. Rejected aliases (`_Avoid_`) are themselves cited concepts, listing them by name is what makes the rejection meaningful.

## Terms

**Module**
A folder under `src/<module>/` containing a cohesive unit, codeunits, tables, pages, permissions for one bounded responsibility. Scale-agnostic: applies equally to a single codeunit, a façade-plus-subsystem cluster, or a multi-table feature slice. The whole AL app stays one shipped artifact; "module" is the in-app boundary, not the `.app` boundary. Modules under `src/<module>/` realise **Vertical Slice Architecture** (Jimmy Bogard), feature folder, not layered architecture.
_Avoid_: component, service, unit, package.

**Interface**
Everything a caller must know to use the module correctly: procedure signatures, invariants, ordering constraints, error modes, required setup, performance characteristics, the events the module publishes, the events the module subscribes to. Includes, but is much wider than, AL `interface` objects.
_Avoid_: API, signature, contract (too narrow, those refer only to the type-level surface). And do not equate "interface" with the AL `interface` keyword: that keyword declares one *kind* of seam; the architectural Interface is the whole knowable surface.

**Implementation**
What's inside the module, codeunit bodies, table triggers, page actions, helpers, internal codeunits. Distinct from **adapter**: a thing can be a small adapter with a large implementation (a real Web Service connector codeunit) or a large adapter with a small implementation (an in-memory test fake). Reach for "adapter" when the seam is the topic; "implementation" otherwise.
_Avoid_: internals (overloaded), guts.

**Depth**
Leverage at the interface, how much behaviour a caller (or test) can exercise per unit of interface they have to learn. **Deep** = a lot of behaviour behind a small interface. **Shallow** = the interface is nearly as complex as the implementation.
_Avoid_: ratio of implementation-lines to interface-lines (rewards padding the body). Depth here is leverage, not line count.

**Seam** _(from Michael Feathers)_
A place where behaviour can be altered without editing in place. The *location* at which a module's interface lives. Choosing where the seam goes is its own design decision, distinct from what sits behind it. In AL, seams take concrete shapes: a published `IntegrationEvent` (with optional `IsHandled`), an AL `interface` object plus an Implementer codeunit, a table-extension field, an event subscriber attaching to a publisher, and a `List of [Interface I…]` / `Dictionary of [Text, Interface I…]` collection (BC 2025 W1, runtime 15.0) where adapters self-register via `.Add()`, no DI plumbing.
_Avoid_: boundary (overloaded with DDD's bounded context). Say **seam**, **interface**, or, when the AL construct is what's meant, **AL `interface` object**.

**Adapter**
A concrete codeunit (or implementing codeunit) that satisfies an interface at a seam. Names a *role* (which slot it fills), not substance (what's inside). An `App Deposit Slip Printer` and a `Stub Deposit Slip Printer` are two adapters at the same seam, Stub returns fixed data; Mock would additionally verify call contracts. The doubles vocabulary (Dummy / Stub / Spy / Mock / Fake) lives below; see `test-doubles.md` for AL code shapes.
_Avoid_: implementation (when you mean role, say adapter), driver, plugin.

**Leverage**
What callers get from depth. More capability per unit of interface they have to learn. One implementation pays back across N call sites and M tests. The reason a façade earns its place: many callers, one well-tested surface.
_Avoid_: reuse (too vague, reuse can be shallow copy-paste).

**Locality**
What maintainers get from depth. Change, bugs, knowledge, and verification concentrate at one place rather than spreading across callers. Fix once, fixed everywhere. Locality is the maintainer-side mirror of leverage.
_Avoid_: cohesion (related, but locality is about *where the change lands*, not about what belongs together).

**R → P → W** _(layering rule for procedures)_
The internal layering inside a module: **R** = reads (DB queries, parameters in, events subscribed to), **P** = pure process (decisions, no DB, no external calls), **W** = writes (`Insert` / `Modify` / `Delete`, telemetry, errors, events published). P is the unit-test surface, `Access = Internal` makes it test-accessible without crossing the external interface. Two test surfaces follow: E2E crosses the external interface (R + P + W end-to-end); unit tests target P directly with stubbed R/W collaborators. Cited by `tdd-cycle.md`, `decoupling.md`, and `/al-implement`.
_Avoid_: treating R / P / W as a label slapped on an existing tangle. The split *is* the refactor, not annotation.

## Behavioural decomposition

The terms above describe static structure (what's a module, where the seams are). The terms below describe behavioural decomposition (what the feature *does*, which trigger initiates each behaviour). Both vocabularies are needed; neither replaces the other.

**Slice** _(Event Modeling, Dymitruk)_
One initiated behaviour expressed as **trigger → command → event → state → view**. The unit of architectural decomposition at the funnel-top, sits between `## Solution` and `## Module map` in `architecture.md`. A feature has one slice if it delivers one initiated behaviour; more if more. AL slices map to Event Modeling's four canonical patterns:

- **Command** slice, page action, report request *(user-initiated)*.
- **Automation** slice, event subscriber, Job Queue, install/upgrade *(system-initiated)*. Most common AL pattern.
- **Translation** slice, API page, web service, webhook *(external-system-initiated)*.
- **View** slice, page render, FlowField, report layout *(read-only)*.

The pattern qualifies the slice in `architecture.md`, `Slice (Automation): trigger ...`. _Avoid_: user story (too unstructured), use case (too OO), flow (already used for the diagram).

**Vertical slicing** _(working principle, predates VSA, implicit in Kent Beck's TDD, 2002)_
Per-task / per-PR rule: every task ships tests + production code together; never data-only, logic-only, or wire-up-only; always leaves the system green. Applies to every `T-NNN` in `tasks.md`. The opposite, *horizontal phasing* (data, then logic, then UI, then tests-as-afterthought), is rejected by name. Lower-altitude than Vertical Slice Architecture; folder structure is VSA, per-task discipline is vertical slicing.
_Avoid_: horizontal phasing, layer-by-layer build, big-bang integration.

## Test doubles

Five kinds (Meszaros, *xUnit Test Patterns*). **Adapter** (above) names a *role*, which slot at the seam an implementation fills. **Double** names a *kind*, what the implementation does. Both axes apply: a Stub of `IConverter` is one adapter playing the Stub kind. Cross-cite `test-doubles.md` for AL code shapes.

**Dummy**: satisfies the interface parameter; no state, no behaviour. Used when the test doesn't exercise that dependency path at all.

**Stub**: returns pre-configured fixed data. Default for environment-interface seams (`IEnvironment`, `IApiRequest`, `IFinance`-family). See `environment-interfaces.md`.

**Spy**: records whether it was called; post-hoc assertion. Used to assert an execution path without inspecting return data.

**Mock**: combines stub + spy; verifies call contracts (count, order, args). Used when the test asserts interaction patterns.

**Fake**: simplified but working implementation (in-memory store standing in for a DB). Used when the test needs real-behaving dependency without real cost.

_Avoid_: calling every double a "Mock". Name the kind exactly. Mock-without-call-assertions is just a Stub with extra fields.

## BC translations (state inline)

The architectural vocabulary above maps onto AL constructs, but the AL construct is never the architectural concept. Keep both labels.

| Architectural term | Common AL realisation | _Avoid_ saying |
|---|---|---|
| Module | folder under `src/<module>/` | "module" = `.app` |
| Interface | the public-by-contract surface a caller sees | "interface" = the AL `interface` keyword |
| Seam | published event, AL `interface` boundary, Implementer injection point, table-extension field | "boundary" |
| Adapter | implementing codeunit, event-subscriber codeunit, mock codeunit | "class" |
| Implementation | codeunit body, table triggers, page actions | "internals" |
| Codeunit | AL's procedure container; *plays the role of* an adapter or holds implementation | "class", codeunits are not classes; they are object-with-procedures, no inheritance |
| Table | AL's persisted record schema; *plays the role of* an entity but with BC semantics (Insert / Modify / Delete triggers, FlowFields, FlowFilters, primary key, SystemId) | "entity" without qualification, the BC semantics matter |
| AL `interface` object | a single seam *declaration*, the contract row of an Implementer-pattern seam; never the whole architectural Interface | TS/C# `interface` keyword (different lifecycle, different runtime) |
| Slice | the trigger / command / event / state / view chain naming one initiated behaviour | "user story", slices include non-user triggers (subscribers, Job Queue, install/upgrade, API) |

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small parts, they just aren't part of the interface. A module has both an *external seam* (its interface, where callers cross) and *internal seams* (private to the implementation, used by its own unit tests).
- **The deletion test.** Imagine deleting the module. If complexity vanishes, the module wasn't hiding anything (it was a pass-through, delete it). If complexity reappears across N callers, the module was earning its keep. Doesn't apply when the seam is a published event with no in-tree callers, there are no N callers to surface in.
- **The two-adapter rule.** One adapter means a hypothetical seam. Two adapters means a real one. Don't introduce a port, AL `interface` object plus Implementer codeunit, or a publishable event plus its first subscriber pair, unless at least two adapters justify it (typically production + test, or two real production variants). One-adapter "interfaces for testability" are speculative bloat.
- **Two test surfaces, both first-class.** Integration / E2E tests cross the external seam, they call the module through its `Access = Public` interface, exercising R (DB reads, parameters, events) and W (Insert / Modify / Delete, telemetry, errors). Unit tests live *inside* the module, they call internal procedures directly, especially the **P** (pure process) layer of R→P→W. AL's `Access = Internal` is test-accessible from the same app; Microsoft's BaseApp tests do this throughout. Scenario test-layer choice (Pure / E2E / Both) in `architecture.md` decides which surface each scenario uses.
- **Internal seams stay private.** Don't expose them through the module's external interface just because tests use them. When unit tests have to reach past `Access = Internal`, reshape, split the responsibility into a smaller internal codeunit, rather than weaken visibility for the test's sake.
- **The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.

## Relationships

- A **module** has exactly one **interface** (the surface it presents to callers and tests).
- **Depth** is a property of a **module**, measured against its **interface**.
- A **seam** is where a **module**'s **interface** lives.
- An **adapter** sits at a **seam** and satisfies the **interface**.
- **Depth** produces **leverage** for callers and **locality** for maintainers.
- A **slice** is decomposed *behaviourally* (one initiated behaviour); a **module** is decomposed *structurally* (one cohesive responsibility). One slice typically lives across one or more modules; one module typically participates in one or more slices.

## Rejected framings

- **"Class" for codeunit.** AL has no inheritance; codeunits are not classes. Say **codeunit**, or **adapter** when role is what matters.
- **"Entity" bare for table.** Tables carry BC semantics, Insert/Modify/Delete triggers, FlowFields, primary key, SystemId. "Entity" loses all of that. Say **table** or **record**.
- **TypeScript `interface` ≡ AL `interface`.** They share a name and almost nothing else. AL `interface` objects are runtime-resolved seams, declared once and Implemented by a codeunit; TS `interface` is a compile-time type. Conflating them leaks wrong intuitions about lifecycle, polymorphism, and testing.
- **"Boundary" for seam.** Overloaded with DDD's bounded context. Use **seam** or **interface**.
- **Depth as ratio of impl-lines to interface-lines.** Rewards padding the body. Use depth-as-leverage instead.
- **"User story" for slice.** Excludes the most common AL trigger sources, event subscribers, Job Queue Entries, install/upgrade hooks, API page handlers. Use **slice** with its qualifying pattern (Command / Automation / Translation / View).
- **"Horizontal phasing" as a build strategy**, data first, then logic, then UI, then tests-as-afterthought. Rejected by **vertical slicing**: each task ships tests + production code together, leaving the system green.
