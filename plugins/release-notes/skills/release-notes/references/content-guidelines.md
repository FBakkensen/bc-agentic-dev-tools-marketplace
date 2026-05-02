# Content Guidelines

Tone, phrasing, and entry shape for the rendered markdown. Apply alongside [output-format.md](output-format.md) when expanding each PR record into its bullet.

## User-Facing entries — primary focus

- **Plain language.** No AL or BC jargon when a user-facing word will do. _Avoid_: `subscriber on OnAfterValidateEvent`. Use: `the Posting Date validation`.
- **Specific.** Name the page, the action, the field. _Avoid_: `the page`, `a setting`. Use: `the Configuration Card page`, `the "Apply Template" action`.
- **Value-led.** Lead with what the user can now do or no longer hits. The implementation is for the Technical Summary.
- **Self-contained.** No PR numbers, no issue numbers, no URLs. The reader never has to leave the document.
- **One fact per line.** No semicolon-glued clauses, no nested subordinate clauses.

## Technical Summary entries

- **Headlines only.** One line per item. The technical audience can read code if they need depth.
- **What changed, not how.** `Replaced NoSeriesManagement with codeunit "No. Series" across posting.` — not `Refactored to use the new pattern by introducing a wrapper around...`.
- **Group related changes.** Two refactors that move the same boundary land as one bullet, not two.

## Drop list

| Drop | Why |
|---|---|
| Hedging — `should`, `may`, `tends to`, `it is now possible to` | Release notes ship facts, not maybes |
| Process noise — `as part of this release`, `we have introduced` | Reader knows it's a release note |
| Passive voice on user actions | Active voice names the actor — `Copy a configuration to multiple target items in one action.` |
| Implementation verbs in user-facing prose — `refactored`, `extracted`, `wired up` | Belongs in Technical Summary, not User-Facing |
| PR/issue references in body text | Self-contained rule — names are the citation |

## Phrasing — Yes/No

| | |
|---|---|
| _Avoid_: | `It is now possible to copy configurations to multiple items.` |
| Use: | `Copy a configuration to multiple target items in one action.` |
| _Avoid_: | `Various improvements to configuration logic.` |
| Use: | `The Item Configurator List page applies template overrides correctly when items share a template group.` |
| _Avoid_: | `Fixed a bug where things didn't work right.` |
| Use: | `Posting a sales invoice with a blocked customer no longer leaves a stray Cust. Ledger Entry.` |

## Good user-facing entry

```markdown
### 🚀 New Features

- **Bulk Configuration Copy**
  - Copy configuration settings from one item to multiple target items in a single operation
  - Access via the "Copy Configuration" action on the Item Configurator List page
  - Reduces setup time when configuring similar products
```

## Good technical entry

```markdown
### Database Changes

- Added `NALICF Bulk Copy Log` table for tracking copy operations
- New field `Last Bulk Copy Date` on Configuration Header
```

## Bad entries

```markdown
- Fixed bug in PR #142
- Updated code per user request
- Various improvements to configuration logic
```

These fail because they:

- **Reference PR numbers** — breaks the self-contained rule.
- **Name no surface** — `code`, `logic` instead of a page, codeunit, or field.
- **Skip the user.** No reader can tell what changed for them.

**Anti-pattern: generic descriptions like 'Updated logic'.** Symptom of rendering off a vague PR analysis line. Fix the JSONL line first via the Deep Dive Protocol in [pr-classification.md](pr-classification.md), then re-render — never paper over a vague line at render time.
