# Voice contract

Style rule lives at the top of each SKILL.md as a one-line inline declaration. This file carries the non-style disciplines: lexical, citation, shape, and artifact-vs-chat scoping. Disciplines below apply to durable artifacts (`event-model.md`, `architecture.md`, `tasks.md`, ADRs, `CONTEXT.md`, `.out-of-scope/`) and to chat output.

## BC vocabulary

Insert / Modify / Delete (not Create / Update / Remove). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method). Codeunit (not class). Name the specific object and procedure: "extract `PostSalesOrder` from codeunit 80 into `Sales-Post Impl`", not "refactor the codeunit".

## Names are the citation

Use the test codeunit, procedure, table, field, event publisher by name. `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address; future readers grep, no inline `(see: file.al:120)` annotations.

## Evidence bar (citation chain)

BC training data is stale fiction; your confidence about a name, signature, or pattern is not evidence any are right. One bar, stated here once; writing skills point at it.

- **Names.** Every exact BC-specific name (object, procedure, event, table, field, enum value, caption) landing in an artifact or AL code: backed this session by `al-symbols-mcp` / `grep` hit, or a quoted fetch. Recall does not satisfy. Names cited upstream count only when `grep` against the upstream file returns them this session.
- **Constructs.** Workspace evidence stops at names. A BC construct class — record loop + modify, partial records (`SetLoadFields`), temp record lifecycle, page/report surface, transaction boundary (`Commit`) — carries execution-order and platform-cost semantics legacy code cannot vouch for: legacy is precedent, not authority. First write of a construct class in a task → fetch the matching topic per [bc-code-intelligence-dispatch.md](bc-code-intelligence-dispatch.md) or a Microsoft Learn passage, apply it yourself.
- **Satisfiers.** Any verbatim-quoted fetch with one-line citation counts: `bc-code-intelligence` topic, Microsoft Learn, `/bc-standard-reference`. `/al-research` is the escalation seat — mandatory when sources disagree or the fact lands in a durable design artifact (`event-model.md`, `architecture.md`, `CONTEXT.md`, ADRs).
- **Trace.** Citation declares in chat as `Researched: <fact> → <source path / URL / topic id>`; task-scoped citations also land as `Contract notes` bullets at task reconcile — the one inline-citation carve-out, making skipped research visible to `/al-code-review` and the next session. Everything else in artifacts stays names-only.

## Artifacts get scanned, not slow-read

Reader lands to decide one task. Scans landing points top to bottom (IDs, statuses, ledes, labels, table rows), slow-reads the one block that catches the eye. Multi-fact passages get one fact per landing line; container is your call (bullets, callouts, table rows, sub-`<details>`). Read only the first line of each landing point in your draft. If that vertical strip says what is there, ship.

## Lists of findings

Multi-item findings: label every line (`Finding:` / `Where:` / `Action:`), lede first.

## Tables of facts

Field/value recaps: borderless two-column table, not bullets.

## No workflow chatter in artifacts

DO NOT prefix artifact lines with the agent that decided (`/al-implement decision:`). DO NOT narrate TDD steps as prose ("bullet 1 went red on stub, green on body fill"). DO NOT cite second-opinion or `advisor()` reconciliation. Workflow log belongs in the commit message; artifact carries the forward-facing fact in declarative voice.

<claude-only>

Claude Code only. The `<claude-only>` block is the single venue for `advisor()` checkpoints and other Claude-only gates. Place inline at the moment the gate fires, not as a top-of-file blockquote. Codex skips the block contents; no need to comment on what was skipped.

</claude-only>

## Chat shape skeletons

Style fills the shape; the skeleton stays. Four skeletons, named defaults.

### Opener (session start)

Chip line `**T-NNN <Title>** · status → status`, then 2-col table of skill-specific rows.

### Gate report (every gate event)

Four lines at app altitude. Mechanics (procedure names, line numbers, mutant IDs, RED/GREEN beats, build counts) belong in commits and the task block; user pulls detail by asking.

| Line | Carries |
|---|---|
| **Did:** | what user-facing behaviour the change enables (Action, Field, API Status, Role Center cue) |
| **Was:** | the problem it solves, one-line scenario the user recognises |
| **Fits:** | how the change fits the app at BC-shape altitude (module, BC pattern, seam, names like `Sales-Post Impl`) |
| **Next:** | what is on the user, or nothing if the agent moves on |

Verify-task variant (`/al-user-verification` closing a slice, `kind=verify`): four answers shift altitude. **Did** = what the user just confirmed (not what the code does). **Was** = user-facing problem the slice solved. **Fits** = journey in `event-model.md` vocabulary (Role / Action / Business Event / View / Status, no AL names). **Next** = handoff. The verify task's point is that the user touched the surface; report cites their observation, not the implementation.

### Answer (user question)

Answer only what was asked, ≤3 lines at the question's altitude. No status recap, no background section, no "why it matters", no deferred-questions list; the user pulls detail by asking. A question is not a gate event — do not promote it to a briefing.

### Stop (halt)

Pre-flight: one line — `**Stop.** <reason in BC vocab>. <next action>.` Mid-flow: Stop reason + State 2-col table + Next action (absorb-and-continue variant uses "Continuing" instead of "Next").

SKILL-specific shapes (AL Runner ERROR table in `/al-implement`, drafted `Test Specification` / `Verification Plan` sections in `/al-refine`, Second opinion line in `/al-second-opinion`) live in their owning SKILL.md and follow the same rule: shape preserved, Style applies.

## Chat carve-out

Chat requires a closing line stating what landed (the user has no `tasks.md` open). Closing line follows the Style rule; not a pleasantry. Workflow markers (`**RED**`, `**GREEN**`, `**Second opinion**`) permitted in chat; workflow narrative prose still banned.
