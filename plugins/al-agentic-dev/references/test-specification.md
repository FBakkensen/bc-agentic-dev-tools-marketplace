# Test specification grammar

Shared grammar for `tasks.md` `Test Specification` and `Verification Plan` sections. Cited by `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, and `/al-user-verification`.

Read-only. Read in place via `${CLAUDE_SKILL_DIR}/../../references/test-specification.md`.

The grammar separates three concerns:

- **Specification**: what behaviour the task must prove.
- **Execution scope**: which pyramid layer proves it.
- **Traceability**: which AL test procedure or verification example covers each behaviour claim.

## Technical task: Test Specification

Technical tasks use a `Test Specification` section. `/al-refine` writes it before implementation. `/al-implement` reconciles it to actual test procedure names and final scopes before flipping the task to `done`.

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

## Verify task: Verification Plan

Verify tasks use a `Verification Plan` section. Include only subsections that apply.

Allowed verify scopes:

| Scope | Mechanism | Use |
|---|---|---|
| `E2E` | Page script / bc-replay | BC Web Client workflow acceptance check. |
| `Contract` | Postman, curl, integration harness, or named client | API or external-client acceptance check. |
| `Exploration` | Agent-driven browser or human walk | UX/usability judgement and observational testing. |

Normal user-facing verify tasks require at least one `E2E` example. API/client-facing verify tasks require at least one `Contract` example. `Exploration` is optional, recommended for new workflows, changed workflows, and error-guidance changes.

### Journey Examples

Use for `E2E`.

```markdown
### Journey Examples

#### V1 BlocksReleaseFromSalesOrderPage
Scope: E2E
Role: Sales Processor
Action:
- Open Sales Order for blocked Customer.
- Choose `Release`.
Observable Checks:
- Blocked-customer error is visible.
- Sales Order Status remains `Open`.
```

IDs: `V1`, `V2`, `V3`.

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

When exact BC-specific names are written into a task, ground them in current workspace symbols/source or authoritative documentation before writing. Keep grounding evidence in chat, not in `tasks.md`.

If `event-model.md` exists, `Verification Plan` wording uses its Role, Action, Business Event, View, and Status vocabulary.

## Closeout summaries

Completed tasks keep the final `Test Specification` or `Verification Plan`. Closeout proof stays concise and citation-free.

Technical closeout:

```markdown
Closeout:
- Unit: `AllowsReleasePolicyWhenRuleDisabled`, `BlocksReleasePolicyWhenRuleEnabled`
- Integration: `BlocksSalesOrderReleaseWhenRuleEnabled`
- Build: full gate green
- Mutation: task-end mutants killed at lowest sensitive layer
```

Verify closeout:

```markdown
Closeout:
- E2E: `V1` page-script replay green
- Contract: `C1` Postman collection green
- Exploration: `X1` produced 1 follow-up UX task, no functional failures
```

Mutation targets are execution work, not durable task specification. A bounded mutation result summary may appear in closeout for non-trivial technical tasks.
