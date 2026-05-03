# al-agentic-dev

Composable skills for AL/Business Central agentic development.

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features** — `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-design` (design ADRs), `/al-steer` (out-of-scope).
- **Branch-scoped, per in-flight feature** — `specs/<NNN>-<slug>/architecture.md` + `tasks.md`. The slug matches the current git branch.

`tasks.md` is the per-feature task bus. Status markers: `[ ]` ready, `[~]` in progress, `[x]` done, `[!]` blocked. `T-NNN` IDs are monotonic and never reused.

## Pipeline

```
/al-grill-adr  →  /al-design  →  /al-scope  →  /al-refine  →  /al-implement  →  /al-refactor  →  /al-mutate
(CONTEXT, ADRs)   (architecture,   (tasks.md)    (per-task        (TDD per task)    (improve      (test-rigor
                   branch)                       Gherkin)                          shape)        gate)

side-band: /al-research, /al-steer (replan venue + .out-of-scope)
```

## Skills

| Skill | Role |
|---|---|
| `/al-steer` | Coach/navigator. Reads state, names next step, never edits code. Owns `.out-of-scope/`. |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only. |
| `/al-design` | Idea → feature architecture. Module map, BC patterns, R→P→W boundary, brownfield touchpoints, test strategy, parallel design-twice. Creates branch + `architecture.md`. |
| `/al-scope` | `architecture.md` → bare task list. Goal + `T-NNN` entries in ZOMBIES order. No grilling, no branch creation. |
| `/al-refine` | One task → numbered Gherkin scenarios. Per task, not per feature. |
| `/al-implement` | Pick a Gherkin-ready task, run TDD: red → green → refactor → mutate. |
| `/al-refactor` | Improve shape while green. No new behaviour. |
| `/al-mutate` | Inject mutations to validate test rigor. Mandatory for non-trivial work. Dispatches the `al-agentic-dev:al-mutate` agent. |
| `/al-research` | Verify BC specifics from authoritative sources. |

Skills compose by name. When you change a skill, scan the others for cross-references and update in lockstep.

## Replan

`/al-steer` is the canonical replan venue. The seven triggers: task too big, hidden pre-req, wrong order, sibling now wrong, new behaviour emerges, architecture decomposition wrong, goal drift. Replan-check gates in `/al-refine`, `/al-implement`, `/al-refactor` either hard-halt (set `[!]`, stop) or soft-flag (append a Notes line, continue).

## Editing rules

- **Each SKILL.md states naming and BC vocabulary inline.** Skills run in projects without this CLAUDE.md present. Do not lean on it.
- **No inline citations in durable artifacts.** `(see: file.al:120)` is forbidden in `architecture.md`, `tasks.md`, `CONTEXT.md`, ADRs, `.out-of-scope/`. Names are the citation — `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address. Future readers grep; the IDE gives line numbers for free.
- **Diagrams are gates, not defaults.** `architecture.md` only — at most one structural `## Module diagram` and one behavioural `## Flow`, each gated by the trigger in `references/architecture.template.md`. Mermaid only. ADRs and every other durable artifact are text only.
- **`architecture.md` is reshape-only.** Written by `/al-design`, read by everyone downstream. Never edit in place — re-run `/al-design`.
- **New skills need a stated gap.** _Avoid_: spinning up a skill that an existing one can absorb, or that fits as a `tasks.md` Notes line, an `/al-research` finding, or a side-band reference. Propose only when no existing skill fits, and say so in one line.

## Reference layout

Two tiers, on purpose.

- **Plugin-level shared** — `plugins/al-agentic-dev/references/`. Cross-skill resources read by more than one skill. Path from any SKILL.md: `${CLAUDE_SKILL_DIR}/../../references/<file>`.
- **Skill-local** — `plugins/al-agentic-dev/skills/<skill>/references/`. Resources only one skill reads. Path from that SKILL.md: `${CLAUDE_SKILL_DIR}/references/<file>`.

**Rule**: a resource read by two or more skills lives in plugin-level `references/`. Skill-local references stay inside the skill that owns them. DO NOT put a shared resource inside one skill's folder — owner ambiguity invites drift.

| File | Tier | Notes |
|---|---|---|
| `LANGUAGE.md` | plugin-level | architectural vocabulary; read by `/al-design`, `/al-grill-adr`, `/al-refactor` |
| `CONTEXT.template.md` | plugin-level | template materialised into the target repo's `CONTEXT.md` |
| `adr.template.md` | plugin-level | template materialised into the target repo's `docs/adr/NNNN-<slug>.md` |
| `voice-contract.md` | plugin-level | voice rules for prose; read by every skill that writes a durable artifact |
| `notes-discipline.md` | plugin-level | Notes-line trigger test, valid shapes, escalation routing; read by every skill that writes `tasks.md` Notes or `.out-of-scope/` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue cited by `architecture.md`, design ADRs, and `/al-design` |
| `architecture.template.md` | `/al-design`-local | template materialised into `specs/<NNN>-<slug>/architecture.md` |
| `out-of-scope.template.md` | `/al-steer`-local | template materialised into `.out-of-scope/<concept>.md` |
| `legacy-refactor-plan.md` | `/al-refactor`-local | reference plan for legacy code without tests |

Templates are materialised lazily on first need by the owning flow.

Cross-skill paths within this plugin (when reaching into another skill's local references): `${CLAUDE_SKILL_DIR}/../<skill>/references/<file>`. Reach for plugin-level first; cross-skill paths are a smell to be migrated.

## Skill / agent split

Most skills stay skill-only — `/al-design`, `/al-refine`, `/al-grill-adr`, `/al-steer` need full reasoning. An agent earns the pattern only on three signals:

- tight tool needs (a small allowlist),
- output-heavy iteration (mutate-build-revert, advisory call-and-format),
- a focused operational system prompt that would otherwise dilute the parent skill.

Two agents currently qualify:

- **`agents/al-mutate.md`** — preflight, canonical `**Mutations**` block, mutation classes, survivor classification, BC safety, output. Tools: `PowerShell, Edit, Read, Glob`. Dispatched by `/al-implement` step 14.
- **`agents/al-second-opinion.md`** — read-only advisory call against copilot CLI. Tool allowlist (`view,rg,glob,show_file,lsp`), 600s timeout, failure formatting. Tools: `PowerShell` only. **Windows-only** — `Start-Job`/`Wait-Job` targets pwsh on Windows; portability is a future concern. Dispatched by `/al-implement`, `/al-refine`, `/al-refactor` at their Second-opinion gates.

## Layout

```
agents/
├── al-mutate.md            # Invoked by /al-implement step 14
└── al-second-opinion.md    # Advisory copilot CLI gate
references/                 # Plugin-level shared — read by ≥2 skills, or cited by shared templates
├── CONTEXT.template.md
├── adr.template.md
├── LANGUAGE.md
├── bc-patterns.md
├── voice-contract.md       # Voice rules for prose
└── notes-discipline.md     # Notes-line trigger test + valid shapes + escalation routing
skills/
├── al-design/
│   ├── SKILL.md
│   └── references/         # Skill-local — read only by /al-design
│       └── architecture.template.md
├── al-grill-adr/SKILL.md
├── al-implement/SKILL.md
├── al-mutate/SKILL.md      # Thin shim — dispatches agents/al-mutate.md
├── al-refactor/
│   ├── SKILL.md
│   └── references/
│       └── legacy-refactor-plan.md
├── al-refine/SKILL.md
├── al-research/SKILL.md
├── al-scope/SKILL.md
└── al-steer/
    ├── SKILL.md
    └── references/
        └── out-of-scope.template.md
```

No build scripts. Skill bodies, agent definitions, and reference templates are the entire product.
