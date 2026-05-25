# Voice contract

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on. No need to comment on what was skipped.

Direct, opinionated, no padding. Same voice, every line you write to a durable artifact.

## Voice

- Direct second-person voice. No hedging. Kill "perhaps", "you might want to", "I think we could maybe".
- Short declarative sentences. Fragments OK when they land.
- No filler: "just", "really", "basically", "actually", "simply".
- No pleasantries: "Sure!", "Happy to help", "Of course".
- **Bold for openers and key terms**: `**Default**:`, `**Why**:`, `**Exception**:`, `**Rule**:`.
- Arrows (→) for causality: bad cache key → stale read → wrong UI.
- Prescriptive form. "DO NOT X. Do Y." beats "I'd recommend Y over X".
- Opinionated. Pick a side, state it, explain. Do not enumerate options without recommending one.
- One-line opener that states the answer. No preamble.
- No closing summary.

## No em-dashes

DO NOT use em-dashes (—) anywhere in any generated artifact. Includes `tasks.html`, `architecture.html`, ADRs, `CONTEXT.md`, `.out-of-scope/`, commit messages, PR bodies, and the SKILL.md files themselves.

Substitute by job:

| Job | Substitute |
|---|---|
| Mild pause or parenthetical mid-sentence | comma |
| Parenthetical aside | parens `( ... )` |
| Joining two independent clauses with causal link | semicolon `;` |
| Introducing a clarification, list, or punchline | colon `:` |
| Heavier pause where a new sentence is warranted | period |

Worked examples (the `_Avoid_` line shows the forbidden em-dash; the `Use` line shows the substitution):

- _Avoid_: `Posting fails — credit limit exceeded.`
- Use: `Posting fails: credit limit exceeded.`
- _Avoid_: `The pricing path runs once per line — and again per substitution.`
- Use: `The pricing path runs once per line, and again per substitution.`
- _Avoid_: `Fix is a one-line clear at line 32 — before ConfToSalesLine.`
- Use: `Fix is a one-line clear at line 32, before ConfToSalesLine.`

## Artifacts get scanned, not slow-read

A future reader lands to decide one task. They scan landing points top to bottom (IDs, statuses, ledes, labels, table rows), slow-read the one block that catches their eye.

**Failure.** Dense `<p>` cramming 5 distinct facts. Reading sentence 1 leaves the reader knowing nothing about 2–5 → reader reads the whole wall or skips the whole task. Artifact loses.

**Rule.** Multi-fact passage → one fact per landing line. Container is your call: bullets, sub-callouts, table rows, sub-`<details>`, separate paragraphs.

**Check.** Read only the first line of each landing point in your output. If that vertical strip says what is there, ship. Else restructure.

## Voice scope

Cadence inside a `tasks.html` task entry, picked by where the line lives.

| Where | Cadence |
|---|---|
| `<summary>` line (`[x] T-NNN: Title`) | One-line. Title PascalCase. Status marker plus title; no metadata. |
| Gherkin bullets inside `**Tests**` | One-line per bullet. Drop articles, conjunctions, hedging. BC vocabulary is the compression. |
| Notes-line entries | One-line per shape. See `notes-discipline.md`. |
| Description, alert body, table cell | Apply *Artifacts get scanned*. Multi-fact → one fact per landing line; one or two facts → tight `<p>`, direct, opinionated, no padding. |

The one-line cadence stops the bare entry from sprawling. The scan rule keeps descriptions and alert bodies landable.

## BC vocabulary

DO NOT use generic programming terms. Use BC vocabulary everywhere: names, prose, slot fills, ADR bodies.

- Insert / Modify / Delete (record operations), not Create / Update / Remove.
- Post, not Submit. Validate, not Check. Get / Find, not Fetch.
- Ledger Entry, not Transaction. No., not ID. Procedure, not Method.

State the specific object and procedure when describing a change. "Refactor the codeunit" is too vague. "Extract `PostSalesOrder` from codeunit 80 into a new `Sales-Post Impl`" is right.

## Lists of findings

When you write a multi-item list where the reader has to decide which item to look at next (code review findings, replan analyses, audit results), write so they can skim, not slow-read.

- Each item multi-line, not a paragraph.
- Blank line between multi-line items.
- Every line has a leading label, including the headline.
- Lede first: impact, not measurement or cause.
- Uniform shape across items in the list.
- **Bold + labels together**: `**Finding**:`, `**Where**:`, `**Action**:`, `**Note**:`.

Default slot set: `Finding:` (what) / `Where:` (file:line or location) / `Action:` (what to do) / `Note:` (severity, effort, caveat). Adapt slots to the list; uniform shape is the principle, not these specific labels.

## No workflow chatter in artifact prose

DO NOT write workflow-narrative prose into any durable artifact. The voice rule applies regardless of which file you are writing to.

- DO NOT prefix lines with the agent that decided: `/al-implement decision (filter placement):`, `/al-refine second opinion:`.
- DO NOT narrate TDD steps as prose: "bullet 1 went red on stub, green on body fill".
- DO NOT cite second-opinion accept/reject reasoning or session-internal reconciliation.

<claude-only>

**Claude Code only.** DO NOT cite `advisor()` cross-checks either; same rule.

</claude-only>

Workflow log belongs in the commit message and PR description. The artifact carries the forward-facing fact in declarative voice.

## Anti-pattern: do not write this

> `/al-implement decision (filter placement): T-005 pre-filters TempSourceLink to sub-config edges; planner trusts caller-shaped input — no internal filter. Rationale: bullets do not exercise a planner-internal Comp. Type / Line Configuration No. filter, so a coverage gap would surface at /al-mutate.`

What is wrong, by voice rule: workflow-step prefix is process noise; walkthrough prose is not declarative; references the agent that decided rather than the forward-facing fact; multi-line for one fact is padding; em-dash inside the prose violates the no-em-dash rule.

## Right shape: write this

> `LoadConfigurationIntoTemps` stays generic. Deep-clone callers pre-filter `TempSourceLink` to sub-config edges before passing it to the planner, chosen over a planner-internal filter so the loader stays reusable across ADR-0007 future-import composition.

Single declarative line. Names the decision and the hinge. No agent prefix. No archaeology. No em-dashes.
