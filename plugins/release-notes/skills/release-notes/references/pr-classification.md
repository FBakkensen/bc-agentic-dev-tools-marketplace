# PR Classification Protocol

Use this protocol to classify a single PR for release notes. Produce a single-line JSON result and nothing else.
Analyze only the PR you were given. Avoid extra investigation unless classification is ambiguous; use the Deep Dive Protocol when needed.

## Inputs

- PR number
- PR record from `.output/releases/release-analysis.jsonl` where `type == "pr"`

Commonly used fields include `title`, `body` or `description`, `files`, `labels`, `breakingChangeIndicators`, and `keyALChanges`.

## Steps

1. Locate the PR record matching the PR number.
2. Determine whether the change is user-facing, technical, breaking, or excluded.
3. Apply classification rules in order:
   - **Breaking**: `breakingChangeIndicators` is non-empty, a breaking-change label is present, or the PR introduces public API changes.
   - **Exclude**: All changed files are limited to `test/`, `docs/`, `.github/`, or `scripts/` and there is no runtime/user impact.
   - **Feature**: `feat:` prefix and introduces new user-facing functionality.
   - **Bugfix**: `fix:` prefix and resolves a user-facing defect.
   - **Technical**: `refactor:`, `chore:`, or `perf:` prefix, or the change is internal only.
   - **Improvement**: Enhances existing user-facing functionality.
4. For user-facing types (`feature`, `improvement`, `bugfix`), extract:
   - **area**: Specific page, report, API, or workflow
   - **desc**: Clear user impact description
   - **details**: UI elements (fields, actions, pages) or concrete usage details
5. For technical items, set:
   - **category**: `refactor`, `chore`, or `perf`
   - **summary**: One-line technical summary
6. For breaking changes, include:
   - **change**: What changed
   - **migration**: Exact migration steps
7. Emit a single-line JSON result and store it in the PR todo description.

## Output Templates

User-facing:

```json
{"pr":<NUMBER>,"type":"feature|improvement|bugfix","area":"Specific Page/Component","desc":"User impact description","details":"Field X, Action Y"}
```

Breaking:

```json
{"pr":<NUMBER>,"type":"breaking","change":"What changed","migration":"Exact migration steps"}
```

Technical:

```json
{"pr":<NUMBER>,"type":"technical","category":"refactor|chore|perf","summary":"One-line summary"}
```

Excluded:

```json
{"pr":<NUMBER>,"type":"exclude","reason":"test|docs|ci|al-go"}
```

## Deep Dive Protocol

Use when the initial classification is vague or fails the quality check.

- Review the PR description, key AL changes, file paths, and commit summaries.
- Identify the exact UI surfaces and workflows impacted (page names, actions, fields).
- If still unclear, inspect the most relevant AL objects to capture concrete names.
- Rewrite `area`, `desc`, and `details` to be specific and user-facing.
- Reclassify if new evidence changes the type.
