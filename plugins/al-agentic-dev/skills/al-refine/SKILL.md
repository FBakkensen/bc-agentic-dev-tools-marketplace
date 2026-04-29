---
name: al-refine
description: Fill in Gherkin tests for one task in tasks.md for AL/Business Central work. Run after /al-scope places a bare task entry. Explores codebase to specify how one behavior should be tested, runs /grill-me if intent is ambiguous, writes compressed Gherkin bullets. Use per task, not per feature.
---

# /al-refine — Task → Gherkin

Fill in the `**Tests**` block for one task from `tasks.md`. Input: a bare task entry from `/al-scope`. Output: Gherkin bullets + Notes (only when non-obvious).

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-scope` first.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Explore** the codebase to specify how the behavior should be tested — test codeunit location, existing helpers, field constraints. Run `/al-research` if non-trivial.
2. **`/grill-me`** when intent is ambiguous or a domain rule isn't explicit.
3. **Second opinion (gate)** on the Gherkin bullets — mandatory for non-trivial.
4. **Write** the `**Tests**` block into the task entry. Stop.

## Tests

Each test is a Gherkin bullet:

```
- Given <preconditions>, When <action>, Then <expected outcome>
```

- **BC vocabulary as compression.** Use field names, codeunit names, table names — no explanation needed.
- **Plain Markdown. No AL code.**
- Both positive AND negative cases. Boundaries when ranges, thresholds, or guards exist.
- Apply ZOMBIES order within the bullet list: Zero cases first, walking outward to Many, Boundaries, Exceptions.
- Prefer tests against the pure Process layer (Read → Process → Write) when the behaviour can be expressed in isolation.

## tasks.md entry format after /al-refine runs

```markdown
### [ ] T-001 — title
context line

**Tests**
- Given ..., When ..., Then ...

**Notes**
- one-line constraint (only if needed)
```

## Notes

- Valid only when stating a non-obvious BC constraint (a hidden invariant, a guard that exists somewhere unexpected, a table missing from an existing routine) OR an explicit deferred decision ("Implementation choice: X vs Y — /al-implement decides").
- One line max. No fixture mechanics. No implementation choices beyond explicit deferrals.
- If removing the note wouldn't confuse `/al-implement`, don't write it.

## Second opinion (gate)

Cross-check the Gherkin bullets with copilot CLI. Mandatory for non-trivial.

**Invoke:** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt meta-shape:** task title + context line + Gherkin bullets + *"what scenarios, negatives, or boundaries are missing or wrong? Return a bulleted list."*

**Reconcile each bullet:** accept (update bullets) or reject with a one-line reason as a Notes line. No silent skip. `/grill-me` when judgement needs the user.

**Failure:** record `Second opinion skipped: <reason>` as a Notes line and proceed.

## Composition

- `/grill-me` whenever intent is ambiguous.
- `/al-research` for non-trivial BC areas.
- `/bc-standard-reference` for BC patterns and BaseApp behaviour.

## Out of scope

- No code edits.
- No mutation lists — mutations are discovered during `/al-implement`.
- No Resolved Questions or Cross-cutting Notes sections.
- No fixture mechanics or implementation choices in Notes beyond explicit deferrals.
