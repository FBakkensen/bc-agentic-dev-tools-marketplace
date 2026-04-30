# BC/AL Design Patterns

Canonical patterns documented at https://alguidelines.dev/docs/patterns/, embedded here so `/al-design` can pick one per module without external lookup.

Pick **one pattern per module**. If a pattern needs explaining, it's wrong for AL — pick a different one or reshape the module.

---

## Façade

**What:** A unified, simplified interface to complex subsystems. Hides implementation details behind an easy-to-understand façade, creating a clear public API while keeping internal complexity private.

**When:** Whenever you build a functional group or independent system with a distinct API. System Application modules (Azure Blob Services, Barcode, Cryptography Management) are canonical examples.

**Structure:**
- **Façade (public)** — single codeunit with `Access = Public`. All methods documented. Methods contain no logic — they delegate.
- **Subsystem (internal)** — one or more codeunits with `Access = Internal`. Holds the actual business logic. Inaccessible externally.

**Benefits:** Decoupling (callers cannot depend on internals), maintainability (rewrite internals without breaking the contract), testability (test the façade's contract).

**When not to use:** Hiding implementation details also prevents external extension points — use judgement when extensibility is primary.

---

## Event Bridge

**What:** A dedicated, isolated codeunit containing only publisher events corresponding to an interface, so multiple implementations of the same interface raise consistent events.

**When:** Interface-based architectures where multiple implementations need shared, consistent events that external apps may subscribe to.

**Structure:**
- **Bridge codeunit** — houses `[IntegrationEvent(false, false)]` procedures. Named to match the interface (e.g. interface `"IScale"` → bridge `"IScale Triggers"`).
- **Implementation codeunits** — instantiate the bridge codeunit and invoke its events.
- **Naming:** interface and bridge share a common prefix for discoverability.

**When not to use:** Only implement events that logically apply across all implementations. Don't over-engineer with events specific to a single implementation.

---

## Generic Method

**What:** A standardised structure for one significant piece of business logic — posting documents, batch operations — encapsulated in a dedicated codeunit with a single public entry point and an extensibility surface.

**When:** Significant business operations. Not for validation code, helper functions, or trivial logic.

**Structure (three layers):**
1. **UI layer** — manages dialogs and interaction via a `HideDialog` parameter.
2. **Event layer** — exposes `OnBefore` and `OnAfter` integration events (with `IsHandled` flags so subscribers can override or disable functionality).
3. **Method layer** — contains the actual business logic in a `Do…` procedure.

The codeunit is exposed through a table or codeunit procedure for IntelliSense discoverability.

**Benefits:** Extensibility (events let dependent apps hook in), decoupling (`IsHandled` flags), testability (single responsibility), maintainability.

**When not to use:** Validation, helpers, or non-method logic. Use judgement on what counts as a "method."

---

## Template Method

**What:** A skeleton algorithm defined in a template codeunit, with specific steps delegated to interface implementations. The template owns the procedural flow; implementations own the details.

**When:** Related problems sharing identical workflows — document posting, report generation, data export. Improves maintainability by preventing "different solutions" for the same flow.

**Structure (three components):**
1. **Template codeunit** — defines the procedural flow without implementation details.
2. **Interface** — specifies required procedures for implementations.
3. **Implementation codeunit(s)** — concrete classes implementing the interface.

**Benefits:** Readability and consistency, simplified addition of new cases, reduced cognitive load (developers focus on details, not the overall flow).

**When not to use:** When implementations differ substantially. If two data exports diverge significantly (e.g. one exports header + lines, the other exports only header), use separate templates instead of forcing a shared one.

---

## Error Handling

**What:** A structured approach to surfacing system issues to users — emphasising error *collection* (accumulating multiple errors during one operation) rather than halting at the first failure.

**When:** Multiple validation errors might occur in a single process; you want to give users comprehensive feedback rather than one-issue-at-a-time interruptions.

**Structure:** `TryFunctions` and `GetLastErrorText` to capture exceptions without halting; collect failures across an operation, then present them together. Microsoft Learn has the full error-collection mechanism details.

**Benefits:** User-friendly comprehensive feedback; transparent, actionable error messages; balances robustness with usability.

---

## API Register Fieldset

**What:** Track which fields appear in an API request body by registering them in a temporary `Field` table during validation, so the API can distinguish *unset* from *set-to-default*.

**When:** API operations that need to enforce mandatory fields, distinguish insert vs modify behaviour, prevent specific fields from being changed during certain operations, or apply templates without overwriting API-provided data.

**Structure:** Store field numbers in a temporary `Field` record during `OnValidate` triggers. Reference the fieldset during `OnInsertRecord` and `OnModifyRecord` for conditional logic.

**Key warning:** Without field registration, the API cannot tell "explicitly set to default" from "unspecified" — both reach the trigger as the same value, blocking validation and rule enforcement.

---

## Delegate API Operation

**What:** Move data manipulation (insert / modify / delete) from API pages into dedicated codeunits, giving you control over the order of business logic relative to record persistence.

**When:** You need logic before record persistence, default values during creation, temporary-buffer use, or `OnValidate` triggers operating on records that already exist.

**Structure:** Create a codeunit with internal procedures taking record parameters. Return `false` from page triggers (`OnInsertRecord`, `OnModifyRecord`, `OnDeleteRecord`) after delegating to the codeunit.

**Key benefit:** Bypasses delayed-insert behaviour on API pages; enables complex business logic before persistence.

**Warning:** Codeunit procedures must update the record parameters with final results so API responses reflect actual state.

---

## Command Queue

**What:** Sequential execution of multiple independent processes via an interface (`ICommand` with `Execute()`) and a Queue codeunit that manages entries. Each command implements the interface independently.

**When:** Several independent processes need to run successively — posting multiple orders, cascading operations — without spaghetti control flow. Each process handles its own error handling.

**Structure:** Interface `ICommand` with `Execute()`. Queue codeunit holding entries. Implementations attach via the interface.

**Key warning:** The queue lives in memory only. Service restart loses it. Not suitable for critical, persistent operations needing durability.

**When not to use:** Controlling a single process. Persistent / mission-critical sequences.

---

## No. Series

**What:** BC's standard system for generating sequential, alphanumeric identifiers for master records and documents. Tracks usage, supports date-driven structures, controls manual entry permissions.

**When:** Unique data entities like Customers or Sales Orders that need automatic numbering.

**Avoid for:** Permanently-recorded entries (ledger Entry No.), mutable working data (journal Line No.).

**Structure:** Define a `Code[20]` field for the number and another field for the series ID. `OnInsert` trigger calls `NoSeries.GetNextNo()` (BC v24+) after validating setup. `OnValidate` of the number field calls `NoSeries.TestManual()` when users override.

**Warning:** BC v24+ deprecated `NoSeriesManagement` in favour of `codeunit "No. Series"` with streamlined methods. Use the new codeunit on v24+.

---

## Picking a pattern at design time

Common at feature level: **Façade**, **Event Bridge**, **Generic Method**, **Template Method**, **Error Handling**.

Specialised: **API Register Fieldset**, **Delegate API Operation** (API page design), **Command Queue** (in-memory sequencing), **No. Series** (numbered records).

Pick one per module. State the choice on the module line in `architecture.md`. If the module's responsibility doesn't match any pattern in this catalogue, the module shape is probably wrong — reshape before naming a pattern.
