# Legacy AL refactor plan

Phased process for legacy AL code that ships **without sufficient tests**. Use when there is no calling task and no `architecture.html`. Companion to `/al-refactor`; does not replace its inline discipline (which assumes tests already exist).

## Preconditions

- Code is version-controlled.
- `/al-build` works.
- Write tests before changing behaviour, not after. No green baseline means no regression signal; stop and write the baseline first.

## Dependency categories

Classify each dependency the candidate module reaches for. The category determines testing strategy and whether a port is justified at the seam.

**1. In-process.** Pure computation, in-memory state, no I/O. Rounding, discount math, document-number assembly, validation predicates. Always deepenable. Merge shallow helpers and test through the new interface directly. No port, no adapter.

**2. Local-substitutable.** Dependencies with local stand-ins inside the BC test runtime. Tables (test isolation gives transactional rollback), `Library*` helpers, `LibraryRandom`. Deepenable when the stand-in exists. Tests use the stand-ins via `[Test]` codeunits with `Subtype = Test`. Seam is internal; no port at the module's external interface.

**3. Remote but owned.** Your own services across a network or async boundary. API pages you publish, integration codeunits calling internal Azure Functions, queues you own. Define a port (AL `interface` object) at the seam. Production adapter implements transport (`HttpClient`, Service Bus); test adapter is an in-memory codeunit implementing the same interface.

**4. True external.** Third-party services you do not control. Stripe, Twilio, ERP-to-CRM webhooks, external rate APIs. The deepened module takes the external dependency as an injected port; tests provide a mock adapter asserting the contract observed in production. Schema drift on the external side is a replan, not a refactor.

## Seam discipline

- **Two adapters = real seam.** No port unless at least two adapters are justified (typically production + test, or two production transports already deployed). A single-adapter seam is just indirection.
- **Internal seams vs external seams.** A deep codeunit can have internal seams (private helpers, used by its own unit tests against `Access = Internal`) alongside the external seam at its public interface. Do not widen `Access` because tests use them.
- AL seam mechanisms: `interface` objects, `Implementation` enums, event publishers. Picking among them is a *seam-shape* decision, separate from *what sits behind the seam*.

## The deletion test

Apply to anything that smells shallow. Imagine deleting the module; does complexity vanish or concentrate?

- **Yes, merge it.** A one-line wrapper around `SalesHeader.Modify` that adds nothing but a name. Inline at call sites.
- **No, leave it.** A posting validator orchestrating dimension checks, No. Series consumption, and ledger writes. Deleting concentrates complexity into the caller; the depth is real.

## Testing strategy: replace, do not layer

- Old unit tests on shallow modules become waste once tests at the deepened module's interface exist. **Delete them.** Keeping the old tests "for safety" preserves the shape you are trying to dissolve.
- Write new tests at the deepened module's interface. The interface is the test surface.
- Assert on observable outcomes through the interface (record state, ledger entries, error messages, returned values), not internal state.
- Tests should survive internal refactors. If a test has to change when the implementation changes, push the assertion outward.

## Phase 1: rename and tighten locality

No behaviour change.

- Rename to BC vocabulary (Insert/Modify/Delete, Post, Validate, Get/Find, Ledger Entry, No., Procedure).
- Extract magic numbers to named constants.
- Add XML doc-comments where the WHY is non-obvious. No comment churn.
- Tighten `Access` modifiers; internal helpers move behind `Access = Internal`.
- Build and re-run tests. Address any failure before Phase 2.

## Phase 2: reshape along R→P→W

- Split tangled procedures along the R→P→W line. Read inputs, pass records-by-value/DTOs into a pure Process procedure, Write outputs last.
- Apply the deletion test to shallow helpers; merge or delete pass-throughs.
- Move feature-envious procedures to where the data lives.
- Replace primitive-obsession `Code[20]` carriers with small records or enums.
- Replace `Message()` with `Error()` for validation failures (behaviour change; pair with the test edit in Phase 3).
- Run `/al-build` after every extraction.

## Phase 3: modernise APIs and define seams

- Replace deprecated `Find('-')` with `FindSet()`.
- Add `SetLoadFields` for performance.
- Implement proper transaction handling.
- Replace hard-coded values with configuration tables (Setup table or similar).
- BC v24+: replace `NoSeriesManagement` with `codeunit "No. Series"`.
- Where dependency category 3 or 4 surfaces, define the port and implement production + in-memory adapters. **Two adapters or no port.**
- Update tests for intentional behaviour changes. `Message → Error` flips a previously-silent branch into an error case; assertions update for the new shape, in the same change.

## Expand coverage

- Add tests for edge cases and error conditions revealed during reshape.
- Test the deepened module through its public interface.
- Add internal unit tests against `Access = Internal` for the Process layer where useful.
- Replace, do not layer; delete unit tests on modules the refactor merged away.

If during Phase 2 or 3 a hidden requirement or design flaw surfaces, halt and recommend `/al-design` (architecture reshape) or `/al-refine` (Gherkin reshape) via `/al-steer`. **No silent scope expansion.**
