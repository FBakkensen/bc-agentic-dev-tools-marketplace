# HTML spec discipline

`event-model.html`, `architecture.html`, and `tasks.html` are the reading surface. Not an intermediate, not a build artifact. This file is what `/al-design`, `/al-event-model`, and `/al-scope` consult before generating, and what every maintaining skill (`/al-refine`, `/al-implement`, `/al-mutate`, `/al-steer`) consults before editing.

ADRs (`docs/adr/*.md`) and `CONTEXT.md` stay markdown. Only the per-feature artifacts under `specs/<NNN>-<slug>/` are HTML.

<claude-only>
Runtime gate. Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it skip the block contents and move on.
</claude-only>

## Source of truth: the design system

The single source of truth for spec artifact visuals is [`design-system/`](./design-system/). The agent reads it; the agent never invents new components, palettes, or typography per feature.

| File | What it is |
|---|---|
| [`design-system/gallery.html`](./design-system/gallery.html) | Component gallery. Every component, rendered + canonical HTML source, light/dark toggle. **The authoritative class names and data attributes live here.** |
| [`design-system/event-model.example.html`](./design-system/event-model.example.html) | Populated example. Pattern-match composition before writing a feature's `event-model.html`. |
| [`design-system/architecture.example.html`](./design-system/architecture.example.html) | Populated example, long-form. Two Mermaid diagrams. |
| [`design-system/tasks.example.html`](./design-system/tasks.example.html) | Populated example. Technical and verify tasks across two slices, one task-deps Mermaid graph. Honors the surgical-edit floor (`data-task`, `data-status`, `data-slice`, `data-kind`). |
| [`design-system/spec-styles.css`](./design-system/spec-styles.css) | The shared inline-style block. Inline an equivalent block into each generated artifact's `<style>` tag. |
| [`design-system/colors_and_type.css`](./design-system/colors_and_type.css) | Readable CSS variable reference. The HTMLs inline equivalent tokens. |
| [`design-system/README.md`](./design-system/README.md) | Content fundamentals, visual foundations, iconography, Mermaid theme, voice. |

**Before generating**, the writing skill opens [`gallery.html`](./design-system/gallery.html) (and the matching `*.example.html` for layout). Read the source block beside each rendered component; that is the contract.

**Cross-links between sibling artifacts** drop the `.example` suffix: generated artifacts link to `event-model.html` / `architecture.html` / `tasks.html` inside the same `specs/<NNN>-<slug>/` folder. The `.example.html` suffix is demo-only.

## Tokens

CSS variables exposed in `:root` (light) and overridden in `@media (prefers-color-scheme: dark)`. Full values in [`design-system/colors_and_type.css`](./design-system/colors_and_type.css).

| Group | Variables |
|---|---|
| Surface ramp | `--surface-0` `--surface-1` `--surface-2` `--surface-3` |
| Text | `--text-primary` `--text-secondary` `--text-muted` |
| Borders | `--border-subtle` `--border-strong` |
| Accent | `--accent` `--accent-hover` `--accent-fg` `--accent-tint` |
| Status (4 × fg / bg / border) | `--status-{ready,in-progress,done,blocked}` + `-bg` + `-border` |
| Callouts (4 × fg / bg) | `--callout-{note,warning,blocked,replan}` + `-bg` |
| Type families | `--font-display` `--font-body` `--font-mono` |
| Type scale | `--fs-display` `--fs-h1` `--fs-h2` `--fs-h3` `--fs-h4` `--fs-body` `--fs-small` `--fs-micro` |
| Line height | `--lh-tight` `--lh-snug` `--lh-body` |
| Spacing (8px grid + 4px half-step) | `--space-1` (4px) through `--space-8` (64px) |
| Radius | `--radius-sm` (4px) `--radius-md` (6px) `--radius-lg` (10px) |
| Reading measure | `--measure: 68ch` |
| Motion | `--ease-out` `--dur-fast` (120ms) `--dur-base` (180ms) |

## Typography

Three families, all from Google Fonts via CDN `<link>`:

- **Inter Tight** for display (`--font-display`). Weights 500/600/700.
- **Inter** for body (`--font-body`). Weights 400/500/600/700.
- **JetBrains Mono** for code (`--font-mono`). Weights 400/500.

Inline the canonical `<link>` block (see [`spec-styles.css`](./design-system/spec-styles.css) header comment, or any `*.example.html` `<head>`) into each generated artifact. Display titles use `letter-spacing: -0.025em`; H1–H3 use `-0.015em`; mono micro labels use `+0.05em` and `text-transform: uppercase`. No other type variations.

## The surgical-edit floor

`tasks.html` carries one surgical-edit contract. Maintaining skills find a task by its ID and flip its status. Everything else regenerates whole when it changes.

Four attribute hooks on each per-task `<details>`:

| Hook | Locates | Used by | Written by |
|---|---|---|---|
| `data-task="T-NNN"` | the per-task block | every skill that touches a task | `/al-scope` |
| `data-status="ready \| in-progress \| done \| blocked"` | the status, single source of truth | `/al-implement`, `/al-user-verification`, `/al-steer` | `/al-scope` (`ready` for every technical task in the first slice, `blocked` for every other task); `/al-implement` flips technical tasks through `in-progress` → `done` and the slice's verify task `blocked` → `ready` when the last sibling lands; `/al-user-verification` flips the verify task `ready` → `in-progress` → `done` or `blocked` and on `done` flips next-slice technical tasks `blocked` → `ready`; `/al-steer` flips to `blocked` on replan triggers |
| `data-slice="<slug>"` | slice membership; matches one `event-model.html` timeline step (user-facing) or `architecture.html` slice (pure-backend) | `/al-implement` (detect last technical task in slice → flip verify ready), `/al-steer` (group by slice when reporting), `/al-code-review` (per-slice diff scope) | `/al-scope` |
| `data-kind="verify"` (omitted on technical tasks) | task kind; routes `/al-implement` vs `/al-user-verification` | `/al-implement` (stop on verify), `/al-refine` (branch by kind), `/al-user-verification` (precondition) | `/al-scope` |

Status flips happen often (every TDD cycle bump), so a stable attribute anchor avoids re-parsing prose to locate the right `<details>`. Two tasks with similar titles do not collide on the attribute. Every other slot (Tests area, callout kinds, edges block, Mermaid container) regenerates whole when its shape changes.

`data-slice` and `data-kind` are scope-time decisions; `/al-scope` writes them, downstream skills read them. A skill that needs to change `data-slice` (slice boundary moved) or `data-kind` (a task miscategorised as technical / verify) is doing replan work and routes through `/al-steer`, which re-runs `/al-scope` or reshapes the task block whole.

`event-model.html` and `architecture.html` carry **no** surgical-edit contract. `/al-design` and `/al-event-model` reshape them whole on re-run. The Mermaid containers (`<div class="mermaid" data-graph="...">`) are the library's hook, not an agent-anchor.

**Rules around the floor:**

- The visible status marker (badge text, color, dot) renders from `data-status` via CSS `::after` with `content: "● Ready"` etc. per state. Inline labels match the gallery: `Ready` / `In progress` / `Done` / `Blocked`. The agent flips only the attribute, never the visible marker.
- A separate verify-kind badge renders from `data-kind="verify"` via CSS, so a verify task carries two badges at a glance: its `data-kind` chip (*"Verify"*) and its `data-status` chip (*"Ready"* / *"Blocked"* / etc.). Technical tasks omit `data-kind`; CSS renders no kind chip for them.
- Status lives only on the `<details>`. A second copy in a Summary row (or anywhere else) would require two-place edits on every flip, which is exactly what the floor avoids.
- The text-fallback markers `[ ]` (ready) / `[~]` (in-progress) / `[x]` (done) / `[!]` (blocked) exist for low-color contexts (printed copies, grayscale screenshots). Visible labels stay primary; the markers are a courtesy fallback when CSS does not render.
- Where each kind of content lives inside the task block (Tests area, callout blocks, edges, scaffolding callouts) is the writing skill's call per task; see `notes-discipline.md` for what kinds of info belong inside the task block at all.
- Mermaid graphs always use `class="mermaid"` so the CDN library can find them. `data-graph` distinguishes graph kinds when more than one is present in a file (`module-deps`, `flow`, `task-deps`).

## Mermaid embedding

One CDN script per document with diagrams, before `</body>`. Pinned major version `@11` via jsdelivr so the spec keeps rendering as Mermaid releases patches.

**Canonical init block** (single mid-tone palette, initialized once, no theme swap on `prefers-color-scheme`):

```html
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>
  mermaid.initialize({
    startOnLoad: false,
    theme: 'base',
    themeVariables: {
      background:          'transparent',
      primaryColor:        '#2d2e33',
      primaryTextColor:    '#f4f4f5',
      primaryBorderColor:  '#8b8d98',
      secondaryColor:      '#5e6ad2',
      secondaryTextColor:  '#ffffff',
      secondaryBorderColor:'#8b8d98',
      tertiaryColor:       '#3c3d44',
      tertiaryTextColor:   '#f4f4f5',
      tertiaryBorderColor: '#8b8d98',
      lineColor:           '#8b8d98',
      textColor:           '#c8c8cd',
      mainBkg:             '#2d2e33',
      nodeBorder:          '#8b8d98',
      nodeTextColor:       '#f4f4f5',
      edgeLabelBackground: '#2d2e33',
      clusterBkg:          '#1f2024',
      clusterBorder:       '#8b8d98',
      titleColor:          '#c8c8cd',
      fontFamily:          '"Inter", system-ui, sans-serif',
      fontSize:            '14px'
    }
  });
  mermaid.run();
</script>
```

Mermaid v11's `mermaid.initialize(...)` configures *future* diagrams; it does not re-theme SVGs already rendered. A naive `matchMedia` listener that re-initialises on theme change leaves existing diagrams untouched until page reload. The mid-tone fills (`#2d2e33` nodes, `#8b8d98` lines) read on both `--surface-0` light (`#ffffff`) and `--surface-0` dark (`#08090a`) without re-rendering.

Graph content inside `<div class="mermaid" data-graph="...">`:

```html
<div class="mermaid" data-graph="task-deps">
graph LR
    T001[T-001 Title] --> T003
</div>
```

Mermaid grammar inside the div is the same as Mermaid in a markdown fence. The library parses textContent.

## Surgical-edit discipline

`/al-implement` and `/al-steer` flip `data-status` via the Edit tool, anchored on the unique `data-task` + `data-status` pair.

**Status flip example** (`/al-implement` from `in-progress` to `done` on T-007):

```
old_string: <details class="task" data-task="T-007" data-status="in-progress">
new_string: <details class="task" data-task="T-007" data-status="done">
```

One Edit, one attribute change. The visible badge re-renders from CSS.

The pair makes the `old_string` unique within a file even when two tasks share status text in surrounding markup. It also catches a stale read: if you think the task is `in-progress` but the file says `ready`, the Edit fails fast rather than corrupting state.

**Other writes regenerate, not surgical-edit.** When `/al-refine` fills the Tests area, `/al-mutate` writes a verdict, or `/al-implement` records a NOTE-style callout alongside the task, the writing skill regenerates that portion of the task block whole.

**Forbidden:**

- Blind Edit calls with no prior Read. Read the relevant task block first; loading nothing and blind-editing is unsafe.
- Anchoring status flips on visible text ("the heading that says T-007"), CSS class names alone (`.task[data-status="..."]` selectors are styling, not anchors), or visual position ("the third `<details>` in the file").
- Whole-file Read followed by whole-file Write for a status flip. The Edit tool exists; use it. Whole-file rewrites lose bytes you forgot.
- Editing through a `data-task` collision. Task IDs are monotonic and never reused; if two task blocks share an ID (impossible by contract), halt and surface the duplicate.
