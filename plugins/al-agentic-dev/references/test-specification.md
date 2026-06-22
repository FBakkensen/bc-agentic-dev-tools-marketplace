# Test specification grammar

Shared grammar for the `Test Specification` and `Verification Plan` sections in a per-task file (`specs/<NNN>-<slug>/tasks/NNN-T-MMM-<slug>.md`). Cited by `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, and `/al-user-verification`.

Read-only. Read in place via `${CLAUDE_SKILL_DIR}/../../references/test-specification.md`.

The grammar separates three concerns:

- **Specification**: what behaviour the task must prove.
- **Execution scope**: which pyramid layer proves it.
- **Traceability**: which AL test procedure or verification example covers each behaviour claim.

## Technical task: Test Specification

Technical tasks use a `Test Specification` section. `/al-refine` writes it for one named technical task from the current app/tests before implementation. `/al-scope` writes task shells only and does not pre-seed proof sections. `/al-implement` reconciles the specification to actual test procedure names and final scopes before flipping the task to `done`.

Use one primary coverage table per technical task:

| Task shape | Coverage table | IDs |
|---|---|---|
| Non-branching behaviour, guard, simple flow | `Expected Behaviors` | `B1`, `B2`, `B3` |
| Branching rule, policy, calculation, status combination | `Decision Matrix` | `R1`, `R2`, `R3` |

Multiple unrelated behaviour groups mean the task is too broad. Split or route through `/al-steer`.

### Acceptance Intent

Include `Acceptance Intent` only when the task has business-facing behaviour. One short paragraph names the business outcome protected by the tests. Behaviour-preserving refactors do not require it.

```markdown
Acceptance Intent:
Release blocking protects posting readiness by preventing Sales Orders from being released when Customer state violates release policy.
```

### New and Modified Objects

Mandatory on every technical task. Names the production AL surface the task lands — objects, fields, procedure signatures, events — so `/al-implement` consumes signatures instead of minting them mid-TDD. Production objects only: test codeunits and test procedures live in `AAA Cases` and `Covered By`, never here. A test-only task (red-suite rework, characterization additions) writes the labeled line `New and Modified Objects: none` in place of the `###` section; absence of both, or a section heading with neither entries nor the `none` line, is a `/al-refine` defect — `al-doc-verify` agent blocks the `ready-for-implementation` flip on it.

Signature-level, no bodies — bodies are what TDD writes. One object per landing line, `New:` or `Modified:` lede. Procedures carry full signature, visibility (`internal` / `local` / public), and their R → P → W letter from `architecture.md`. Fields carry AL type. Events carry the full publisher signature.

Lede semantics: `New:` = object not in the workspace at this task's start — a fresh extension object on an existing base is `New:` with `extends <base>`. `Modified:` = object already in the workspace, including objects an earlier task in the same feature landed; an object another open task's section already mints is also `Modified:` here — one `New:` owner per object, ordering via `depends_on:`. Any new object a listed signature references (enum, interface) earns its own `New:` entry.

Boundary at implementation time: a production object the task's assertions require but the section never named is replan trigger #2; build-gate scaffolding the assertions never observe (permission set entry, object ID, caption) absorbs as trivia per `/al-implement`. A change whose only effect is behaviour inside a procedure an open sibling task owns is trigger #4 (sibling now wrong), not a `Modified:` entry.

```markdown
### New and Modified Objects

- New: codeunit `Release Policy`
  - `internal procedure IsReleaseBlocked(Customer: Record Customer): Boolean` — P
  - Publishes `OnAfterEvaluateReleasePolicy(Customer: Record Customer; IsBlocked: Boolean)` — W
- New: tableextension `Customer Release Ext` extends `Customer`
  - Field: `Release Blocked` (Boolean)
```

Grounding: minted names meet the evidence bar's minted-name clause in `voice-contract.md`. `/al-refine` proposes; `/al-implement` reconciles the section to actuals before `done`.

### Contract notes

Include `Contract notes` only when the task carries proof-shaping freight the coverage tables cannot hold: oracle design, push-up justification (every `Integration` case, every `Record: yes` E2E, every `Contract` example: why the layer below cannot hold it + the named seam or the wall — see `test-strategy.md`; `Record: no` E2E and `Exploration` are not push-ups and carry none), seam or test-double decisions, binding mechanics, transaction model, red-suite rework — or the task's `Researched:` evidence-bar citations (`voice-contract.md`). Most tasks otherwise need none.

Shape: bulleted, one fact per landing line, lede word first. A `;`-spliced multi-fact paragraph is density, not concision — the reader scans landing lines, then slow-reads one.

```markdown
Contract notes:
- Oracle: handler-absence — a dialog with no declared handler fails the run.
- No Message handler on the Yes path — a surviving completion Message fails the run.
- Push-up `BlocksSalesOrderReleaseWhenRuleEnabled` Integration — the real `Release` crosses the posting seam a `Unit` auto-stub would falsify; costs-a-seam: an `IFinance` double around the release call, not built for one case.
- Zero Unit cases — structural wall: both W entries self-inject the production Confirm, leaving no unit seam.
- Decision surface proved: T-001.
- Transaction: service commits before first dialog → `[TransactionModel(TransactionModel::AutoCommit)]`.
- Red-suite rework: `PostsWithCompletionMessage` sheds its `MessageHandler` for a Yes ConfirmHandler — part of this task's green gate.
- Researched: `FindSet(true)` required for modify-in-loop → Learn al-record-findset.
```

A bullet survives only if the next agent acts differently because of it. How a decision was reached never survives: provenance ("settled:", "second-opinion added", "resolved by user decision") belongs in the commit message, per the no-workflow-chatter rule in `voice-contract.md` and the session-internal-reasoning row in `notes-discipline.md`. `Researched: <fact> → <source>` is not decision provenance — it is the evidence-bar trace (`voice-contract.md`), the one citation that lands here; `/al-code-review` audits its absence on construct-touching tasks. Cross-task retelling trims to a pointer — `proved: T-001` — not the story.

### Out of automated reach

Include only when the task leaves claims no automated layer proves. Each bullet names the claim and its destination: code-review invariant, verify-task journey, or accepted gap.

```markdown
Out of automated reach:
- `GuiAllowed()` silent branch — container sessions are interactive; code-review invariant.
- Drill from list row to card — verify-layer outcome; V-task journey.
```

`/al-code-review` reads this section as its invariant list. A claim without a destination is a hole, not a note.

### Expected Behaviors

Use for non-branching technical tasks.

```markdown
### Expected Behaviors

| ID | Expected Behavior | Covered By |
|---|---|---|
| B1 | Blank prompt is rejected before generation starts | RejectsBlankPrompt |
| B2 | Whitespace-only prompt is rejected before generation starts | RejectsWhitespacePrompt |
| B3 | Non-blank prompt proceeds to generation | AllowsNonBlankPrompt |
```

`Covered By` contains AL test procedure names only. Multiple procedures are separated by semicolon.

### Decision Matrix

Use when branching business logic matters.

```markdown
### Decision Matrix

| Case | Release Blocking Enabled | Customer Blocked | Expected Release | Sales Order Status | Covered By |
|---|---:|---:|---|---|---|
| R1 | No | Yes | Released | Released | AllowsReleasePolicyWhenRuleDisabled |
| R2 | Yes | Yes | Blocked | Open | BlocksReleasePolicyWhenRuleEnabled; BlocksSalesOrderReleaseWhenRuleEnabled |
```

Columns prefer project/domain language and BC display labels. Use exact object or field names only when ambiguity matters, for example `Customer Blocked (Customer.Blocked)`.

Each row requires `Covered By`. A row may be covered by one or more procedures across scopes. If a row affects BC state, page behaviour, or a public procedure, an integration procedure normally proves the wiring even when a unit procedure proves the decision.

### AAA Cases

Each technical task has `AAA Cases`. Cases are ordered by scope first: all `Unit` cases, then all `Integration` cases. Within each scope, order by coverage ID.

Allowed technical scopes:

| Scope | Mechanism | Use |
|---|---|---|
| `Unit` | AL-Runner | Isolated decision proof. Fast red-first foundation. |
| `Integration` | Container AL tests, including TestPage | BC runtime, database, event, page, posting, install, permission, or wiring proof. |

Every AAA case has exactly one `Scope`. If the same behaviour needs both scopes, write two cases.

```markdown
### AAA Cases

#### BlocksReleasePolicyWhenRuleEnabled
Procedure: `BlocksReleasePolicyWhenRuleEnabled`
Scope: Unit
Covers: R2
Arrange:
- Release-blocking policy is enabled.
- Customer state is blocked.
Act:
- Evaluate release policy.
Assert:
- Policy returns blocked release outcome.

#### BlocksSalesOrderReleaseWhenRuleEnabled
Procedure: `BlocksSalesOrderReleaseWhenRuleEnabled`
Scope: Integration
Covers: R2
Arrange:
- Sales Order exists for blocked Customer.
- Release-blocking policy is enabled.
Act:
- Release the Sales Order.
Assert:
- Blocked-customer error is raised.
- Sales Order remains `Open`.
```

AAA case rules:

- Header matches `Procedure`.
- `Procedure` is the exact AL test procedure name. `/al-refine` proposes it; `/al-implement` reconciles it to the actual name.
- `Covers` references `B#` or `R#` from the same `Test Specification`.
- `Arrange`, `Act`, and `Assert` are bullet blocks. Each phase has at least one bullet.
- `Arrange` describes business state first. Helper names appear only when the helper or seam matters.
- `Act` names one business action. Multiple execution steps are allowed when they execute that one action.
- `Assert` uses observable outcomes by default. Internal call assertions belong only in `Unit` cases where a double or spy is the behaviour boundary.
- Expected errors stay in `Assert`.
- An `Integration` case is a push-up from `Unit`: record its justification in `Contract notes` (`test-strategy.md`) — why a `Unit` seam cannot hold it (the MS-logic collaborator it must run for real) + the seam that would isolate it if built, or the wall. `/al-implement` gates a *new* or *reclassified* `Integration` case on this before the test is written.

## Verify task: Verification Plan

Verify tasks use a `Verification Plan` section. `/al-refine` writes it for one named verify task from the current app/tests before verification. `/al-scope` writes task shells only and does not pre-seed proof sections. Include only subsections that apply.

Allowed verify scopes:

| Scope | Mechanism | Use |
|---|---|---|
| `E2E` | BC Web Client workflow: either **user-recorded** (Page Scripting recorder → bc-replay) or **user-walked** in `/al-user-verification` | BC Web Client workflow acceptance check. |
| `Contract` | Postman, curl, integration harness, or named client | API or external-client acceptance check. |
| `Exploration` | Guided user walk (user drives the browser, agent guides) | UX/usability judgement and observational testing. |

Normal user-facing verify tasks require at least one `E2E` example. API/client-facing verify tasks require at least one `Contract` example. `Exploration` is optional, recommended for new workflows, changed workflows, and error-guidance changes.

**The `Record:` flag (E2E only).** Every Journey Example carries `Record: yes` or `Record: no` — the generation-time push-down call (see [`test-strategy.md`](test-strategy.md)). `Record: yes` means **no AL test layer can automate this behaviour** (control add-in, canvas, web-client-only behaviour), so `/al-page-script` guides the user to record it as a `.yml` regression guard; `Record: no` means a Unit/Integration test already pins the regression, so the example is **walked by the user in `/al-user-verification` for acceptance but not recorded** — recording it would double a lower test. Most slices are `Record: no` throughout; a slice can legitimately have zero `Record: yes` examples (then `/al-page-script` is skipped). A `Record: yes` example is a **push-up** (`test-strategy.md`) and a `Contract` example is too — their justification (the wall for E2E, why-not-`Integration` for Contract) lands in the Push-up report and `Contract notes`; a `Record: no` example is the pushed-*down* state, not a push-up, and an `Exploration` charter has no checkable floor — neither carries a push-up justification. Either way the `Observable Checks` are mandatory — they are the grounded gating values the user-walk checks against, which `event-model.md` alone does not carry for edge/error cases.

### Journey Examples

Use for `E2E`. Each carries a `Record:` flag (above): `Record: yes` → `/al-page-script` records it; `Record: no` → `/al-user-verification` walks it.

```markdown
### Journey Examples

#### V1 BlocksReleaseFromSalesOrderPage
Scope: E2E
Record: no                  # an Integration test pins the block; user walks it for acceptance
Role: Sales Processor
Action:
- Open Sales Order for blocked Customer.
- Choose `Release`.
Observable Checks:
- Blocked-customer error is visible.
- Sales Order Status remains `Open`.

#### V2 ReleaseRefreshesCanvasFactbox
Scope: E2E
Record: yes                 # factbox repaint is canvas — no AL test layer can assert it
Role: Sales Processor
Action:
- Open the released Sales Order.
Observable Checks:
- The status canvas factbox shows `Released`.
```

IDs: `V1`, `V2`, `V3`. `Record:` is mandatory on every E2E example; `Role` / `Action` / `Observable Checks` apply to both flag values (the recorder encodes the checks as Validate steps; the walk reads them off the screen).

### Contract Examples

Use for API or client-facing verification.

```markdown
### Contract Examples

#### C1 RejectsReleaseWithoutCustomerNo
Scope: Contract
Client: Postman collection `tests/postman/sales-order-release.json`
Action:
- Send release request without `Customer No.`
Observable Checks:
- HTTP status is `400`.
- Response body identifies missing Customer No.
- Sales Order remains `Open`.
```

IDs: `C1`, `C2`, `C3`.

### Exploration Charters

Use for usability and judgement.

```markdown
### Exploration Charters

#### X1 ReleaseErrorTextGuidesNextAction
Scope: Exploration
Charter: Judge whether the release-blocking error tells the Sales Processor what to fix next.
Prompts:
- Is the blocked Customer named or discoverable?
- Is the next action clear?
- Does the flow return the user to a useful place?
```

IDs: `X1`, `X2`, `X3`.

An exploration charter has one charter sentence and 2-4 prompts. It has no exact click script and no expected subjective verdict. Usability findings become follow-up tasks unless a functional failure is observed.

## Language and grounding

Language priority:

1. Project domain language from `CONTEXT.md`.
2. BC display labels.
3. Exact AL object, field, page, procedure, event, or API names only when needed for traceability or ambiguity.

`New and Modified Objects` is the deliberate exception: exact AL names and signatures are its whole content. Coverage tables, AAA cases, and verify examples keep the priority above.

When exact BC-specific names are written into a task, ground them in current workspace symbols/source or authoritative documentation before writing. Grounding evidence stays in chat — except `Researched:` bullets, which land in `Contract notes` per the evidence bar in `voice-contract.md`.

If `event-model.md` exists, `Verification Plan` wording uses its Role, Action, Business Event, View, and Status vocabulary.

## Closeout summaries

Completed tasks keep the final `Test Specification` or `Verification Plan`. Closeout proof stays concise and citation-free.

Technical closeout:

```markdown
Closeout:
- Unit: `AllowsReleasePolicyWhenRuleDisabled`, `BlocksReleasePolicyWhenRuleEnabled`
- Integration: `BlocksSalesOrderReleaseWhenRuleEnabled`
- Build: full gate green

Mutation verdict:

| | |
|---|---|
| Baseline | `2d02629f` |
| Report | `.output/mutation-report/20260605-214958.md` |
| Mutants | 5 — release guard chain, blocked-state boundary, status flip |
| Killed | 4 (3 by named tests, 1 compile-time) |
| Survivors | 1 |
| Final gate | full green |

Survivor: `SetRecFilter()` removal in `OpenReleasedOrder`.
Why kept: outside the pinned contract — the event model pins that the order's card opens, not its rowset; a killer test would pin presentation. Net: the slice verify journey probes card scoping.
```

The mutation verdict is a borderless two-column field/value table; each survivor gets labeled `Survivor:` / `Why kept:` lines stating the gap → killer-test direction, the equivalence reason, or the accepted gap and the net that catches it. One fact per line; a survivor rationale is a finding, not a paragraph. Tasks where mutation ran with zero survivors collapse the labeled lines and keep the table.

Verify closeout:

```markdown
Closeout:
- E2E: `V1` page-script replay green
- Contract: `C1` Postman collection green
- Exploration: `X1` produced 1 follow-up UX task, no functional failures
```

Mutation targets are execution work, not durable task specification. The verdict table and survivor lines are the only mutation content in the per-task file; the full mutation table lives in the `.output` report.
