# Output Format

Render the final markdown using the template below. Skip empty sections — never emit a header with no entries underneath. User-Facing Changes always precedes Technical Summary. No PR or issue links anywhere; release notes are self-contained.

Version comes from `summary.appJsonDiff.version.new` (fall back to `summary.toVersion`). BC compatibility comes from `summary.appJsonDiff.application`.

## Canonical template

```markdown
# Release Notes - Version <X.Y.Z>

**Release Date**: <YYYY-MM-DD>
**Business Central Compatibility**: <BC version range from summary.appJsonDiff.application>

## User-Facing Changes

### 🚀 New Features

- **<Feature name based on `area`>**
  - <`desc` — what the user can now do>
  - <`details` — how to reach it: page, action, field>
  - <Why it matters — business value>

### ✨ Improvements

- **<`area`>**: <`desc` — user benefit, not implementation>

### 🐛 Bug Fixes

- **<`area`>**: <What was wrong, how it affected users, now resolved>

### ⚠️ Breaking Changes & Migration Notes

- **<`change`>**: <`migration` — exact, imperative, ordered steps>

---

## Technical Summary

### Architecture Changes

- <`technical` items with category `refactor` that affect architecture — one line each>

### API Changes

- <New, modified, or deprecated procedures, events, or interfaces — one line each>

### Database Changes

- <Table additions, field additions, obsolete markers — one line each>

### Performance Optimizations

- <`technical` items with category `perf` — one line each>

### Dependency Updates

- <Version bumps, runtime updates, drawn from `summary.appJsonDiff` — one line each>
```

## Slot mapping

| Section | Source | Type filter |
|---|---|---|
| New Features | PR records | `type == "feature"` |
| Improvements | PR records | `type == "improvement"` |
| Bug Fixes | PR records | `type == "bugfix"` |
| Breaking Changes | PR records | `type == "breaking"` |
| Architecture Changes | PR records + judgement | `type == "technical"` AND `category == "refactor"` AND architecture-affecting |
| API Changes | PR records + judgement | Public surface change (procedure/event/interface) |
| Database Changes | PR records + judgement | Table or field change |
| Performance Optimizations | PR records | `type == "technical"` AND `category == "perf"` |
| Dependency Updates | `summary.appJsonDiff` | Runtime, platform, or dependency version delta |

## Section rules

- **Skip empty sections.** Drop the header entirely when no entry would land beneath it.
- **User-Facing first.** Always above Technical Summary.
- **No links.** No PR numbers, no issue numbers, no URLs. Names are the citation.
- **Version from summary.** Pull from `summary.appJsonDiff.version.new` first, `summary.toVersion` as fallback. Do not infer from elsewhere.
- **Emoji on section headers only.** Keep `🚀`, `✨`, `🐛`, `⚠️` exactly as shown — they are part of the markdown contract. Do not add emoji elsewhere in the body.
- **Migration steps are imperative.** `Replace X with Y. Re-run upgrade codeunit. Recompile dependent extensions.` — not `It is recommended to consider replacing X.`
