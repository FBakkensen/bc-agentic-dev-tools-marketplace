# Claude Design prompt — AL/Business Central spec artifacts

> **Purpose**: bootstrap a "Linear-style" design system in `claude design` that the `al-agentic-dev` plugin's skills consume to generate three per-feature spec HTMLs (`event-model.html`, `architecture.html`, `tasks.html`) in target BC repos.
>
> **How to use**: paste the prompt block below into claude design. Upload the six Linear screenshots named in the *Aesthetic direction* section as assets. Run through the onboarding (system → review → publish), then issue this brief as the first project. Once exports land, the four HTMLs go into `plugins/al-agentic-dev/references/design-system/` and `references/html-spec-discipline.md` gets rewritten to match.

---

## Prompt (paste into claude design)

I am setting up a design system in claude design that my agentic-development tooling will consume to generate three kinds of spec documents for AL/Business Central engineering work. Read the brief carefully. There are non-negotiable technical contracts the design system must honor, and a specific component inventory it must produce.

### Aesthetic direction

Linear-style. Restraint, density that breathes, an 8px grid, hairline borders, a dark surface palette as the primary identity with a clean light counterpart for print and embedded contexts. See the attached screenshots from `linear.app` for typography weight, palette restraint, spacing rhythm, and component density:

1. Linear inbox / issues list (status badge density, list compactness)
2. Linear issue detail (long-form treatment, metadata sidebar)
3. Linear cycles / project view (progress bars, dense tables)
4. Linear settings page (form treatment, secondary surfaces)
5. Linear marketing homepage at `linear.app` (display typography, hero aesthetic)
6. Linear roadmap / timeline view (lane treatment, for swimlane reference)

Pick one display + body family pair from Google Fonts and a monospace family for code. The pair should carry Linear's restraint: a clean geometric or grotesque sans, paired thoughtfully. Avoid generic AI defaults that read as "I had no opinion" (Arial, Roboto, system-ui). A deliberate choice from the same neighborhood as Linear's own family (Inter or a sibling) is welcomed if you make it; that is why typography is your call.

The system runs in two modes via `prefers-color-scheme: dark`. Dark is the identity. Light is the courtesy. Both palettes must be defined as CSS variables and swap with a single media query block.

### Immovable technical contracts

The agent that maintains these documents performs surgical edits. The design system must honor these contracts or it is unusable.

1. **Self-contained HTML.** Each artifact is a single `.html` file. Inline `<style>`. Google Fonts via `<link rel="stylesheet">` in `<head>`. Mermaid via CDN `<script>` pinned `@11` from jsdelivr. No external CSS files, no JS bundles, no asset folders. The file opens in a browser and renders given an internet connection.

2. **Two-attribute floor on task blocks.** Each task in `tasks.html` is a `<details>` element with exactly two contract attributes:
   - `data-task="T-NNN"` — task ID, monotonic, never reused.
   - `data-status="ready|in-progress|done|blocked"` — exactly four states.

   The visible status marker (badge, color, icon, text fallback like `[ ]` / `[~]` / `[x]` / `[!]`) **renders from `data-status` via CSS pseudo-element or duplicated `<span>` whose text is generated via `content: attr(...)`**. The agent flips only the attribute. Never the visible marker.

3. **No duplicated status state.** `data-status` lives on the `<details>` and nowhere else. No second copy in a summary row, status bar, or anywhere else. A second copy would force two-place edits on every status flip; that is the explicit thing this contract prevents.

4. **`event-model.html` and `architecture.html` are reshape-only.** No surgical-edit contracts there. The agent regenerates them wholesale on every run, so optimise their layout for reading, not for stable edit anchors. Only `tasks.html` carries the two-attribute floor above.

5. **Mermaid containers.** Diagrams live in `<div class="mermaid" data-graph="...">` where `data-graph` identifies the graph kind (`module-deps`, `flow`, `task-deps`). The `mermaid` class is required so the CDN library finds them.

6. **Mermaid theming — mid-tone palette, single theme.** Produce one Mermaid `themeVariables` block (~15 named color slots: `primaryColor`, `primaryTextColor`, `primaryBorderColor`, `lineColor`, `secondaryColor`, `tertiaryColor`, etc.) tuned to read legibly on **both** the light and dark page surfaces. Do not produce a light theme and a dark theme separately and try to swap them on `prefers-color-scheme` change — Mermaid v11's `mermaid.initialize(...)` does not re-theme already-rendered SVGs, so a naive matchMedia listener will not update existing diagrams without a full SVG teardown and `mermaid.run()` re-render. A single mid-tone palette avoids that whole problem. Pick colors that hold contrast against both `--surface-0` light and `--surface-0` dark. Initialise once with `mermaid.initialize({theme:'base', themeVariables:{...}}); mermaid.run();`.

7. **No inline source citations.** No `(see: Codeunit80.al:120)` in artifact prose. Object and procedure names are the citation; readers grep.

### Component inventory

The design system must define and the gallery must show each of these. Generic UI defaults (buttons, links, form inputs, navigation menus) inherit from claude design's defaults — they may appear in the gallery for completeness but are not part of the spec-document contract.

**State and status**
- Status badge (pill or chip), 4 variants: `ready` / `in-progress` / `done` / `blocked`. Each variant has its own color treatment and an accessible text label. Rendered via CSS pseudo-element from `data-status` on the parent `<details>`, OR via a `<span class="status-badge">` whose content is generated via CSS `content: attr(data-status-label)`. Pick the cleanest rendering mechanism that lets the agent flip ONLY the attribute.
- Status marker text fallback for low-color contexts: `[ ]` (ready) / `[~]` (in-progress) / `[x]` (done) / `[!]` (blocked).

**Task block**
- Collapsible task card built on `<details>` / `<summary>`. Slots: title (in `<summary>`), status badge, body prose, dependencies/edges list, tests area (typically Gherkin scenarios), callout band.

**Scenario / test content**
- Gherkin scenario block: numbered, collapsible, with formatted `Given` / `When` / `Then` / `And` lines in the monospace family for step bodies and a heading treatment for the scenario name.
- Scenario list container that holds multiple scenarios inside a task block.

**Event-model atoms**
- Role swimlane: vertical lane with a prominent role label header, holds a sequence of event chain rows belonging to that role.
- Event chain row: a single timeline node carrying Role / Action / Business Event / View / Status as labeled fields.
- Chain timeline: horizontal or vertical sequence of event chain rows with visible connector treatment between them.

**Long-read prose atoms** (`architecture.html` especially)
- Display title with monograph treatment (large display weight, generous leading).
- Heading scale H1 through H4.
- Body paragraph optimised for long-form reading (generous line-height, comfortable measure ~65–75ch).
- Inline `<code>` (subtle background tint).
- Code block (multi-line, monospace, syntax-neutral; AL is the language but no syntax highlighting required).
- Blockquote / pull quote.
- Ordered and unordered lists.
- Table with hairline borders, generous row height, restrained header treatment.
- Marginalia / aside callout: a floated `<aside>` that sits in the margin on wide viewports, collapses inline on narrow.

**Callouts / alerts**
- Four variants, distinct color treatments: `note` (informational), `warning` (caution), `blocked` (replan trigger), `replan` (process meta). Each carries an icon or marker glyph and a body slot.

**Diagrams**
- Mermaid container wrapper that gives the diagram a surface matching the page palette, with the themed colors above.

**Goal block** (`tasks.html`)
- Prominent panel at the top of `tasks.html` carrying the feature's single-sentence goal. Distinct surface treatment, scannable from a screenshot.

**Navigation and meta**
- File title header with feature slug, date, ADR cross-references.
- Metadata strip (subtle, secondary surface, fixed-pitch values).
- Cross-reference link styling for ADR refs (`ADR-0007`), sibling specs, and external references.

### Tokens

Define and expose as CSS variables, both in `:root` (light) and inside `@media (prefers-color-scheme: dark)` (dark overrides):

- **Surface**: `--surface-0` (page background), `--surface-1` (panel), `--surface-2` (raised panel), `--surface-3` (hovered/active).
- **Text**: `--text-primary`, `--text-secondary`, `--text-muted`.
- **Border**: `--border-subtle`, `--border-strong`.
- **Accent**: `--accent`, `--accent-fg` (text on accent surface).
- **Status colors** (4): `--status-ready`, `--status-in-progress`, `--status-done`, `--status-blocked`. Each has a matching `--status-X-bg` for badge backgrounds.
- **Type**: `--font-display`, `--font-body`, `--font-mono`. Size scale via CSS variables or fluid `clamp()`.
- **Spacing**: 8px grid. Expose at least `--space-1` (4px) through `--space-8` (64px).
- **Radius**: `--radius-sm`, `--radius-md`, `--radius-lg`. Linear restraint: small radii, never pill-shaped panels.
- **Mermaid**: a JS object literal of theme variables (mid-tone, single palette per *Immovable technical contracts* #6).

### Three example pages

Export three populated example pages alongside the component gallery. The pages use the realistic Business Central feature content below. Do not paraphrase or generalise it. Render the content as-is using the design system. This is so the agent that consumes the design system can pattern-match real composition.

**Example feature**: *Sales Document Posting: Item Charge Allocation Validation*

**`event-model.example.html`** — user-facing journey, two roles, four event chains.

Roles: `Order Processor`, `Posting Engine`.

Timeline:

1. `Order Processor` → Action `Releases Sales Order` → Business Event `Sales Order Released` → View `Released Sales Order Card` → Status `Released`.
2. `Order Processor` → Action `Initiates Posting` → Business Event `Posting Started` → View `Posting Progress` → Status `Posting`.
3. `Posting Engine` → Action `Validates Item Charges` → Business Event `Item Charge Allocation Validated` → View `Posting Progress` → Status `Validating`.
4. `Posting Engine` → Action `Posts Sales Invoice` → Business Event `Sales Invoice Posted` → View `Posted Sales Invoice` → Status `Posted`.

Include a short prose preamble at the top describing the feature in two sentences.

**`architecture.example.html`** — feature architecture in long-read form.

Sections (with realistic prose, not Lorem ipsum):

- **Goal** — single paragraph: "Catch item charge allocation mismatches at posting time before the invoice posts, surface the cause inline on the document, and produce a deterministic audit trail tying each allocation back to its source line."
- **Module map** (table): three rows — `Charge Validation` (Read → Process), `Allocation Resolver` (Process), `Posting Subscribers` (Write, brownfield touchpoint in `Sales-Post` codeunit 80).
- **R → P → W boundary** (prose, ~3 paragraphs explaining where reads sit, where the validation processes, where writes happen).
- **Brownfield touchpoints** (table): `Sales-Post` codeunit 80, event subscribers `OnAfterCheckSalesDoc` and `OnBeforePostSalesDoc`.
- **BC patterns referenced** (list): `Event Subscriber`, `Validation Codeunit`, `Posting Routine Extension`.
- **Two Mermaid diagrams**:
  - `data-graph="module-deps"`: shows `Charge Validation` and `Allocation Resolver` both depending on `Posting Subscribers`, which depends on `Sales-Post (BaseApp)`.
  - `data-graph="flow"`: shows the four-step posting flow (Release → Initiate → Validate → Post) with a branch on validation failure looping back to `Released Sales Order`.
- **ADR cross-reference**: link to `ADR-0007 Allocation Mismatch Surfacing`.
- **One marginalia aside** in the R → P → W section noting "Posting Subscribers is the only module that writes; everything else reads or processes. This is the boundary that protects the BaseApp posting routine."

**`tasks.example.html`** — feature task bus, five tasks, one Mermaid task-deps graph.

Goal block: same goal statement as architecture.

Tasks:

1. **T-001** — *Read released sales order item charge assignments*. Status: `done`. Body: one-sentence description. Tests slot: 2 Gherkin scenarios (`Reading assignments on a released order with one charge`, `Reading assignments on an order with no charges yields empty`).
2. **T-002** — *Validate that allocated quantities sum to charge quantity*. Status: `done`. Body: description. Tests slot: 3 Gherkin scenarios (sum equals, sum less than, sum greater than). Note callout: "Replan trigger fired during refine. Original test only covered equality, refined to cover both inequality directions."
3. **T-003** — *Subscribe to OnAfterCheckSalesDoc and route through validator*. Status: `in-progress`. Body: description. Tests slot: 2 Gherkin scenarios. Dependencies: T-001, T-002.
4. **T-004** — *Surface validation failure inline on Sales Order Card with allocation breakdown*. Status: `ready`. Body: description. Tests slot: 3 Gherkin scenarios. Dependencies: T-003.
5. **T-005** — *Persist allocation audit entries via Allocation Ledger Entry table*. Status: `blocked`. Body: description. Blocked callout: "Awaiting decision on whether to extend existing Allocation Account Entry table or introduce new Item Charge Allocation Ledger Entry table. See `.out-of-scope/allocation-ledger-shape.md`." Dependencies: T-002.

Mermaid `data-graph="task-deps"`: shows T-001 and T-002 as roots, T-003 depending on both, T-004 depending on T-003, T-005 depending on T-002.

Include each Gherkin scenario as `Given` / `When` / `Then` with one or two `And` continuations where realistic. Use BC vocabulary throughout: `Sales Header`, `Sales Line`, `Item Charge Assignment (Sales)`, `Posting Date`, `No.`, `Insert`, `Modify`, `Post`, `Validate`.

### Deliverables I need from you

1. **A published design system** in this organization with all components, tokens, and the Mermaid theme block defined.

2. **`gallery.html`** — single self-contained HTML file showing every component above, every variant. **Each component is shown twice: once rendered, once as a syntax-highlighted HTML source block immediately adjacent (right column on wide viewports, below on narrow). The agent reads the source block to learn class names and data attributes; the rendered view is for human eyes.** Include both light and dark mode demonstrations side by side or via a toggle that demonstrates the `prefers-color-scheme` swap.

3. **`event-model.example.html`** — populated with the BC content above.

4. **`architecture.example.html`** — populated with the BC content above.

5. **`tasks.example.html`** — populated with the BC content above.

All four files must be **self-contained**: inline `<style>`, Google Fonts via `<link>`, Mermaid via CDN `@11` `<script>`. No external CSS files, no JS bundles, no asset folders. Each file opens in a browser and renders.

When you generate, return the four files along with a short note (5–10 sentences) explaining the family pair you chose and why, the dominant color story (light and dark), the Mermaid mid-tone palette you settled on, and any tradeoffs you accepted to honor the immovable technical contracts above.

---

## After claude design returns

1. Drop the four HTMLs into `plugins/al-agentic-dev/references/design-system/`:
   - `gallery.html`
   - `event-model.example.html`
   - `architecture.example.html`
   - `tasks.example.html`

2. Rewrite `plugins/al-agentic-dev/references/html-spec-discipline.md`:
   - Replace *Aesthetic posture* section with a pointer to `references/design-system/gallery.html` as the source of truth + a token-name summary table (CSS variable names, Mermaid theme variable names).
   - Delete *Prior-spec consultation* section entirely (no more per-project aesthetic divergence).
   - Keep the *Two-attribute floor*, *Mermaid embedding*, *Surgical-edit discipline*, and *What this file does NOT prescribe* sections as immovable contracts. They survive.
   - Update *Google Fonts embedding* to point at the design system's chosen families rather than leaving it open.

3. Update `plugins/al-agentic-dev/CLAUDE.md`:
   - Editing rules section gains a line: "The design system at `references/design-system/` is the single source of truth for spec artifact visuals. Read `gallery.html` to learn component class names and data attributes before generating."
