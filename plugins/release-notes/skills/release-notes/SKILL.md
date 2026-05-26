---
name: release-notes
description: Generate release notes from per-PR analysis of merged work since the last release. Use after producing .output/releases/release-analysis.jsonl when drafting release notes, summarising changes between releases, or preparing version documentation for an AL/Business Central app.
---

**Style:** Drop articles, filler, hedging. Fragments OK. Arrows for causality. Technical terms exact, code unchanged, errors quoted exact. **Exception**: shift to prose where clarity or safety would be hurt.

# /release-notes — PR JSONL to release notes

Turn `.output/releases/release-analysis.jsonl` into `.output/releases/RELEASE-NOTES-<VERSION>.md`. One PR at a time, classified into single-line JSON record stored in todo description, then folded into final markdown. Main context holds summary record and final output — never the per-PR diffs.

Drop hedging. One fact per analysis line. BC vocabulary is the compression → name the page, codeunit, table, field, action.

Output markdown uses canonical section emoji defined in [references/output-format.md](references/output-format.md) — explicit exception to the no-emoji prose rule.

## Resolve inputs

- **Analysis file** `.output/releases/release-analysis.jsonl` must exist. Missing → `Stop.` Run `scripts\Get-ReleaseAnalysis.ps1` from skill folder.
- **Output path** `.output/releases/RELEASE-NOTES-<VERSION>.md`. Version comes from `summary.appJsonDiff.version.new` or `summary.toVersion`. Downstream tooling reads this exact path → do not relocate.

## Flow

### 1. Generate analysis (if not done)

```powershell
scripts\Get-ReleaseAnalysis.ps1
```

Produces one `type == "summary"` record (release boundaries, totals, files-by-category, `appJsonDiff`) and one `type == "pr"` record per merged PR (title, body, files, commits, key AL changes, breaking-change indicators).

### 2. Initialise

- Verify file: `Test-Path .output/releases/release-analysis.jsonl`.
- Load `type == "summary"` record. Hold version + BC compatibility in main context.
- Build PR list from `type == "pr"` records — number + title only.
- Create todo list:
  - **Phase todos** — Initialise, Analyse PRs, Generate Notes.
  - **One todo per PR** — title in todo, single-line JSON result lands in description.

### 3. Analyse each PR

Mark "Analyse PRs" in progress.

For each PR, apply **PR Classification Protocol** in [references/pr-classification.md](references/pr-classification.md). Produce one single-line JSON record. Store in that PR's todo description. Mark todo `[x]`.

**Per-PR analysis line — Yes/No.**

- No: `{"pr":142,"type":"improvement","area":"Configuration","desc":"Updated logic","details":""}`
- Yes: `{"pr":142,"type":"improvement","area":"Item Configurator List page","desc":"Bulk-copy configuration from one item to many in one action","details":"\"Copy Configuration\" action; target items selected via lookup"}`

_Avoid_: `desc` is `Updated logic` → name user-visible change. _Avoid_: `area` is `Configuration` → name page, report, API, or workflow. _Avoid_: empty `details` on user-facing PR → name the field, action, or page.

**Anti-pattern: generic descriptions like 'Updated logic'.** Symptom of skipping AL walk. Run Deep Dive Protocol in [references/pr-classification.md](references/pr-classification.md) before retrying.

### 4. Quality check (gate)

Sweep todo descriptions. PR fails gate when any of these hold:

| Symptom | Action |
|---|---|
| `desc` is generic ("Updated logic", "Fixed issue") | Deep Dive |
| `area` is vague ("Configuration", "the page") | Deep Dive |
| `details` empty on user-facing PR | Deep Dive |
| User-facing PR marked `exclude` with no justification | Deep Dive |

Re-run analysis on each failing PR via Deep Dive Protocol in [references/pr-classification.md](references/pr-classification.md). Overwrite todo description with sharper line.

### 5. Generate the notes

Mark "Generate Notes" in progress.

- Collect all PR results from todo descriptions.
- Group by `type`:

| `type` | Section |
|---|---|
| `feature` | New Features |
| `improvement` | Improvements |
| `bugfix` | Bug Fixes |
| `breaking` | Breaking Changes & Migration Notes |
| `technical` | Technical Summary |
| `exclude` | Omitted from output |

- Render markdown using [references/output-format.md](references/output-format.md).
- Apply [references/content-guidelines.md](references/content-guidelines.md) for tone and phrasing.
- Write file to `.output/releases/RELEASE-NOTES-<VERSION>.md`.

## Edge cases

| Condition | Action |
|---|---|
| Zero PRs | Emit version header + `No changes in this release.` |
| All PRs `exclude` | Emit version header + `This release contains only internal changes.` |
| No user-facing PRs | Skip User-Facing Changes section; render Technical Summary only |
| No technical PRs | Skip Technical Summary section |

## Context management

Each PR diff can be 500+ lines. Loading ten PRs into main context burns 50K+ tokens before a single note is written.

**Strategy:**

- **Main context** holds summary record, todo list, final markdown.
- **Per-PR analysis** loads one `type == "pr"` record at a time and emits one single-line JSON record.
- **Todo descriptions** are durable storage for every PR result across the run.

**Anti-pattern: collapse all PR context into main agent.** Reading every PR record into the main loop pushes context past the point where final markdown stays coherent → descriptions degrade to `Updated logic` and sections collide. Per-PR todo description is the load-bearing buffer; never bypass it.

## Per-PR cycle checklist

```
[ ] One PR record loaded; nothing else from the JSONL
[ ] Single-line JSON emitted, matches a template in references/pr-classification.md
[ ] User-facing PR cites a real page/codeunit/table/field/action
[ ] Technical PR has category + one-line summary
[ ] Breaking PR has change + exact migration steps
[ ] Result lives in the todo description, not in main context
```

## Composition

- `scripts\Get-ReleaseAnalysis.ps1` — precondition. Produces JSONL the skill consumes.
- [references/pr-classification.md](references/pr-classification.md) — per-PR classification + Deep Dive Protocol.
- [references/output-format.md](references/output-format.md) — final markdown template.
- [references/content-guidelines.md](references/content-guidelines.md) — tone, phrasing, Good/Bad entries.

## Out of scope

- No PR or issue links in output — release notes are self-contained.
- No re-running analysis script mid-flow — fix PR record by Deep Dive, not by regenerating JSONL.
- No alternate output paths — `.output/releases/RELEASE-NOTES-<VERSION>.md` is fixed.
- No multi-release synthesis — one version per run.
