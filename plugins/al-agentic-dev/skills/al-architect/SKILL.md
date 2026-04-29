---
name: al-architect
description: Design the test-friendly shape for one task in tasks.md before TDD runs. Picks the AL pattern by name, draws the Read → Process → Write boundary, lists the brownfield touchpoints to refactor, and decides per Gherkin scenario whether the test lives at the pure layer, end-to-end, or both. Run after /al-refine fills Gherkin, before /al-implement. Use per task, not per feature.
---

# /al-architect — Task → testable shape

Design the testable shape for one task in `tasks.md`. Pick the AL pattern, draw the Read → Process → Write boundary, list brownfield touchpoints, decide the test layer per Gherkin scenario. Output is an `**Architecture**` block on the task entry.

**Resolve `tasks.md`:** Check the current branch name — if it matches `^\d{3}-`, use `specs/<branch>/tasks.md`. Otherwise stop: run `/al-scope` first.

## Flow

**Prefer parallel subagents for independent work.**
**Prefer a subagent for output-heavy work.**

1. **Pick task.** The `**Tests**` block must exist — if missing, stop: run `/al-refine <T-NNN>` first.
2. **Explore** the production code the task touches. Identify what is already testable in isolation, what isn't, and why (DB I/O, time, HTTP, page/API surface, environment, missing seam).
3. **`/al-research`** when an AL pattern choice or BC-specific seam is uncertain.
4. **`/grill-me`** when a brownfield trade-off needs the user (extract-vs-inline, new module vs extend existing, visibility change).
5. **Decide test layer per scenario.** **Pure** (Process layer, no DB) by default; **E2E** when the behaviour is composition or side effect that cannot be reproduced at the pure layer; **Both** only when the same intent splits cleanly across layers. **Not every scenario needs E2E.**
6. **Second opinion (gate)** on the Architecture block — mandatory for non-trivial.
7. **Write** the `**Architecture**` block into the task entry. Stop.

## tasks.md entry format after /al-architect runs

```markdown
### [ ] T-NNN — title
context line

**Tests**
...Gherkin from /al-refine...

**Architecture**

- **Module / service:** <name> — <one-line role>
- **Pattern:** <name from alguidelines.dev — e.g. Implementer, Façade, Handled events, Setup table, Variant Façade>
- **Interface:** <name + key procedures> | `none — pure procedure`
- **Read → Process → Write:** R = <inputs>; P = <pure procedure>; W = <effects>
- **Brownfield touchpoints:**
  - `<File/Codeunit:Procedure>` — <extract / inject seam / rename / split>
- **Test layer per scenario:**
  - 1 — Pure
  - 2 — E2E
  - 3 — Pure

**Notes**
- one-line constraint (only if needed)
```

## Patterns (state explicitly — do not rely on CLAUDE.md)

Name canonical BC patterns inline: Implementer, Façade, Handled events, Variant Façade, Setup table. Defer definitions to `https://alguidelines.dev/docs/patterns/`. Prefer standard BC patterns over clever abstractions. If a pattern needs explaining, it's wrong for AL. Pick one pattern per task; name it on the `**Pattern:**` line and stop.

## Naming and vocabulary (state explicitly — do not rely on CLAUDE.md)

- **BC vocabulary:** Insert / Modify / Delete (records — not Create/Update/Remove), Post (not Submit), Validate (not Check), Get / Find (not Fetch), Ledger Entry (not Transaction), No. (not ID), Procedure (not Method).
- **Objects:** `"Prefix Feature Suffix"` with suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Record variables** match the table name (`Customer`, `SalesHeader`). Primitives are descriptive (`TotalBalance`, `IsBlocked`).
- **Procedures:** PascalCase, verb-first. **Events:** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

## Second opinion (gate)

Cross-check the Architecture block with copilot CLI. Mandatory for non-trivial. Independent perspective from a different training distribution — not authority.

**Invoke:** `copilot -p "<prompt>" -s --no-ask-user --allow-all-tools --model gpt-5.5 --effort xhigh`

**Prompt meta-shape:** task title + Gherkin bullets + draft Architecture block + *"what's wrong or missing for testable shape under R→P→W in BC? Return a bulleted list."*

**Reconcile each bullet:** accept (update the Architecture block) or reject with a one-line reason as a Notes line. **No silent skip.** `/grill-me` when judgement needs the user.

**Trust:** copilot's AL/BC training is also thin — weigh against this skill's discipline and *"standard BC patterns over clever abstractions."*

**Failure:** if copilot is unavailable / errors / times out, record `Second opinion skipped: <reason>` as a Notes line and proceed.

## Composition

- `/al-refine` — required precondition (Gherkin must exist).
- `/al-research` for AL pattern uncertainty or BC-specific seams.
- `/bc-standard-reference` for BaseApp event/codeunit signatures and patterns.
- `/grill-me` for brownfield trade-off calls.
- `/al-implement` consumes the Architecture block.
- `/al-refactor` consumes the brownfield touchpoints as its checklist seed.
- copilot CLI — second-opinion gate.

## Out of scope

- No code edits. No interface extraction yet — that's `/al-refactor`.
- No new Gherkin or scenario tweaks — that's `/al-refine`.
- No mutations.
- No enumerated pattern catalogue — name patterns inline; defer to alguidelines.dev/docs/patterns.
