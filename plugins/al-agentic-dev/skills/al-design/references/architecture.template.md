# architecture.md template

Slot-fill, not free prose. Each slot is sharpened by a gate — say what earns the section, what skips it. Names are the citation, rationale lives in ADRs (when load-bearing) or in the conversation transcript that produced this doc.

**Map entry** — `| src/settlement-export/ | new | Façade | closes a settlement batch and emits the bank-file payload |`. One row, one phrase, domain vocabulary. The reader navigates from the name.

**Memoir prose** — *"We chose the Façade pattern here because, after considering Variant Façade and Generic Method, we felt that the synchronous return values needed by the caller and the relatively stable shape of the export workflow argued for a plain Façade; the alternative would have been..."* — rationale, alternatives considered, narrative voice. None of that goes in this doc. Load-bearing rationale becomes an ADR; the rest stays in the conversation.

Required sections, in this order:
`## Goal` → `## Problem` → `## Solution` → `## Slice(s) (Event Modeling)` → `## Module map` → `## R → P → W` → (optional `## Module diagram`, `## Flow`) → `## Brownfield touchpoints` → `## Test strategy` → `## ADRs cited` → `## Risks`.

Every section uses the gate format: a short slot-fill, with `_When earned:_` / `_Skip when:_` triggers stating what makes the section honest.

---

## Goal

{The user-visible outcome. Phrase as the result, not as the work.}

- No: *"Implement a new settlement export feature that, when a sales invoice is posted, will take the relevant data from the posted document and produce a bank-file payload conforming to the partner bank's specification, so that finance users no longer have to manually export and upload the file…"*
- Yes: *"Posted sales invoices land in the partner bank's settlement file within the same posting transaction."*

_When earned:_ always — every architecture has a goal.
_Skip when:_ never.

## Problem

{The gap this feature closes, in user-visible terms.}

- No: *"There is currently no automated way to export posted invoice data to the bank, which means that finance users have to manually copy the totals from each posted invoice into the bank portal one at a time, and this process is both time-consuming and error-prone, particularly when corrections are made to the underlying invoices…"*
- Yes: *"Finance re-keys posted invoice totals into the bank portal — a daily 30-minute manual step that drifts from the ledger on every correction."*

_When earned:_ always.
_Skip when:_ never.

## Solution

{What ships, in user-visible terms. Names the visible behaviour change, not the modules.}

- No: *"We will build a new module called `settlement-export` that subscribes to the `OnAfterPostSalesDoc` event published by codeunit `Sales-Post`, extracts the posted document into a payload, and through a Façade pattern emits the bank-file line, which is then surfaced via a new page where finance users can review the day's batch…"*
- Yes: *"Posting a sales invoice emits a bank-file line; finance reviews the daily batch on a new Settlement Export page."*

_When earned:_ always.
_Skip when:_ never.

## Slice(s) (Event Modeling)

One paragraph per slice. Each slice opens with its **pattern** — `Command` / `Automation` / `Translation` / `View` — and fills five positions: **trigger → command → event → state → view**. Pattern qualifies the trigger source; positions describe the chain. Pattern catalogue and BC trigger-source mapping live in `LANGUAGE.md` *Slice* entry.

Slot-fill format:

> **Slice ({Pattern}) — {one-phrase name in domain vocabulary}.**
> **Trigger:** {what initiates the slice — page action / event publisher / API path / install hook}.
> **Command:** {procedure or composition that mutates state}.
> **Event(s):** {`IntegrationEvent` published, BaseApp event subscribed to, or `none` for slices that change state without publishing}.
> **State:** {tables / fields the slice writes; existing state it preserves}.
> **View:** {page, list, FlowField, or report row that confirms the state change to a human or downstream system}.

- No: *"User-facing slice — when something happens on the sales side, the system processes it and updates configuration data, then the relevant pages refresh to show what changed…"*
- Yes: *"**Slice (Automation) — Posted sales invoices queue a bank-file line.** Trigger: `OnAfterInsertSalesInvoiceHeader` published from BaseApp `Sales-Post`. Command: `SettlementExportMgt.QueueLine(SalesInvHeader)`. Event(s): none — slice subscribes; does not publish. State: new `Settlement Export Line` row keyed on the posted invoice; `Settlement Batch.Status` advances when the day's queue closes. View: Settlement Export page shows the day's batch with line totals."*

**Sharpness — slice completeness gate.** Every slice fills all five positions. A void = the feature isn't ready for `/al-scope`. Voids and what they mean:

- *No trigger* → no interface; the work is internal-only (pure refactor / build / test only) — see `_Skip when:_` below.
- *No command* → the slice is a *View* (read-only); confirm that's intended.
- *No event(s)* → either the BaseApp event you'd subscribe to / publish doesn't exist (run `/al-research`) or the slice doesn't change state (View again).
- *No state* → View slice.
- *No view* → no observable confirmation; reconsider whether the slice belongs here.

_When earned:_ the feature delivers at least one initiated behaviour — Command / Automation / Translation / View.
_Skip when:_ the feature is purely internal — pure refactor (no behaviour change), build-only, test-only. State the skip reason in the conversation, not the doc.

## Module map

| Module | Status | Pattern | Role |
|---|---|---|---|
| `src/{module-a}/` | new | Façade | {one phrase — the responsibility, in CONTEXT.md vocabulary} |
| `src/{module-b}/` | extended | Generic Method | {one phrase} |
| `src/{module-c}/` | touched | — | {one phrase — what's added or changed at the seam} |

One row per module. Status is `new` / `extended` / `touched`. Pattern is one entry from `bc-patterns.md`, or `—` for trivial touchpoints. Role is one phrase in domain vocabulary, never a procedure signature.

_When earned:_ always.
_Skip when:_ never. The module map is the load-bearing slot in this doc.

**Sharpness:** apply the deletion test to every new row before writing it. If deleting the proposed module would just shift complexity by one hop, reshape — don't add the row. Apply the two-adapter rule to every Pattern that implies a seam (Event Bridge, Template Method, Command Queue): name both adapters now or change the pattern.

## R → P → W

- **R** — {inputs: records read, parameters, events subscribed to}
- **P** — {pure procedure(s): the computation, no DB, no side effects}
- **W** — {effects: Insert / Modify / Delete, telemetry, errors, events published}

The boundary, not the mechanics. Pseudocode lives in `/al-implement` notes. The P line is the most load-bearing — it names what can be unit-tested without standing up DB state.

_When earned:_ always.
_Skip when:_ never. Even pure-extension features have R→P→W (often R = "the event payload", P = "validate", W = "subscriber side effect").

## Module diagram (optional)

{Mermaid `flowchart LR`. Names match Module map exactly. Arrow labels only when the verb isn't obvious.}

_When earned:_ ≥4 modules involved AND at least one non-linear edge (fan-out, fan-in, layered indirection, cross-module event flow).
_Skip when:_ the Module map's Pattern + Role columns already convey the shape; ≤3 modules; the relationships are linear and obvious.

## Flow (optional)

{Mermaid `sequenceDiagram` for actor-call ordering, or `flowchart TD` for data-transformation pipelines.}

_When earned:_ temporal ordering text would numerate, the branch is the architectural decision (not just a flag), async handoff between modules, re-entry into a phase already executed, or an event-publish/subscribe loop.
_Skip when:_ the `## R → P → W` summary already covers the ordering; the ordering is single-pass and obvious from the Module map.

When both diagrams earn their place, group them under `## Diagrams` with `### Module diagram` and `### Flow` subsections. When neither earns its place, the section is absent — no empty slot. Mermaid only. Maximum one of each.

## Brownfield touchpoints

| File | Action | Note |
|---|---|---|
| `Foo.Codeunit.al` | extend signature | add `SkipReseed` 5th param + 4-param overload |
| `Bar.Codeunit.al` | new procedure | `RegenerateVariantsInHierarchy(ConfigNo)` |
| `Sales-Post.Codeunit.al` | subscribe | `OnAfterInsertSalesInvoiceHeader` |

One row per touchpoint. Action is `extend signature` / `new procedure` / `subscribe` / `rename` / `split` / `obsolete`. Note carries the *what* in five-to-twelve words — no rationale, no procedure bodies.

_When earned:_ the feature touches existing objects.
_Skip when:_ pure greenfield with no published event subscriptions and no existing object extensions. Most AL features touch something — be honest about it.

**Sharpness:** every row must come from `/al-research` verification of the current procedure / event / table-field name and signature. Stale memory turns this section into fiction.

## Test strategy

| Scenario family | Layer | Lives in |
|---|---|---|
| {family in domain vocabulary} | Pure | `FooTest.Codeunit.al` |
| {family} | E2E | `BarTest.Codeunit.al` |
| {family} | Both | `BazTest.Codeunit.al`, `BazIntegration.Codeunit.al` |

One row per scenario family. Layer is `Pure` / `E2E` / `Both`. ZOMBIES sequencing happens in `/al-scope` and `/al-refine`, not here.

_When earned:_ always.
_Skip when:_ never.

**Sharpness:** Pure is the default — the P layer of R→P→W is what makes it possible. E2E earns its place when the behaviour is composition or a side effect that can't be reproduced at the pure layer (event wiring, table triggers running, telemetry shape, install/upgrade transitions). `Both` only when intent splits cleanly across layers; if you're tempted to write `Both` for everything, the scenario family is too broad — split it.

## ADRs cited

- ADR-NNNN — {slug} — {one phrase on relevance to this feature}

Link list. Do not quote ADR content — point to it.

_When earned:_ at least one ADR informs this design.
_Skip when:_ no existing ADR is relevant. Empty section is omitted, not left blank.

## Risks

- **AppSource:** {one line — the compliance risk and how the design addresses it}
- **Breaking change:** {one line — the affected callers, and the migration path or absence of one}
- **Data loss:** {one line — the table or field at risk and the safeguard}
- **Performance:** {one line — the hot path and the budget}

_When earned:_ a class of risk genuinely applies. Each bullet has its own gate — write only the bullets that fire.
_Skip when:_ no risks of these classes apply. The section is then absent.

**Sharpness:** these are named slots, not a brainstorm list. *"Risk: this might be slow"* is not a risk — name the hot path, the budget, and the safeguard. If a candidate risk doesn't fit one of the four classes, it isn't a risk for *this* doc; it belongs in `/al-implement` notes or in an ADR.
