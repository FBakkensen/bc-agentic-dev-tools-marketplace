# al-agentic-dev

Six composable skills for AL/Business Central agentic development sharing a single living document, `tasks.md`:

| Skill | Role |
|---|---|
| `al-steer` | Coach/navigator — reads state, recommends next step, never edits code |
| `al-refine` | Idea → tasks in `tasks.md` (Gherkin bullets, ZOMBIES order) |
| `al-implement` | Pick a ready task, run TDD (red → green → refactor → mutate) |
| `al-refactor` | Improve shape while green; no new behaviour |
| `al-mutate` | Inject mutations to validate test rigor; mandatory for non-trivial work |
| `al-research` | Verify BC specifics from authoritative sources |

## Editing rules

- **Six is a deliberate ceiling.** Do not propose a seventh skill without a strong, repeated case the existing six cannot cover.
- **No enumerated reference checklists.** Adequacy disciplines belong in `/al-mutate`'s loop; refinement disciplines belong in `/al-refine` prose. Static checklists in references rot fast and fight the prose.
- Each SKILL.md states naming/vocabulary inline rather than relying on CLAUDE.md — keep that pattern (the skills run in projects without this CLAUDE.md present).
- Skills compose by name (`/al-build`, `/grill-me`, `/bc-standard-reference`, etc.). When changing a skill, scan the others for cross-references.
- `tasks.md` is the shared bus. Status markers: `[ ]` ready, `[~]` in progress, `[x]` done. Task IDs `T-NNN` are monotonic and never reused.

## Layout

```
skills/
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
├── al-refactor/SKILL.md
├── al-refine/SKILL.md
├── al-research/SKILL.md
└── al-steer/SKILL.md
```

No scripts. Skill bodies are the entire product.
