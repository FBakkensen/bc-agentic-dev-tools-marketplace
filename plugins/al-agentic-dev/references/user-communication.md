# User communication

Principles and worked examples for chat output. The user reads chat to track which task is running, what is happening, and what landed. They do not always have `tasks.html` open.

This file is for the *human reader*, not for agent-to-agent prompts. The shapes below earned their place because they let the user skim a long session without slow-reading prose. Apply each one where its rationale fits; the agent picks the shape that best serves the moment, not a template to walk.

## Scope

Governs **chat output**: lines the runtime emits to the user during an interactive skill session. Read by every gate-style skill that emits chat at the user: `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-refactor`, `/al-mutate`, `/al-code-review`, `/al-steer`. Conversational/pass-through skills (`/al-grill-adr`, `/al-second-opinion`, `/al-research`) don't apply this file's gate-report discipline; their output shape comes from their own SKILL.md.

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

### Gate report

Use when a gate event closes inside a chat-emitting skill: a scenario goes green in `/al-implement`, Gherkin lands in `/al-refine`, `architecture.html` lands in `/al-design`, a confidence-filtered finding closes in `/al-code-review`, a feature decomposes in `/al-scope`, an `event-model.html` lands in `/al-event-model`, a refactor pass lands standalone, a mutation pass lands standalone, the user asks "where are we" in `/al-steer`. The per-skill cadence (which event qualifies as a gate event for that skill) is named in each SKILL.md; this section defines the shape.

**Why**: the user reads chat to evaluate the work the way a manager evaluates work, in terms of what the application now does for its user, the problem the change solved, how the change fits the app's shape, and whether a decision is theirs to make. The chat is the user's source of truth; they are not opening artifacts. Reports written at AL-implementation altitude (procedure names, codeunit numbers, mutant IDs, lens findings, RED/GREEN test rhythms, build counts) hide the application-level meaning the user came to evaluate. Those mechanics belong in the durable artifacts: commit messages, `tasks.html` task blocks, `.out-of-scope/`, the mutation report. The user pulls detail by asking.

**The four answers, reached in prose when they apply**: what user-facing behavior the change enables (in BC user language: a Sales Order action, a Customer field's new behavior, an API consumer's now-visible Status, a Role Center cue), the problem it solves (with a concrete one-line scenario the user recognises from the application), how the change fits the app at BC-shape altitude (the module, the BC pattern chosen, the seam; names like `Sales-Post Impl` and `OnAfterInsertCustomer` belong here; procedure names, line numbers, lens findings, mutant IDs do not), and whether a decision is on the user. When the work did not touch structure, the "how this fits" answer collapses or disappears. When no decision is pending, the closing line is explicit: `Nothing. Ready for the next <scenario | task | feature>.`

This is **intent prose**, not a slot template. DO NOT render `**What enabled**:` / `**Problem**:` / `**How this fits**:` / `**Your call?**:` as a fixed form. The discipline is reaching the four answers in natural prose, not filling labeled rows.

Worked example, `/al-implement` closing one scenario:

> Copying a customer in the configurator now reliably carries Description over. A salesperson duplicating "Acme Corp Special Pricing" into a new pricing tier keeps the descriptive text instead of getting a blank.
>
> Before, Description could silently blank under one of two copy paths. The salesperson would not notice until after save.
>
> This lives in a new `Configurator Copy Impl` codeunit under `src/Configurator/Copy/`, subscribing to `OnAfterInsertCustomer` rather than rewriting the standard Copy Customer flow, keeping the extension out of Microsoft's way when 26.x ships. R→P→W boundary lands at the subscriber: standard does the read and insert, the new codeunit layers the description copy as a follow-up write.
>
> Nothing. Ready for the next scenario.

Same shape adapts per skill. `/al-design` gate report names the chosen BC pattern + R→P→W boundary as "how this fits"; the user's call is whether to greenlight `/al-scope`. `/al-refine` gate report describes what the Gherkin will exercise in app terms; the user's call is whether to greenlight `/al-implement`. `/al-steer` gate report answers "where are we": what's next, what's blocked, what's drifting, where the user needs to step in.

**Out of chat, into artifacts**: every test name, codeunit number, procedure name, line number, mutant ID, refactor lens finding, build invocation, AL Runner verdict, second-opinion gap list. The audit trail lives in commits and the task block; the chat carries the meaning.

**Anti-patterns** (forbidden in gate reports):

> _Avoid:_ *"**RED** added `BlockedCustomerCannotPostInvoice` in `T-NALICF Sales Post Tests`. `/al-build -UnitTestOnly` → 1 failed, 0 passed. **GREEN** added `CheckCustomerBlocked` in `Sales-Post Impl`. `/al-build -UnitTestOnly` → 1 passed."*
>
> _Use:_ the worked example above. The scenario closing as one prose paragraph at app altitude, no per-cycle RED/GREEN beats.

> _Avoid:_ *"Mutation testing complete: 12 mutants, 10 killed, 2 survived. M3 survived: field assignment on line 47 of codeunit 50100 was mutated from `Customer.Description := Source.Description` to `Customer.Description := ''`. Test suite did not catch this. Analysis: defensive code because BC version 25.3 changed how blank strings propagate. Recommendation: leave M3 as-is."*
>
> _Use:_ *"Description-on-copy is now under test. One soft spot remains: if the source customer has no description, the new one is also blank. By design, the tests do not cover it because there is nothing to assert. Nothing. Ready for the next scenario."*

> _Avoid:_ a closing "Bullets / Refactor / Mutations / Status / Commit / Next ready" table that mechanically lists the inner-loop outcomes.
>
> _Use:_ a prose closing that states what the user-facing behavior of the task now is, what application problem the whole task solved, where it lives in the module map, and whether the next task is theirs to greenlight.

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

### Per-bullet (superseded)

**Superseded by Gate report for gate events.** This shape prescribed a `T-NNN#K` header + Given/When/Then bullets + RED/GREEN tables with build counts after every TDD cycle. That cadence and altitude (per-bullet, implementation-mechanics) produced the transaction-altitude flood the Gate report discipline corrects. The TDD cycle (red, green, refactor, mutate) still happens internally, but does not emit per-bullet chat output; only the scenario-close gate event fires a Gate report. The old shape is preserved as an anti-pattern inside the Gate report section above.

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

### Close (superseded)

**Superseded by Gate report for gate events.** This shape prescribed a mechanical Bullets / Refactor / Mutations / Status / Commit / Next ready table at task close. The rows count inner-loop outcomes (build greenness, mutation kills, refactor passes) instead of stating what the application now does for its user, which application problem the whole task solved, and where the new behavior lives in the module map. The Gate report discipline replaces both `/al-refine` close and `/al-implement` close with prose at app altitude; the durable mechanics (test counts, mutation verdicts, commit SHA, next task pointer) ride in the commit message and task block where the audit trail belongs. The old shape is preserved as an anti-pattern inside the Gate report section above.

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

> **For gate events** (scenario close, task close, feature close): the Gate report section above carries the canonical anti-patterns. The RED/GREEN table and the mechanical Close table that some `_Use:_` targets below point at are themselves superseded by the Gate report discipline for gate-event chat output. The "avoid prose narration" lessons still apply; treat the superseded table targets as historical reference only.

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
- **Gate report** (the canonical end-of-gate-event shape for the nine gate-style skills) is prose at app altitude, not a table. The four answers are reached in natural prose, not slot-filled. See the section near the top.
- Multi-fact status shapes (Opener, Phase multi-fact, Stop mid-flow) render well as two-column borderless tables; AL Runner ERROR resolution as a three-column table; one-clause shapes (Phase single-fact, Second opinion, Replan check, Stop pre-flight) as single lines. Labeled bullets work for free-form Gherkin echoes (Given/When/Then) where each value is sentence flow rather than a field. These mappings are the patterns that earned their place; the agent picks the shape that fits the moment, not from a per-flow lookup.
- Per-skill mapping (which shape the skill reaches for at which moment) is the SKILL.md's call; this reference holds the shapes and their rationale. Per-skill cadence for the Gate report (which event qualifies as a gate event in that skill) lives inline in each gate-style SKILL.md.
