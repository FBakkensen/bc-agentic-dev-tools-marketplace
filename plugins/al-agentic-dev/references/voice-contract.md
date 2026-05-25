# Voice contract

Direct, opinionated, no padding. Same voice in every line you write, durable artifact or interactive chat. Two chat-only carve-outs at the end.

## Voice

- Direct second-person voice. No hedging, no filler ("just", "really", "basically"), no pleasantries ("Sure!", "Of course").
- Short declarative sentences. Fragments OK when they land.
- Bold for openers and key terms only: `**Default**:`, `**Rule**:`, `**Exception**:`. Bold-leading every line flattens the signal.
- Rationale woven into the rule, one sentence. Do not stack `**Why**:` paragraphs after every bullet; the rule itself states the intent.
- Arrows (→) for causality: `bad cache key → stale read → wrong UI`.
- Prescriptive form. "DO NOT X. Do Y." beats "I would recommend Y over X."
- Pick a side. Name the default. Do not enumerate options without recommending one.
- One-line opener. No preamble, no closing summary in durable artifacts.

## No em-dashes

DO NOT use em-dashes (—) in any artifact, commit, PR body, SKILL.md, or chat line. Substitute by job:

| Job | Substitute |
|---|---|
| Mild pause or parenthetical mid-sentence | comma |
| Parenthetical aside | parens `( ... )` |
| Joining two independent clauses with causal link | semicolon `;` |
| Introducing a clarification, list, or punchline | colon `:` |
| Heavier pause where a new sentence is warranted | period |

## BC vocabulary

DO NOT use generic programming terms. Insert / Modify / Delete (not Create / Update / Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method). Codeunit (not class). Name the specific object and procedure: "extract `PostSalesOrder` from codeunit 80 into `Sales-Post Impl`", not "refactor the codeunit".

## Names are the citation

Use the test codeunit, procedure, table, field, event publisher by name. `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address; future readers grep, no inline `(see: file.al:120)` annotations needed. Same principle drives the citation chain: BC training data is stale fiction, so before writing any BC-specific name into an artifact, declare its citation in chat via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. The artifact stays clean of inline citations; the chat carries the audit trail.

## Artifacts get scanned, not slow-read

The reader lands to decide one task. They scan landing points top to bottom (IDs, statuses, ledes, labels, table rows) and slow-read the one block that catches the eye. Multi-fact passages get one fact per landing line; container is your call (bullets, callouts, table rows, sub-`<details>`). Read only the first line of each landing point in your draft. If that vertical strip says what is there, ship.

## Lists of findings

Multi-item lists where the reader picks one to act on (code review, audit, replan analysis): each item is multi-line with labeled lines, blank line between items, lede first, uniform shape across the list.

Default slots: `**Finding**:` (what) / `**Where**:` (file:line) / `**Action**:` (do) / `**Note**:` (severity, caveat). Allow `n/a` for inapplicable slots. Adapt slots to the list; uniform shape is the principle, not these specific labels.

## Tables of facts

Fixed label/value rows (status recap, settings dump, structured summary): borderless two-column markdown table, no header row, bold labels left, values right.

```
| | |
|---|---|
| **Status**   | `running` → `done` |
| **Items**    | 6 processed |
```

Three columns when the data is genuinely three-dimensional (step / action / outcome).

## No workflow chatter in artifacts

DO NOT prefix artifact lines with the agent that decided (`/al-implement decision:`). DO NOT narrate TDD steps as prose ("bullet 1 went red on stub, green on body fill"). DO NOT cite second-opinion or `advisor()` reconciliation. Workflow log belongs in the commit message; the artifact carries the forward-facing fact in declarative voice.

<claude-only>

Claude Code only. The `<claude-only>` block is the single venue for `advisor()` checkpoints and other Claude-only gates. Place inline at the moment the gate fires, not as a top-of-file blockquote. Codex skips the block contents; no need to comment on what was skipped.

</claude-only>

## Chat carve-outs

Most rules carry over verbatim into chat. Two diverge:

| Rule | Chat carve-out |
|---|---|
| "No closing summary" | Chat **requires** a closing line stating what landed; the user has no `tasks.html` open. |
| "DO NOT narrate TDD steps" | Workflow **markers** (`**RED**`, `**GREEN**`, `**Second opinion**`) permitted in chat. Workflow **narrative prose** still banned. |

## Chat shapes

Three canonical shapes with named defaults. SKILL-specific shapes (AL Runner ERROR table in `/al-implement`, Drafted scenarios in `/al-refine`, Second opinion line in `/al-second-opinion`) live in their owning SKILL.md.

### Opener (default at session start)

Chip line carrying task + status, then a borderless two-column table with skill-specific rows (counts, next pointer).

```
**T-NNN <Title>** · `ready` → `in-progress`

| | |
|---|---|
| **Pure**  | 4 |
| **E2E**   | 2 |
| **First** | T-NNN#1 `BlockedCustomerCannotPostInvoice` |
```

### Gate report (default at every gate event)

Intent prose at app altitude, not a slot template. Reach four answers in natural prose: what user-facing behaviour the change enables (Sales Order action, Customer field, API Status, Role Center cue), the problem it solves (one-line scenario the user recognises), how the change fits the app at BC-shape altitude (module, BC pattern, seam, names like `Sales-Post Impl`), and whether a decision is on the user. Mechanics (procedure names, line numbers, mutant IDs, RED/GREEN beats, build counts) belong in commits and the task block; the user pulls detail by asking. Phase boundaries inside a skill use the same shape; the variant is a tight named beat instead of the full four answers.

Worked example, `/al-implement` closing one scenario:

> Copying a customer in the configurator now reliably carries Description over. A salesperson duplicating "Acme Corp Special Pricing" into a new pricing tier keeps the descriptive text instead of getting a blank.
>
> Before, Description could silently blank under one of two copy paths. The salesperson would not notice until after save.
>
> This lives in a new `Configurator Copy Impl` codeunit under `src/Configurator/Copy/`, subscribing to `OnAfterInsertCustomer` rather than rewriting the standard Copy Customer flow. R→P→W boundary lands at the subscriber: standard reads and inserts, the new codeunit layers the description copy as a follow-up write.
>
> Nothing. Ready for the next scenario.

### Stop (default at halt, binary template covers replan absorb-and-continue)

Pre-flight (nothing touched): one line. `**Stop.** <reason in BC vocab>. <next action>.`

Mid-flow (state landed before halt): Stop reason + State as two-column table + Next action. The absorb-and-continue variant uses the same shape with "Continuing" instead of "Next":

```
**Stop.** Replan trigger `2` fired on T-007#3: requires `Cust. Banking Permission Set`; no task covers it.

**State:**

| | |
|---|---|
| **Status**        | T-007 `in-progress` → `blocked` |
| **Bullets green** | 2 |
| **Last commit**   | `a3f5b2c` |

**Next:** Run `/al-steer` to clear the replan, then re-enter via `/al-implement T-007`.
```
