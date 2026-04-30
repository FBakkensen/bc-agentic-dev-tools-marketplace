---
name: al-refine
description: One task → numbered Gherkin scenarios for AL/Business Central. Reads architecture.md and the codebase to spec how the behaviour is tested, runs /grill-me when intent is fuzzy, confirms the per-scenario test layer, walks the seven replan triggers, then writes compressed Gherkin bullets onto that task's entry in tasks.md. Use after /al-scope places a bare task entry. Per task, not per feature.
---

# /al-refine — Task → Gherkin

Fill the `**Tests**` block for one task in `tasks.md`. Read `architecture.md`, explore the codebase, confirm the per-scenario layer, walk the replan gate, write Gherkin bullets. One task per run. Stop — `/al-implement` consumes it next.

**Resolve `tasks.md`:** branch matches `^\d{3}-` → `specs/<branch>/tasks.md`. Otherwise `Stop.` — run `/al-design`. Task is `[!]` → `Stop.` — `T-X is [!], run /al-steer to clear the replan.` `architecture.md` missing in the spec folder → `Stop.` — run `/al-design`.

## Flow

Prefer parallel subagents for independent work and output-heavy steps.

1. **Read** `architecture.md` for module map, R → P → W boundary, brownfield touchpoints, and the family-level test layer covering this task.
2. **Explore** the codebase to ground each scenario — test codeunit location, existing helpers, field constraints, BaseApp events on the boundary. Run `/al-research` for non-trivial BC behaviour; cross-reference every precondition and outcome to a real field/codeunit/event before writing.
3. **`/grill-me`** when intent is ambiguous, when a domain rule isn't explicit, or when ZOMBIES surfaces a case the user must adjudicate.
4. **Confirm test layer per scenario.** Architecture decided the family default. Override per scenario only when intent forces it: Pure (process layer, no DB) by default; E2E when behaviour is composition or side effect unreproducible at the pure layer; Both only when intent splits cleanly. Record overrides as a Notes line.
5. **Draft** numbered scenarios in ZOMBIES order — Zero first, then Many, Boundaries, Exceptions. Both positive and negative cases. Use the canonical block shape below. BC vocabulary as compression — field/codeunit/table names, no explanation. Plain Markdown, no AL code.
6. **Second opinion (gate)** — mandatory for non-trivial. See *Second opinion*.
7. **Replan check (gate)** — walk all seven triggers. See *Replan check*.
8. **Write** the `**Tests**` block (and optional `**Notes**` line) into the task entry. `Stop.`

## Canonical Gherkin block

```
1. **<short scenario title>**
   - **Given** <preconditions>
   - **When** <action>
   - **Then** <expected outcome>
     **And** <additional invariant>
```

Title is a stable handle for grilling and commits (`T-007#3`) — same intent as the `[SCENARIO]` comment `/al-implement` writes inside the AL `[Test]`. Numbering restarts per task. Use **And** / **But** to extend a clause rather than splitting the scenario.

## tasks.md entry shape after /al-refine

```markdown
### [ ] T-001 — title
context line

**Tests**

1. **<scenario title>**
   - **Given** ...
   - **When** ...
   - **Then** ...

**Notes**
- one-line constraint (only if needed)
```

## Notes line — when valid

- A non-obvious BC constraint — hidden invariant, guard in an unexpected place, table missing from an existing routine.
- An explicit deferred decision — `Implementation choice: X vs Y — /al-implement decides`.
- A per-scenario layer override from step 4.
- A replan soft-flag from step 7.

One line max. No fixture mechanics, no implementation choices beyond explicit deferrals. If removing the note wouldn't confuse `/al-implement`, don't write it.

## Replan check (gate)

All seven triggers in scope. Subjective triggers require a written verdict — one line stating what was checked. **No silent skip.** Hard-halt: set `[!]`, append the Notes line, stop, recommend `/al-steer`. Soft-flag: append the Notes line, continue. Code state untouched.

| # | Trigger | Detect | Action |
|---|---|---|---|
| 1 | Task too big | `>5` scenarios, or scenarios cluster around two distinct subjects | Soft-flag |
| 2 | Hidden pre-req | Gherkin references a table, codeunit, or permission with no covering task | Hard-halt |
| 3 | Wrong order | A bullet references behaviour a later task introduces | Hard-halt |
| 4 | Sibling now wrong | This task's behaviour invalidates another task's context line or scenarios | Hard-halt |
| 5 | New behavior emerges | A scenario specifies behavior outside any current task's intent | Soft-flag |
| 6 | Architecture decomposition wrong | The family-level layer or module boundary can't house this scenario cleanly | Hard-halt |
| 7 | Goal drift | Scenarios push past the feature `Goal` line in `tasks.md` | Soft-flag |

Notes-line format: `**Replan** trigger #N: <one-line reason>`.

## Second opinion (gate)

Cross-check the Gherkin bullets via the `al-agentic-dev:al-second-opinion` agent. Mandatory for non-trivial.

**Invoke:** `Agent(subagent_type: 'al-agentic-dev:al-second-opinion', prompt: <body>)`.

**Prompt body shape:** task title + context line + Gherkin bullets + *"what scenarios, negatives, or boundaries are missing or wrong? AND does this surface any of the seven replan triggers? Return a bulleted list."* The agent prepends the role frame and applies the canonical safety envelope.

**Reconcile each returned bullet:** accept (update bullets) or reject with a one-line reason as a Notes line. `/grill-me` when judgement needs the user. If the agent returns `Second opinion skipped: <reason>`, paste it verbatim as a Notes line and proceed.

## Composition

`/grill-me` whenever intent is ambiguous. `/al-research` for non-trivial BC areas. `/bc-standard-reference` for BaseApp behaviour and patterns. `/al-steer` is the replan venue when a hard-halt fires. `/al-implement` consumes the Gherkin next.

## Out of scope

- No code edits. No fixture mechanics. No mutation lists — discovered during `/al-implement`.
- No feature-level test strategy — that's `architecture.md` via `/al-design`.
- No replan mutations — that's `/al-steer`.
- No Resolved Questions or Cross-cutting Notes sections.
