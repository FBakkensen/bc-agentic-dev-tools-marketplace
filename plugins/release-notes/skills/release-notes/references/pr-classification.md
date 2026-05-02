# PR Classification Protocol

Classify one PR. Emit one single-line JSON record. Nothing else. Store the line in that PR's todo description.

Stay inside the PR you were given. Do not browse the rest of the JSONL or the wider codebase unless the Deep Dive Protocol says to.

## Inputs

- PR number.
- The matching `type == "pr"` record from `.output/releases/release-analysis.jsonl`.

Common fields: `title`, `body` / `description`, `files`, `labels`, `breakingChangeIndicators`, `keyALChanges`, `commits`.

## Steps

1. **Locate** the record matching the PR number.
2. **Decide the type** by walking the rules in order — first match wins:

| Order | Type | Rule |
|---|---|---|
| 1 | `breaking` | `breakingChangeIndicators` non-empty, breaking-change label present, or public API surface changed |
| 2 | `exclude` | All changed files in `test/`, `docs/`, `.github/`, or `scripts/`; no runtime or user impact |
| 3 | `feature` | `feat:` prefix and the change introduces new user-facing functionality |
| 4 | `bugfix` | `fix:` prefix and the change resolves a user-facing defect |
| 5 | `technical` | `refactor:`, `chore:`, or `perf:` prefix, or change is internal only |
| 6 | `improvement` | Enhances existing user-facing functionality |

3. **Extract slots** for the type:
   - **User-facing** (`feature`, `improvement`, `bugfix`): `area`, `desc`, `details`.
   - **Breaking**: `change`, `migration`.
   - **Technical**: `category`, `summary`.
   - **Exclude**: `reason`.
4. **Emit** the matching template below as a single line. Store it in the PR's todo description.

## Slot rules

- **`area`** — name the page, report, API, codeunit, table, or workflow. _Avoid_: `Configuration`, `the page`. Use: `Item Configurator List page`, `Codeunit 80 Sales-Post`, `Sales Header table`.
- **`desc`** — what the user can now do or no longer hits. One sentence, BC vocabulary. _Avoid_: `Updated logic`. Use: `Bulk-copy configuration from one item to many in one action`.
- **`details`** — concrete UI surface or usage path. Name the field, action, page, or runtime entry point. _Avoid_: empty on a user-facing PR.
- **`category`** — exactly one of `refactor`, `chore`, `perf`.
- **`summary`** — one line, technical audience, what changed (not how).
- **`change`** + **`migration`** — what broke + the exact steps a consumer takes. Migration is imperative, ordered, code-grounded.
- **`reason`** — one of `test`, `docs`, `ci`, `al-go` (or another short tag if the file scope justifies it).

**Anti-pattern: generic descriptions like 'Updated logic'.** Symptom of classifying off the title alone, without reading `keyALChanges` or `files`. Run the Deep Dive Protocol below before re-emitting.

## Output templates

User-facing:

```json
{"pr":<NUMBER>,"type":"feature|improvement|bugfix","area":"<page/codeunit/report>","desc":"<user impact>","details":"<field/action/page>"}
```

Breaking:

```json
{"pr":<NUMBER>,"type":"breaking","change":"<what changed>","migration":"<exact steps>"}
```

Technical:

```json
{"pr":<NUMBER>,"type":"technical","category":"refactor|chore|perf","summary":"<one line>"}
```

Excluded:

```json
{"pr":<NUMBER>,"type":"exclude","reason":"test|docs|ci|al-go"}
```

## Per-PR Yes/No

- No: `{"pr":142,"type":"improvement","area":"Configuration","desc":"Updated logic","details":""}`
- Yes: `{"pr":142,"type":"improvement","area":"Item Configurator List page","desc":"Bulk-copy configuration from one item to many in one action","details":"\"Copy Configuration\" action; target items selected via lookup"}`

The Yes line names the page, the action, and the user-visible behaviour. The No line names none.

## Deep Dive Protocol

Run when initial classification is vague, ambiguous, or fails the SKILL.md quality-check gate.

1. **Re-read** the PR record's `body`/`description`, `keyALChanges`, `files`, and `commits`.
2. **Name the surface.** Identify the exact pages, actions, and fields the change touches. If `keyALChanges` does not name them, walk the file paths and look at the AL object headers (object name, page caption, action captions).
3. **Inspect** the most relevant AL object only when names still aren't pinned down. One object, not the whole module.
4. **Reclassify** if new evidence flips the type — e.g. a `chore:` PR that actually adds a user-visible action becomes `feature` or `improvement`.
5. **Rewrite** `area`, `desc`, and `details` against the surface you just named. Overwrite the todo description with the sharper single-line JSON.

One Deep Dive per PR. If the second pass still produces a vague line, flag it in the todo description with `"deepDive":"insufficient evidence"` and let the human resolve it before the final render.
