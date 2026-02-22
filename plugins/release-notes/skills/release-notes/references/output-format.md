# Release Notes Output Format

Use this template when generating release notes.

```markdown
# Release Notes - Version [X.X.X]

**Release Date**: [Date]
**Business Central Compatibility**: [BC version range from summary.appJsonDiff.application]

## User-Facing Changes

### 🚀 New Features

For each PR with type "feature":

- **[Feature Name based on area]**
  - What it does (from desc)
  - How to use it (from details)
  - Why it matters (business value)

### ✨ Improvements

For each PR with type "improvement":

- **[Area]**: Description and user benefit

### 🐛 Bug Fixes

For each PR with type "bugfix":

- **[Area]**: What was wrong and how it affected users, now resolved

### ⚠️ Breaking Changes & Migration Notes

For each PR with type "breaking":

- **[Change]**: What changed and exact migration steps

---

## Technical Summary

### Architecture Changes

Items with category "refactor" that affect architecture

### API Changes

New/modified/deprecated procedures or events

### Database Changes

Table modifications, new fields

### Performance Optimizations

Items with category "perf"

### Dependency Updates

Version bumps, runtime updates (from summary.appJsonDiff)
```

## Section Rules

- **Skip empty sections** - Don't include headers with no content
- **User-Facing first** - Always prioritize user-facing changes at the top
- **No links** - Release notes should be self-contained, no PR/issue links
- **Version from summary** - Use `summary.appJsonDiff.version.new` or `summary.toVersion`
