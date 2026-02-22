# Content Guidelines for Release Notes

## User-Facing Section (Primary Focus)

- Write in plain language, avoid AL/BC jargon
- Focus on what users can do and why it matters
- Be specific: include field names, page names, action names
- Provide context: explain the scenario or workflow affected
- Be comprehensive: every user-visible change should be documented
- Self-contained: no PR/issue links, all information in the text

## Technical Summary Section

- Headlines only, one line per item
- Technical audience can read code if they need details
- Focus on "what changed" not "how it was implemented"
- Group related changes together

## Writing Style

| Do | Don't |
|----|-------|
| Active voice: "You can now..." | Passive: "It is now possible to..." |
| Specific: "The Configuration Card page" | Vague: "the page" |
| Value-oriented: Lead with benefit | Feature-first: Lead with implementation |
| Complete: Reader understands without code | Incomplete: Requires looking at code |

## Examples

### Good User-Facing Entry

```markdown
### 🚀 New Features

- **Bulk Configuration Copy**
  - Copy configuration settings from one item to multiple target items in a single operation
  - Access via the "Copy Configuration" action on the Item Configurator List page
  - Reduces setup time when configuring similar products
```

### Good Technical Entry

```markdown
### Database Changes

- Added `NALICF Bulk Copy Log` table for tracking copy operations
- New field `Last Bulk Copy Date` on Configuration Header
```

### Bad Entries (Avoid)

```markdown
- Fixed bug in PR #142
- Updated code per user request
- Various improvements to configuration logic
```

These are bad because they:
- Reference PR numbers (not self-contained)
- Lack specificity (what code? what logic?)
- Don't explain user impact
