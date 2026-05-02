# Legacy AL Refactor Plan — deepening shallow modules without a safety net

Phased process for refactoring legacy AL code that ships **without sufficient tests**. Companion to `/al-refactor`. Use when there is no calling task and no `architecture.md`.

## When to use

- **Standalone refactor of legacy code** — predates this plugin's TDD flow, lacks behaviour-verifying tests, or has tangled responsibilities.
- **Not** for the post-green refactor inside `/al-implement` — that uses `/al-refactor`'s inline discipline (tests already exist, R→P→W boundary already drawn, brownfield touchpoints already named in `architecture.md`).

This plan complements `/al-refactor`'s inline discipline; it does not replace it.

## Preconditions

- Code is version-controlled.
- `/al-build` works.
- Write tests before changing behaviour, not after.

**Anti-pattern: rolling refactor without baseline tests.** No green baseline means no regression signal. Stop and write the baseline first.

## Dependency categories

Classify each dependency the candidate module reaches for. The category determines testing strategy and whether a port is justified at the seam.

### 1. In-process

Pure computation, in-memory state, no I/O. AL examples: rounding, discount math, document-number assembly, validation predicates.
**Always deepenable.** Merge shallow helpers and test through the new interface directly. No port, no adapter.

### 2. Local-substitutable

Dependencies with local stand-ins inside the BC test runtime. AL examples: tables (test isolation gives transactional rollback), `Library*` helpers, `LibraryRandom`, in-memory document-number patterns.
**Deepenable when the stand-in exists.** Tests use the stand-ins via `[Test]` codeunits with `Subtype = Test`. Seam is internal; no port at the module's external interface.

### 3. Remote but owned

Your own services across a network or async boundary. AL examples: API pages you publish, integration codeunits calling internal Azure Functions, queues you own.
Define a port — typically an AL `interface` object — at the seam. Production adapter implements transport (`HttpClient`, Service Bus). Test adapter is an in-memory codeunit implementing the same interface, registered via `Implementation` enum or DI parameter.

Recommendation shape: *"Define a port at the seam, ship one production adapter and one in-memory test adapter, so the logic sits in one deep module even though it crosses a network."*

### 4. True external

Third-party services you don't control. AL examples: Stripe, Twilio, ERP-to-CRM webhooks, external rate APIs.
The deepened module takes the external dependency as an injected port; tests provide a mock adapter asserting the contract observed in production. Schema drift on the external side is a replan, not a refactor.

## Seam discipline

- **Two adapters = real seam.** No port unless at least two adapters are justified — typically production + test, or two production transports already deployed. A single-adapter seam is just indirection.
- **Internal seams vs external seams.** A deep codeunit can have internal seams (private helpers, used by its own unit tests against `Access = Internal`) alongside the external seam at its public interface. Don't widen `Access` because tests use them — that pushes implementation into the contract.
- **AL-specific:** `interface` objects, `Implementation` enums, and event publishers are seam mechanisms. Picking among them is a *seam-shape* decision, separate from *what sits behind the seam*.

## The deletion test

Apply to anything that smells shallow. Imagine deleting the module — does complexity vanish or concentrate?

- **Yes — merge it.** A one-line wrapper around `SalesHeader.Modify` that adds nothing but a name. Inline at call sites; the abstraction earns nothing.
- **No — leave it.** A posting validator orchestrating dimension checks, No. Series consumption, and ledger writes. Deleting concentrates complexity into the caller. The depth is real.

## Testing strategy: replace, don't layer

- Old unit tests on shallow modules become waste once tests at the deepened module's interface exist — **delete them.**
- **Anti-pattern: layering tests instead of replacing.** Keeping the old shallow-module tests "for safety" preserves the shape you're trying to dissolve. Tests on a merged-away module document a contract that no longer exists.
- Write new tests at the deepened module's interface. The interface is the test surface.
- Assert on observable outcomes through the interface (record state, ledger entries, error messages, returned values), not internal state.
- Tests should survive internal refactors. If a test has to change when the implementation changes, push the assertion outward.

## Phase 1 — Rename and tighten locality

No behaviour change.

- Rename to BC vocabulary (Insert/Modify/Delete, Post, Validate, Get/Find, Ledger Entry, No., Procedure — see `/al-refactor` Naming table).
- Extract magic numbers to named constants.
- Add XML doc-comments where the WHY is non-obvious. No comment churn.
- Tighten `Access` modifiers — internal helpers move behind `Access = Internal`.
- Build and re-run tests. Address any failure before Phase 2.

## Phase 2 — Reshape along R→P→W

- Split tangled procedures along the R→P→W line. Read inputs, pass records-by-value/DTOs into a pure Process procedure, Write outputs last.
- Apply the deletion test to shallow helpers — merge or delete pass-throughs.
- Move feature-envious procedures to where the data lives.
- Replace primitive-obsession `Code[20]` carriers with small records or enums.
- Replace `Message()` with `Error()` for validation failures (behaviour change — pair with the test edit in Phase 3).
- Run `/al-build` after every extraction.

## Phase 3 — Modernise APIs and define seams

- Replace deprecated `Find('-')` with `FindSet()`.
- Add `SetLoadFields` for performance.
- Implement proper transaction handling.
- Replace hard-coded values with configuration tables (Setup table or similar).
- BC v24+: replace `NoSeriesManagement` with `codeunit "No. Series"`.
- Where dependency category 3 or 4 surfaces, define the port and implement production + in-memory adapters. **Two adapters or no port.**
- Update tests for intentional behaviour changes. `Message → Error` flips a previously-silent branch into an error case — assertions update for the new shape, in the same change.

## Expand coverage

- Add tests for edge cases and error conditions revealed during reshape.
- Test the deepened module through its public interface.
- Add internal unit tests against `Access = Internal` for the Process layer where useful.
- Replace, don't layer — delete unit tests on modules the refactor merged away.

## Composition

- After baseline tests exist, the rest of this plan composes with `/al-refactor` — its inline *Smells*, *Reshape*, *Naming*, *AppSource* sections are effectively Phases 1 + 2, with the second-opinion gate and `/al-build` after every meaningful change.
- If during Phase 2 or 3 a hidden requirement or design flaw surfaces, halt and recommend `/al-design` (architecture reshape) or `/al-refine` (Gherkin reshape) via `/al-steer`. **No silent scope expansion.**
- If R→P→W boundary work surfaces during Phase 2/3 and there is a calling task, that's `/al-refactor` Replan trigger #6 — set `[!]`. Otherwise note and recommend `/al-steer`.
