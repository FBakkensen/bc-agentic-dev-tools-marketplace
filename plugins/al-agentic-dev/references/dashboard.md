# The feature dashboard

One HTML page per in-flight feature — the human-facing surface of the pipeline. Task files are agent-facing state; the developer should never need to open one to know where the feature stands. Chat carries the interaction; the dashboard carries the standing picture: what's done, what's moving, what's blocked, and what waits on the developer.

## Projection, not a document

The dashboard is a **rendering of task frontmatter, rebuilt whole on every render**. It is never hand-edited, never surgically patched, and never a source of truth: delete it and nothing is lost — the next render reproduces it from the files. It is not an index file in the sense `markdown-spec-discipline.md` forbids: it owns no state and no order (the `status:` field and the `NNN` filename prefix stay the sole sources); it only shows them.

Inputs, exhaustively: `000-feature.md` (feature title + Goal line), and each per-task file's filename (run order, `T-MMM`, slug) and frontmatter (`status:`, `slice:`, `kind:`, `depends_on:`, `review: clean`, `deviations:`, `blocked-on:`). Task **body prose never renders** — rendering it would rebuild the parallel document the split exists to kill. A reader who wants depth follows the chat or asks.

## The render invariant

**Whoever changes task frontmatter re-renders the dashboard.** No enumerated skill list — any skill (current or future) that flips a `status:`, appends a `deviations:` entry, or writes `blocked-on:` rebuilds the page in the same working step. A skill that only reads never renders. Several flips in one step (a replan touching five tasks) render once, at the end.

## Where it lives

Write to `.output/dashboard.html` (already gitignored — the dashboard is a render artifact, never committed). If the harness offers a hosted live-page tool with a stable URL (e.g. Claude Code Artifacts), also publish the same file to the same URL each render so the developer keeps one browser tab that always shows current state; otherwise the local file is the surface — name its path once per session so the developer can open it.

## What the page shows

Self-contained HTML, no external requests, glanceable — the developer decides from the top of the page, not by reading to the bottom:

- **Attention panel first.** Everything waiting on the developer, or empty-state "nothing waits on you". A `blocked` task shows its `blocked-on:` line verbatim; a task at a user-driven step (`ready-for-verification` walk, a review fix queue the chat reported) names the skill to invoke.
- **The pipeline picture.** Slices in run order, each task as a card: `T-MMM`, slug, `kind`, status rendered as colour/position, `review: clean` as a stamp. The run order and dependency edges come from filename prefix and `depends_on:` — the page shows the same graph `/al-steer` reasons over.
- **Deviation badges.** Each `deviations:` entry renders as a one-line badge on its task card — the standing record of unknowns the agent absorbed without asking. Nothing here demands action; visibility is the point.
- **Feature header.** Title and Goal from `000-feature.md`, so drift is visible against what the page shows moving.

Visual shape beyond this is the rendering skill's call per feature — this file fixes the inputs, the rebuild-whole rule, and the attention-first ordering, not a template.
