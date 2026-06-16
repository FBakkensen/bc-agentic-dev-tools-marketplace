# Notes discipline

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has `advisor()` tool). Codex and other runtimes without it: skip block contents and move on.

Destination map for content the skills generate. Answers one question per kind of content: *does this survive past `done`, and if so, where does it live?*

Format-agnostic. Markdown mechanics (`task:`, `status:`, `slice:`, `kind:` in per-task-file frontmatter, surgical-edit) live in `markdown-spec-discipline.md`. Style (Drop articles + filler + hedging, BC vocabulary, declarative cadence) lives in `voice-contract.md` and per-SKILL.md inline declaration. This file is destination only.

## Two destinations, picked by lifetime

- **Survives past `done`** → durable artifact outside the task file: `CONTEXT.md`, domain ADR, `.out-of-scope/`, commit message, PR description, or side-band reference. The per-task file is branch-scoped; dies when feature merges.
- **Dies with branch** → may live inside the per-task file (frontmatter + H1 title + body). Status flips, in-flight scaffolding, replan flags, mutation verdicts, deferred-decision notes the next agent on this branch needs.

Cannot tell which side a piece belongs on → ask trigger test: *will this line be useful past `done`?* Yes → durable. No → inside the task file or commit-only.

## Destination map

| Content | Destination | Owner |
|---|---|---|
| Status | `status:` field in per-task-file frontmatter | `/al-implement`, `/al-code-review`, `/al-user-verification`, `/al-steer` |
| Slice membership | `slice: <slug>` field in per-task-file frontmatter | `/al-scope` (write), every reader |
| Task kind (verify vs technical) | `kind: verify` or `kind: technical` in per-task-file frontmatter | `/al-scope` (write), every reader |
| In-flight scaffolding the next agent on this branch needs | inside the task file body | writing skill (shape is its call) |
| Replan flag (trigger fired; plan invalid or note added) | inside the task file body (and `status: blocked` in frontmatter when plan invalid) | `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification`, `/al-steer` |
| Verification failure (example, check, observed vs expected) | inside the verify task file body | `/al-user-verification` |
| Mutation verdict (kills / survivors / equivalence) | inside the task file body | `/al-mutate` |
| Critical hidden risk surfaced during refinement, implementation, or scope | inside the task file body | `/al-scope`, `/al-refine`, `/al-implement` |
| Architectural decision with cross-task impact inside the feature | architecture trade-off callout | `/al-design` |
| BC vocabulary, business rule, cross-feature truth | domain ADR or `CONTEXT.md` (via `/al-grill-adr`) | `/al-grill-adr` |
| Recurring scope rejection with substantive reason | `.out-of-scope/<concept>.md` | `/al-steer` |
| Process IDs (issue / PR numbers, "the current fix") | commit message or PR description | writing skill at commit time |
| Environment lessons (`-Force` is mandatory here, container needs republishing) | `scripts/` or local `CLAUDE.md` | project, not this plugin |
| Lessons learned, post-mortems, "Note for next time" | PR description (if cross-cutting) or retrospective doc | writing skill at PR time |
| Session-internal reasoning (second-opinion accept/reject, reconciliation chatter) | stays in session; durable artifact carries outcome, never deliberation | writing skill |

The *shape* content takes inside the task file body (chip, alert, callout, prose line, table cell, collapsible details) is writing skill's call per task. This file does not prescribe shape; `voice-contract.md` governs the prose.

## Escalation routing

When something surfaces inside an in-flight task file but actually belongs to durable destination:

| Surface | Route to |
|---|---|
| Architectural decision with cross-task impact inside the feature | `/al-steer` → `/al-design` (architecture reshape or trade-off callout) |
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

Trigger ID survives as address (flag inside one task file can reference "trigger 4" and the next agent knows what pattern was seen). Response to trigger is writing skill's judgment per situation: trigger means plan invalid as planned → flip `status:` to `blocked` and route to `/al-steer`; trigger means new info that doesn't invalidate → note it inside the task file and continue. Detection cues are skill-specific; each skill's replan check names what cue looks like in its own work. Trigger #8 special-cased to `/al-user-verification`: gate is binary, response is always `status: blocked` and route to `/al-steer`; no "absorb and continue" variant for failed user verification.

## What the status board is now

There is no Summary table and no index file. The status board is a view computed on demand by grepping `status:` across the `tasks/` folder; `/al-steer` renders it. Status lives only in the `status:` frontmatter field of each per-task file — the single source of truth. The filesystem (`ls tasks/` = run order) is the manifest; nothing in this file requires a materialised board.
