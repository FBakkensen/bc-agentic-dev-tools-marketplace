# al-agentic-dev

Seven composable skills for AL/Business Central agentic development sharing a single living document, `tasks.md`:

| Skill | Role |
|---|---|
| `al-steer` | Coach/navigator — reads state, recommends next step, never edits code |
| `al-scope` | Feature → scoped task list (Goal + bare task entries, /grill-me mandatory) |
| `al-refine` | One task → Gherkin bullets (per task, not per feature) |
| `al-implement` | Pick a Gherkin-ready task, run TDD (red → green → refactor → mutate) |
| `al-refactor` | Improve shape while green; no new behaviour |
| `al-mutate` | Inject mutations to validate test rigor; mandatory for non-trivial work |
| `al-research` | Verify BC specifics from authoritative sources |

## Editing rules

- **Seven is the ceiling.** Do not propose an eighth skill without a strong, repeated case the existing seven cannot cover.
- **No enumerated reference checklists.** Adequacy disciplines belong in `/al-mutate`'s loop; refinement disciplines belong in `/al-refine` prose. Static checklists in references rot fast and fight the prose.
- Each SKILL.md states naming/vocabulary inline rather than relying on CLAUDE.md — keep that pattern (the skills run in projects without this CLAUDE.md present).
- Skills compose by name (`/al-build`, `/grill-me`, `/bc-standard-reference`, etc.). When changing a skill, scan the others for cross-references.
- `tasks.md` is the shared bus, located at `specs/<NNN-slug>/tasks.md` where `NNN-slug` matches the current git branch. Status markers: `[ ]` ready, `[~]` in progress, `[x]` done. Task IDs `T-NNN` are monotonic and never reused.

## Layout

```
skills/
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
├── al-refactor/SKILL.md
├── al-refine/SKILL.md
├── al-research/SKILL.md
├── al-scope/SKILL.md
└── al-steer/SKILL.md
```

No scripts. Skill bodies are the entire product.
