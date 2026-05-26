# Notes discipline

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on.

Destination map for content the skills generate. Answers one question per kind of content: *does this survive past `done`, and if so, where does it live?*

Format-agnostic. HTML mechanics (`data-task`, `data-status`, Mermaid containers, surgical-edit) live in `html-spec-discipline.md`. Voice (em-dash ban, BC vocabulary, declarative cadence) lives in `voice-contract.md`. This file is destination only.

## Two destinations, picked by lifetime

- **Survives past `done`** → goes into a durable artifact outside the task block: `CONTEXT.md`, a domain ADR, a design ADR, `.out-of-scope/`, the commit message, the PR description, or a side-band reference. The task block is branch-scoped; it dies when the feature merges.
- **Dies with the branch** → may live inside the task block (`<details data-task="T-NNN">`). Status flips, in-flight scaffolding, replan flags, mutation verdicts, deferred-decision notes the next agent on this branch needs.

If you cannot tell which side a piece of content belongs on, ask the trigger test: *will this line be useful past `done`?* Yes → durable. No → inside-task or commit-only.

## Destination map

| Content | Destination | Owner |
|---|---|---|
| Status | `data-status` attribute on the task `<details>` | `/al-implement`, `/al-user-verification`, `/al-steer` |
| Slice membership | `data-slice="<slug>"` attribute on the task `<details>` | `/al-scope` (write), every reader |
| Task kind (verify vs technical) | `data-kind="verify"` on the verify task (technical tasks omit) | `/al-scope` (write), every reader |
| In-flight scaffolding the next agent on this branch needs | inside the task block | the writing skill (shape is its call) |
| Replan flag (the trigger fired; plan invalid or note added) | inside the task block (and `data-status="blocked"` when plan invalid) | `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification`, `/al-steer` |
| Verification failure (scenario, step, observed vs expected) | inside the verify task block | `/al-user-verification` |
| Mutation verdict (kills / survivors / equivalence) | inside the task block | `/al-mutate` |
| Critical hidden risk surfaced during refinement, implementation, or scope | inside the task block | `/al-scope`, `/al-refine`, `/al-implement` |
| Architectural decision with cross-task or future-feature impact | design ADR (via `/al-design` or `/al-steer` re-routing) | `/al-design` |
| BC vocabulary, business rule, cross-feature truth | domain ADR or `CONTEXT.md` (via `/al-grill-adr`) | `/al-grill-adr` |
| Recurring scope rejection with substantive reason | `.out-of-scope/<concept>.md` | `/al-steer` |
| Process IDs (issue / PR numbers, "the current fix") | commit message or PR description | the writing skill at commit time |
| Environment lessons (`-Force` is mandatory here, container needs republishing) | `scripts/` or a local `CLAUDE.md` | the project, not this plugin |
| Lessons learned, post-mortems, "Note for next time" | PR description (if cross-cutting) or a retrospective doc | the writing skill at PR time |
| Session-internal reasoning (second-opinion accept/reject, reconciliation chatter) | stays in the session; the durable artifact carries the outcome, never the deliberation | the writing skill |

The *shape* the content takes inside the task block (chip, alert, callout, prose line, table cell, collapsible details) is the writing skill's call per task. This file does not prescribe shape; `voice-contract.md` governs the prose.

## Escalation routing

When something surfaces inside an in-flight task but actually belongs to a durable destination:

| Surface | Route to |
|---|---|
| Architectural decision with cross-task or future-feature impact | `/al-steer` → `/al-design` (architecture reshape or design ADR) |
| BC vocabulary, business rule, cross-feature truth | `/al-steer` → `/al-grill-adr` (domain ADR or `CONTEXT.md`) |
| Recurring scope rejection with substantive reason | `/al-steer` (writes `.out-of-scope/<concept>.md`) |

`/al-steer` is the single replan venue; routing through it keeps the rejection knowledge base and the ADR queue coherent.

## Replan triggers

Eight named patterns the skills learn to spot. Cited by `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification` (each runs a replan check before close); cleared by `/al-steer`.

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

The trigger ID survives as an address (so a flag inside one task can reference "trigger 4" and the next agent knows what pattern was seen). The response to a trigger is the writing skill's judgment per situation: when the trigger means the plan is invalid as planned, flip `data-status` to `blocked` and route to `/al-steer`; when the trigger means new info that doesn't invalidate the plan, note it inside the task and continue. Detection cues are skill-specific; each skill's replan check names what the cue looks like in its own work. Trigger #8 is special-cased to `/al-user-verification`: the gate is binary, so the response is always `data-status="blocked"` and a route to `/al-steer`; there is no "absorb and continue" variant for a failed user verification.

## What the Summary table is now

If the writing skill chooses to render a Summary table in `tasks.html`, the Summary is a view derived from the per-task content; it is not the source of truth. Status lives only on `data-status` of the task `<details>`. Whether a Summary table earns its place in this feature is the writing skill's call per `tasks.html`; nothing in this file requires one.
