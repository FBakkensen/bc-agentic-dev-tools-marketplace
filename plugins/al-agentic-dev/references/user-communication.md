# User communication

Principles and worked examples for chat output. The user reads chat to track which task is running, what is happening, and what landed. They do not always have `tasks.html` open.

This file is for the *human reader*, not for agent-to-agent prompts. The shapes below earned their place because they let the user skim a long session without slow-reading prose. Apply each one where its rationale fits; the agent picks the shape that best serves the moment, not a template to walk.

## Scope

Governs **chat output**: lines the runtime emits to the user during an interactive skill session. Skills that emit interactive output (currently `/al-refine`, `/al-implement`) consult this; others may adopt later.

DO NOT confuse with `voice-contract.md`, which governs **durable artifacts** (`tasks.html`, `architecture.html`, ADRs, `CONTEXT.md`, `.out-of-scope/`, commit messages, PR bodies, SKILL.md files). Two different surfaces, two different cadences.

## Principles

- **Names are the citation.** Use the test codeunit, procedure, table, field, codeunit, event publisher by name. Named seam beats described seam. The user can grep, navigate, review.
- **Lede first.** State the action or state change on the opener; supporting evidence follows on labeled lines.
- **Named output, not narration.** Say what was produced, not what you were doing. `**RED** · **Test**: BlockedCustomerCannotPostInvoice` beats "I went and wrote the test for the blocked customer scenario".
- **Two-column tables when ≥2 label/value pairs share a structure.** Use a borderless `| | |` markdown table (no header row, two columns: bold label left, value right) when the shape is a fixed list of "field: value" rows. Tables give the values vertical alignment that labeled bullets can't — eye drops down the value column instead of jumping ragged across rows of varying widths. Applies to Close, Opener, Phase boundary multi-fact, Per-bullet RED/GREEN, Stop (mid-flow) `**State:**`. Three-column tables (Step | Action | Outcome) for AL Runner ERROR resolution.
- **Labeled bullets when ≥2 named facts in a free-form list.** Use `- **Label**: value` bullets only when the row list is open-ended or items have wildly different shapes (e.g. Given/When/Then where each row is a sentence-flow). For fixed field/value structures, prefer tables per the rule above.
- **Horizontal separator between shapes.** Emit `---` between every shape boundary: Opener → Phase, Phase → Phase, Phase → Per-bullet, Per-bullet → Per-bullet, Per-bullet → Phase (refactor / mutate), Phase → Close. Visual break beats relying on bold prefix alone. Inside a single shape (e.g., the three sub-beats of one Per-bullet: header + Given/When/Then + RED + GREEN), no separator; the shape is one unit.
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

## Common shapes

Worked examples below. The agent reaches for the shape whose rationale fits the moment; nothing here is a state machine to walk in order. Each shape's *Why* paragraph names what it earns; if that rationale doesn't apply to the moment, the shape doesn't fit and the agent uses something else.

### Opener

Use at session start, after the skill has resolved the target task. **Why**: the user wants to know which task is running and where it sits in the flow before any work output streams in.

```
**T-NNN <Title>** · <status or status-change>

| | |
|---|---|
| **<key>** | <value> |
| **<key>** | <value> |
```

Chip line carries title + status only. Two-column borderless table carries counts, scenario-state, and the next-pointer. No description paragraph; the user reads `tasks.html` for context.

Row content is skill-specific:
- `/al-refine` opener: `**Scenarios**` (none yet or count) + `**Next**` (drafting Gherkin or current phase).
- `/al-implement` opener: `**Pure**` (count) + `**E2E**` (count) + `**First**` (T-NNN#1 with scenario title).

Worked example, `/al-refine`:

> **T-007 PostSalesOrderWithBlockedCustomer** · `ready`
>
> | | |
> |---|---|
> | **Scenarios** | none yet |
> | **Next**      | drafting Gherkin |

Worked example, `/al-implement`:

> **T-007 PostSalesOrderWithBlockedCustomer** · `ready` → `in-progress`
>
> | | |
> |---|---|
> | **Pure**  | 4 |
> | **E2E**   | 2 |
> | **First** | T-007#1 `BlockedCustomerCannotPostInvoice` |

### Phase boundary

Use when crossing a major phase boundary. **Why**: phase transitions are where the user re-orients; a tight named beat beats a paragraph of narration. Adaptive shape:

- **Single fact**: one line, bold prefix + one substantive clause.
- **≥2 facts**: bold prefix on its own line + two-column borderless table.

```
**<Phase name>** <one substantive clause>.            ← single fact

**<Phase name>**                                       ← multi-fact

| | |
|---|---|
| **<sub-label>** | <value> |
| **<sub-label>** | <value> |
```

When two phases run in parallel subagents, emit one line acknowledging both, then one shape per phase as results return. Each sequenced shape is separated by `---` per the *Horizontal separator between shapes* principle.

Worked examples:

> **Reading architecture, walking codebase** in parallel.
>
> ---
>
> **Architecture**
>
> | | |
> |---|---|
> | **Module**          | Sales Posting |
> | **R→P→W boundary**  | `Sales-Post Impl` |
> | **Test layer**      | Pure default, E2E for posting flow |
>
> ---
>
> **Codebase** Grounded in: `Customer.Blocked`, `Sales Header`, codeunit 80, `OnAfterCheckSalesPostRestrictions`.

> **Seam map**
>
> | | |
> |---|---|
> | **Process seam** | `Sales-Post Impl.PreCheck` |
> | **Extract**      | `CheckCustomerBlocked` with `Access = Internal` (Pure) |
> | **E2E surface**  | page-50 action `Post` |

### Per-bullet (`/al-implement` only)

Use for each Gherkin bullet during the TDD inner loop. **Why**: the inner loop produces the highest-volume output of any session; landing it in three small named beats (bullet header → RED → GREEN) lets the user see each cycle complete without scanning prose. Three beats:

```
**T-NNN#K <ScenarioTitle>** · <Pure | E2E | Both>

- **Given** <precondition>
- **When** <action>
- **Then** <outcome>
  - **And** <invariant>  (if present)
  - **But** <exclusion>  (if present)

**RED**

| | |
|---|---|
| **Test**  | `<test procedure>` |
| **In**    | `<test codeunit>` |
| **Build** | `<build invocation>` → <count> failed, <count> passed |

**GREEN**

| | |
|---|---|
| **Change** | <named production change(s)> |
| **Build**  | `<build invocation>` → <count> passed |
```

Echo the Given/When/Then bullets verbatim from the task's Tests slot. Build invocation is `/al-build -UnitTestOnly` for Pure, `/al-build` for E2E. When GREEN touches multiple files, add one `**Change**` row per file rather than comma-splicing.

**`Both`-tagged bullets emit two sequential Per-bullet blocks**, not one combined block. Same `T-NNN#K` and `ScenarioTitle` repeat on both; the layer label in the header differs. First block: `· Pure` (full Pure cycle, gated by `/al-build -UnitTestOnly`). Second block: `· E2E` (E2E test exercising the same scenario through the public surface, gated by full `/al-build`). The user sees the same scenario landing twice at different layers, which is the intent.

Worked example:

> **T-007#1 BlockedCustomerCannotPostInvoice** · Pure
>
> - **Given** Customer.Blocked = All
> - **When** Codeunit 80 runs on Sales Header type Invoice
> - **Then** error `Customer is blocked` raised; no Cust. Ledger Entry inserted
>
> **RED**
>
> | | |
> |---|---|
> | **Test**  | `BlockedCustomerCannotPostInvoice` |
> | **In**    | `T-NALICF Sales Post Tests` |
> | **Build** | `/al-build -UnitTestOnly` → 1 failed, 0 passed |
>
> **GREEN**
>
> | | |
> |---|---|
> | **Change** | added `CheckCustomerBlocked` in `Sales-Post Impl` |
> | **Build**  | `/al-build -UnitTestOnly` → 1 passed |

### AL Runner ERROR resolution

Use when `/al-build -UnitTestOnly` returns ERROR / exit 2 on a Pure bullet. **Why**: the resolution sequence (review test → refactor production → reclassify) is the same cheapest-first order every time; rendering it as a step table lets the user see which step landed PASS and what the layer reclassification implied. Not a Stop; surfaces inside the per-bullet flow. One row per step actually taken; stop adding rows after the first PASS.

```
**AL Runner ERROR on T-NNN#K.**

| Step | Action | Outcome |
|---|---|---|
| `1` | <what was tried> | <result> |
| `2` | <what was tried> | <result> |
| `3` | <what was tried> | <result> |
```

Step numbers chip-styled per the load-bearing-number rule (`` `1` ``, `` `2` ``, `` `3` ``).

Worked example:

> **AL Runner ERROR on T-007#3.**
>
> | Step | Action | Outcome |
> |---|---|---|
> | `1` | review test for unsupported features | none found; retried, still ERROR |
> | `2` | refactor seam at `Sales-Post Impl.PreCheck`, extract `CheckCustomerBlockedImpl` | retried, still ERROR |
> | `3` | reclassify T-007#3 as E2E | NOTE chip `**Layer**: E2E (override; AL Runner ERROR)` written to T-007 |

Then the bullet resumes at the new layer.

### Drafted scenarios (`/al-refine` only)

Use after Gherkin drafting, before second opinion runs. **Why**: the user wants to see proposed scenarios in chat without opening `tasks.html`, especially before the second opinion gates them.

```
**Proposed for T-NNN:**

**Pure**

1. **<ScenarioTitle>**
   - **Given** <...>
   - **When** <...>
   - **Then** <...>

2. **<ScenarioTitle>**
   ...

**E2E**

N. **<ScenarioTitle>**
   - **Given** <...>
   - **When** <...>
   - **Then** <...>
```

No leading indent on Pure / E2E headers or on the numbered scenarios; markdown indentation past 2 spaces detaches numbered lists and breaks the rendering. Bullets nest 3 spaces under each scenario title (lines up with the text after `1. `). Blank line between the header and the first numbered scenario, and between scenarios — markdown's loose-list mode renders the spacing cleanly.

Sub-block absent when the task has no scenarios at that layer. Numbering contiguous across sub-blocks. Same shape as the canonical Gherkin block in `tasks.html`, transcribed into chat.

### Second opinion

Use after `/al-second-opinion` returns. **Why**: the user wants the aggregate outcome (no gaps, N gaps surfaced, or skipped + why) in one line; per-bullet accept/reject reasoning stays in the session and never goes to chat or to artifacts (mirrors `voice-contract.md` rule on workflow chatter).

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

Use after the replan check completes. **Why**: the user wants to know whether any replan trigger fired and, if so, whether the skill is continuing or halting.

```
**Replan check** <outcome>.
```

Outcomes:
- `walked seven triggers, none fired.`
- ``trigger `N` hard-halt: <one-line reason>.`` Followed immediately by the **Stop (mid-flow)** shape.
- ``trigger `N` soft-flag: <one-line reason>. IMPORTANT alert added; continuing.`` Skill proceeds; the next Phase / Per-bullet / Close lines follow as normal.

Load-bearing numbers (trigger ID, bullet ID, step ID inside an AL Runner ERROR resolution) are wrapped in backticks: `` `5` ``, `` `3` ``. Three reasons together:

1. **No autolink.** The Claude desktop client treats standalone `#N` tokens as GitHub-style references and linkifies them blue; backticks block this without losing the integer.
2. **Visual weight.** Bare integers blend into the sentence; a backticked chip lands the eye on the number the same way `T-007` or `Sales Header` does.
3. **Consistency.** Other named entities (codeunits, fields, build commands) already chip; load-bearing numbers join the same pattern.

Per-bullet IDs like `T-NNN#K` stay as written — they are one token with no space before the `#`, so the autolinker does not fire, and the dash already chips the prefix visually.

Worked examples:

> **Replan check** Walked seven triggers, none fired.

> **Replan check** Trigger `5` soft-flag: bullet `3` specifies a new posting path. IMPORTANT alert added; continuing.

### Close

Use at end of session. **Why**: the user cannot read `tasks.html` to learn what landed; the Close is their artifact. The two-column table aligns the named outcomes vertically so the user scans down to the row they care about.

`/al-refine` close:

```
**T-NNN refined.**

| | |
|---|---|
| **Tests slot** | <N> Pure + <M> E2E (<N+M> scenarios) |
| **Summary**    | regenerated |
| **Status**     | stays `ready` |
| **Next**       | `/al-implement T-NNN` or `/al-refine T-MMM` |
```

`/al-implement` close:

```
**T-NNN done.**

| | |
|---|---|
| **Bullets**    | <count> green |
| **Refactor**   | <one-line outcome> |
| **Mutations**  | <one-line outcome> |
| **Status**     | `in-progress` → `done` |
| **Commit**     | `<short SHA>` |
| **Next ready** | T-MMM <Title> |
```

Refactor outcome shapes: `clean` | `<N> renames, <M> extracts` | `<one-line summary of substantive reshape>`.

Mutations outcome shapes: `skipped, no decision logic changed` | `<N> killed, 0 survived` | `<N> killed, <M> survived; <one-line summary>`.

Worked examples:

> **T-007 refined.**
>
> | | |
> |---|---|
> | **Tests slot** | 4 Pure + 2 E2E (6 scenarios) |
> | **Summary**    | regenerated |
> | **Status**     | stays `ready` |
> | **Next**       | `/al-implement T-007` or `/al-refine T-008` |

> **T-007 done.**
>
> | | |
> |---|---|
> | **Bullets**    | 6 green |
> | **Refactor**   | 2 renames, 1 extract |
> | **Mutations**  | 4 killed, 0 survived |
> | **Status**     | `in-progress` → `done` |
> | **Commit**     | `a3f5b2c` |
> | **Next ready** | T-008 RuleSetCopyPreservesIntervals |

### Stop

Use when the skill halts before its normal Close. **Why**: the user needs to know what halted, what landed before the halt, and what to do next. Two flavours by phase: pre-flight (nothing touched) and mid-flow (state landed before halt).

**Pre-flight Stop** (one-liner, B-shape):

```
**Stop.** <reason in BC vocab>. <next action>.
```

Worked examples:

> **Stop.** Branch `feature/sales-tweaks` does not match `^\d{3}-`. Run `/al-design` to create a numbered branch and `architecture.html`.

> **Stop.** T-007 Tests slot empty. Run `/al-refine T-007` first.

> **Stop.** T-007 status `blocked`. Run `/al-steer` to clear the replan.

> **Stop.** Legacy markdown spec (`tasks.md` present without `tasks.html`). Hand-migrate before re-running.

**Mid-flow Stop** (Stop reason + State as two-column table + Next action):

```
**Stop.** <reason in BC vocab>.

**State:**

| | |
|---|---|
| **Status**        | <T-NNN status flip> |
| **Alert**         | <alert written, if any> |
| **Bullets green** | <count> |
| **Partial**       | <bullet ID + what landed, if any> |
| **Last commit**   | <short SHA + when> |

**Next:** <action>.
```

Rows cover whatever landed: status flips, alerts written, bullets green, partial work, last commit. Skip any row that doesn't apply.

Worked example (replan trigger fires after 2 bullets green):

> **Stop.** Replan trigger `2` fired on T-007#3: requires `Cust. Banking Permission Set`; no task covers it.
>
> **State:**
>
> | | |
> |---|---|
> | **Status**        | T-007 `in-progress` → `blocked` |
> | **Alert**         | IMPORTANT written |
> | **Bullets green** | 2 |
> | **Partial**       | bullet `3` (test written, no production, build red) |
> | **Last commit**   | `a3f5b2c` (after bullet `2` green) |
>
> **Next:** Run `/al-steer` to clear the replan, then re-enter via `/al-implement T-007`.

## Anti-patterns

> _Avoid:_ *"Now I'm going to read the architecture file to understand the module structure, and then I'll start walking the codebase to identify the relevant tables, codeunits, and events that this task depends on."*
>
> _Use:_ *"**Reading architecture, walking codebase** in parallel."*

> _Avoid:_ *"The test went red as expected because the production code doesn't have the guard yet, so I added a guard procedure to handle the blocked customer case."*
>
> _Use:_
> > **RED**
> >
> > | | |
> > |---|---|
> > | **Test**  | `BlockedCustomerCannotPostInvoice` |
> > | **In**    | `T-NALICF Sales Post Tests` |
> > | **Build** | `/al-build -UnitTestOnly` → 1 failed, 0 passed |
> >
> > **GREEN**
> >
> > | | |
> > |---|---|
> > | **Change** | added `CheckCustomerBlocked` in `Sales-Post Impl` |
> > | **Build**  | `/al-build -UnitTestOnly` → 1 passed |

> _Avoid:_ *"**RED** Wrote `BlockedCustomerCannotPostInvoice` in `T-NALICF Sales Post Tests`. `/al-build -UnitTestOnly`: 1 failed, 0 passed."* (sentence form packs four facts into one line; eye has to parse prose to find the build outcome)
>
> _Use:_ the two-column RED table above.

> _Avoid:_ labeled bullets for the Close, with chip density varying row to row.
>
> > **T-007 done.**
> > - **Bullets**: 6 green
> > - **Refactor**: 2 renames, 1 extract
> > - **Mutations**: 4 killed, 0 survived
> > - **Status**: `in-progress` → `done`
> > - **Commit**: `a3f5b2c`
> > - **Next ready**: T-008 RuleSetCopyPreservesIntervals
>
> (Values rag left-to-right: some plain prose, some heavy chips, some naked task IDs. Eye finds no vertical alignment.)
>
> _Use:_
> > **T-007 done.**
> >
> > | | |
> > |---|---|
> > | **Bullets**    | 6 green |
> > | **Refactor**   | 2 renames, 1 extract |
> > | **Mutations**  | 4 killed, 0 survived |
> > | **Status**     | `in-progress` → `done` |
> > | **Commit**     | `a3f5b2c` |
> > | **Next ready** | T-008 RuleSetCopyPreservesIntervals |

> _Avoid:_ *"Great! T-007 is now done. I posted a sales order with a blocked customer and it correctly errored out. Let me know if you want me to start the next task!"*
>
> _Use:_ the table-form Close above.

> _Avoid:_ *"Stopping because the branch is wrong. You probably want to make a new branch."*
>
> _Use:_ *"**Stop.** Branch `feature/sales-tweaks` does not match `^\d{3}-`. Run `/al-design` to create a numbered branch and `architecture.html`.*"

## Composition

- Inherits voice from `voice-contract.md` with the two carve-outs above.
- Multi-fact shapes (Opener, Phase multi-fact, Per-bullet RED/GREEN, Close, Stop mid-flow) render well as two-column borderless tables; AL Runner ERROR resolution as a three-column table; one-clause shapes (Phase single-fact, Second opinion, Replan check, Stop pre-flight) as single lines. Labeled bullets work for free-form Gherkin echoes (Given/When/Then) where each value is sentence flow rather than a field. These mappings are the patterns that earned their place; the agent picks the shape that fits the moment, not from a per-flow lookup.
- Per-skill mapping (which shape the skill reaches for at which moment) is the SKILL.md's call; this reference holds the shapes and their rationale.
