# Notes discipline

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has `advisor()` tool). Codex and other runtimes without it: skip block contents and move on.

Destination map for content the skills generate. Answers one question per kind of content: *does this survive past `done`, and if so, where does it live?*

Format-agnostic. HTML mechanics (`data-task`, `data-status`, Mermaid containers, surgical-edit) live in `html-spec-discipline.md`. Voice (caveman, em-dash ban, BC vocabulary, declarative cadence) lives in `voice-contract.md` and per-SKILL.md inline declaration. This file is destination only.

## Two destinations, picked by lifetime

- **Survives past `done`** → durable artifact outside task block: `CONTEXT.md`, domain ADR, design ADR, `.out-of-scope/`, commit message, PR description, or side-band reference. Task block is branch-scoped; dies when feature merges.
- **Dies with branch** → may live inside task block (`<details data-task="T-NNN">`). Status flips, in-flight scaffolding, replan flags, mutation verdicts, deferred-decision notes the next agent on this branch needs.

Cannot tell which side a piece belongs on → ask trigger test: *will this line be useful past `done`?* Yes → durable. No → inside-task or commit-only.

## Destination map

| Content | Destination | Owner |
|---|---|---|
| Status | `data-status` attribute on task `<details>` | `/al-implement`, `/al-user-verification`, `/al-steer` |
| Slice membership | `data-slice="<slug>"` attribute on task `<details>` | `/al-scope` (write), every reader |
| Task kind (verify vs technical) | `data-kind="verify"` on verify task (technical tasks omit) | `/al-scope` (write), every reader |
| In-flight scaffolding the next agent on this branch needs | inside task block | writing skill (shape is its call) |
| Replan flag (trigger fired; plan invalid or note added) | inside task block (and `data-status="blocked"` when plan invalid) | `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification`, `/al-steer` |
| Verification failure (scenario, step, observed vs expected) | inside verify task block | `/al-user-verification` |
| Mutation verdict (kills / survivors / equivalence) | inside task block | `/al-mutate` |
| Critical hidden risk surfaced during refinement, implementation, or scope | inside task block | `/al-scope`, `/al-refine`, `/al-implement` |
| Architectural decision with cross-task or future-feature impact | design ADR (via `/al-design` or `/al-steer` re-routing) | `/al-design` |
| BC vocabulary, business rule, cross-feature truth | domain ADR or `CONTEXT.md` (via `/al-grill-adr`) | `/al-grill-adr` |
| Recurring scope rejection with substantive reason | `.out-of-scope/<concept>.md` | `/al-steer` |
| Process IDs (issue / PR numbers, "the current fix") | commit message or PR description | writing skill at commit time |
| Environment lessons (`-Force` is mandatory here, container needs republishing) | `scripts/` or local `CLAUDE.md` | project, not this plugin |
| Lessons learned, post-mortems, "Note for next time" | PR description (if cross-cutting) or retrospective doc | writing skill at PR time |
| Session-internal reasoning (second-opinion accept/reject, reconciliation chatter) | stays in session; durable artifact carries outcome, never deliberation | writing skill |

The *shape* content takes inside task block (chip, alert, callout, prose line, table cell, collapsible details) is writing skill's call per task. This file does not prescribe shape; `voice-contract.md` governs the prose.

## Escalation routing

When something surfaces inside in-flight task but actually belongs to durable destination:

| Surface | Route to |
|---|---|
| Architectural decision with cross-task or future-feature impact | `/al-steer` → `/al-design` (architecture reshape or design ADR) |
| BC vocabulary, business rule, cross-feature truth | `/al-steer` → `/al-grill-adr` (domain ADR or `CONTEXT.md`) |
| Recurring scope rejection with substantive reason | `/al-steer` (writes `.out-of-scope/<concept>.md`) |

`/al-steer` is single replan venue; routing through it keeps rejection knowledge base and ADR queue coherent.

## Replan triggers

Eight named patterns the skills learn to spot. Cited by `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification` (each runs replan check before close); cleared by `/al-steer`.

| # | Trigger |
|---|---|
| 1 | Task too big |
| 2 | Hidden pre-req |
| 3 | Wrong order |
| 4 | Sibling now wrong |
| 5 | New behaviour emerges |
| 6 | Architecture decomposition wrong |
| 7 | Goal drift |
| 8 | Verification failed |

Trigger ID survives as address (flag inside one task can reference "trigger 4" and the next agent knows what pattern was seen). Response to trigger is writing skill's judgment per situation: trigger means plan invalid as planned → flip `data-status` to `blocked` and route to `/al-steer`; trigger means new info that doesn't invalidate → note it inside task and continue. Detection cues are skill-specific; each skill's replan check names what cue looks like in its own work. Trigger #8 special-cased to `/al-user-verification`: gate is binary, response is always `data-status="blocked"` and route to `/al-steer`; no "absorb and continue" variant for failed user verification.

## What the Summary table is now

If writing skill chooses to render Summary table in `tasks.html`, Summary is view derived from per-task content; not source of truth. Status lives only on `data-status` of task `<details>`. Whether Summary table earns its place in this feature is writing skill's call per `tasks.html`; nothing in this file requires one.
