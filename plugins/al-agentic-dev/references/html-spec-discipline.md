# HTML spec discipline

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on. No need to comment on what was skipped.

`architecture.html` and `tasks.html` are the reading surface. Not an intermediate, not a build artifact. This file is what `/al-design` and `/al-scope` consult before generating, and what every maintaining skill (`/al-refine`, `/al-implement`, `/al-mutate`, `/al-steer`) consults before editing.

ADRs (`docs/adr/*.md`) and `CONTEXT.md` stay markdown. Only the per-feature artifacts under `specs/<NNN>-<slug>/` are HTML.

## Aesthetic posture

Inherited from frontend-design discipline, restated for spec documents.

- **Bold direction.** Pick a coherent aesthetic per spec: refined editorial, brutalist grid, art-deco geometric, organic, industrial. Execute one direction with precision. Not several at once.
- **Distinctive typography.** Display font paired with body font, both from Google Fonts via CDN. Pair a characterful display with a readable body. DO NOT use Inter, Roboto, Arial, system-ui, or any generic AI default.
- **Cohesive palette.** Dominant ink plus one or two accents. CSS variables for every reused colour. DO NOT default to purple gradients on white.
- **Monograph treatment.** Display type for the title. Drop cap or oversized capital on the opening paragraph when the aesthetic permits. Marginalia callouts via floated `<aside>` when a sidebar note serves the reader. Hairline rules on tables. Generous leading on body prose. Long-reading is the use case; respect it.
- **Self-contained file.** One HTML document. Inline `<style>` for everything project-local. Google Fonts via `<link rel="stylesheet">`. Mermaid via CDN `<script>`. No external CSS files, no JS bundles, no asset folders. The file opens in a browser and renders, given an internet connection.
- **Offline trade accepted.** No CDN reachability means broken fonts and unrendered graphs. Bodies still read. The plugin does not mirror or inline CDN assets to defeat this.

Within a project, ride the prior spec's aesthetic for visual coherence across the monograph. Across projects, vary freely. Two `/al-design` runs in different repos should not converge on the same font pairing or palette.

## The two-attribute floor

`tasks.html` carries one surgical-edit contract. Maintaining skills find a task by its ID and flip its status. Everything else regenerates whole when it changes.

The two hooks:

| Hook | Locates | Used by |
|---|---|---|
| `<details data-task="T-NNN">` on each per-task block | The per-task block | every skill that touches a task |
| `data-status="ready \| in-progress \| done \| blocked"` on the same `<details>` | The status, single source of truth | `/al-implement`, `/al-steer` |

**Why these two and nothing else.** Status flips happen often (every TDD cycle bump), so a stable attribute anchor avoids re-parsing prose to locate the right `<details>`. Two tasks with similar titles do not collide on the attribute. Every other slot (Tests area, alert kinds, edges block, Summary row, Mermaid container) is the writing skill's call per feature; if its shape needs to change, the skill regenerates that part of the task block whole. Anchors for things that change rarely are not anchors that earn their place.

`architecture.html` carries no surgical-edit contract at all. Maintaining skills do not edit it; `/al-design` reshapes it whole on re-run. The only HTML hooks in `architecture.html` are Mermaid containers (`<div class="mermaid" data-graph="module-deps">` and / or `<div class="mermaid" data-graph="flow">`), and those exist so the Mermaid CDN library can find its graphs, not so the agent can find slots.

**Rules around the floor:**

- The visible status marker (`[ ]`, `[~]`, `[x]`, `[!]`, badge, colour) renders from `data-status` via CSS pseudo-element, JS template, or duplicated `<span>`. Whatever `/al-design` and `/al-scope` choose per project. The agent flips only the attribute, never the visible marker.
- Status lives only on the `<details>`. A second copy in a Summary row (or anywhere else) would require two-place edits on every flip, which is exactly what the floor avoids.
- Where each kind of content lives inside the task block (Tests area, alert blocks, edges, scaffolding callouts) is the writing skill's call per task; see `notes-discipline.md` for what kinds of info belong inside the task block at all.
- Mermaid graphs always use `class="mermaid"` so the CDN library can find them. `data-graph` distinguishes graph kinds when more than one is present in a file.

## Mermaid embedding

One CDN script per document, in `<head>` or before `</body>`. Pinned major version `@11` via jsdelivr so the spec keeps rendering as Mermaid releases patches and the CDN GCs old pins.

```html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```

Graph content inside `<div class="mermaid" data-graph="...">`:

```html
<div class="mermaid" data-graph="task-deps">
graph LR
    subgraph "Phase A"
        T001[T-001 Title]
    end
    T001 --> T002
</div>
```

Mermaid grammar inside the div is the same as Mermaid in a markdown fence. The library parses textContent.

## Google Fonts embedding

`<link>` tags in `<head>`. Specific families chosen per spec. Names of generic AI defaults are forbidden.

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=<DisplayFamily>:wght@400;700&family=<BodyFamily>:wght@400;500;700&display=swap" rel="stylesheet">
```

Pick two families minimum: one display, one body. A third for monospace when the spec embeds significant code snippets is allowed.

## Prior-spec consultation

When generating, scan `specs/*/` for the most recently modified `architecture.html` or `tasks.html`. Read it. Match the typography, palette, and monograph style for visual coherence within this project.

**First spec on a project:** no prior to consult. Aesthetic floor is this discipline file's *Aesthetic posture* prose alone. The agent picks a direction and runs with it. Subsequent specs converge on whatever that first spec established.

**Cross-project divergence is correct.** Generations in different projects should look different. Frontend-design's "NEVER converge across generations" rule applies between projects, not within one.

## Surgical-edit discipline

`/al-implement` and `/al-steer` flip `data-status` via the Edit tool, anchored on the unique `data-task` + `data-status` pair.

**Status flip example** (`/al-implement` from `in-progress` to `done` on T-007):

```
old_string: <details data-task="T-007" data-status="in-progress">
new_string: <details data-task="T-007" data-status="done">
```

One Edit, one attribute change. The visible marker follows from whatever rendering `/al-design` / `/al-scope` wired up.

**Why anchor on the pair, not just `data-task`.** The pair makes the `old_string` unique within a file even when two tasks share status text in surrounding markup. It also catches a stale read: if you think the task is `in-progress` but the file says `ready`, the Edit fails fast rather than corrupting state.

**Other writes regenerate, not surgical-edit.** When `/al-refine` fills the Tests area, `/al-mutate` writes a verdict, or `/al-implement` records a NOTE-style chip alongside the task, the writing skill regenerates that portion of the task block whole. Anchoring writes to slots that change rarely or whose shape is the writing skill's call would re-introduce the prescription the floor was set up to drop.

**Forbidden:**

- Blind Edit calls with no prior Read. Read the relevant task block first; loading nothing and blind-editing is unsafe.
- Anchoring status flips on visible text ("the heading that says T-007"), CSS class names, or visual position ("the third `<details>` in the file"). These break the first time `/al-design` or `/al-scope` regenerates the aesthetic.
- Whole-file Read followed by whole-file Write for a status flip. The Edit tool exists; use it. Whole-file rewrites lose bytes you forgot.
- Editing through a `data-task` collision. Task IDs are monotonic and never reused; if two task blocks share an ID (impossible by contract), halt and surface the duplicate.

## What this file does NOT prescribe

- No fixed HTML structure. Headings, layout, marginalia placement, drop cap rendering, table styling, code-block treatment are all `/al-design` / `/al-scope` choices.
- No fixed class names. Class names are styling; they are not the contract. Maintaining skills never bind on class names.
- No fixed IDs beyond what data attributes already cover. If `/al-design` wants ARIA anchors or table-of-contents IDs, fine; they are not a contract.
- No fixed font family. The aesthetic posture forbids specific generic defaults; positive choice is open.
- No fixed palette. CSS variables are encouraged for theme consistency, but the palette itself is per-spec.

## Composition

- Read by `/al-design` and `/al-scope` before generating any HTML artifact.
- Read by `/al-implement` and `/al-steer` before flipping `data-status` on a task.
- See `notes-discipline.md` for what kinds of info live inside the task block versus elsewhere (commit message, ADR, `.out-of-scope/`). This file covers HTML mechanics; that file covers destination.
- See `voice-contract.md` for prose voice (em-dash ban, declarative cadence) throughout the artifact.
