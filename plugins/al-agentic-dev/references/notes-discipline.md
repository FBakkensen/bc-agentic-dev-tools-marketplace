# Notes discipline

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
| Block reason (the headline, one line) | `blocked-on:` frontmatter field, written/removed in the same Edit as the `status:` flip; depth stays body prose | the skill flipping to/from `blocked` |
| Absorbed unknown (assumption made inline without asking) | one-line entry appended to `deviations:` frontmatter; agent-depth stays body prose (`Contract notes` or a note) | the absorbing skill (`/al-implement` foremost) |
| Human-facing status picture (what's moving, blocked, waiting on the developer) | the dashboard — rebuilt-whole HTML projection of frontmatter per [dashboard.md](./dashboard.md); never the task file body | whoever changes frontmatter re-renders |
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

## Apply a decision vs. make a decision

Not every task-ledger mutation is a replan. A mutation that only *applies a decision already made* is provable from current state and reversible: the active skill acts on it inline and announces it, never routing through `/al-steer`. Examples: open a task whose `depends_on:` is now all `done`, flip the active task `done` on a green gate, fix a non-semantic edit inline (a comment, a local rename, formatting that moves no decision logic — whether a review surfaced it or the user asked mid-flow), reuse a seam a sibling task already established. Only a mutation that *makes a new decision* reaches the venue: re-scope, reorder, a new seam, decompose, or clear a block whose cause is a missing edge or an unsettled rule. The test is *new decision or not*, not *touches the ledger or not* — routing the provable case through the venue is the friction the floor removes. A public/shipped-surface change is never "non-semantic": a public procedure, table field, or page-action rename is an AppSource decision, not hygiene.

A trigger resting on a tool *diagnosis* (compile-error class, AL Runner gap, heuristic "structural blocker") is re-confirmed once before it flips `status: blocked` — a first-pass diagnosis is frequently a cascade artifact (an AL0305 missing-dependency reads as an AL0327 runner gap), and a block recorded on a phantom is false state the next session inherits and unwinds. A trigger resting on a recorded fact (`depends_on:`, Goal text, an observed verification mismatch) is acted on as-is.

## What the status board is now

There is no Summary table and no index file. The status board is a view computed on demand by grepping `status:` across the `tasks/` folder; `/al-steer` renders it in chat. Status lives only in the `status:` frontmatter field of each per-task file — the single source of truth. The filesystem (`ls tasks/` = run order) is the manifest.

The standing human-facing view is the **dashboard** ([dashboard.md](./dashboard.md)): a rebuilt-whole HTML projection of the same frontmatter, written to `.output/dashboard.html`. It owns no state — it can never disagree with the files, only lag them, and the render invariant closes the lag: **whoever changes task frontmatter re-renders the dashboard in the same working step.** Task files stay agent-facing; a line written into a task body "so the developer sees it" is in the wrong channel — the developer's channels are chat and the dashboard.
