# al-agentic-dev

Eight composable skills for AL/Business Central agentic development sharing a single living document, `tasks.md`:

| Skill | Role |
|---|---|
| `al-steer` | Coach/navigator — reads state, recommends next step, never edits code |
| `al-scope` | Feature → scoped task list (Goal + bare task entries, /grill-me mandatory) |
| `al-refine` | One task → numbered Gherkin scenarios (per task, not per feature) |
| `al-architect` | Task → testable shape; modules, interfaces, R→P→W boundary, brownfield touchpoints, test-layer per scenario |
| `al-implement` | Pick a Gherkin-ready task, run TDD (red → green → refactor → mutate) |
| `al-refactor` | Improve shape while green; no new behaviour |
| `al-mutate` | Inject mutations to validate test rigor; mandatory for non-trivial work |
| `al-research` | Verify BC specifics from authoritative sources |

## Editing rules

- **Eight is the ceiling.** Do not propose a ninth skill without a strong, repeated case the existing eight cannot cover.
- **No enumerated reference checklists.** Adequacy disciplines belong in `/al-mutate`'s loop; refinement disciplines belong in `/al-refine` prose. Static checklists in references rot fast and fight the prose.
- Each SKILL.md states naming/vocabulary inline rather than relying on CLAUDE.md — keep that pattern (the skills run in projects without this CLAUDE.md present).
- Skills compose by name (`/al-build`, `/grill-me`, `/bc-standard-reference`, etc.). When changing a skill, scan the others for cross-references.
- `tasks.md` is the shared bus, located at `specs/<NNN-slug>/tasks.md` where `NNN-slug` matches the current git branch. Status markers: `[ ]` ready, `[~]` in progress, `[x]` done, `[!]` blocked, replan needed. Task IDs `T-NNN` are monotonic and never reused.
- `/al-steer` is the canonical replan venue. Replan-check gates in `/al-refine`, `/al-architect`, `/al-implement`, `/al-refactor` halt or soft-flag on the seven named triggers (task too big, hidden pre-req, wrong order, sibling now wrong, new behavior emerges, architecture decomposition wrong, goal drift). Hard-halt sets `[!]` and stops; soft-flag appends a Notes line and continues.

## Layout

```
skills/
├── al-architect/SKILL.md
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
├── al-refactor/SKILL.md
├── al-refine/SKILL.md
├── al-research/SKILL.md
├── al-scope/SKILL.md
└── al-steer/SKILL.md
```

No scripts. Skill bodies are the entire product.
