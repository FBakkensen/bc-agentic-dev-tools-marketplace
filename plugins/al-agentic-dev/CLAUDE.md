# al-agentic-dev

Composable skills for AL/Business Central agentic development.

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**, markdown: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-design` (design ADRs), `/al-steer` (out-of-scope).
- **Branch-scoped, per in-flight feature**, HTML: `specs/<NNN>-<slug>/architecture.html` + `tasks.html`. Self-contained, Mermaid + Google Fonts via CDN. Slug matches the current git branch.

`tasks.html` is the per-feature task bus. Status lives on a `data-status` attribute on the task `<details>`: `ready`, `in-progress`, `done`, `blocked`. `T-NNN` IDs are monotonic and never reused.

**Legacy markdown specs** (`specs/*/architecture.md` + `tasks.md` from before 0.14.0) are frozen historical artifacts. The new skills refuse to operate on them; users hand-migrate if they need to reshape one.

## Pipeline

```
/al-grill-adr  →  /al-design  →  /al-scope   →  /al-refine    →  /al-implement  →  /al-refactor  →  /al-mutate
(CONTEXT, ADRs)   (architecture (tasks.html)    (per-task         (TDD per task)    (improve        (test-rigor
                   .html,                       Gherkin)                            shape)          gate)
                   branch)

side-band: /al-research, /al-steer (replan venue + .out-of-scope)
```

## Skills

| Skill | Role |
|---|---|
| `/al-steer` | Coach/navigator. Reads state, names next step, never edits code. Owns `.out-of-scope/`. |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only. |
| `/al-design` | Idea → feature architecture. Module map, BC patterns, R→P→W boundary, brownfield touchpoints, test strategy, parallel design-twice. Creates branch + `architecture.html`. |
| `/al-scope` | `architecture.html` → bare task list in `tasks.html`. Goal + `T-NNN` entries in ZOMBIES order. No grilling, no branch creation. |
| `/al-refine` | One task → numbered Gherkin scenarios. Per task, not per feature. |
| `/al-implement` | Pick a Gherkin-ready task, run TDD: red → green → refactor → mutate. |
| `/al-refactor` | Improve shape while green. No new behaviour. |
| `/al-mutate` | Inject mutations to validate test rigor. Mandatory for non-trivial work. Owns the mutate-build-revert cycle. |
| `/al-research` | Verify BC specifics from authoritative sources. |
| `/al-second-opinion` | Cross-runtime read-only advisory gate for non-trivial scenarios, mutation lists, and refactor checklists. From Claude Code: `codex exec`. From Codex: `claude -p`. |

Skills compose by name. When you change a skill, scan the others for cross-references and update in lockstep.

## Replan

`/al-steer` is the canonical replan venue. The seven triggers: task too big, hidden pre-req, wrong order, sibling now wrong, new behaviour emerges, architecture decomposition wrong, goal drift. Replan-check gates in `/al-refine`, `/al-implement`, `/al-refactor` either hard-halt (set `data-status="blocked"`, stop) or soft-flag (add an `<aside data-alert="important">` callout containing `**Replan flag**: trigger #N` inside the task block, continue).

## Editing rules

- **Each SKILL.md states naming and BC vocabulary inline.** Skills run in projects without this CLAUDE.md present. Do not lean on it.
- **No inline citations in durable artifacts.** `(see: file.al:120)` is forbidden in `architecture.html`, `tasks.html`, `CONTEXT.md`, ADRs, `.out-of-scope/`. Names are the citation; `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address. Future readers grep; the IDE gives line numbers for free.
- **Diagrams are gates, not defaults.** Mermaid is permitted in `architecture.html` (`<div class="mermaid" data-graph="module-deps">` and / or `data-graph="flow">`, at most one structural and one behavioural) and in `tasks.html` (`<div class="mermaid" data-graph="task-deps">`, one task-dependency graph derived from declared edges). Each diagram is gated per the rules in the owning skill's SKILL.md. ADRs and every other markdown artifact stay text-only.
- **HTML files are self-contained.** Inline `<style>`, Google Fonts via CDN `<link>`, Mermaid via CDN `<script>` pinned `@11`. No external CSS files, no JS bundles. Offline = broken docs is the accepted trade.
- **`architecture.html` is reshape-only.** Written by `/al-design`, read by everyone downstream. Never edit in place; re-run `/al-design`.
- **`tasks.html` is surgically edited.** Maintaining skills locate slots via the data-attribute contract (`data-task`, `data-status`, `data-alert`, `data-section`, `data-summary-row`) and edit via the Edit tool anchored on those attributes. Never anchor on visible text, CSS class, or position. See `references/html-spec-discipline.md`.
- **No HTML for ADRs or `CONTEXT.md`.** Markdown. The HTML shift covers only `specs/<NNN>-<slug>/`.
- **New skills need a stated gap.** _Avoid_: spinning up a skill that an existing one can absorb, or that fits as a Notes line, an `/al-research` finding, or a side-band reference. Propose only when no existing skill fits, and say so in one line.

## Reference layout

Two tiers, on purpose.

- **Plugin-level shared**, `plugins/al-agentic-dev/references/`. Cross-skill resources read by more than one skill. Path from any SKILL.md: `${CLAUDE_SKILL_DIR}/../../references/<file>`.
- **Skill-local**, `plugins/al-agentic-dev/skills/<skill>/references/`. Resources only one skill reads. Path from that SKILL.md: `${CLAUDE_SKILL_DIR}/references/<file>`.

**Rule**: a resource read by two or more skills lives in plugin-level `references/`. Skill-local references stay inside the skill that owns them. DO NOT put a shared resource inside one skill's folder; owner ambiguity invites drift.

| File | Tier | Notes |
|---|---|---|
| `LANGUAGE.md` | plugin-level | architectural vocabulary; read by `/al-design`, `/al-grill-adr`, `/al-refactor` |
| `CONTEXT.template.md` | plugin-level | template materialised into the target repo's `CONTEXT.md` |
| `adr.template.md` | plugin-level | template materialised into the target repo's `docs/adr/NNNN-<slug>.md` |
| `voice-contract.md` | plugin-level | voice rules for prose; read by every skill that writes a durable artifact |
| `notes-discipline.md` | plugin-level | destination map for chips, alerts, Notes lines; Summary regeneration rule; read by every skill that writes `tasks.html` Notes or `.out-of-scope/` |
| `html-spec-discipline.md` | plugin-level | aesthetic posture, data-attribute contract, Mermaid embedding, self-contained constraint, prior-spec consultation, surgical-edit discipline; read by `/al-design`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-mutate`, `/al-steer` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue cited by `architecture.html`, design ADRs, and `/al-design` |
| `out-of-scope.template.md` | `/al-steer`-local | template materialised into `.out-of-scope/<concept>.md` |
| `legacy-refactor-plan.md` | `/al-refactor`-local | reference plan for legacy code without tests |

Templates are materialised lazily on first need by the owning flow. `html-spec-discipline.md` is read but never materialised; it is a discipline reference, not a template.

Cross-skill paths within this plugin (when reaching into another skill's local references): `${CLAUDE_SKILL_DIR}/../<skill>/references/<file>`. Reach for plugin-level first; cross-skill paths are a smell to be migrated.

## Skill-only runtime

**Rule**: Ship runtime behavior as skills only. DO NOT add Claude-only plugin agents or Codex-invisible runtime prompts. Put reusable runtime rules in `SKILL.md` or in a `references/*.md` file a skill explicitly reads.

The two former agent-shaped workflows now live as skills:

- **`skills/al-mutate/SKILL.md`**, preflight, canonical `**Mutations plan**` block, mutation classes, survivor classification, BC safety, output.
- **`skills/al-second-opinion/SKILL.md`** is the contract; **`skills/al-second-opinion/scripts/Invoke-AlSecondOpinion.ps1`** is the execution. Dispatched by runtime. `$env:CLAUDECODE -eq '1'` → `codex exec --sandbox read-only --skip-git-repo-check --color never --json -c model_reasoning_effort=medium`. Else → `claude -p --output-format json --no-session-persistence --disable-slash-commands --strict-mcp-config '{}'`. 600s timeout via `Start-Job` / `Wait-Job`. Skip lines name the target CLI. SKILL.md documents the sandbox flags so the security envelope stays visible without reading the script. **Windows-only**; `Start-Job` / `Wait-Job` targets pwsh on Windows; portability is a future concern.

## Layout

```
references/                 # Plugin-level shared, read by ≥2 skills, or cited by shared templates
├── CONTEXT.template.md
├── adr.template.md
├── LANGUAGE.md
├── bc-patterns.md
├── voice-contract.md       # Voice rules for prose
├── notes-discipline.md     # Destination map for chips, alerts, Notes lines; Summary regeneration
└── html-spec-discipline.md # Aesthetic posture, data-attribute contract, Mermaid, self-contained, prior-spec consultation
skills/
├── al-design/SKILL.md
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
