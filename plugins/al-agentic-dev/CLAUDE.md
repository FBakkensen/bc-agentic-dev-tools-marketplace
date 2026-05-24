# al-agentic-dev

Composable skills for AL/Business Central agentic development.

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**, markdown: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-design` (design ADRs), `/al-steer` (out-of-scope).
- **Branch-scoped, per in-flight feature**, HTML: `specs/<NNN>-<slug>/event-model.html` (user-facing journey, present for user/API-facing features) + `architecture.html` + `tasks.html`. Self-contained, Mermaid + Google Fonts via CDN. Slug matches the current git branch.

`tasks.html` is the per-feature task bus. Status lives on a `data-status` attribute on the task `<details>`: `ready`, `in-progress`, `done`, `blocked`. `T-NNN` IDs are monotonic and never reused.

**Branch creation is shared between `/al-event-model` and `/al-design`.** The first per-feature skill to run from `main` creates the branch and `specs/<NNN>-<slug>/`. For user/API-facing features that runs `/al-event-model` first; pure-backend features skip `/al-event-model` and `/al-design` does it.

**Legacy markdown specs** (`specs/*/architecture.md` + `tasks.md` from before 0.14.0) are frozen historical artifacts. The new skills refuse to operate on them; users hand-migrate if they need to reshape one.

## Pipeline

```
/al-grill-adr  →  /al-event-model    →  /al-design     →  /al-scope    →  /al-refine    →  /al-implement   →  /al-refactor  →  /al-mutate
(CONTEXT,         (event-model.html,     (architecture     (tasks.html)    (per-task        (TDD per task)     (improve        (test-rigor
 ADRs)             user/API-facing        .html, AL-shape                   Gherkin)                            shape)          gate)
                   only — pure backend    only)
                   skips this step)

side-band: /al-research, /al-steer (replan venue + .out-of-scope)
```

## Skills

| Skill | Role |
|---|---|
| `/al-steer` | Coach/navigator. Reads state, names next step, never edits code. Owns `.out-of-scope/`. |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only. |
| `/al-event-model` | User-facing journey settlement. BC-vocabulary chains (Role / Action / Business Event / View / Status), one timeline per feature, Role swimlanes when more than one Role participates. Writes `event-model.html`. Optional, pure-backend features skip it. |
| `/al-design` | Event-model.html → feature architecture. Module map, BC patterns, R→P→W boundary, brownfield touchpoints, test strategy, parallel design-twice. Writes `architecture.html`; creates branch when `/al-event-model` did not. |
| `/al-scope` | `architecture.html` → bare task list in `tasks.html`. Goal + `T-NNN` entries in ZOMBIES order. No grilling, no branch creation. |
| `/al-refine` | One task → numbered Gherkin scenarios. Per task, not per feature. |
| `/al-implement` | Pick a Gherkin-ready task, run TDD: red → green → refactor → mutate. |
| `/al-refactor` | Improve shape while green. No new behaviour. |
| `/al-mutate` | Inject mutations to validate test rigor. Mandatory for non-trivial work. Owns the mutate-build-revert cycle. |
| `/al-research` | Verify BC specifics from authoritative sources. |
| `/al-second-opinion` | Cross-runtime read-only advisory gate for non-trivial scenarios, mutation lists, and refactor checklists. From Claude Code: `codex exec`. From Codex: `claude -p`. |

Skills compose by name. When you change a skill, scan the others for cross-references and update in lockstep.

## Replan

`/al-steer` is the canonical replan venue. The seven triggers as named patterns to learn: task too big, hidden pre-req, wrong order, sibling now wrong, new behaviour emerges, architecture decomposition wrong, goal drift. Replan checks in `/al-refine`, `/al-implement`, `/al-refactor` map the trigger to response per situation: when the trigger means the plan is invalid as planned, flip `data-status` to `blocked` and route to `/al-steer`; when the trigger means new info that doesn't invalidate, note it inside the task and continue.

## Editing rules

- **Each SKILL.md states naming and BC vocabulary inline.** Skills run in projects without this CLAUDE.md present. Do not lean on it.
- **No inline citations in durable artifacts.** `(see: file.al:120)` is forbidden in `architecture.html`, `tasks.html`, `CONTEXT.md`, ADRs, `.out-of-scope/`. Names are the citation; `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address. Future readers grep; the IDE gives line numbers for free.
- **Mermaid containers are for Mermaid to find graphs.** Permitted in `architecture.html` (`<div class="mermaid" data-graph="module-deps">` and / or `data-graph="flow">`) and in `tasks.html` (`<div class="mermaid" data-graph="task-deps">`). Whether a diagram earns its place per feature is the writing skill's call; this list just enumerates the container hooks Mermaid recognises. ADRs and every other markdown artifact stay text-only.
- **HTML files are self-contained.** Inline `<style>`, Google Fonts via CDN `<link>`, Mermaid via CDN `<script>` pinned `@11`. No external CSS files, no JS bundles. Offline = broken docs is the accepted trade.
- **The design system at `references/design-system/` is the single source of truth for spec artifact visuals.** Class names, palette, typography, spacing, and component shape are prescribed by [`design-system/gallery.html`](./references/design-system/) and the populated `*.example.html` files. Per-feature aesthetic divergence is gone; pick content shape per feature, never visual shape. See `references/html-spec-discipline.md`.
- **`architecture.html` is reshape-only.** Written by `/al-design`, read by everyone downstream. Never edit in place; re-run `/al-design`. No surgical-edit contract beyond the Mermaid container hooks.
- **`tasks.html` carries one surgical-edit contract.** Maintaining skills find a task by `<details class="task" data-task="T-NNN">` and flip its `data-status="ready | in-progress | done | blocked"`. The visible badge renders from `data-status` via CSS (`::after { content: "● Ready" }` etc.); the agent flips only the attribute. See `references/html-spec-discipline.md`.
- **No HTML for ADRs or `CONTEXT.md`.** Markdown. The HTML shift covers only `specs/<NNN>-<slug>/`.
- **New skills need a stated gap.** _Avoid_: spinning up a skill that an existing one can absorb, or that fits as a brief note inside an existing task block, an `/al-research` finding, or a side-band reference. Propose only when no existing skill fits, and say so in one line.
- **Express intent and rationale, not enumerated rules with skip conditions.** SKILLs and references state *why a discipline exists and what problem it solves*; the agent maps rationale to situation. Slot prescriptions, `_When earned:_` / `_Skip when:_` enumerations, and templates the agent must fill are rejected by name. The agent is capable of shaping output per feature.

## Reference layout

Two tiers, on purpose.

- **Plugin-level shared**, `plugins/al-agentic-dev/references/`. Cross-skill resources read by more than one skill. Path from any SKILL.md: `${CLAUDE_SKILL_DIR}/../../references/<file>`.
- **Skill-local**, `plugins/al-agentic-dev/skills/<skill>/references/`. Resources only one skill reads. Path from that SKILL.md: `${CLAUDE_SKILL_DIR}/references/<file>`.

**Rule**: a resource read by two or more skills lives in plugin-level `references/`. Skill-local references stay inside the skill that owns them. DO NOT put a shared resource inside one skill's folder; owner ambiguity invites drift.

| File | Tier | Notes |
|---|---|---|
| `LANGUAGE.md` | plugin-level | architectural vocabulary; read by `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-refactor` |
| `CONTEXT.template.md` | plugin-level | template materialised into the target repo's `CONTEXT.md` |
| `adr.template.md` | plugin-level | template materialised into the target repo's `docs/adr/NNNN-<slug>.md` |
| `voice-contract.md` | plugin-level | voice rules for prose; read by every skill that writes a durable artifact |
| `user-communication.md` | plugin-level | principles for chat output (names are the citation, lede first, terse, BC vocab, no em-dashes) and voice carve-outs from `voice-contract.md`; read by skills that emit interactive chat |
| `notes-discipline.md` | plugin-level | what kinds of info live in the task block vs elsewhere (commit message, ADR, `.out-of-scope/`), what survives past `done`, what dies with the branch; read by skills that write `tasks.html` |
| `html-spec-discipline.md` | plugin-level | pointer to `design-system/` (source of truth), token summary, the two-attribute floor (`data-task` + `data-status`), Mermaid init block, self-contained constraint, status-flip surgical-edit; read by `/al-design`, `/al-event-model`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-mutate`, `/al-steer` |
| `design-system/` (folder) | plugin-level | the source of truth for spec artifact visuals; `gallery.html` + three populated `*.example.html` + `spec-styles.css` + `colors_and_type.css` + `README.md`. Read by every skill that generates or maintains HTML artifacts |
| `cross-branch-numbering.md` | plugin-level | algorithm for picking `NNN` (spec folders) and `NNNN` (ADRs) across parallel branches; read by `/al-design`, `/al-event-model`, `/al-grill-adr` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue cited by `architecture.html`, design ADRs, and `/al-design` |
| `out-of-scope.template.md` | `/al-steer`-local | template materialised into `.out-of-scope/<concept>.md` |
| `legacy-refactor-plan.md` | `/al-refactor`-local | reference plan for legacy code without tests |

Templates are materialised lazily on first need by the owning flow. `html-spec-discipline.md` is read but never materialised; it is a discipline reference, not a template.

Cross-skill paths within this plugin (when reaching into another skill's local references): `${CLAUDE_SKILL_DIR}/../<skill>/references/<file>`. Reach for plugin-level first; cross-skill paths are a smell to be migrated.

## Skill-only runtime

**Rule**: Ship runtime behavior as skills only. DO NOT add Claude-only plugin agents or Codex-invisible runtime prompts. Put reusable runtime rules in `SKILL.md` or in a `references/*.md` file a skill explicitly reads.

The two former agent-shaped workflows now live as skills:

- **`skills/al-mutate/SKILL.md`**, mutate-build-revert cycle, mutation kinds, survivor classification, BC safety.
- **`skills/al-second-opinion/SKILL.md`** is the contract; **`skills/al-second-opinion/scripts/Invoke-AlSecondOpinion.ps1`** is the execution. Dispatched by runtime. `$env:CLAUDECODE -eq '1'` → `codex exec --sandbox read-only --skip-git-repo-check --color never --json -c model_reasoning_effort=medium`. Else → `claude -p --output-format json --no-session-persistence --disable-slash-commands --strict-mcp-config '{}'`. 600s timeout via `Start-Job` / `Wait-Job`. Skip lines name the target CLI. SKILL.md documents the sandbox flags so the security envelope stays visible without reading the script. **Windows-only**; `Start-Job` / `Wait-Job` targets pwsh on Windows; portability is a future concern.

## Layout

```
references/                 # Plugin-level shared, read by ≥2 skills, or cited by shared templates
├── CONTEXT.template.md
├── adr.template.md
├── LANGUAGE.md
├── bc-patterns.md
├── voice-contract.md       # Voice rules for prose
├── user-communication.md   # Chat output principles and voice carve-outs from voice-contract.md
├── notes-discipline.md     # What lives in the task block vs the commit / ADR / .out-of-scope/
├── html-spec-discipline.md # Pointer to design-system/, two-attribute floor, Mermaid init, self-contained, surgical-edit
└── design-system/          # Source of truth for spec artifact visuals
    ├── README.md           # Content fundamentals, visual foundations, iconography, voice
    ├── gallery.html        # Component gallery — rendered + canonical HTML source per component
    ├── event-model.example.html
    ├── architecture.example.html
    ├── tasks.example.html
    ├── spec-styles.css     # Shared inline <style> block (inline an equivalent into each artifact)
    └── colors_and_type.css # Readable CSS variable reference
skills/
├── al-design/SKILL.md
├── al-event-model/SKILL.md
├── al-grill-adr/SKILL.md
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
├── al-refactor/
│   ├── SKILL.md
│   └── references/
│       └── legacy-refactor-plan.md
├── al-refine/SKILL.md
├── al-research/SKILL.md
├── al-second-opinion/
│   ├── SKILL.md
│   └── scripts/
│       └── Invoke-AlSecondOpinion.ps1
├── al-scope/SKILL.md
└── al-steer/
    ├── SKILL.md
    └── references/
        └── out-of-scope.template.md
```

No build scripts. Skill bodies and reference templates are the entire product.
