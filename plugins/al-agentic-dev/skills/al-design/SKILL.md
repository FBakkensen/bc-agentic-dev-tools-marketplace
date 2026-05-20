---
name: al-design
description: Idea → feature architecture for AL/Business Central. Names modules under src/, picks one BC pattern per module, draws the R → P → W boundary, lists brownfield touchpoints, decides test layer per scenario family, runs parallel design-twice for non-trivial calls, then creates the branch and writes architecture.html. Use after /al-grill-adr, before /al-scope. Per feature, not per task.
---

# /al-design, Idea → feature architecture

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on. No need to comment on what was skipped.

Turn a sharpened idea into a feature-level architecture. Name **modules**, pick one BC **pattern** per module, draw R → P → W, list brownfield touchpoints, decide the test layer. Run parallel design-twice for non-trivial calls. Create the branch + spec folder. Write `architecture.html` as a map, not a memoir. Stop, `/al-scope` consumes it next.

This skill produces a slot-fill `architecture.html` whose load-bearing decisions are: which **modules** earn rows, where their **seams** sit, which **adapters** justify each seam, and which test surface each scenario family crosses. Vocabulary is fixed; see *Architectural vocabulary* below and `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` in full.

Voice contract for everything this skill writes to `architecture.html`, ADRs, and `CONTEXT.md`: `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. Read it before writing.

HTML styling discipline and self-contained constraints: `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md`. Read it before writing the HTML.

**Resolve target paths:**
- **Repo root**, `CONTEXT.md`, `docs/adr/`. Durable across features. Markdown.
- **Spec folder**, `specs/<NNN>-<slug>/architecture.html`. Created here. HTML, self-contained, Mermaid + Google Fonts via CDN.
- **Templates**, `CONTEXT.template.md` and `adr.template.md` at `${CLAUDE_SKILL_DIR}/../../references/` (plugin-level shared). Read-only; materialised lazily into the target repo on first need. `architecture.html` has no template; structure follows `html-spec-discipline.md` plus the slot rules below.
- **Legacy markdown specs.** Folders under `specs/` containing `architecture.md` are frozen historical artifacts from before the HTML shift. DO NOT re-run `/al-design` on a folder that holds `architecture.md` without `architecture.html`; halt and surface the choice (delete the markdown and reshape into HTML, or hand-migrate).

## Flow

Prefer parallel delegated workers for independent work and output-heavy steps when the host supports subagents.

1. **Precondition.** `/al-grill-adr` must have run for this idea. No exception. If not, `Stop.` and run it first. The grilling outcome (sharpened intent + `CONTEXT.md` / domain ADR side-effects) feeds step 2.
2. **Repo memory.** Read `CONTEXT.md` (materialise from template if missing). Read every ADR in `docs/adr/` touching the area. Use the project's domain language throughout the rest of this flow. **Absorb every cited ADR's Consequence section (where present) into a slot of `architecture.html`** (Slice(s), Module map, Brownfield touchpoints, R→P→W, Test strategy); the `## ADRs cited` slot is a pointer list, not a substitute. Downstream skills do not re-read the ADR.
3. **Slice(s).** Name every initiated behaviour the feature delivers. Format from **Event Modeling** (Adam Dymitruk, eventmodeling.org): **trigger → command → event → state → view**, one paragraph per slice in `architecture.html`'s `Slice(s) (Event Modeling)` section. Each slice opens with its pattern (`Command` / `Automation` / `Translation` / `View`); pattern catalogue and BC trigger-source mapping live in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` *Slice* entry. **Apply the slice completeness gate**: every slice fills all five positions; a void means the feature isn't ready for `/al-scope`. See *Slot rules* below for void semantics.
4. **Module map.** A **module** is a folder under `src/<module>/` containing the cohesive unit. List modules added / extended / touched. **Apply the deletion test** to every candidate row before writing it: imagine deleting the module, if complexity vanishes, it's a pass-through (don't add it); if complexity reappears across N callers, it earns its row. Use **CONTEXT.md vocabulary** for the role; *the `Settlement intake` module*, never *the `FooBarHandler`*. Every new table / page / codeunit will need an AppSource permission-set entry and an ID from the registered range; note this against the row, but the assignment happens in `/al-implement`.
5. **Pattern per module.** Run `/al-research` first to verify against current BaseApp examples and AppSource rules. Pick one pattern from `${CLAUDE_SKILL_DIR}/../../references/bc-patterns.md`. **Apply the two-adapter rule** to every pattern that implies a seam (Event Bridge, Template Method, Command Queue, AL `interface`-based Façade): name both adapters now (typically production + test, or two real production variants), or change the pattern. One adapter means a hypothetical seam; do not introduce it. If a pattern needs explaining, the module shape is wrong; reshape, do not rename.
6. **R → P → W boundary** at feature level. Run `/al-research` first to verify any BaseApp procedure or event signature on the boundary. **R** = inputs (records, parameters, events subscribed to). **P** = pure procedure(s), no DB, no side effects; this is the unit-testable surface. **W** = effects (Insert / Modify / Delete, telemetry, errors, events published).
7. **Brownfield touchpoints.** Run `/al-research` first to verify exact procedure / event / table-field names and signatures; stale memory turns the touchpoint list into fiction. List every existing object / procedure to extract, inject seam into, rename, or split. Shipped fields and objects are never removed or renamed in place; `ObsoleteState`: `Pending` → `Removed` over the deprecation window, scheduled in `/al-implement`.
8. **Test layer per scenario family.** Pure (P-layer, no DB) by default; drawing the R → P → W boundary is what makes Pure available. E2E when the behaviour is composition or a side effect that can't be reproduced at the pure layer (event wiring, table triggers, telemetry shape, install/upgrade transitions). `Both` only when intent splits cleanly across layers. ZOMBIES sequencing happens in `/al-scope` / `/al-refine`, not here.
9. **Parallel design-twice (gate)**: mandatory for non-trivial. See *Parallel design-twice*.
10. **AppSource compliance sanity.** Two design-time risks: BaseApp modification (intercept via published events, table extensions, or AL `interface` implementations; never edit in place), and design choices that force a shipped-field rename or removal. Both are reshape triggers. The full compliance block (IDs, permission sets, `DataClassification`, captions, install / upgrade) lives in `/al-implement`, where it bites per task.
11. **ADR offers.** Architectural picks (mechanism, seam placement, pattern, test layer) surface here; see *ADR offer criteria*. If a fresh **domain** rule surfaces, pause and run `/al-grill-adr` again; do not write a domain ADR inline.
12. **Branch + folder + write.** Already on `^\d{3}-`?
`Stop.`
Must run from `main`. Resolve `<NNN>` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` (the cross-branch scan, not a local-only scan of `specs/`). Derive a 2–4-word kebab-case slug; do not ask. Announce the branch name and slug, then create branch `<NNN>-<slug>` and `specs/<NNN>-<slug>/`. Branch exists locally or remotely?
`Stop.`
User resolves. Read `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` and the most recently modified prior spec under `specs/*/` (if any) for visual coherence; write `architecture.html` per the *Section list and order* and *Slot rules* below. Names are the citation.
`Stop.`

## Output: architecture.html

Self-contained HTML, one document. Inline `<style>`, Google Fonts via CDN (no Inter / Roboto / Arial), Mermaid pinned `@11` via jsdelivr. Aesthetic discipline and surgical-edit hooks in `html-spec-discipline.md`. `architecture.html` carries one hook only: `<div class="mermaid" data-graph="module-deps">` and / or `<div class="mermaid" data-graph="flow">` when the diagrams are present. Maintaining skills do not surgical-edit `architecture.html`; reshape happens by re-running `/al-design`.

**Map, not memoir.** No inline citations (`(see: file.al:120)` is forbidden; names are the citation). No rationale paragraphs. No `Notes` dumping ground. No future-roadmap sketches. Rationale lives in ADRs (when load-bearing) or in the conversation transcript that produced this doc.

**Sharpness gates, not length caps.** Each slot below states `_When earned:_` / `_Skip when:_`. Slot-fill earns its place by passing the gate; padding to hit a length and stripping to hit a length both miss the point. One paragraph per slot; if a slot needs more, the slot likely splits.

### Section list and order

Required, in this order. Section headings are typographically free (the aesthetic chooses display weight and rhythm) but the slot identity and slot order are fixed.

1. `Goal`
2. `Problem`
3. `Solution`
4. `Slice(s) (Event Modeling)`
5. `Module map`
6. `R → P → W`
7. *(optional)* `Module dependencies` (Mermaid `graph LR`, gated)
8. *(optional)* `Flow` (Mermaid `sequenceDiagram` or `flowchart TD`, gated)
9. `Brownfield touchpoints`
10. `Test strategy`
11. `ADRs cited`
12. *(optional)* `Future composition`
13. `Risks`

Linkify ADR mentions as `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>` wherever they appear in Module map roles, R → P → W, ADRs cited, and Risks bodies.

### Slot rules

#### Goal

The user-visible outcome. Phrase as the result, not as the work.

- _Avoid_: *"Implement a new settlement export feature that, when a sales invoice is posted, will take the relevant data from the posted document and produce a bank-file payload..."*
- Use: *"Posted sales invoices land in the partner bank's settlement file within the same posting transaction."*

#### Problem

Wrap in a CAUTION callout. Aesthetic chooses the visible form (styled `<aside>`, marginalia, framed paragraph); the slot semantic is "caution-class problem statement."

- _Avoid_: *"There is currently no automated way to export posted invoice data to the bank, which means that finance users have to manually copy the totals..."*
- Use: *"Finance re-keys posted invoice totals into the bank portal: a daily 30-minute manual step that drifts from the ledger on every correction."*

#### Solution

Wrap in a TIP callout. Names the visible behaviour change, not the modules.

- _Avoid_: *"We will build a new module called `settlement-export` that subscribes to the `OnAfterPostSalesDoc` event published by codeunit `Sales-Post`, extracts the posted document into a payload..."*
- Use: *"Posting a sales invoice emits a bank-file line; finance reviews the daily batch on a new Settlement Export page."*

#### Slice(s) (Event Modeling)

One paragraph per slice. Each slice opens with its **pattern** (`Command` / `Automation` / `Translation` / `View`) and fills five positions: **trigger → command → event → state → view**. Pattern catalogue and BC trigger-source mapping in `LANGUAGE.md` *Slice* entry.

Slot-fill shape (express in prose; the aesthetic decides whether positions render as a labelled list, hanging-indent labels, or inline bold runs):

> **Slice ({Pattern}), {one-phrase name in domain vocabulary}.**
> **Trigger:** {what initiates the slice: page action, event publisher, API path, install hook}.
> **Command:** {procedure or composition that mutates state}.
> **Event(s):** {`IntegrationEvent` published, BaseApp event subscribed to, or `none` for slices that change state without publishing}.
> **State:** {tables / fields the slice writes; existing state it preserves}.
> **View:** {page, list, FlowField, or report row that confirms the state change to a human or downstream system}.

- _Avoid_: *"User-facing slice; when something happens on the sales side, the system processes it and updates configuration data..."*
- Use: *"**Slice (Automation), Posted sales invoices queue a bank-file line.** Trigger: `OnAfterInsertSalesInvoiceHeader` published from BaseApp `Sales-Post`. Command: `SettlementExportMgt.QueueLine(SalesInvHeader)`. Event(s): none; slice subscribes, does not publish. State: new `Settlement Export Line` row keyed on the posted invoice; `Settlement Batch.Status` advances when the day's queue closes. View: Settlement Export page shows the day's batch with line totals."*

**Slice completeness gate.** Every slice fills all five positions. A void means the feature is not ready for `/al-scope`. Voids and what they mean:

- *No trigger* → no interface; the work is internal-only (pure refactor / build / test only). See `_Skip when:_` below.
- *No command* → the slice is a *View* (read-only); confirm that is intended.
- *No event(s)* → either the BaseApp event you would subscribe to or publish does not exist (run `/al-research`), or the slice does not change state (View again).
- *No state* → View slice.
- *No view* → no observable confirmation; reconsider whether the slice belongs here.

_When earned:_ the feature delivers at least one initiated behaviour (Command / Automation / Translation / View).
_Skip when:_ the feature is purely internal (pure refactor with no behaviour change, build-only, test-only). State the skip reason in the conversation, not the doc.

#### Module map

A table. Aesthetic renders the table with hairline rules or whatever the monograph style chose; structure is one row per module. Columns: `Module`, `Status`, `Pattern`, `Role`. Bold the Status column values (`new`, `changed`, `extended`); leave `kept` plain. Linkify ADR mentions in the Role column.

Example row content:

| Module | Status | Pattern | Role |
|---|---|---|---|
| `src/settlement-export/` | **new** | Façade | one phrase, the responsibility in CONTEXT.md vocabulary, with ADR cites linkified |
| `src/sales-post-ext/` | **extended** | Generic Method | one phrase |
| `src/finance-shared/` | touched | - | one phrase, what is added or changed at the seam |

Status is `new` / `changed` / `extended` / `touched` / `kept`. Pattern is one entry from `bc-patterns.md`, or `-` for trivial touchpoints. Role is one phrase in domain vocabulary, never a procedure signature.

_When earned:_ always.
_Skip when:_ never. The module map is the load-bearing slot in this doc.

**Sharpness:** apply the deletion test to every new row before writing it. If deleting the proposed module would just shift complexity by one hop, reshape; do not add the row. Apply the two-adapter rule to every Pattern that implies a seam (Event Bridge, Template Method, Command Queue): name both adapters now or change the pattern.

#### R → P → W

Linkify ADR mentions inline.

- **R**: inputs: records read, parameters, events subscribed to.
- **P**: pure procedure(s): the computation, no DB, no side effects.
- **W**: effects: Insert / Modify / Delete, telemetry, errors, events published.

The boundary, not the mechanics. Pseudocode lives in `/al-implement` notes. The P line is the most load-bearing; it names what can be unit-tested without standing up DB state.

_When earned:_ always.
_Skip when:_ never. Even pure-extension features have R→P→W (often R is "the event payload", P is "validate", W is "subscriber side effect").

#### Module dependencies (optional)

Mermaid `graph LR` between codeunits. Names match Module map exactly. Arrow labels only when the verb is not obvious. Complements the Flow diagram with a static dependency view.

Embed in HTML as `<div class="mermaid" data-graph="module-deps">graph LR\n  A --> B\n</div>`.

_When earned:_ ≥4 modules involved AND at least one non-linear edge (fan-out, fan-in, layered indirection, cross-module event flow).
_Skip when:_ the Module map's Pattern and Role columns already convey the shape; ≤3 modules; the relationships are linear and obvious.

#### Flow (optional)

Mermaid `sequenceDiagram` for actor-call ordering, or `flowchart TD` for data-transformation pipelines. Embed as `<div class="mermaid" data-graph="flow">...</div>`.

_When earned:_ temporal ordering text would numerate; the branch is the architectural decision (not just a flag); async handoff between modules; re-entry into a phase already executed; or an event-publish/subscribe loop.
_Skip when:_ the R → P → W summary already covers the ordering; the ordering is single-pass and obvious from the Module map.

Maximum one of each diagram kind. When neither earns its place, both sections are absent; no empty slot.

#### Brownfield touchpoints

Table. Columns: `File`, `Action`, `Note`.

| File | Action | Note |
|---|---|---|
| `Foo.Codeunit.al` | extend signature | add `SkipReseed` 5th param + 4-param overload |
| `Bar.Codeunit.al` | new procedure | `RegenerateVariantsInHierarchy(ConfigNo)` |
| `Sales-Post.Codeunit.al` | subscribe | `OnAfterInsertSalesInvoiceHeader` |

Action is `extend signature` / `new procedure` / `subscribe` / `rename` / `split` / `obsolete`. Note carries the *what* in five-to-twelve words; no rationale, no procedure bodies.

_When earned:_ the feature touches existing objects.
_Skip when:_ pure greenfield with no published event subscriptions and no existing object extensions. Most AL features touch something; be honest about it.

**Sharpness:** every row must come from `/al-research` verification of the current procedure / event / table-field name and signature. Stale memory turns this section into fiction.

#### Test strategy

Table. Columns: `Scenario family`, `Layer`, `Lives in`.

| Scenario family | Layer | Lives in |
|---|---|---|
| family in domain vocabulary | Pure | `FooTest.Codeunit.al` |
| family | E2E | `BarTest.Codeunit.al` |
| family | Both | `BazTest.Codeunit.al`, `BazIntegration.Codeunit.al` |

Layer is `Pure` / `E2E` / `Both`. ZOMBIES sequencing happens in `/al-scope` and `/al-refine`, not here.

**Sharpness:** Pure is the default; the P layer of R → P → W is what makes it possible. E2E earns its place when the behaviour is composition or a side effect that cannot be reproduced at the pure layer (event wiring, table triggers running, telemetry shape, install/upgrade transitions). `Both` only when intent splits cleanly across layers; if you are tempted to write `Both` for everything, the scenario family is too broad. Split it.

#### ADRs cited

Link list. Each entry is one ADR plus one phrase on its relevance to this feature.

- `<a href="../../docs/adr/NNNN-slug.md">ADR-NNNN</a>`, one phrase on relevance.

Do not quote ADR content; point to it.

_When earned:_ at least one ADR informs this design.
_Skip when:_ no existing ADR is relevant. Empty section is omitted, not left blank.

#### Future composition (optional)

Forward-looking content wrapped in a default-closed `<details>` block.

```html
<details>
<summary><strong>Future composition (ADR-NNNN)</strong>, forward-looking, collapsed by default</summary>
<p>Content describing how a future feature is expected to compose on the current architecture.</p>
</details>
```

_When earned:_ the current architecture deliberately leaves a composition seam for a planned future feature, and the planning context is load-bearing for readers of this doc.
_Skip when:_ no planned future composition, or the planning context lives in an ADR already.

#### Risks

One alert per risk class, severity matched to actual risk. Each alert leads with a bold label then body. Aesthetic chooses the visible alert form (styled `<aside>`, framed panel, marginalia); the severity classes below name what the slot is.

| Class | Severity | Slot |
|---|---|---|
| AppSource compatibility / informational | low | NOTE alert |
| Mitigated breaking change (e.g. shielded by overload) | medium | TIP alert |
| Real data-loss or unmitigated breaking risk | high | WARNING alert (or CAUTION when destructive) |
| Performance regression on a hot path with stated budget | varies | match severity to budget gap |

Example bodies:

> **AppSource**: side-table approach avoids extending shipped `Customer` flowfield; install upgrade is data-only.

> **Breaking change**: callers of `CopyConfiguration(SourceNo, TargetNo, var Header)` see a fifth `SkipReseed` parameter; 4-arg overload shielded for backwards compatibility.

_When earned:_ a class of risk genuinely applies. Each alert has its own gate; write only the alerts that fire.
_Skip when:_ no risks of these classes apply. The section is then absent.

**Sharpness:** these are named slots, not a brainstorm list. *"Risk: this might be slow"* is not a risk. Name the hot path, the budget, and the safeguard. If a candidate risk does not fit one of the listed classes, it is not a risk for *this* doc; it belongs in `/al-implement` notes or in an ADR.

## Parallel design-twice (gate)

Non-trivial = multi-module, brownfield refactor, or novel pattern selection. Use three parallel delegated design passes with divergent constraints when the host supports subagents:

| Pass | Constraint |
|---|---|
| 1 | Minimise the **interface**, 1–3 entry points, maximise leverage per entry. |
| 2 | Maximise flexibility, many use cases, easy extension. |
| 3 | Optimise the most common caller, default case trivial. |

Each delegated pass runs its own `/al-research` for any AL/BC behavioural claim. Each receives a brief that includes BC vocabulary from `CONTEXT.md` and architectural vocabulary from `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`, so all three name things consistently.

**Output contract:** module map + per-module interface, named adapters at every seam, and the one trade-off line that distinguishes this design from the others.

Reconcile: present all three sequentially so the user can absorb each. Then compare in prose along three axes: **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**. Pick one design, or a hybrid, with reasoning. Be opinionated; the user wants a strong read, not a menu. Run `/grill-me` when judgement needs the user. **No silent skip.**

Skip when single-module addition, well-known pattern, no brownfield seams. Record the skip reason in the conversation, not the doc.

## ADR offer criteria

Offer only when **all four** are true:

1. **Hard to reverse**: cost of changing later is meaningful.
2. **Surprising without context**: a future reader will wonder why.
3. **Real trade-off**: genuine alternatives, picked one for specific reasons.
4. **Architectural, picks a point in the design space.** Mechanism, module shape, pattern, seam placement, test layer. Domain rules belong to `/al-grill-adr`.

Format: `${CLAUDE_SKILL_DIR}/../../references/adr.template.md`, short body, optional sections gated. ADRs stay markdown; HTML mode does not apply to `docs/adr/`.

## Architectural vocabulary

Full discipline in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`.

- **Module**: a folder under `src/<module>/` containing a cohesive unit. _Avoid_: component, service, unit.
- **Interface**: everything a caller must know: signatures, invariants, ordering, error modes, required setup, performance characteristics. Includes, but is much wider than, AL `interface` objects. _Avoid_: API, signature; do not equate the architectural Interface with the AL `interface` keyword.
- **Implementation**: what's inside: codeunit bodies, table triggers, helpers.
- **Seam**: where behaviour can be altered without editing in place. In AL: published events (`OnBefore*` / `OnAfter*` with optional `IsHandled`), AL `interface` boundaries, Implementer codeunit injection points, table-extension fields. _Avoid_: boundary.
- **Adapter**: a concrete codeunit (or implementing codeunit) satisfying an interface at a seam. Names a role, not substance. _Avoid_: class.
- **Depth**: leverage at the interface. Deep = a lot of behaviour behind a small interface; shallow = interface as complex as the implementation.
- **Leverage** / **Locality**: what callers and maintainers respectively get from depth. **Depth produces leverage and locality.**
- **Slice** *(Event Modeling, Dymitruk)*, one initiated behaviour expressed as **trigger → command → event → state → view**, qualified by pattern (Command / Automation / Translation / View). Behavioural decomposition; sits alongside the structural Module map. _Avoid_: user story, use case.

**Deletion test, two-adapter rule.** Cited in flow steps 4 and 5 above. Both apply at design time: don't add a module that fails the deletion test; don't introduce a seam that doesn't justify two adapters.

**Slice completeness gate.** Cited in flow step 3 above. Every slice fills trigger / command / event / state / view; voids halt the flow until the gap is named (research, replan, or skip the slice as internal-only).

## Lazy reference reads

| Source (read-only) | Target (writable) | Trigger |
|---|---|---|
| `${CLAUDE_SKILL_DIR}/../../references/CONTEXT.template.md` | `CONTEXT.md` (repo root) | step 2, if missing |
| `${CLAUDE_SKILL_DIR}/../../references/adr.template.md` | `docs/adr/NNNN-<slug>.md` | step 11, on ADR accept; resolve `NNNN` per `cross-branch-numbering.md` |
| `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` | (read, not materialised) | step 11 (ADR `NNNN`) and step 12 (spec folder `NNN`), before picking the number |
| `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` | (read, not materialised) | step 12, before writing HTML |
| most recently modified prior spec under `specs/*/` | (read, not materialised) | step 12, before writing HTML, when a prior spec exists |

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records, not Create / Update / Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Records** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Composition

- `/al-grill-adr`, precondition.
- `/al-research`, mandatory at flow steps 4, 5, 6, and inside every design-twice delegated pass.
- `/bc-standard-reference`, reachable directly when the question is purely BaseApp behaviour.
- `/grill-me`, for ADR offers and design-twice reconciliation.
- `/al-scope`, consumes `architecture.html` next.
- `/al-steer`, replan venue if a flow gate hard-halts.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before materialising `architecture.html` for the first time. The slot-fill is load-bearing for every downstream skill; drift caught here costs minutes, drift caught at `/al-implement` costs a feature.

</claude-only>

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `html-spec-discipline.md`, aesthetic posture + Mermaid embedding + self-contained constraint + prior-spec consultation; mandatory before writing `architecture.html`.
- `cross-branch-numbering.md`, source-of-truth for picking `NNN` (spec folders, step 12) and `NNNN` (ADRs, step 11) across parallel branches.
- `decoupling.md`, three-phase legacy refactor (extract internals → interface → inject) when brownfield touchpoints surface seams worth carving.
- `environment-interfaces.md`, three default decoupling seams (`IEnvironment`, `IApiRequest`, `IFinance`-family); reach for the named pattern before declaring a fresh one.

## Out of scope

- No code edits, no interface extraction (`/al-refactor`), no Gherkin (`/al-refine`), no mutations (`/al-mutate`).
- No per-task architecture (`/al-implement` step 2).
- No replan gates beyond the precondition (`/al-steer`).
- No domain ADRs inline; those belong to `/al-grill-adr`.
- No markdown-mode output. Legacy markdown specs are frozen historical artifacts; `/al-design` refuses to run on a spec folder that holds `architecture.md` without `architecture.html`.
