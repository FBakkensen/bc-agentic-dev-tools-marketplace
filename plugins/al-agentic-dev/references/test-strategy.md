# Test strategy — the execution pyramid

Shared frame for the **verification** skills: where each kind of test runs, what it can prove, and how a failure at one layer routes to another. Sits alongside `LANGUAGE.md` (static design vocabulary), `test-specification.md` (task grammar), and `tdd.md` (the red-green *cycle*); this file owns the *execution* axis. Cited by `/al-build`, `/al-implement`, `/al-mutate`, `/al-refine`, `/al-page-script`, `/al-user-verification`.

Read-only. Read in place via `${CLAUDE_SKILL_DIR}/../../references/test-strategy.md`.

The terms are sourced — a sourced term has an external definition the project cannot quietly redefine. **Test Pyramid** from Cohn (*Succeeding with Agile*, 2009) and Fowler; the inverted **Ice-Cream-Cone** anti-pattern from Alister Scott; **oracle problem** from Weyuker (*On Testing Non-testable Programs*, 1982); **checking vs testing** from Bach & Bolton (Rapid Software Testing); **nested feedback loops** from Beck (XP). Naming them is what lets the next agent inherit a whole operating contract in one clause.

## The five layers (mapped to the BC tech stack)

| Layer | Mechanism | Oracle | Role | Owning skill(s) |
|---|---|---|---|---|
| **Unit** | AL-Runner (fast, in-process) | assertion, isolated | red-first driver | `/al-implement` (`-UnitTestOnly`), `/al-build` |
| **Integration** | container + TestPage | assertion, transactional rollback | red-first driver | `/al-implement`, `/al-build` |
| **E2E** | bc-replay page-script (fresh container, no rollback) | assertion, **oracle-limited** | UI acceptance regression guard | `/al-page-script`; batch run by `/al-user-verification` |
| **Contract** | Postman, curl, integration harness, or named client | assertion, client-facing | API/client acceptance regression guard | `/al-user-verification`; harness named by `Verification Plan` |
| **Exploratory** | guided user walk (user drives the real client; agent guides, records, routes) | **sapient judgement** (the user's) | usability oracle (findings → tasks) | `/al-user-verification` |

The mapping is **primary mechanism, not a wall.** AL-Runner is the fast subset / pre-gate; the container is authoritative and runs both isolated decision and TestPage `[Test]` codeunits. Speed and oracle fidelity, not a rigid unit/integration boundary, decide where a test lives. Placement mechanics — the two-peer-test-app layout, the AL Runner capability boundary, isolation semantics, and the test-app authoring contract — live in [test-layout.md](test-layout.md).

**Push tests down.** Cover behaviour at the lowest (fastest, most isolated, most sensitive) layer that *can* cover it; reserve the slow, brittle upper layers for what lower layers genuinely cannot reach. The inverted shape where E2E and contract checks carry the primary proof is the Ice-Cream-Cone anti-pattern. E2E, Contract, and Exploratory checks are **written after** the code from verify-task examples: they are regression guards and quality probes, **not** red-first design drivers. Expecting a page-script recording to "go red first" is a category error.

## The three feedback rules

Each is named only because it changes what the agent does.

**Push-down** (the pyramid's prescriptive core). A failure surfaced at a higher layer that a lower layer missed is a signal to add the red test at the *cheapest layer that can pin it*, fix there, and leave the higher test as the guard. A production bug surfaced by a page-script or contract red normally routes **down** to `/al-implement` for a Unit or Integration red test + TDD fix. Fix at the higher layer only when no lower layer can reach the behaviour (real BC TestPage limits: control add-ins, canvas, rendering, web-client-only behaviour, client-only contract behaviour). The surviving guard is bounded by ownership: standard BaseApp/SA behaviour (posting computes the right amounts, a number series increments) is Microsoft's to test — re-asserting it is theatre and a duplicate of BaseApp's own suite. So it asserts neither MS math nor a weak "it didn't error", but the *contract your extension depends on across the seam* — the event fired with the parameters you consume, a field you read is populated, the status you branch on transitioned, your side-effect landed after MS processing. A Unit test cannot see that (the real seam never runs there), and it catches MS *drift*. Re-assert your own branching logic a Unit case already pins, and it is duplication again — strip those, keep the seam-level obligation.

**Oracle problem** (Weyuker). An oracle is the mechanism that decides pass/fail. A test that greens against known-broken code has an oracle *insensitive* to that fault — it cannot distinguish correct from buggy. That is not a defect to fix in place; it means the test is at the **wrong layer**. bc-replay re-reads the page-bound `Rec` exactly as a TestPage does, so it is insensitive to the stale-bound-`Rec` fault class: such a recording is a false net. Push down to a layer with a sensitive oracle, or escalate.

**Checking vs testing** (Bach & Bolton). *Checking* confirms machine-decidable facts via assertions (TestPage asserts, bc-replay `validate`, HTTP response checks). *Testing* is sapient exploration: judging whether a flow feels like one motion, whether an error reads sanely, whether a surface is usable. Usability questions are **un-checkable by construction**; they belong to the exploratory layer, where the user drives the real client with the agent guiding. Its usability output is **findings that become tasks**, not a green/red gate. The same guided walk does both: the user *checks* the observable outcomes (reads a Status value, a cue count off the screen; these gate) and *tests* usability (which does not). `/al-user-verification` splits them: gating only on the checkable dimension, routing usability to tasks, and guarding the leading-the-witness risk with ask-before-reveal plus `/al-second-opinion` coverage review.

## Nested loops

The layers run at different cadences — Beck's fast-inner / slow-outer feedback loops, which the pipeline already realises:

- **Inner** (seconds-minutes, red-first): `/al-implement` + AL-Runner/TestPage. Drives design.
- **Middle** (minutes, guard): `/al-page-script` and contract checks on a fresh environment. Written after; pushes bugs down; never the driver.
- **Outer** (sapient, qualitative): `/al-user-verification` — the user drives the real (bad) web client, the agent guides one step at a time. Observable outcomes are *checked* and gate the slice; subjective usability is *judged* and emits findings → tasks.

A skill states its own layer and role in one line and points here; it does not restate the pyramid.
