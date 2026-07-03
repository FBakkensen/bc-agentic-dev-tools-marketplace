# release-notes

Generate release notes from per-PR analysis of merged work since the last release.

*Dev-time only — this file never ships. The shipped surface is `SKILL.md`, `scripts/`, and `references/`; see the root `CLAUDE.md` "Shipped artefacts vs dev-time files".*

## Layout

```
skills/release-notes/
├── SKILL.md
├── scripts/
│   └── Get-ReleaseAnalysis.ps1    # produces .output/releases/release-analysis.jsonl
└── references/
    ├── pr-classification.md       # per-PR classification + Deep Dive Protocol
    ├── output-format.md           # final markdown template
    └── content-guidelines.md      # tone, phrasing, Good/Bad entries
```

## Editing rules

- **JSONL contract is load-bearing.** `Get-ReleaseAnalysis.ps1` emits one `type == "summary"` record and one `type == "pr"` record per PR. SKILL.md's load steps depend on these names. Do not change the script's output schema without updating SKILL.md and `pr-classification.md` in lockstep.
- **Per-PR todo descriptions are the buffer.** The skill writes each PR's single-line JSON result into that PR's todo description so main context never holds the diff. This is *the* reason this skill works on releases with many PRs — preserve it when refactoring. The named anti-pattern is `**Anti-pattern: collapse all PR context into the main agent.**`
- **Output path is fixed.** `.output/releases/RELEASE-NOTES-<VERSION>.md`. Downstream tooling reads this exact path.
- **Reference-doc split.** `pr-classification.md` (per-PR protocol), `output-format.md` (markdown template), `content-guidelines.md` (tone). Each owns one concern — do not merge them.
- **Six classifications.** `feature`, `improvement`, `bugfix`, `breaking`, `technical`, `exclude`. Adding a seventh changes the output template and the classification table.
