# User communication contract

Chat output rules for skills that run interactively in the user's terminal. The user reads chat to track which task is running, what is happening, and what landed. They do not always have `tasks.html` open.

## Scope

Governs **chat output**: lines the runtime emits to the user during a skill session. Read by `/al-refine` and `/al-implement` today. Other skills may adopt later.

DO NOT confuse with `voice-contract.md`, which governs **durable artifacts** (`tasks.html`, `architecture.html`, ADRs, `CONTEXT.md`, `.out-of-scope/`, commit messages, PR bodies, SKILL.md files). Two different surfaces, two different cadences.

## Principles

- **Names are the citation.** Use the test codeunit, procedure, table, field, codeunit, event publisher by name. Named seam beats described seam. The user can grep, navigate, review.
- **Lede first.** State the action or state change on the opener; supporting evidence follows on labeled lines.
- **Named output, not narration.** Say what was produced, not what you were doing. `RED Wrote BlockedCustomerCannotPostInvoice in T-NALICF Sales Post Tests` beats "I went and wrote the test for the blocked customer scenario".
- **BC vocabulary everywhere.** Codeunit not class. Procedure not method. Insert / Modify / Delete not Create / Update / Remove. Post not Submit. Validate not Check. Ledger Entry not Transaction.
- **Terse, declarative, no padding.** Same voice as `voice-contract.md` for direct prose: no hedging, no filler ("just", "really", "basically"), no pleasantries ("Sure!", "Of course!"), no closing pep ("Hope this helps!").
- **No em-dashes.** Same substitution table as `voice-contract.md`: comma (mild pause), parens (aside), semicolon (causal joining), colon (introduce), period (new sentence).

## Voice carve-outs from `voice-contract.md`

Most rules carry over verbatim. Two diverge:

| Rule in `voice-contract.md` | Chat carve-out |
|---|---|
| "No closing summary." | Chat **requires** a Close shape at end of session. The user cannot read `tasks.html` to learn what landed; the Close is their artifact. |
| "DO NOT narrate TDD steps as prose." | Workflow **markers** (`**RED**`, `**GREEN**`, `**Second opinion**`, `**Replan check**`) are permitted in chat. Workflow **narrative prose** ("bullet 1 went red on stub, green on body fill") is still banned. Marker + named output: yes. Marker + descriptive sentence about what you were thinking: no. |

The artifact rules are unchanged. Both carve-outs apply only to chat output.

## Canonical shapes

### Opener

Fires once at session start, after the skill has resolved the target task.

```
**T-NNN <Title>** · <status or status-change> · <counts> · <what's happening>

<task description paragraph, quoted verbatim from tasks.html>

<one-line "starting X" or "first bullet preview">.
```

`<counts>` is skill-specific:
- `/al-refine` opener: omit counts or use `description-only` if scenarios do not yet exist.
- `/al-implement` opener: `N Pure / M E2E` from the existing Tests slot.

Worked example, `/al-refine`:

> **T-007 PostSalesOrderWithBlockedCustomer** · `ready` · description-only · refining now
>
> Cust ledger entry suppressed when posting a sales order against a customer carrying `Blocked = All`. The guard sits in `Sales-Post Impl.PreCheck` before the line-loop entry; this task adds it plus the rename of the existing pre-check chain.
>
> Reading architecture and walking codebase.

Worked example, `/al-implement`:

> **T-007 PostSalesOrderWithBlockedCustomer** · `ready` → `in-progress` · 4 Pure / 2 E2E
>
> Cust ledger entry suppressed when posting a sales order against a customer carrying `Blocked = All`. The guard sits in `Sales-Post Impl.PreCheck` before the line-loop entry; this task adds it plus the rename of the existing pre-check chain.
>
> Starting TDD. First bullet: T-007#1 `BlockedCustomerCannotPostInvoice`.

### Phase boundary

Fires when crossing a major phase boundary. One line. Bold prefix + one substantive clause.

```
**<Phase name>** <substance in BC vocab>.
```

When two phases run in parallel subagents, emit one line acknowledging both, then one substantive line per phase as results return.

Worked examples:

> **Reading architecture, walking codebase** in parallel.
>
> **Architecture** Module: Sales Posting. R→P→W boundary at `Sales-Post Impl`. Family-level test layer: Pure default, E2E for posting flow.
>
> **Codebase** Grounded in: `Customer.Blocked`, `Sales Header`, codeunit 80, `OnAfterCheckSalesPostRestrictions`.

> **Seam map** Process layer at `Sales-Post Impl.PreCheck`; extract `CheckCustomerBlocked` procedure with `Access = Internal` for Pure layer; E2E exercises page-50-action `Post`.

### Per-bullet (`/al-implement` only)

Fires for each Gherkin bullet during the TDD inner loop. Three beats: bullet header, RED, GREEN.

```
**T-NNN#K <ScenarioTitle>** · <Pure | E2E | Both>

- **Given** <precondition>
- **When** <action>
- **Then** <outcome>
  - **And** <invariant>  (if present)
  - **But** <exclusion>  (if present)

**RED** Wrote `<test procedure>` in `<test codeunit>`. `<build invocation>`: <count> failed, <count> passed.

**GREEN** <named production change(s)>. `<build invocation>`: <count> passed.
```

Echo the Given/When/Then bullets verbatim from the task's Tests slot. Build invocation is `/al-build -UnitTestOnly` for Pure, `/al-build` for E2E.

**`Both`-tagged bullets emit two sequential Per-bullet blocks**, not one combined block. Same `T-NNN#K` and `ScenarioTitle` repeat on both; the layer label in the header differs. First block: `· Pure` (full Pure cycle, gated by `/al-build -UnitTestOnly`). Second block: `· E2E` (E2E test exercising the same scenario through the public surface, gated by full `/al-build`). The user sees the same scenario landing twice at different layers, which is the intent.

Worked example:

> **T-007#1 BlockedCustomerCannotPostInvoice** · Pure
>
> - **Given** Customer.Blocked = All
> - **When** Codeunit 80 runs on Sales Header type Invoice
> - **Then** error `Customer is blocked` raised; no Cust. Ledger Entry inserted
>
> **RED** Wrote `BlockedCustomerCannotPostInvoice` in `T-NALICF Sales Post Tests`. `/al-build -UnitTestOnly`: 1 failed, 0 passed.
>
> **GREEN** Added procedure `CheckCustomerBlocked` in `Sales-Post Impl`. `/al-build -UnitTestOnly`: 1 passed.

### AL Runner ERROR resolution

Not a Stop. Surfaces as a beat inside the per-bullet flow when `/al-build -UnitTestOnly` returns ERROR / exit 2 on a Pure bullet. Emits one labeled line per resolution step actually taken.

```
**AL Runner ERROR on T-NNN#K.** Three-step resolution:
- Step 1: <action and outcome>.
- Step 2: <action and outcome>.
- Step 3: <action and outcome>.
```

Worked example:

> **AL Runner ERROR on T-007#3.** Three-step resolution:
> - Step 1: Test reviewed, no unsupported feature. Retried, still ERROR.
> - Step 2: Refactored seam at `Sales-Post Impl.PreCheck`, extracted `CheckCustomerBlockedImpl` for stub injection. Retried, still ERROR.
> - Step 3: Reclassifying T-007#3 as E2E. NOTE chip `**Layer**: E2E (override; AL Runner ERROR)` written to T-007.

Then the bullet resumes at the new layer.

### Drafted scenarios (`/al-refine` only)

Fires once after Gherkin drafting, before second opinion runs. Lets the user see the proposed scenarios in chat without opening `tasks.html`.

```
**Proposed for T-NNN:**

  **Pure**
  1. **<ScenarioTitle>**
     - **Given** <...>
     - **When** <...>
     - **Then** <...>

  ...

  **E2E**
  N. **<ScenarioTitle>**
     ...
```

Sub-block absent when the task has no scenarios at that layer. Numbering contiguous across sub-blocks. Same shape as the canonical Gherkin block in `tasks.html`, transcribed into chat.

### Second opinion

Fires after `/al-second-opinion` returns. Aggregate outcome only; per-bullet accept/reject reasoning stays in the session and never goes to chat or to artifacts (mirrors `voice-contract.md` rule on workflow chatter).

```
**Second opinion** via `/al-second-opinion`: <aggregate outcome>.
```

Aggregate outcome shapes:
- `no gaps`
- `N gaps surfaced; <one-line summary of what changed>`
- `skipped: <reason CLI returned>`

Worked examples:

> **Second opinion** via `/al-second-opinion`: no gaps.

> **Second opinion** via `/al-second-opinion`: 1 gap surfaced (missing Boundary scenario for `Blocked = Invoice`). Added as scenario 2.

> **Second opinion** via `/al-second-opinion`: skipped (codex CLI not found).

### Replan check

Fires after the seven-trigger walk. State the outcome.

```
**Replan check** <outcome>.
```

Outcomes:
- `walked seven triggers, none fired.`
- `trigger #N hard-halt: <one-line reason>.` Followed immediately by the **Stop (mid-flow)** shape.
- `trigger #N soft-flag: <one-line reason>. IMPORTANT alert added; continuing.` Skill proceeds; the next Phase / Per-bullet / Close lines follow as normal.

Worked examples:

> **Replan check** Walked seven triggers, none fired.

> **Replan check** Trigger #5 soft-flag: bullet #3 specifies a new posting path. IMPORTANT alert added; continuing.

### Close

Fires once at the end of the session. Multi-line: status change + counts + next-ready hint.

`/al-refine` close:

```
**T-NNN refined.** Tests slot filled: <N> Pure + <M> E2E (<N+M> scenarios). Summary regenerated. Status stays `ready`.

Next: `/al-implement T-NNN` to run TDD, or `/al-refine T-MMM` for the next bare task.
```

`/al-implement` close:

```
**T-NNN done.** <bullet-count> bullets green. Refactor pass: <one-line outcome>. Mutations: <one-line outcome>. Status `in-progress` → `done`. Committed `<short SHA>`.

Next ready: **T-MMM <Title>**.
```

Refactor outcome shapes: `clean` | `<N> renames, <M> extracts` | `<one-line summary of substantive reshape>`.

Mutations outcome shapes: `skipped, no decision logic changed` | `<N> killed, 0 survived` | `<N> killed, <M> survived; <one-line summary>`.

Worked examples:

> **T-007 refined.** Tests slot filled: 4 Pure + 2 E2E (6 scenarios). Summary regenerated. Status stays `ready`.
>
> Next: `/al-implement T-007` to run TDD, or `/al-refine T-008` for the next bare task.

> **T-007 done.** 6 bullets green. Refactor pass: 2 renames, 1 extract. Mutations: 4 killed, 0 survived. Status `in-progress` → `done`. Committed `a3f5b2c`.
>
> Next ready: **T-008 RuleSetCopyPreservesIntervals**.

### Stop

Two flavours by phase: pre-flight (nothing touched) and mid-flow (state landed before halt).

**Pre-flight Stop** (one-liner, B-shape):

```
**Stop.** <reason in BC vocab>. <next action>.
```

Worked examples:

> **Stop.** Branch `feature/sales-tweaks` does not match `^\d{3}-`. Run `/al-design` to create a numbered branch and `architecture.html`.

> **Stop.** T-007 Tests slot empty. Run `/al-refine T-007` first.

> **Stop.** T-007 status `blocked`. Run `/al-steer` to clear the replan.

> **Stop.** Legacy markdown spec (`tasks.md` present without `tasks.html`). Hand-migrate before re-running.

**Mid-flow Stop** (three labeled lines, C-shape):

```
**Stop.** <reason in BC vocab>.

**State:** <what landed before halt: status flips, alerts written, bullets green, partial work, last commit>.

**Next:** <action>.
```

Worked example (replan trigger fires after 2 bullets green):

> **Stop.** Replan trigger #2 fired on T-007#3: requires `Cust. Banking Permission Set`; no task covers it.
>
> **State:** T-007 status `in-progress` → `blocked`. IMPORTANT alert written. 2 bullets green, bullet #3 partial (test written, no production code, build red). Last commit `a3f5b2c` (after bullet #2 green).
>
> **Next:** Run `/al-steer` to clear the replan, then re-enter via `/al-implement T-007`.

## Anti-patterns

> _Avoid:_ *"Now I'm going to read the architecture file to understand the module structure, and then I'll start walking the codebase to identify the relevant tables, codeunits, and events that this task depends on."*
>
> _Use:_ *"**Reading architecture, walking codebase** in parallel."*

> _Avoid:_ *"The test went red as expected because the production code doesn't have the guard yet, so I added a guard procedure to handle the blocked customer case."*
>
> _Use:_ *"**RED** Wrote `BlockedCustomerCannotPostInvoice` in `T-NALICF Sales Post Tests`. `/al-build -UnitTestOnly`: 1 failed, 0 passed.* * **GREEN** Added procedure `CheckCustomerBlocked` in `Sales-Post Impl`. `/al-build -UnitTestOnly`: 1 passed.*"

> _Avoid:_ *"Great! T-007 is now done. I posted a sales order with a blocked customer and it correctly errored out. Let me know if you want me to start the next task!"*
>
> _Use:_ *"**T-007 done.** 6 bullets green. Refactor pass: 2 renames, 1 extract. Mutations: 4 killed, 0 survived. Status `in-progress` → `done`. Committed `a3f5b2c`.* * Next ready: **T-008 RuleSetCopyPreservesIntervals**.*"

> _Avoid:_ *"Stopping because the branch is wrong. You probably want to make a new branch."*
>
> _Use:_ *"**Stop.** Branch `feature/sales-tweaks` does not match `^\d{3}-`. Run `/al-design` to create a numbered branch and `architecture.html`.*"

## Composition

- Inherits voice from `voice-contract.md` with the two carve-outs above.
- Uniform-shape rule from `voice-contract.md` *Lists of findings* applies: `**Stop.**` / `**State:**` / `**Next:**` is the labelled multi-line shape; per-bullet `**RED**` / `**GREEN**` is the per-cycle shape.
- Per-skill mapping (which shape fires at which flow step) lives in each SKILL.md's *User-facing chat* section; this reference holds shape definitions only.
