# Notes discipline

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on. No need to comment on what was skipped.

Placement rules for `tasks.md` content. What goes in the `**Notes**` block, what goes in a NOTE/IMPORTANT/WARNING alert, what gets rejected entirely.

Voice for the prose itself comes from `voice-contract.md`. This file is destination-only: where content lives, not how prose is shaped.

## tasks.md per-task structure

Each task entry is one `<details>` block. Inside, in this order:

```
<a id="t-NNN"></a>
<details>
<summary><strong>[ ] T-NNN, Title</strong></summary>

> [!NOTE]
> **Layer**: ... · **Mutations**: ... · **Absorbed**: ...

> [!IMPORTANT]
> **Replan flag**: trigger #N, context

> [!WARNING]
> Body describes a critical hidden risk surfaced in the task.

**Depends on:** T-NNN, T-NNN
**Refactors:** T-NNN
**Fixes:** T-NNN

Description paragraph(s).

**Tests**

1. **<ScenarioTitle>**
   - **Given** ...
   - **When** ...
   - **Then** ...

**Mutations plan**

| ID | Site | Operator | Expected killer |
|---|---|---|---|
| M1 | ... | ... | T-NNN#K |

**Notes**

- BC-constraint or deferred-decision lines.

</details>
```

Every section is optional except `<summary>`, anchor, and the description paragraph. Empty sections are omitted, not present-but-blank.

## Where each piece of metadata lives

| Content | Destination | Owner |
|---|---|---|
| Status marker (`[ ]` `[~]` `[x]` `[!]`) | `<summary>` line | `/al-implement`, `/al-steer` |
| Layer (override or explicit) | NOTE alert `**Layer**` chip | `/al-refine` (override at scenario level), `/al-design` (family default) |
| Mutations result | NOTE alert `**Mutations**` chip + Summary table cell | `/al-mutate` |
| Absorbed scaffolding | NOTE alert `**Absorbed**` chip | `/al-implement` (trivia exception), `/al-scope` (scaffolding-rides-with-object) |
| Replan flag (hard-halt or soft-flag) | IMPORTANT alert | `/al-refine`, `/al-implement`, `/al-refactor`, `/al-steer` |
| Critical hidden risk surfaced in task body | WARNING alert | `/al-scope`, `/al-refine`, `/al-implement` |
| Declared task dependencies | `**Depends on:**` line | `/al-scope` |
| Declared refactor-of relationship | `**Refactors:**` line | `/al-scope`, `/al-steer` |
| Declared fix-of relationship | `**Fixes:**` line | `/al-scope`, `/al-steer` |
| Mutation plan (transient) | `**Mutations plan**` table inside `<details>` | `/al-implement` writes; `/al-mutate` reads then deletes |
| Non-obvious BC constraint specific to this task | `**Notes**` line | any writer |
| Explicit deferred decision | `**Notes**` line | any writer |

The chip / alert is the single source of truth. The Summary table is regenerated from the chip values plus scenario counts on every write.

## What a Notes line is now

A `**Notes**` line is scaffolding for the next agent on the in-flight TDD cycle. Branch-scoped. Dies at `[x]`. Forward-facing fact, not a log of how it was reached.

The valid shapes shrank when Layer / Mutations / Absorbed / Replan moved to chips and alerts. **Notes lines now carry only:**

- **Non-obvious BC constraint specific to this task**: hidden invariant, guard in an unexpected place, table missing from an existing routine, AL-language pitfall (var-aliasing, type-coercion edge case).
- **Explicit deferred decision**: `Implementation choice: X vs Y, /al-implement decides`. Delete the line once decided.

Anything else fails the trigger test below.

## Trigger test before writing a Notes line

→ Will this line be useful past `[x]`?

- **Yes** → DO NOT write to Notes. Halt. Take it to `/al-steer` to clear, then `/al-design` (architecture or design ADR) or `/al-grill-adr` (domain ADR or `CONTEXT.md`).
- **No** → Is the content one of the two valid shapes above?
  - **Yes** → Notes, one line.
  - **No** → It belongs in a chip, alert, or structured line. Place it there.

## Content that goes elsewhere, not Notes

This is destination routing. Prose-form rules (declarative, no workflow chatter) live in `voice-contract.md`.

- **Process IDs**: issue numbers, PR numbers, "the current fix", "this PR". Goes in the commit message and PR description, not the artifact.
- **Environment lessons**: "`-Force` is mandatory on this workstation", "the container needs republishing". Goes in `scripts/` or a local `CLAUDE.md`, not the artifact.
- **Lessons learned**: `Lesson:` entries, post-mortems, "Note for next time". Goes in the PR description if cross-cutting, or a retrospective doc. Never in `tasks.md` Notes.
- **Session-internal reasoning**: second-opinion accept/reject lists, mutation rationale not selected. <claude-only>Also: `advisor()` cross-checks.</claude-only> Stays in the session; the durable artifact carries the outcome, not the deliberation.

## Escalation routing

| Surface | Route to |
|---|---|
| Architectural decision with cross-task or future-feature impact | `/al-steer` → `/al-design` (architecture update or design ADR) |
| BC vocabulary, business rule, cross-feature truth | `/al-steer` → `/al-grill-adr` (domain ADR or `CONTEXT.md`) |
| Recurring scope rejection with substantive reason | `/al-steer` (`.out-of-scope/<concept>.md`) |
| Branch-scoped scaffolding the next agent needs | `**Notes**` line, valid shape above |

## Alert authoring rules

- **NOTE chip line**: leads with bold label, joins multiple chips with ` · ` separator. `**Layer**: component (override) · **Mutations**: 4 killed, 0 survivors · **Absorbed**: permission-set for `NALICF Comp. Line Variant Svc` inline`.
- **IMPORTANT**: `**Replan flag**: trigger #N, <one-line reason>.` Quote the trigger number every time.
- **WARNING**: lead with the consequence, then the fix in one line. `Without this clear, BC default cross-copy of Variant Code combined with SkipReseed := true silently overwrites the source Routing Header. Fix is a one-line clear at line 32.`
- **CAUTION**: reserved for ADR supersession callouts. Not used in `tasks.md`.
- **TIP**: reserved for architecture.md `## Solution` callout. Not used in `tasks.md`.

Each alert body is normal prose under the voice contract, multi-sentence allowed, no em-dashes.
