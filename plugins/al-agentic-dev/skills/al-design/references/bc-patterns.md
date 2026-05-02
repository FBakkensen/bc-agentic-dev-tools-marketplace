# BC/AL design patterns

Reference vocabulary for `/al-design`. Pick **one pattern per module**. If a pattern needs explaining, the module shape is wrong — reshape, don't rename.

Each entry follows the same shape: **What** / **When** / **When not** / **Structure** / **_Avoid_:** (named misuse → anti-pattern). Anti-patterns are named so reviews can call them by name.

Source: https://alguidelines.dev/docs/patterns/.

---

## Façade

**What:** A unified, simplified interface to complex subsystems. Single `Access = Public` codeunit fronts a cluster of `Access = Internal` workers. The façade is depth made visible — small interface, large implementation behind it.

**When:** A functional group with a distinct API that callers should never reach past. System Application modules (Azure Blob Services, Barcode, Cryptography Management) are canonical examples. Two-adapter rule applies if the façade fronts a swappable subsystem; otherwise, façade-without-seam is still legitimate when the value is locality and discoverability.

**When not:** When external apps must extend the subsystem. Hiding implementation also hides extension points — choose Generic Method or Event Bridge instead.

**Structure:**
- **Façade (public)** — single codeunit with `Access = Public`. Methods documented. Methods contain delegation, not logic.
- **Subsystem (internal)** — one or more codeunits with `Access = Internal`. Holds the business logic. Inaccessible externally.

**_Avoid_:** **Pass-through façade** (anti-pattern) — façade methods that just forward call-by-call to one internal codeunit, no aggregation, no hiding. Fails the deletion test: delete the façade and complexity doesn't reappear across callers, it just shifts one hop. Either deepen (move real logic up, hide more behind), or delete and let callers depend on the internal codeunit directly.

---

## Event Bridge

**What:** A dedicated codeunit containing only `IntegrationEvent` publishers, raised by every implementation of a shared AL `interface`. Every adapter raises consistent events through one bridge.

**When:** Interface-based architectures where two-or-more implementations need shared, consistent events that external apps may subscribe to. The two-adapter rule earns its keep here — one implementation does not justify a bridge.

**When not:** Single implementation. One adapter = hypothetical seam — wait for the second.

**Structure:**
- **Bridge codeunit** — houses `[IntegrationEvent(false, false)]` procedures. Named to match the AL `interface` (interface `"IScale"` → bridge `"IScale Triggers"`).
- **Implementation codeunits** — instantiate the bridge codeunit and invoke its events.
- **Naming:** AL `interface` and bridge share a common prefix for discoverability.

**_Avoid_:** **Per-implementation event drift** (anti-pattern) — adapters publish their own events because "this one's special." Subscribers then bind to one adapter. The contract breaks the moment a second adapter ships. Only events that logically apply across all adapters belong on the bridge; if an event truly is implementation-specific, it does not belong in the seam at all.

---

## Generic Method

**What:** A standardised three-layer structure for one significant business operation — posting documents, batch operations — with a single public entry point and an extensibility surface (`OnBefore` / `OnAfter` with `IsHandled`).

**When:** Significant business operations where extensibility is part of the contract. Document posting, large batch jobs, anything other apps will hook.

**When not:** Validation, helpers, or trivial logic. The pattern's overhead — UI / Event / Method layering — is wasted if the operation is small or has no extension story.

**Structure (three layers):**
1. **UI layer** — manages dialogs and interaction via a `HideDialog` parameter.
2. **Event layer** — exposes `OnBefore` and `OnAfter` integration events with `IsHandled` flags so subscribers can override or disable functionality.
3. **Method layer** — the actual business logic in a `Do…` procedure.

The codeunit is exposed through a table or codeunit procedure for IntelliSense discoverability.

**_Avoid_:** **Validation dressed as Generic Method** (anti-pattern) — wrapping a validation procedure or helper in the three-layer ceremony. The events get no subscribers, the UI layer is empty, the `Do…` procedure is the only thing that ever runs. Use a plain procedure on a focused codeunit instead.

---

## Template Method

**What:** A skeleton algorithm in a template codeunit with specific steps delegated to AL `interface` implementations. The template owns the procedural flow; adapters own the details.

**When:** Related problems sharing identical workflows — document posting, report generation, data export. Stops "different solutions" emerging for the same flow. Two-adapter rule must hold — one variant is not a Template Method, it's just a codeunit.

**When not:** Implementations diverge substantially. If two data exports differ in shape (one exports header + lines, the other only header), use separate templates instead of forcing a shared one.

**Structure (three components):**
1. **Template codeunit** — defines the procedural flow; calls into the AL `interface` for the variant steps.
2. **AL `interface` object** — specifies required procedures.
3. **Implementation codeunit(s)** — adapters realising the AL `interface`.

**_Avoid_:** **Forced commonality** (anti-pattern) — flattening genuinely different workflows into a single template by stuffing the differences into wide AL `interface` parameters or `case`-on-type branches inside adapters. The template stops being a flow and becomes a router. Split into two templates the moment a variant carries shape-changing branches.

---

## Error Handling

**What:** Structured error *collection* — accumulating multiple validation failures during one operation and surfacing them together, instead of halting at the first failure. Built on `TryFunctions` and `GetLastErrorText`.

**When:** Multiple validation errors might occur in a single process and users benefit from comprehensive feedback (mass-import, document posting with many lines, batch validation).

**When not:** Single validation, or where the first failure invalidates everything that follows. Don't collect errors when collecting them is misleading.

**Structure:** `TryFunctions` capture exceptions without halting; collect failures across the operation; present them together at the end. Microsoft Learn covers the full collection mechanism.

**_Avoid_:** **Silent collection** (anti-pattern) — gathering errors and forgetting to surface them, or surfacing them in a place users don't read (a hidden table, a log line). Collected errors that aren't shown are worse than first-failure-halt: the user thinks the operation succeeded.

---

## API Register Fieldset

**What:** Track which fields appear in an API request body by registering them in a temporary `Field` table during validation, so the API can distinguish *unset* from *set-to-default*.

**When:** API operations enforcing mandatory fields, distinguishing insert vs modify, blocking specific fields during certain operations, or applying templates without overwriting API-provided data.

**When not:** Internal callers or UI flows. The pattern exists because the API surface can't otherwise tell "absent" from "default" — non-API callers don't have the ambiguity.

**Structure:** Store field numbers in a temporary `Field` record during `OnValidate` triggers. Reference the fieldset during `OnInsertRecord` and `OnModifyRecord` for conditional logic.

**_Avoid_:** **Default-as-absent** (anti-pattern) — assuming a field's default value means the caller didn't send it. Without registration, both reach the trigger as the same value, blocking validation and rule enforcement, and the bug is invisible until a customer sets a field to its default deliberately.

---

## Delegate API Operation

**What:** Move data manipulation (Insert / Modify / Delete) out of API pages into dedicated codeunits. Gives explicit control over the order of business logic relative to record persistence.

**When:** Logic must run before record persistence; default values must be set during creation; temporary buffers are involved; `OnValidate` triggers must operate on records that already exist.

**When not:** Plain CRUD without ordering needs. The pattern's cost is the indirection; pay it only when ordering or pre-persistence work demands it.

**Structure:** Codeunit with internal procedures taking record parameters. Page triggers (`OnInsertRecord`, `OnModifyRecord`, `OnDeleteRecord`) delegate to the codeunit and return `false`.

**_Avoid_:** **Stale response record** (anti-pattern) — codeunit procedures mutate a local copy and forget to update the record parameter. The page returns the pre-mutation state; the API response disagrees with what was actually written. Always update the record parameter with final state.

---

## Command Queue

**What:** Sequential execution of independent processes through an AL `interface` (`ICommand` with `Execute()`) and a Queue codeunit that owns the entries. Each command is one adapter.

**When:** Several independent processes need to run in sequence — posting multiple orders, cascading operations — without spaghetti control flow. Each adapter handles its own errors.

**When not:** Controlling a single process; persistent / mission-critical sequences; anything that must survive a service restart. The queue lives in memory only.

**Structure:** AL `interface` `ICommand` with `Execute()`. Queue codeunit holding entries. Adapters attach via the AL `interface`.

**_Avoid_:** **Persistent-illusion queue** (anti-pattern) — using Command Queue for operations that must survive process restart (long-running posting batches, scheduled jobs). The queue evaporates on restart; half-executed sequences leave inconsistent state. For durable work, use Job Queue Entries or persisted command tables — not this pattern.

---

## No. Series

**What:** BC's standard system for generating sequential, alphanumeric identifiers for master records and documents. Tracks usage, supports date-driven structures, controls manual entry permissions.

**When:** Unique data entities — Customers, Sales Orders, custom master records — needing automatic numbering with manual-override semantics.

**When not:** Permanently-recorded entries (ledger Entry No. fields — these are sequence-stamped at posting time, not from a series), mutable working data (journal Line No. — this is line ordering, not identity).

**Structure:** `Code[20]` field for the number plus a field for the series ID. `OnInsert` calls `NoSeries.GetNextNo()` (BC v24+) after validating setup. `OnValidate` of the number field calls `NoSeries.TestManual()` when users override.

**_Avoid_:** **Legacy `NoSeriesManagement`** (anti-pattern on v24+) — BC v24 deprecated `NoSeriesManagement` in favour of codeunit `"No. Series"` with streamlined methods. New code on v24+ that still calls the deprecated codeunit ages instantly. Use the new codeunit.

---

## Picking a pattern at design time

Common at feature level: **Façade**, **Event Bridge**, **Generic Method**, **Template Method**, **Error Handling**.

Specialised: **API Register Fieldset**, **Delegate API Operation** (API page design), **Command Queue** (in-memory sequencing), **No. Series** (numbered records).

Pick one per module. State the choice on the module line in `architecture.md`. If the module's responsibility doesn't match any pattern in this catalogue, the module shape is probably wrong — reshape before naming a pattern.
