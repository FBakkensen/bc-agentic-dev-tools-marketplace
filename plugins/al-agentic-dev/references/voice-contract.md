# Voice contract

Voice rules live at the top of each SKILL.md as a 2-line inline declaration (caveman + four carve-outs). This file carries the non-voice disciplines: lexical, citation, shape, and artifact-vs-chat scoping. Disciplines below apply to durable artifacts (`event-model.md`, `architecture.md`, `tasks.md`, ADRs, `CONTEXT.md`, `.out-of-scope/`) and to chat output.

## Artifact content is telegraphic

`event-model.md`, `architecture.md`, `tasks.md` drop articles, padding, hedges; fragments fine. Output tokens dominate the per-feature budget; same content read across re-runs and consumer skills (`/al-refine`, `/al-implement`, `/al-mutate`, `/al-code-review`) compounds the cost.

Gherkin step content keeps `Given/When/Then` sentence shape so steps stay parseable for test-mapping tooling. Numbered user-action steps in verify tasks keep imperative sentence shape so a human can read them aloud and act.

## No em-dashes

DO NOT use em-dashes (—) anywhere. Substitute by job:

| Job | Substitute |
|---|---|
| Mild pause or parenthetical mid-sentence | comma |
| Parenthetical aside | parens `( ... )` |
| Joining two independent clauses with causal link | semicolon `;` |
| Introducing a clarification, list, or punchline | colon `:` |
| Heavier pause where a new sentence is warranted | period |

## BC vocabulary

Insert / Modify / Delete (not Create / Update / Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method). Codeunit (not class). Name the specific object and procedure: "extract `PostSalesOrder` from codeunit 80 into `Sales-Post Impl`", not "refactor the codeunit".

## Names are the citation

Use the test codeunit, procedure, table, field, event publisher by name. `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address; future readers grep, no inline `(see: file.al:120)` annotations. Same principle drives the citation chain: BC training data is stale fiction, so before writing any BC-specific name into an artifact, declare its citation in chat via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Artifact stays clean of inline citations; chat carries the audit trail.

## Artifacts get scanned, not slow-read

Reader lands to decide one task. Scans landing points top to bottom (IDs, statuses, ledes, labels, table rows), slow-reads the one block that catches the eye. Multi-fact passages get one fact per landing line; container is your call (bullets, callouts, table rows, sub-`<details>`). Read only the first line of each landing point in your draft. If that vertical strip says what is there, ship.

## Lists of findings

Multi-item lists where the reader picks one to act on (code review, audit, replan analysis): each item multi-line with labeled lines, blank line between items, lede first, uniform shape across the list.

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

DO NOT prefix artifact lines with the agent that decided (`/al-implement decision:`). DO NOT narrate TDD steps as prose ("bullet 1 went red on stub, green on body fill"). DO NOT cite second-opinion or `advisor()` reconciliation. Workflow log belongs in the commit message; artifact carries the forward-facing fact in declarative voice.

<claude-only>

Claude Code only. The `<claude-only>` block is the single venue for `advisor()` checkpoints and other Claude-only gates. Place inline at the moment the gate fires, not as a top-of-file blockquote. Codex skips the block contents; no need to comment on what was skipped.

</claude-only>

## Chat shape skeletons

Caveman voice fills the shape; the skeleton stays. Three skeletons, named defaults.

### Opener (session start)

Chip line carrying task + status, then a borderless two-column table with skill-specific rows.

```
**T-NNN <Title>** · `ready` → `in-progress`

| | |
|---|---|
| **Pure**  | 4 |
| **E2E**   | 2 |
| **First** | T-NNN#1 `BlockedCustomerCannotPostInvoice` |
```

### Gate report (every gate event)

Four caveman lines at app altitude. Mechanics (procedure names, line numbers, mutant IDs, RED/GREEN beats, build counts) belong in commits and the task block; user pulls detail by asking.

| Line | Carries |
|---|---|
| **Did:** | what user-facing behaviour the change enables (Action, Field, API Status, Role Center cue) |
| **Was:** | the problem it solves, one-line scenario the user recognises |
| **Fits:** | how the change fits the app at BC-shape altitude (module, BC pattern, seam, names like `Sales-Post Impl`) |
| **Next:** | what is on the user, or nothing if the agent moves on |

Verify-task variant (`/al-user-verification` closing a slice, `kind=verify`): four answers shift altitude. **Did** = what the user just confirmed (not what the code does). **Was** = user-facing problem the slice solved. **Fits** = journey in `event-model.md` vocabulary (Role / Action / Business Event / View / Status, no AL names). **Next** = handoff. The verify task's point is that the user touched the surface; report cites their observation, not the implementation.

### Stop (halt)

Pre-flight (nothing touched): one line. `**Stop.** <reason in BC vocab>. <next action>.` Reason line is the C4 carve-out (natural form for safety).

Mid-flow (state landed before halt): Stop reason + State 2-col table + Next action. Absorb-and-continue variant uses the same shape with "Continuing" instead of "Next":

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

SKILL-specific shapes (AL Runner ERROR table in `/al-implement`, Drafted scenarios in `/al-refine`, Second opinion line in `/al-second-opinion`) live in their owning SKILL.md and follow the same rule: shape preserved, voice caveman.

## Chat carve-out

Chat requires a closing line stating what landed (the user has no `tasks.md` open). Closing line is caveman-form; not a pleasantry. Workflow markers (`**RED**`, `**GREEN**`, `**Second opinion**`) permitted in chat; workflow narrative prose still banned.
