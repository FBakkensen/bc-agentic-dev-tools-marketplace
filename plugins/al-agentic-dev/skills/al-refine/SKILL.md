---
name: al-refine
description: One task → numbered Gherkin scenarios for AL/Business Central. Reads architecture.md and the codebase to spec how the behaviour is tested, runs /grill-me when intent is fuzzy, confirms the per-scenario test layer, walks the seven replan triggers, then writes compressed Gherkin bullets onto that task's <details> block in tasks.md. Use after /al-scope places a bare task entry. Per task, not per feature.
---

# /al-refine, Task to Gherkin

Fill the `**Tests**` block for one task in `tasks.md`. Read `architecture.md`, walk the codebase, write numbered Gherkin in ZOMBIES order, confirm the test layer per scenario, gate against the seven replan triggers. One task per run. Stop, `/al-implement` consumes it next.

Drop articles, conjunctions, hedging on Gherkin bullets. Scenario titles are positional: `<Action><Subject><Qualifier>` PascalCase, no underscores.

## Resolve `tasks.md`

- Branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise `Stop.` Run `/al-design`.
- Task is `[!]` → `Stop.` `T-X is [!], run /al-steer to clear the replan.`
- `architecture.md` missing in spec folder → `Stop.` Run `/al-design`.

Read before writing to `tasks.md`:

- `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`, voice rules, em-dash ban, one-line vs prose cadence map.
- `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md`, per-task structure, NOTE/IMPORTANT alert rules, valid Notes-line shapes, Summary regeneration rule.

## Flow

Parallelise step 1 and step 2 in subagents.

### 1. Read architecture.md

Module map. R → P → W boundary. Brownfield touchpoints. Family-level test layer covering this task. Note the default (Pure, E2E, or Both) and which scenario families the family-level decision covers.

**Slice context.** Read the `## Slice(s) (Event Modeling)` paragraph that this task contributes to. For *wire* tasks (those crossing the slice's trigger), Gherkin scenarios must cross the trigger → state path of the slice. For *primitive / extract / fix / refactor* tasks, scenarios stay at the task's own scope; the slice is upstream context, not the per-task spec. Vertical slicing (tests + code together) is inherited from `/al-scope`.

### 2. Walk the codebase

Ground every precondition and outcome in real symbols before writing.

- Test codeunit location and existing helpers.
- Field constraints, table relations, validation triggers.
- BaseApp events on the boundary: publishers, signature, where they fire.
- Run `/al-research` for non-trivial BC behaviour. `/bc-standard-reference` for BaseApp patterns.

If you cannot point at the codeunit, table, field, or event, you cannot write the scenario yet. Go look.

### 3. Refine the description paragraph (optional)

If the codebase walk surfaces specifics the scope-time description lacks (concrete `file:line` site, object IDs, sharpened invariants, ADR cites grounded in the code), rewrite the description paragraph inside the task's `<details>`. Keep it one to three sentences; normal prose voice; no em-dashes. The chip / alert / declared-edge lines above the paragraph are untouched.

Skip when scope-time description is already accurate at the level the codebase confirms.

### 4. `/grill-me` when fuzzy

Trigger `/grill-me` when:

- A domain rule is implicit; user says it but it is not in `architecture.md`.
- ZOMBIES surfaces a case the user must adjudicate: *Many* has no stated upper bound, *Boundary* falls between two contradicting rules, *Exception* has no agreed recovery.
- Intent splits: *"validate"* could mean schema-check or business-rule-check.

Sharpen vague language inline. _Avoid_: "the order is processed". Instead: "Sales Order is posted via Codeunit 80".

### 5. Decide test layer per scenario

Architecture set the family default. Override per scenario only when intent forces it. The tag decides which sub-block (Pure or E2E) the bullet sits in (see step 6).

- **Pure**: process layer, no DB. Default for value-in/value-out logic. Pure block.
- **E2E**: composition or side effect unreproducible at the pure layer (posting, document flow, event chain). E2E block.
- **Both**: intent splits cleanly; same behaviour at both layers buys distinct evidence. Pure block (one bullet; `/al-implement` produces tests at both layers).

Scenario disagrees with family default → place the bullet in the override block and record the override on the **NOTE alert** chip: `**Layer**: <layer> (override; <reason>)`. If the task already has a NOTE alert, extend the chip line with ` · ` separator. If not, add a NOTE alert. **Do not write Layer overrides to `**Notes**` lines.**

*Pure tag is intent. AL Runner verifies at `/al-implement` RED; the unit test app contract is PASS-or-FAIL. ERROR / exit 2 routes to the three-step resolution (review test → refactor production → reclassify) in `/al-implement` and `al-runner.md`.*

### 6. Draft scenarios in layer-then-ZOMBIES order

**Pure block first, then E2E block.** Within each block, ZOMBIES order: Zero, One, Many, Boundary, Interfaces, Exception, Simple. Both positive and negative cases per letter that admits them.

**ZOMBIES coverage is across the task, not per block.** A `Z` scenario at Pure satisfies the `Z` slot even when E2E has no `Z`. Edge cases belong at the cheaper layer (Pure runs in seconds via AL Runner); E2E proves wiring, not edges. Re-proving every letter in the container is the ice-cream-cone anti-pattern: slow, brittle, no new signal.

Numbering is contiguous across blocks and reflects this final order: `T-NNN#1` is the first Pure bullet; the first E2E bullet's number equals `(count of Pure bullets) + 1`. The numbering becomes the execution order; `/al-implement` traverses bullets sequentially, so Pure-first is enforced by construction. Layer tag from step 5 decides which block a scenario sits in.

`Both`-tagged scenarios sit in the Pure block; `/al-implement` drives RED→GREEN at the Pure layer (inner loop) and adds the E2E counterpart alongside; the bullet is listed once.

Title cadence: positional, BaseApp PascalCase, behaviour not implementation:

| | |
|---|---|
| _Avoid_: | `GivenEmptyCart_WhenCheckout_ThenError`, `Test_Cancel_Order_Works`, `should_post_invoice` |
| _Avoid_: | `UsesCodeunit80ToPostSalesHeader` (names the implementation, not the behaviour) |
| Use: | `PostSalesOrderWithItemCharge`, `RuleSetCopyPreservesIntervals`, `BlockedCustomerCannotPostInvoice` |

**Anti-pattern: scenario title that names the implementation, not the behaviour.** The codeunit number, event name, or table accessor belongs in the body, not the title. Title survives refactors. Implementation does not.

Scenario body cadence: drop articles, one-line per bullet. BC vocabulary is the compression. Field/codeunit/table names verbatim.

| | |
|---|---|
| _Avoid_: | **Given** `the customer has been blocked because of credit issues` |
| Use: | **Given** Customer.Blocked = All |
| _Avoid_: | **When** `the user tries to post the sales invoice` |
| Use: | **When** Codeunit 80 runs on Sales Header type Invoice |
| _Avoid_: | **Then** `an error message should be displayed to the user` |
| Use: | **Then** error `Customer is blocked` raised; no Cust. Ledger Entry inserted |

### 7. Second opinion (gate)

Mandatory for non-trivial. Cross-check Gherkin bullets via `/al-second-opinion`.

Invoke `/al-second-opinion` with the prompt body below.

**Prompt body shape:** task title + description paragraph + Gherkin bullets + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the seven replan triggers? Return a bulleted list."*

Reconcile each returned bullet, accept (update) or reject. Rejection rationale stays in the session; DO NOT write it to Notes. If a rejection encodes a durable principle, escalate via `/al-steer` to `/al-grill-adr` or `/al-design`. `/grill-me` when judgement needs the user. If `/al-second-opinion` returns `Second opinion skipped: <reason>`, note it in session and proceed.

### 8. Replan check (gate)

Walk all seven triggers. Subjective triggers require a written verdict (one line stating what was checked). **No silent skip.** Code state untouched throughout.

| # | Trigger | Detect | Action |
|---|---|---|---|
| 1 | Task too big | `>5` scenarios, or scenarios cluster around two distinct subjects | Soft-flag |
| 2 | Hidden pre-req | Gherkin references a table, codeunit, or permission with no covering task | Hard-halt |
| 3 | Wrong order | Bullet references behaviour a later task introduces | Hard-halt |
| 4 | Sibling now wrong | This task's behaviour invalidates another task's description or scenarios | Hard-halt |
| 5 | New behaviour emerges | Scenario specifies behaviour outside any current task's intent | Soft-flag |
| 6 | Architecture decomposition wrong | Family-level layer or module boundary cannot house this scenario cleanly | Hard-halt |
| 7 | Goal drift | Scenarios push past the feature `Goal` line | Soft-flag |

Hard-halt → set `[!]` in the `<summary>` line, add an **IMPORTANT alert** to the task block, stop, run `/al-steer`.
Soft-flag → add an **IMPORTANT alert** to the task block, continue.

IMPORTANT alert shape: `> [!IMPORTANT]\n> **Replan flag**: trigger #N, <one-line reason>.` **Do not write replan flags to `**Notes**` lines.** If the task already carries a soft-flag IMPORTANT alert and a new trigger fires that requires hard-halt, replace the alert with the hard-halt version (status `[!]`, new trigger reason).

### 9. Write the block

Update the task's `<details>` in this order:

1. If you refined the description in step 3, replace the paragraph (chip / alert / edge lines above stay).
2. If you added a Layer override in step 5, update the NOTE chip line (add the alert if absent).
3. If step 8 fired a replan flag, add the IMPORTANT alert.
4. Write the `**Tests**` block: Pure sub-block first, E2E sub-block second, contiguous numbering across blocks. When the task has ≥6 scenarios, use nested `<details>` per scenario (see *Nested collapsibles* below).
5. Regenerate the Summary table from current per-task NOTE chips plus scenario counts (see *Summary regeneration*).

`Stop.`

## Canonical Gherkin block (inside the task `<details>`)

```
**Tests**

**Pure**

1. **<ScenarioTitle>**
   - **Given** <precondition>
   - **When** <action>
   - **Then** <outcome>
     **And** <invariant>
     **But** <exclusion>

2. **<ScenarioTitle>**
   - **Given** ...
   - **When** ...
   - **Then** ...

**E2E**

3. **<ScenarioTitle>**
   - **Given** ...
   - **When** ...
   - **Then** ...
```

Pure or E2E sub-block may be absent when the task has no scenarios at that layer; the remaining sub-block stays. Numbering is contiguous across the present blocks.

Title is the stable handle for grilling and commits (`T-007#3`); same intent as the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]`. Numbering restarts per task. **And** / **But** extend a clause; do not split the scenario.

## Nested collapsibles for tasks with ≥6 scenarios

When the task's total scenario count (Pure + E2E) is ≥6, replace the numbered-list scenario layout with nested `<details>` per scenario inside each sub-block:

```
**Tests**

**Pure**

<details>
<summary>Scenario 1: <strong>ScenarioTitle</strong></summary>

- **Given** ...
- **When** ...
- **Then** ...

</details>

<details>
<summary>Scenario 2: <strong>ScenarioTitle</strong></summary>

- **Given** ...
- **When** ...
- **Then** ...

</details>

**E2E**

<details>
<summary>Scenario 6: <strong>ScenarioTitle</strong></summary>

- **Given** ...
- **When** ...
- **Then** ...

</details>
```

Blank lines around the nested `<details>` are required for GFM to render markdown inside. Preserve scenario shorthand (one-line "second call reuses") as-is inside the body; do not fabricate Given/When/Then expansions.

Scenario numbering continues contiguously across sub-blocks (the first E2E scenario number equals Pure-count + 1). The `<summary>` carries `Scenario N, <strong>Title</strong>`.

## Summary regeneration

After writing the `**Tests**` block, regenerate the `## Summary` table at the top of `tasks.md`. The table is a view over per-task `<details>` blocks; never edit it directly without re-reading the per-task data.

Regeneration rule, per row:

| Cell | Source |
|---|---|
| `Task` | `[T-NNN](#t-NNN)` derived from the task's anchor |
| `Title` | The `<summary>` line title (everything after `T-NNN, `) |
| `Tests` | Count of scenarios in the task's `**Tests**` block (Pure + E2E combined); right-aligned |
| `Layer` | Value of `**Layer**` chip in the task's NOTE alert, or `-` if absent |
| `Mutations` | Value of `**Mutations**` chip in the task's NOTE alert, or `-` if absent |

**Drop any column whose values would be `-` for every row.** If no task carries Layer metadata, drop the Layer column. When the next write makes a column relevant, re-add it.

## Notes-line shapes valid for this skill

Per `notes-discipline.md`, the `**Notes**` block is now strictly:

- **Non-obvious BC constraint specific to this task** (hidden invariant, guard in an unexpected place, AL-language pitfall).
- **Explicit deferred decision** (`Implementation choice: X vs Y, /al-implement decides`).

DO NOT write Layer overrides (now NOTE chip), Replan flags (now IMPORTANT alert), or Mutations results (now NOTE chip plus Summary cell) as `**Notes**` lines. Single source of truth is the alert / chip.

One line max. No fixture mechanics, no implementation choices beyond explicit deferrals. Removing the note would not confuse `/al-implement` → do not write it.

## Per-cycle checklist

```
[ ] Title is positional PascalCase; no Given_When_Then; no implementation name
[ ] Body cites real fields/codeunits/events; grep finds them
[ ] ZOMBIES letters covered across the task (Pure + E2E combined) or explicitly skipped (Notes line)
[ ] Both positive and negative where the letter admits
[ ] Per-scenario layer matches architecture default OR NOTE chip carries the override
[ ] Pure sub-block precedes E2E sub-block; numbering contiguous across blocks; ZOMBIES preserved within each
[ ] ≥6 scenarios → nested collapsibles
[ ] Summary table regenerated from per-task NOTE chips plus scenario counts
[ ] No em-dashes anywhere in the written prose
```

## Composition

- `/al-scope`, precondition. A bare `<details>` block with anchor + description + empty Tests must exist before `/al-refine` runs.
- `/grill-me`, call whenever intent ambiguous. Standalone-callable mid-flow.
- `/al-grill-adr`, call standalone when a domain term is fuzzy and `CONTEXT.md` needs sharpening.
- `/al-research`, non-trivial BC behaviour.
- `/bc-standard-reference`, BaseApp patterns and event signatures.
- `/al-steer`, replan venue when a hard-halt fires.
- `/al-implement`, consumes the Gherkin next.

**References** (`${CLAUDE_SKILL_DIR}/../../references/`):

- `zombies-scenarios.md`, Z/O/M/B/I/E/S ordering rationale and naming examples.
- `al-runner.md`, what `/al-build -UnitTestOnly` runs against; Pure tag is intent, AL Runner verifies.

## Out of scope

- No code edits.
- No fixture mechanics. `/al-implement` decides.
- No mutation lists. Discovered during `/al-implement`, validated in `/al-mutate`.
- No feature-level test strategy. That is `architecture.md` via `/al-design`.
- No replan mutations. That is `/al-steer`.
- No Resolved Questions or Cross-cutting Notes sections.
