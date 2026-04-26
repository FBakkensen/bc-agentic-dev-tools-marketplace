# release-notes

Generate release notes from analysis of merged PRs since the last release.

## Layout

```
skills/release-notes/
├── SKILL.md
├── scripts/
│   └── Get-ReleaseAnalysis.ps1   # produces .output/releases/release-analysis.jsonl
└── references/
    ├── pr-classification.md       # PR classification + Deep Dive protocol
    ├── output-format.md           # release notes template
    └── content-guidelines.md      # tone/style rules
```

## Editing rules

- The JSONL contract between `Get-ReleaseAnalysis.ps1` and SKILL.md is load-bearing: `type == "summary"` (one record) and `type == "pr"` (one per PR). Don't change the script's output schema without updating SKILL.md's loading steps.
- The context-management strategy (todo descriptions hold per-PR analysis so the main context stays small) is the reason this skill works on large releases — preserve it when refactoring.
- Output path is fixed: `.output/releases/RELEASE-NOTES-<VERSION>.md`. Downstream tooling may depend on this.
