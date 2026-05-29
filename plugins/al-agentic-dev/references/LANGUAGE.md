# Architectural vocabulary

Shared language for `/al-design`, `/al-refactor`, and `/al-code-review`. Use these terms exactly; do not substitute "component," "service," "API," "boundary," "class," or "entity." Consistent language is the whole point. Sits alongside the BC pattern catalogue (`bc-patterns.md`), does not replace it.

Read-only. Read in place via `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`.

Structural terms (Module, Depth, Leverage) come from Ousterhout (*A Philosophy of Software Design*); **Seam** from Feathers (*Working Effectively with Legacy Code*); **Connascence** from Page-Jones (*What Every Programmer Should Know About OOA*); **Command-Query Separation** from Meyer (*Object-Oriented Software Construction*); behavioural-decomposition terms from Event Modeling (Adam Dymitruk). A sourced term has an external definition the project cannot quietly redefine. Rejected aliases (`_Avoid_`) are themselves cited concepts; naming them is what makes the rejection meaningful.

## Terms

**Module**
A folder under `src/<module>/` containing a cohesive unit (codeunits, tables, pages, permissions) for one bounded responsibility. Scale-agnostic: a single codeunit, a façade-plus-subsystem cluster, or a multi-table feature slice. The whole AL app stays one shipped artifact; "module" is the in-app boundary, not the `.app` boundary. Realises **Vertical Slice Architecture** (Jimmy Bogard): feature folder, not layered architecture.
_Avoid_: component, service, unit, package.

**Interface**
Everything a caller must know to use the module correctly: procedure signatures, invariants, ordering constraints, error modes, required setup, performance characteristics, the events the module publishes, the events the module subscribes to. Includes but is wider than AL `interface` objects.
_Avoid_: API, signature, contract (too narrow). And do not equate "interface" with the AL `interface` keyword: that keyword declares one *kind* of seam; the architectural Interface is the whole knowable surface.

**Implementation**
What is inside the module: codeunit bodies, table triggers, page actions, helpers, internal codeunits. Distinct from **adapter**: a thing can be a small adapter with a large implementation (a real Web Service connector) or a large adapter with a small implementation (an in-memory test fake). Reach for "adapter" when the seam is the topic; "implementation" otherwise.
_Avoid_: internals (overloaded), guts.

**Depth**
Leverage at the interface: how much behaviour a caller (or test) can exercise per unit of interface they have to learn. **Deep** = a lot of behaviour behind a small interface. **Shallow** = the interface is nearly as complex as the implementation. Not a ratio of implementation-lines to interface-lines (that rewards padding the body).

**Seam** _(Feathers)_
A place where behaviour can be altered without editing in place. The *location* at which a module's interface lives. Choosing where the seam goes is its own design decision, distinct from what sits behind it. AL shapes: a published `IntegrationEvent` (with optional `IsHandled`), an AL `interface` object plus an Implementer codeunit, a table-extension field, an event subscriber attaching to a publisher, and a `List of [Interface I…]` / `Dictionary of [Text, Interface I…]` collection (BC 2025 W1, runtime 15.0) where adapters self-register via `.Add()`.
_Avoid_: boundary (overloaded with DDD's bounded context).

**Adapter**
A concrete codeunit (or implementing codeunit) that satisfies an interface at a seam. Names a *role* (which slot it fills), not substance. An `App Deposit Slip Printer` and a `Stub Deposit Slip Printer` are two adapters at the same seam. See [testability.md](testability.md) for AL code shapes.
_Avoid_: implementation (when you mean role, say adapter), driver, plugin.

**Leverage**
What callers get from depth. More capability per unit of interface they have to learn. One implementation pays back across N call sites and M tests. The reason a façade earns its place: many callers, one well-tested surface.
_Avoid_: reuse (too vague; reuse can be shallow copy-paste).

**Locality**
What maintainers get from depth. Change, bugs, knowledge, and verification concentrate at one place rather than spreading across callers. Fix once, fixed everywhere. The maintainer-side mirror of leverage.
_Avoid_: cohesion (related, but locality is about *where the change lands*, not about what belongs together).

**Connascence** _(Page-Jones)_
The coupling grammar: two elements are connascent when changing one forces a change in the other. Names *what kind* of coupling and *how strong*, where "tight coupling" only gestures. Static forms (weaker → stronger): of **name** (both must agree on a name), of **type**, of **meaning** (both must agree what a value signifies — a magic `Code[20]` or status string two procedures interpret in lockstep), of **position** (callers depend on argument order — a long positional parameter list). Dynamic forms (stronger still): of **execution order** (B only works if A ran first — `SetLoadFields` after `SetRange`, or `repeat` with no `Find` before it), of **timing**, of **value**, of **identity**. Refactor rule: prefer weaker connascence over stronger, and where strong connascence is unavoidable, **localize** it (keep the connascent elements in one module). Generalises primitive-obsession (connascence of meaning) and long-parameter-lists (connascence of position) under one axis; gives the structural lens a reason to introduce an enum, a parameter record, or a guard.
_Avoid_: "tight coupling" (names the symptom, not the kind or strength), "dependency" (too generic).

**Command-Query Separation (CQS)** _(Meyer)_
A procedure is either a **command** (causes an effect — `Insert`/`Modify`/`Delete`, telemetry, error, event — and returns nothing) or a **query** (returns a value and has no observable effect), never both. The procedure-level expression of R → P → W: the query side is P (pure, returns a decision), the command side is W (effect, returns nothing). Canonical violation: a *business* procedure that `Modify`s a record *and* returns a computed total — a caller cannot read the total without also posting. Splitting it along the command/query line is the refactor.
**AL carve-out.** BC platform contracts that legitimately return a value *and* touch state are NOT violations — do not flag them: `Get` / `Find*` (return found-status, populate the record), `Codeunit.Run` / `[TryFunction]` (return success Boolean, effects by design), `NoSeries` next-number (returns the number, advances the series). The smell is a business query that mutates as an incidental side effect, never these.
_Avoid_: "getter/setter" (too OO, misses the no-effect guarantee), "side-effect-free" (only half — names the query, not the command).

**R → P → W** _(procedure layering)_
**R** = reads (DB queries, parameters in, events subscribed to), **P** = pure process (decisions, no DB, no external calls), **W** = writes (`Insert` / `Modify` / `Delete`, telemetry, errors, events published). P is the unit-test surface; `Access = Internal` makes it test-accessible without crossing the external interface. Two test surfaces follow: E2E crosses the external interface (R + P + W end-to-end); unit tests target P directly with stubbed R/W collaborators. See [tdd.md](tdd.md) and [testability.md](testability.md).
_Avoid_: treating R / P / W as a label slapped on an existing tangle. The split *is* the refactor.

## Behavioural decomposition

The terms above describe static structure. The terms below describe behavioural decomposition: what the feature *does*, which trigger initiates each behaviour.

**Slice** _(Event Modeling)_
One initiated behaviour expressed as **trigger → command → event → state → view**. The unit of architectural decomposition at the funnel-top, sits between the Solution slot and the Module map slot in `architecture.md`. AL slices map to four canonical patterns:

- **Command** slice: page action, report request *(user-initiated)*.
- **Automation** slice: event subscriber, Job Queue, install/upgrade *(system-initiated)*. Most common AL pattern.
- **Translation** slice: API page, web service, webhook *(external-system-initiated)*.
- **View** slice: page render, FlowField, report layout *(read-only)*.

Settlement is two-artifact for user/API-facing slices. User-facing slots (Role, Action, Business Event, View, Status; BC vocabulary at external-observer altitude, no AL pub/sub) settle in `event-model.md` via `/al-event-model`. AL realisation (trigger object, command codeunit, publication or subscription, state mutation, view rendering) settles in `architecture.md` via `/al-design`. Pure-backend slices (Job Queue, install / upgrade, scheduled task) skip `event-model.md`; the trigger-source slot carries them and AL realisation settles in `architecture.md` directly.

The pattern qualifies the slice in `architecture.md`: `Slice (Automation): trigger ...`. _Avoid_: user story (too unstructured), use case (too OO), flow (already used for the diagram).

**Vertical slicing** _(predates VSA, implicit in Kent Beck's TDD, 2002)_
Per-task / per-PR rule: every task ships tests + production code together; never data-only, logic-only, or wire-up-only; always leaves the system green. Applies to every `T-NNN` in `tasks.md`. The opposite, *horizontal phasing*, is rejected by name. Lower-altitude than Vertical Slice Architecture; folder structure is VSA, per-task discipline is vertical slicing.
_Avoid_: horizontal phasing, layer-by-layer build, big-bang integration.

## Pillars

Four pillars under unit-testable AL. Cited by `/al-design` (test strategy), `/al-implement` (TDD cycle), `/al-refactor` (legacy code without tests). Content absorbed from the former `testability-pillars.md`; see [testability.md](testability.md) for AL code shapes.

**Pillar 1: Decoupling production from BC infrastructure.**
Production code does not call the database directly inside decision logic; it accepts data and dependencies as parameters. A well-decoupled unit test needs **zero `Library*` calls**. If a test calls `Library - Sales` or `Library - ERM` to prepare the SUT, the production code is still coupled to BC infrastructure. Fix the production code, not the test.

**Pillar 2: Three-phase refactor with self-overload injection.**
Extract internal procedures (one responsibility each), declare an `Access = Internal` interface, inject via self-overload: production codeunit implements its own interface; `OnRun()` passes `This`. Existing `Codeunit.Run()` callsites stay untouched. Zero breaking changes for downstream consumers.

**Pillar 3: Three default seams for environment-style dependencies.**
Environment seam `"IEnvironment"`, external-API seam `"IApiRequest"`, BaseApp standard-application seam (e.g., `"IFinance"`, `"IPosting"`, `"ISales"`). Reach for the named pattern first; declare a new seam only when none fits. Production impl prefixed `App`, stub impl prefixed `Stub`, never shipped in the production app. For logic that depends only on a record's own fields, pass `var TempRecord: Record X temporary` instead of declaring an interface.

**Pillar 4: Test double taxonomy and naming.**
Five kinds (Meszaros): **Dummy** (satisfies parameter), **Stub** (returns fixed data; default for env seams), **Spy** (records call), **Mock** (stub + spy; verifies call contracts), **Fake** (working implementation). File prefix signals the kind: `StubIConverter.Codeunit.al`, `MockIPurchInvEdit.Codeunit.al`. All test doubles live in the unit test app, never in the production app. Naming a Stub a "Mock" loses the distinction; name the kind exactly.

## BC translations

The architectural vocabulary maps onto AL constructs, but the AL construct is never the architectural concept. Keep both labels.

| Architectural term | Common AL realisation | _Avoid_ saying |
|---|---|---|
| Module | folder under `src/<module>/` | "module" = `.app` |
| Interface | the public-by-contract surface a caller sees | "interface" = the AL `interface` keyword |
| Seam | published event, AL `interface` boundary, Implementer injection point, table-extension field | "boundary" |
| Adapter | implementing codeunit, event-subscriber codeunit, mock codeunit | "class" |
| Implementation | codeunit body, table triggers, page actions | "internals" |
| Codeunit | AL's procedure container; *plays the role of* an adapter or holds implementation | "class" (codeunits have no inheritance) |
| Table | AL's persisted record schema; *plays the role of* an entity but with BC semantics (Insert / Modify / Delete triggers, FlowFields, FlowFilters, primary key, SystemId) | "entity" without qualification |
| AL `interface` object | a single seam *declaration*, the contract row of an Implementer-pattern seam; never the whole architectural Interface | TS/C# `interface` keyword (different lifecycle, different runtime) |
| Slice | the trigger / command / event / state / view chain naming one initiated behaviour | "user story" (slices include non-user triggers) |

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small parts; they just are not part of the interface. A module has both an *external seam* (its interface, where callers cross) and *internal seams* (private to the implementation, used by its own unit tests).
- **The deletion test.** Imagine deleting the module. If complexity vanishes, the module was not hiding anything (it was a pass-through; delete it). If complexity reappears across N callers, the module was earning its keep. Does not apply when the seam is a published event with no in-tree callers.
- **The two-adapter rule.** One adapter means a hypothetical seam. Two adapters means a real one. Do not introduce a port (AL `interface` plus Implementer codeunit, or a publishable event plus its first subscriber) unless at least two adapters justify it (typically production + test, or two real production variants). One-adapter "interfaces for testability" are speculative bloat.
- **Two test surfaces, both first-class.** Integration / E2E tests cross the external seam via `Access = Public`, exercising R and W. Unit tests live *inside* the module, calling internal procedures directly (especially the P layer). AL's `Access = Internal` is test-accessible from the same app; Microsoft's BaseApp tests do this throughout. Scenario test-layer choice (Pure / E2E / Both) in `architecture.md` decides which surface each scenario uses.
- **Internal seams stay private.** Do not expose them through the module's external interface just because tests use them. When unit tests have to reach past `Access = Internal`, reshape: split the responsibility into a smaller internal codeunit, rather than weaken visibility for the test's sake.
- **The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.
- **"Class" for codeunit is wrong.** AL has no inheritance; codeunits are not classes. Say **codeunit**, or **adapter** when role is what matters.
- **"Entity" bare for table loses the BC semantics.** Tables carry Insert/Modify/Delete triggers, FlowFields, primary key, SystemId. Say **table** or **record**.

## Relationships

- A **module** has exactly one **interface** (the surface it presents to callers and tests).
- **Depth** is a property of a **module**, measured against its **interface**.
- A **seam** is where a **module**'s **interface** lives.
- An **adapter** sits at a **seam** and satisfies the **interface**.
- **Depth** produces **leverage** for callers and **locality** for maintainers.
- A **slice** is decomposed *behaviourally* (one initiated behaviour); a **module** is decomposed *structurally* (one cohesive responsibility). One slice typically lives across one or more modules; one module typically participates in one or more slices.
