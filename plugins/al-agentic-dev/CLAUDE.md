# al-agentic-dev

Composable skills for AL/Business Central agentic development. Two persistent layers — repo-root memory (`CONTEXT.md`, `docs/adr/`, `.out-of-scope/`) that survives merges, and branch-scoped feature state (`specs/<NNN>-<slug>/architecture.md` + `tasks.md`) per in-flight feature.

| Skill | Role |
|---|---|
| `al-steer` | Coach/navigator — reads state, recommends next step, never edits code. Owns `.out-of-scope/`. |
| `al-grill-adr` | Domain-aware grilling — sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only (no design picks; those defer to `/al-design`). Standalone-callable. |
| `al-design` | Idea → feature architecture: module map, BC patterns, R→P→W boundary, brownfield touchpoints, test strategy, parallel design-twice. Creates branch + `architecture.md`. |
| `al-scope` | `architecture.md` → bare task list (Goal + `T-NNN` entries, ZOMBIES order). Reads, no grilling, no branch creation. |
| `al-refine` | One task → numbered Gherkin scenarios (per task, not per feature). |
| `al-implement` | Pick a Gherkin-ready task, run TDD (red → green → refactor → mutate). |
| `al-refactor` | Improve shape while green; no new behaviour. |
| `al-mutate` | Inject mutations to validate test rigor; mandatory for non-trivial work. |
| `al-research` | Verify BC specifics from authoritative sources. |

## Pipeline

```
/al-grill-adr   →  /al-design  →  /al-scope  →  /al-refine  →  /al-implement  →  /al-refactor  →  /al-mutate
(CONTEXT, ADRs)    (architecture.md,    (tasks.md)     (per-task    (TDD per task)    (improve     (test-rigor
                    branch)                            Gherkin)                       shape)        gate)

side-band: /al-research, /al-steer (replan venue + .out-of-scope)
```

## Editing rules

- **New skills need a stated purpose.** Adding a skill is fine when it earns its place. Before proposing one, check:
  - whether an existing skill can absorb the work,
  - whether the artifact fits as a `tasks.md` Notes line, an `/al-research` finding, or a side-band reference inside an existing skill, and
  - only then propose, with one explicit line stating the gap and why no existing skill fits.
- **No enumerated reference checklists.** Adequacy disciplines belong in `/al-mutate`'s loop; refinement disciplines belong in `/al-refine` prose. Static checklists in references rot fast and fight the prose. Reference docs are vocabulary and durable formats only — `LANGUAGE.md`, templates — never enumerations.
- Each SKILL.md states naming/vocabulary inline rather than relying on CLAUDE.md — keep that pattern (the skills run in projects without this CLAUDE.md present).
- Skills compose by name (`/al-build`, `/grill-me`, `/bc-standard-reference`, etc.). When changing a skill, scan the others for cross-references.
- `tasks.md` is the per-feature task bus, located at `specs/<NNN-slug>/tasks.md` where `NNN-slug` matches the current git branch. Status markers: `[ ]` ready, `[~]` in progress, `[x]` done, `[!]` blocked, replan needed. Task IDs `T-NNN` are monotonic and never reused.
- `architecture.md` lives alongside `tasks.md` in the spec folder. Written by `/al-design`, read by `/al-scope`/`/al-refine`/`/al-implement`/`/al-refactor`. Not edited in place — reshape via `/al-design` re-run.
- `CONTEXT.md`, `docs/adr/`, `.out-of-scope/` live at repo root. Durable across features. Owned by `/al-grill-adr`, `/al-design`, `/al-steer` respectively.
- **Lazy template materialisation.** Repo-root and spec-folder files are created only when first needed, copied from `${CLAUDE_SKILL_DIR}/references/*.template.md`. `/al-design` owns the canonical templates (`CONTEXT.template.md`, `adr.template.md`, `architecture.template.md`, plus the read-only `LANGUAGE.md`); `/al-steer` owns `out-of-scope.template.md`. Cross-skill paths within this plugin use `${CLAUDE_SKILL_DIR}/../<skill>/references/`.
- `/al-steer` is the canonical replan venue. Replan-check gates in `/al-refine`, `/al-implement`, `/al-refactor` halt or soft-flag on the seven named triggers (task too big, hidden pre-req, wrong order, sibling now wrong, new behavior emerges, architecture decomposition wrong, goal drift). Hard-halt sets `[!]` and stops; soft-flag appends a Notes line and continues.

## Layout

```
skills/
├── al-design/
│   ├── SKILL.md
│   └── references/
│       ├── CONTEXT.template.md
│       ├── adr.template.md
│       ├── architecture.template.md
│       ├── bc-patterns.md
│       └── LANGUAGE.md
├── al-grill-adr/SKILL.md
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
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

No build scripts. Skill bodies + reference templates are the entire product.
