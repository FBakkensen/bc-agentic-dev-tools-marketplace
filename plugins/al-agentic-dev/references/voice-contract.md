# Voice contract

Style rule lives at the top of each SKILL.md as a one-line inline declaration. This file carries the non-style disciplines: lexical, citation, shape, and artifact-vs-chat scoping. Disciplines below apply to durable artifacts (`event-model.md`, `architecture.md`, `tasks.md`, ADRs, `CONTEXT.md`, `.out-of-scope/`) and to chat output.

## Format

Applies everywhere — chat output and artifacts — unless a specific skeleton below dictates otherwise.

**Bold header** on every section.

Verdict, conclusion, or status on line 1. Context and detail after.

3 sentences max per paragraph. Empty line between paragraphs.

- Bullets for lists.
- Not prose dressed as a list.

## BC vocabulary

| Use | Not |
|---|---|
| Insert / Modify / Delete | Create / Update / Remove |
| Post | Submit |
| Validate | Check |
| Get / Find | Fetch |
| Ledger Entry | Transaction |
| No. | ID |
| Procedure | Method |
| Codeunit | Class |

Name the specific object and procedure: "extract `PostSalesOrder` from codeunit 80 into `Sales-Post Impl`", not "refactor the codeunit".

## Names are the citation

Use the test codeunit, procedure, table, field, event publisher by name. `ABCCopyDocSubscribers.OnAfterInsertToSalesLine` is the address; future readers grep, no inline `(see: file.al:120)` annotations.

## Evidence bar (citation chain)

BC training data is stale fiction; your confidence about a name, signature, or pattern is not evidence any are right. One bar, stated here once; writing skills point at it.

- **Names.** Every exact BC-specific name (object, procedure, event, table, field, enum value, caption) in an artifact or AL code must be backed this session by `al-symbols-mcp` / `grep` hit, or a quoted fetch. Recall does not satisfy. Names cited upstream count only when `grep` against the upstream file returns them this session.

- **Minted names.** A name that does not exist yet cannot have a workspace hit. Its bar is a zero-hit collision lookup this session (`al-symbols-mcp` / `grep` — genuinely new, not shadowing) plus BC-vocabulary compliance.
  - Collision scope: object names against workspace object declarations; fields against the target table and its extensions; procedures against the target object only; enum values against the target enum and its extensions.
  - Base object in a dependency (not workspace source): grep covers workspace extensions only — the `/al-build` compiler is the backstop for base-field collisions.
  - `New and Modified Objects` is proposal, not carried evidence. The skill that lands the object re-runs the collision lookup in its own session.

- **Constructs.** Workspace evidence stops at names. BC construct classes — record loop + modify, `SetLoadFields`, temp record lifecycle, page/report surface, `Commit` — carry execution-order and platform-cost semantics legacy code cannot vouch for. First write of a construct class in a task → fetch the matching topic per [bc-code-intelligence-dispatch.md](bc-code-intelligence-dispatch.md) or a Microsoft Learn passage, and declare it: `Researched: <construct> → <topic id / Learn URL>`.

- **Satisfiers.** Any verbatim-quoted fetch with one-line citation counts.
  - Names: `bc-code-intelligence` topic, Microsoft Learn, or `/bc-standard-reference`.
  - Constructs: topic or Learn passage only — BaseApp source shows an instance, not the rule.
  - `/al-research` is mandatory when sources disagree or a fetched fact lands in a durable design artifact (`event-model.md`, `architecture.md`, `CONTEXT.md`, ADRs).

- **Trace.** Declare in chat as `Researched: <fact> → <source path / URL / topic id>`. Task-scoped citations also land as `Contract notes` bullets at task reconcile — the one inline-citation carve-out, making skipped research visible to `/al-code-review` and the next session. Everything else in artifacts stays names-only.

## Artifacts get scanned, not slow-read

Reader lands to decide one task. They scan landing points top to bottom (IDs, statuses, ledes, labels, table rows) and slow-read only the one block that catches the eye.

Multi-fact passages get one fact per landing line — bullets, callouts, table rows, or sub-`<details>`, your call.

Read only the first line of each landing point in your draft. If that vertical strip says what is there, ship.

## Lists of findings

Multi-item findings: label every line (`Finding:` / `Where:` / `Action:`), lede first.

## Tables of facts

Field/value recaps: borderless two-column table, not bullets.

## No workflow chatter in artifacts

Artifact carries the forward-facing fact in declarative voice. Workflow log belongs in the commit message.

- Do NOT prefix lines with the agent that decided (`/al-implement decision:`).
- Do NOT narrate TDD steps as prose ("bullet 1 went red on stub, green on body fill").
- Do NOT cite second-opinion or `advisor()` reconciliation.

<claude-only>

Claude Code only. The `<claude-only>` block is the single venue for `advisor()` checkpoints and other Claude-only gates. Place inline at the moment the gate fires, not as a top-of-file blockquote. Codex skips the block contents; no need to comment on what was skipped.

</claude-only>

## Chat shape skeletons

Style fills the shape; the skeleton stays. Four skeletons, named defaults.

### Opener (session start)

Chip line `**T-NNN <Title>** · status → status`, then 2-col table of skill-specific rows.

### Gate report

Two tiers. The event type determines the tier.

**Mid-task gate** — a RED→GREEN that does not flip task status:

One line. `**GREEN** <what changed> → <next step>.` or `**RED** <what failed> → <next step>.`

**Task-close gate** — status flips to `done` or `blocked`:

Four lines.

| Line | Carries |
|---|---|
| **Did:** | what user-facing behaviour the change enables (Action, Field, API Status, Role Center cue) |
| **Was:** | the problem it solves, one-line scenario the user recognises |
| **Fits:** | how the change fits the app at BC-shape altitude (module, BC pattern, seam, names like `Sales-Post Impl`) |
| **Next:** | what is on the user, or nothing if the agent moves on |

Mechanics (procedure names, line numbers, mutant IDs, build counts) belong in the commit and the task block.

**Verify-task variant** (`/al-user-verification` closing a slice, `kind=verify`): same four lines, shifted altitude. **Did** = what the user confirmed. **Was** = user-facing problem the slice solved. **Fits** = journey in `event-model.md` vocabulary (Role / Action / Business Event / View / Status, no AL names). **Next** = handoff.

### Answer (user question)

Answer on line 1. 3 sentences max at the question's altitude.

- No status recap, no background section, no "why it matters."
- Flag open questions explicitly — don't silently drop them.
- A question is not a gate event — do not promote it to a briefing.

### Stop (halt)

Pre-flight: one line — `**Stop.** <reason in BC vocab>. <next action>.` Mid-flow: Stop reason + State 2-col table + Next action (absorb-and-continue variant uses "Continuing" instead of "Next").

SKILL-specific shapes (AL Runner ERROR table in `/al-implement`, drafted `Test Specification` / `Verification Plan` sections in `/al-refine`, Second opinion line in `/al-second-opinion`) live in their owning SKILL.md and follow the same rule: shape preserved, Style applies.

## Chat carve-out

Chat requires a closing line stating what landed (the user has no `tasks.md` open). Closing line follows the Style rule; not a pleasantry. Workflow markers (`**RED**`, `**GREEN**`, `**Second opinion**`) permitted in chat; workflow narrative prose still banned.
