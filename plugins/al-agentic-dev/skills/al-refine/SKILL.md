---
name: al-refine
description: One task → numbered Gherkin scenarios for AL/Business Central. Reads architecture.md and the codebase to spec how the behaviour is tested, runs /grill-me when intent is fuzzy, confirms the per-scenario test layer, walks the seven replan triggers, then writes compressed Gherkin bullets onto that task's entry in tasks.md. Use after /al-scope places a bare task entry. Per task, not per feature.
---

# /al-refine — Task to Gherkin

Fill the `**Tests**` block for one task in `tasks.md`. Read `architecture.md`, walk the codebase, write numbered Gherkin in ZOMBIES order, confirm the test layer per scenario, gate against the seven replan triggers. One task per run. Stop — `/al-implement` consumes it next.

Drop articles, conjunctions, hedging. Scenario titles are positional: `<Action><Subject><Qualifier>` PascalCase, no underscores.

## Resolve `tasks.md`

- Branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise `Stop.` — run `/al-design`.
- Task is `[!]` → `Stop.` — `T-X is [!], run /al-steer to clear the replan.`
- `architecture.md` missing in spec folder → `Stop.` — run `/al-design`.

Read before writing to `tasks.md`:
- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` — voice rules for the prose itself.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md` — what goes in a Notes line vs an ADR; trigger test; valid shapes.

## Flow

Parallelise step 1 and step 2 in subagents.

### 1. Read architecture.md

Module map. R → P → W boundary. Brownfield touchpoints. Family-level test layer covering this task. Note the default — Pure, E2E, or Both — and which scenario families the family-level decision covers.

### 2. Walk the codebase

Ground every precondition and outcome in real symbols before writing.

- Test codeunit location and existing helpers.
- Field constraints, table relations, validation triggers.
- BaseApp events on the boundary — publishers, signature, where they fire.
- Run `/al-research` for non-trivial BC behaviour. `/bc-standard-reference` for BaseApp patterns.

If you cannot point at the codeunit, table, field, or event, you cannot write the scenario yet. Go look.

### 3. /grill-me when fuzzy

Trigger `/grill-me` when:

- A domain rule is implicit — user says it but it's not in `architecture.md` or `CONTEXT.md`.
- ZOMBIES surfaces a case the user must adjudicate — _Many_ has no stated upper bound, _Boundary_ falls between two contradicting rules, _Exception_ has no agreed recovery.
- Intent splits — *"validate"* could mean schema-check or business-rule-check.

Sharpen vague language inline. _Avoid_: "the order is processed". Instead: "Sales Order is posted via Codeunit 80".

### 4. Draft scenarios in ZOMBIES order

Zero, One, Many, Boundary, Interfaces, Exception, Simple. Both positive and negative cases per letter that admits them.

Title cadence — positional, BaseApp PascalCase, behaviour not implementation:

| | |
|---|---|
| _Avoid_: | `GivenEmptyCart_WhenCheckout_ThenError`, `Test_Cancel_Order_Works`, `should_post_invoice` |
| _Avoid_: | `UsesCodeunit80ToPostSalesHeader` (names the implementation, not the behaviour) |
| Use: | `PostSalesOrderWithItemCharge`, `RuleSetCopyPreservesIntervals`, `BlockedCustomerCannotPostInvoice` |

**Anti-pattern: scenario title that names the implementation, not the behaviour.** The codeunit number, event name, or table accessor belongs in the body, not the title. Title survives refactors. Implementation does not.

Scenario body — drop articles. BC vocabulary is the compression. Field/codeunit/table names verbatim.

| | |
|---|---|
| _Avoid_: | **Given** `the customer has been blocked because of credit issues` |
| Use: | **Given** Customer.Blocked = All |
| _Avoid_: | **When** `the user tries to post the sales invoice` |
| Use: | **When** Codeunit 80 runs on Sales Header type Invoice |
| _Avoid_: | **Then** `an error message should be displayed to the user` |
| Use: | **Then** error `Customer is blocked` raised; no Cust. Ledger Entry inserted |

### 5. Confirm test layer per scenario

Architecture set the family default. Override per scenario only when intent forces it.

- **Pure** — process layer, no DB. Default for value-in/value-out logic.
- **E2E** — composition or side effect unreproducible at the pure layer (posting, document flow, event chain).
- **Both** — intent splits cleanly; same behaviour at both layers buys distinct evidence.

Scenario disagrees with family default → record override as a Notes line: `T-007#3: layer = E2E (override; posting side effect)`.

### 6. Second opinion (gate)

Mandatory for non-trivial. Cross-check Gherkin bullets via the `al-agentic-dev:al-second-opinion` agent.

`Agent(subagent_type: 'al-agentic-dev:al-second-opinion', prompt: <body>)`

**Prompt body shape:** task title + context line + Gherkin bullets + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the seven replan triggers? Return a bulleted list."*

Reconcile each returned bullet — accept (update) or reject. Rejection rationale stays in the session — DO NOT write it to Notes. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`. `/grill-me` when judgement needs the user. If the agent returns `Second opinion skipped: <reason>`, note it in session and proceed.

### 7. Replan check (gate)

Walk all seven triggers. Subjective triggers require a written verdict — one line stating what was checked. **No silent skip.** Code state untouched throughout.

| # | Trigger | Detect | Action |
|---|---|---|---|
| 1 | Task too big | `>5` scenarios, or scenarios cluster around two distinct subjects | Soft-flag |
| 2 | Hidden pre-req | Gherkin references a table, codeunit, or permission with no covering task | Hard-halt |
| 3 | Wrong order | Bullet references behaviour a later task introduces | Hard-halt |
| 4 | Sibling now wrong | This task's behaviour invalidates another task's context line or scenarios | Hard-halt |
| 5 | New behaviour emerges | Scenario specifies behaviour outside any current task's intent | Soft-flag |
| 6 | Architecture decomposition wrong | Family-level layer or module boundary cannot house this scenario cleanly | Hard-halt |
| 7 | Goal drift | Scenarios push past the feature `Goal` line | Soft-flag |

Hard-halt → set `[!]`, append Notes, stop, recommend `/al-steer`.
Soft-flag → append Notes, continue.

Notes-line format: `**Replan** trigger #N: <one-line reason>`.

### 8. Write the block

Write `**Tests**` block (and optional `**Notes**` line) onto the task entry. `Stop.`

## Canonical Gherkin block

```
1. **<ScenarioTitlePascalCase>**
   - **Given** <precondition>
   - **When** <action>
   - **Then** <outcome>
     **And** <invariant>
     **But** <exclusion>
```

Title is the stable handle for grilling and commits (`T-007#3`) — same intent as the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]`. Numbering restarts per task. **And** / **But** extend a clause; do not split the scenario.

## tasks.md entry shape

```markdown
### [ ] T-001 — title
context line

**Tests**

1. **<ScenarioTitle>**
   - **Given** ...
   - **When** ...
   - **Then** ...

**Notes**
- one-line constraint (only if needed)
```

## Notes line — when valid

- Non-obvious BC constraint — hidden invariant, guard in an unexpected place, table missing from an existing routine.
- Explicit deferred decision — `Implementation choice: X vs Y — /al-implement decides`.
- Per-scenario layer override from step 5.
- Replan soft-flag from step 7.

One line max. No fixture mechanics, no implementation choices beyond explicit deferrals. Removing the note wouldn't confuse `/al-implement` → don't write it.

## Per-cycle checklist

```
[ ] Title is positional PascalCase; no Given_When_Then; no implementation name
[ ] Body cites real fields/codeunits/events — grep finds them
[ ] ZOMBIES letters covered or explicitly skipped (Notes line)
[ ] Both positive and negative where the letter admits
[ ] Per-scenario layer matches architecture default OR Notes line records override
```

## Composition

- `/al-scope` — precondition. Bare `T-NNN` entry must exist before `/al-refine` runs.
- `/grill-me` — call whenever intent ambiguous. Standalone-callable mid-flow.
- `/al-grill-adr` — call standalone when a domain term is fuzzy and `CONTEXT.md` needs sharpening.
- `/al-research` — non-trivial BC behaviour.
- `/bc-standard-reference` — BaseApp patterns and event signatures.
- `/al-steer` — replan venue when a hard-halt fires.
- `/al-implement` — consumes the Gherkin next.

## Out of scope

- No code edits.
- No fixture mechanics — `/al-implement` decides.
- No mutation lists — discovered during `/al-implement`, validated in `/al-mutate`.
- No feature-level test strategy — that's `architecture.md` via `/al-design`.
- No replan mutations — that's `/al-steer`.
- No Resolved Questions or Cross-cutting Notes sections.
