# AL Agentic Dev, Design System

A Linear-style design system that the `al-agentic-dev` plugin's skills consume to generate three per-feature spec artifacts in target Business Central repos:

- `event-model.html`: user-facing journey, roles + event chains.
- `architecture.html`: long-read module/boundary documentation.
- `tasks.html`: task bus with surgically-edited status states.

This system is the single source of truth for spec-document visuals. The agent reads `gallery.html` to learn component class names and data attributes before generating. It never invents new components or new aesthetics per-feature.

---

## Index

| File | What it is |
|---|---|
| `gallery.html` | Component gallery. Every component, rendered + canonical HTML source, light/dark toggle. **The source of truth.** |
| `event-model.example.html` | Populated example: Sales Document Posting / Item Charge Allocation Validation. |
| `architecture.example.html` | Populated example, long-form. Includes two Mermaid diagrams. |
| `tasks.example.html` | Populated example, 5 tasks + task-deps Mermaid graph. |
| `colors_and_type.css` | Canonical CSS variable reference. HTML artifacts inline an equivalent block; this file is the readable reference. |
| `spec-styles.css` | The shared inline-style block used by the three example HTMLs. Inline an equivalent block into each generated artifact's `<style>` tag. |

---

## Context

`al-agentic-dev` is a Claude Code / agent toolkit that maintains three HTML spec artifacts per Business Central feature. The artifacts are edited in place by an agent between sessions, so two parts of the design system are non-negotiable contracts:

1. **Self-contained HTML.** Each artifact is a single `.html` file. Inline `<style>`. Google Fonts via `<link>` in `<head>`. Mermaid via CDN `<script>` pinned `@11` from jsdelivr. No external CSS files, no JS bundles, no asset folders.
2. **Two-attribute floor on task blocks.** Each task in `tasks.html` is a `<details>` element with exactly two contract attributes (`data-task="T-NNN"` and `data-status="ready|in-progress|done|blocked"`), and the visible status marker renders from `data-status` via CSS. The agent flips only the attribute, never the visible marker. `data-status` lives on the `<details>` and nowhere else.
3. **Mermaid single-theme.** A single mid-tone palette is initialised once. Mermaid v11 does not re-theme already-rendered SVGs; a naive `prefers-color-scheme` listener would break diagrams. The palette is tuned to read on both `--surface-0` light and dark.

`event-model.html` and `architecture.html` carry no surgical-edit contracts; they regenerate wholesale every run, so their layouts optimise for reading, not for stable edit anchors.

There is no provided codebase or Figma project. This system was bootstrapped from the brief alone.

---

## Content fundamentals

The spec artifacts are written for engineers. The voice is direct, declarative, and short.

**Tone and casing.** Sentence case for everything except identifiers. Identifiers (`Sales Header`, `OnAfterCheckSalesDoc`, `Item Charge Assignment (Sales)`) keep their canonical casing: they are quotations from the codebase, not headlines. Headings end without periods; body sentences end with them.

**Person.** Third person and imperative. "The validator reads…", "Subscribe to `OnAfterCheckSalesDoc`…". Never "I", rarely "you"; "you" is reserved for instructions to the human reader, never as narrative voice.

**Identifier protocol.** Always quote object and procedure names exactly: `codeunit 80 "Sales-Post"`, `Item Charge Assignment (Sales)`, `OnBeforePostSalesDoc`. Always inline `<code>` for them. No prose paraphrases (write `Sales Header`, not "the sales header record").

**Names are the citation.** Never write `(see: Codeunit80.al:120)`. `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address; future readers grep, no inline annotations needed.

**Density.** Linear-style: dense that breathes. A single-fact paragraph is 2 to 4 sentences. Multi-fact content takes structured shape: one fact per landing line per `voice-contract.md` *Artifacts get scanned*. Bullet lists 3 to 6 items. Tables for module maps, brownfield touchpoints, any keyed inventory.

**No emoji.** No decorative iconography. The four callout glyphs (`i` / `!` / `×` / `↻`) are monospace ASCII so they survive every render path.

**Examples of voice (good):**

- "Reads sit on the released document. Processing builds an in-memory allocation graph. Writes go through the BaseApp posting routine; no direct table writes from feature code."
- "Subscribers on `OnBeforePostSalesDoc` can run inside a transaction. Do not call long-running validators here."

**Examples (bad):**

- "🚀 We're going to validate item charges!" (emoji, exclamation, first-person plural).
- "I think the validator should probably check the sums." (hedging, first-person).
- "See Codeunit80.al line 120 for details." (inline source citation; just say `Sales-Post` codeunit 80).

---

## Visual foundations

**Aesthetic.** Linear-style. Restraint, density that breathes, an 8px grid, hairline borders, a dark surface palette as the primary identity with a clean light counterpart for print and embedded contexts.

**Colors.** Both modes share names; only values shift via `prefers-color-scheme`. Dark is the identity: `--surface-0: #08090a` (near-black with a tiny cool tint). Light is `#ffffff`. The accent is `#5e6ad2` light / `#6e7aff` dark (a single indigo) used only for links, focused borders, the goal panel tint, and the Mermaid `secondaryColor`. Four status colors carry both fg and a low-saturation bg.

**Type.** Inter Tight for display (tighter alternate of Inter; carries Linear's restraint), Inter for body, JetBrains Mono for code. All weights ≤ 700. Display titles use `letter-spacing: -0.025em`; H1 through H3 use `-0.015em`; mono micro labels use `+0.05em` and `text-transform: uppercase`. No other type variations.

**Backgrounds.** Always solid surfaces. No gradients (the accent tint is a 8% to 14% rgba overlay, not a gradient). No background images. No textures.

**Borders.** Hairline. `--border-subtle: #ebebed` (light) / `#1f2024` (dark). `--border-strong` is the open/focused variant.

**Shadows.** None. Linear uses borders instead of shadows; this system follows. The theme-toggle pill carries a 1px shadow on its active pip and that is the only exception.

**Radii.** Small only: `4` / `6` / `10` px. Never pill-shaped panels. Inline code `4px`, panels `6px`, the goal block and gallery examples `10px`.

**Animation.** Subtle. 120ms hover transitions on links and the theme toggle, 180ms for the task chevron rotation. Easing is `cubic-bezier(0.16, 1, 0.3, 1)` (fast-out, slow-in). No bounces, no scale animations.

**Hover and press.** Link hover: shift to `--accent-hover` (slightly darker indigo). Task and scenario hover: no chrome change; the `<summary>` cursor is the affordance. Press states: none beyond the browser default.

**Transparency.** Used in three places only: the accent tint (8 to 14% indigo over surface), the sticky gallery header (`color-mix(in srgb, var(--surface-0) 92%, transparent)` + 8px backdrop blur), and callout background fills.

**Layout rules.** Long-read prose caps at `--measure: 68ch`. Marginalia floats into the right margin on viewports ≥ 1100px, collapses inline with a left rule below that. The gallery page is `max-width: 1240px`; the example pages are `max-width: 920px`.

**Imagery.** None. This system documents text artifacts. No icons beyond the four callout glyphs (`i`, `!`, `×`, `↻`).

---

## Iconography

The system is essentially icon-free. Every glyph that appears is one of:

- A monospace ASCII character serving a structural purpose (the callout glyphs `i` / `!` / `×` / `↻`; the status markers `[ ]` / `[~]` / `[x]` / `[!]`).
- A unicode ornament used sparingly: `●` inside status badges, `▸` on `<details>` chevrons, `→` in Mermaid edges.
- An SVG chevron drawn via CSS borders on `summary::before` (no `<svg>` element).

There is no icon font, no SVG sprite, no Lucide/Heroicons CDN. The spec artifacts must be inlinable into a single self-contained HTML file with no asset folder, so external icon dependencies are off the table. If a future component needs an icon, it should be a unicode glyph or a CSS-drawn shape.

**Emoji policy: none.** Emoji are forbidden in artifact prose, callout glyphs, and component decoration. They render unpredictably across BC versions, print badly, and clash with the Linear-style restraint.

---

## Mermaid theme

A single mid-tone palette. Initialised once. Do not swap on `prefers-color-scheme`.

The palette uses `#2d2e33` (mid-dark gray) for node fills and `#8b8d98` (mid gray) for borders and edges. Both colours hold contrast against `#ffffff` (light `--surface-0`) and `#08090a` (dark `--surface-0`). Text on nodes is `#f4f4f5` because the node fill is dark enough. See `gallery.html#diagrams` for the canonical init block.

---

## Caveats and substitutions

- No codebase or Figma was provided. This system was built from the brief alone. Any deviation between this system and an as-yet-undisclosed prior style should be reconciled by editing `gallery.html`; the agent reads from there.
- Fonts are loaded from Google Fonts via CDN. If the target BC repo serves spec artifacts offline, Inter / Inter Tight / JetBrains Mono should be self-hosted; the `<link>` tag is replaceable with `@font-face` declarations against locally-served `.woff2` files.
- The example feature (Sales Document Posting: Item Charge Allocation Validation) is realistic but synthetic. ADR-0007 references are intentionally dead links.

---

## How to use

1. The agent generating `event-model.html`, `architecture.html`, or `tasks.html` for a feature reads `gallery.html` to learn class names and data attributes.
2. The agent inlines the equivalent of `spec-styles.css` (or a subset matching the artifact) into the file's `<style>` tag.
3. For `tasks.html`, the agent enforces the two-attribute floor: `data-task` and `data-status` on `<details>`, never duplicated, visible status rendered by CSS.
4. For diagrams, the agent wraps each in `<div class="mermaid" data-graph="...">` and includes the canonical init script.

The three `*.example.html` files cross-link to siblings as `*.example.html` for demo purposes. Generated artifacts cross-link without the `.example` suffix: `<a href="event-model.html">` etc., resolving inside the feature's `specs/<NNN>-<slug>/` folder.
