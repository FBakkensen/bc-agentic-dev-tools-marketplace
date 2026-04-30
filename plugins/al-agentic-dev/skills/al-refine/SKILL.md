---
name: al-refine
description: Fill in Gherkin tests for one task in tasks.md for AL/Business Central work. Run after /al-scope places a bare task entry. Explores codebase to specify how one behavior should be tested, runs /grill-me if intent is ambiguous, writes compressed Gherkin bullets. Use per task, not per feature.
---

# /al-refine — Task → Gherkin

Fill in the `**Tests**` block for one task from `tasks.md`. Input: a bare task entry from `/al-scope`. Output: Gherkin bullets + Notes (only when non-obvious).

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-design` first. If the task is `[!]`, stop: `T-X is [!] — run /al-steer to clear the replan.`

`architecture.md` should exist in the same spec folder — read it for module map, R→P→W boundary, and test strategy before writing scenarios.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Read** `architecture.md` for the module map, R→P→W boundary, and likely scenario family for this task.
2. **Explore** the codebase to specify how the behavior should be tested — test codeunit location, existing helpers, field constraints. Run `/al-research` if non-trivial.
3. **`/grill-me`** when intent is ambiguous or a domain rule isn't explicit.
4. **Second opinion (gate)** on the Gherkin bullets — mandatory for non-trivial.
5. **Replan check (gate)** — walk triggers #1, #2, #3, #4. Subjective triggers (#2, #4) require a written verdict. On hard-halt set the task `[!]`, append `**Replan** trigger #N: <one-line reason>`, stop. On soft-flag append the same Notes line and continue.
6. **Write** the `**Tests**` block into the task entry. Stop.

## Tests

Each test is a numbered scenario with **Given / When / Then** on their own bullets:

```
1. **<short scenario title>**
   - **Given** <preconditions>
   - **When** <action>
   - **Then** <expected outcome>
```

- **Scenario title.** Short phrase that names the behaviour — same intent as the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]`. Stable handle for grilling and commits (`T-007#3`).
- **Numbering** restarts within each task.
- **And / But continuation.** When a clause has multiple invariants, extend the bullet rather than splitting the scenario:
  ```
  - **Then** the new configuration has one `NALICF Cust Price` row
    **And** `Configuration No.` is rewritten
    **And** every other field equals the source row
  ```
- **BC vocabulary as compression.** Use field names, codeunit names, table names — no explanation needed.
- **Plain Markdown. No AL code.**
- Both positive AND negative cases. Boundaries when ranges, thresholds, or guards exist.
- Apply ZOMBIES order across the numbered scenarios: Zero cases first, walking outward to Many, Boundaries, Exceptions.
- Prefer tests against the pure Process layer (Read → Process → Write) when the behaviour can be expressed in isolation. Consult `architecture.md`'s test strategy for the per-scenario-family default.

## Anti-pattern: bulk Gherkin drift

Writing all Gherkin bullets at once can drift into testing *imagined* behaviour rather than *actual* behaviour — bullets become insensitive to real changes (pass when behaviour breaks, fail when behaviour is fine). Mitigations:

- **ZOMBIES order** — Zero cases first force the simplest path through real code; Many/Boundaries/Exceptions then explore against ground truth.
- **Cross-reference each bullet against the codebase** before writing. If you can't trace the precondition or the expected outcome to existing fields/codeunits/events, halt — either the task is wrong or `/al-research` is needed.
- **`/al-implement` re-verifies** each bullet against the AL `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` it transcribes. If they drift during TDD, fix the bullet OR the test — never let them diverge silently.

## tasks.md entry format after /al-refine runs

```markdown
### [ ] T-001 — title
context line

**Tests**

1. **<scenario title>**
   - **Given** ...
   - **When** ...
   - **Then** ...

2. **<scenario title>**
   - **Given** ...
   - **When** ...
   - **Then** ...

**Notes**
- one-line constraint (only if needed)
```

## Notes

- Valid only when stating a non-obvious BC constraint (a hidden invariant, a guard that exists somewhere unexpected, a table missing from an existing routine) OR an explicit deferred decision ("Implementation choice: X vs Y — /al-implement decides").
- One line max. No fixture mechanics. No implementation choices beyond explicit deferrals.
- If removing the note wouldn't confuse `/al-implement`, don't write it.

## Replan check (gate)

Triggers in scope: #1 task too big (soft), #2 hidden pre-req (hard), #3 wrong order (hard), #4 sibling now wrong (hard).

| # | Detect | Action |
|---|---|---|
| 1 | `>5` scenarios after refinement, or scenarios cluster around two distinct subjects | Soft-flag: append `**Replan** trigger #1: <reason>`, continue. |
| 2 | Gherkin references a table, codeunit, or permission with no covering task | Hard-halt: set `[!]`, append `**Replan** trigger #2: <reason>`, stop. |
| 3 | A Gherkin bullet references behavior a later task introduces | Hard-halt: set `[!]`, append `**Replan** trigger #3: <reason>`, stop. |
| 4 | This task's behavior invalidates another task's context line or scenarios | Hard-halt: set `[!]`, append `**Replan** trigger #4: <reason>`, stop. |

Subjective triggers (#2, #4) require a written verdict — one line stating what was checked. **No silent skip.** On hard-halt: stop the skill, recommend `/al-steer` to clear the replan. Halted gates downstream record `Replan halt before <gate>` as a Notes line. Code state untouched — this is a planning halt, not a rollback.

## Second opinion (gate)

Cross-check the Gherkin bullets with copilot CLI. Mandatory for non-trivial.

**Invoke:** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt meta-shape:** task title + context line + Gherkin bullets + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the seven replan triggers (#1 task too big, #2 hidden pre-req, #3 wrong order, #4 sibling now wrong)? Return a bulleted list."*

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
- No test-layer decisions (Pure / E2E / Both) — feature-level strategy lives in `architecture.md`; per-task confirmation happens in `/al-implement` step 2.
- No replan mutations — that's `/al-steer`.
