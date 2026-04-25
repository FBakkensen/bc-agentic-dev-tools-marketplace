<!-- Historical: project-specific PoC. See ../../al-skills-design.md for the current design. -->
---
name: jobman-refactor-steer
description: Repo-specific JobManager refactor steering workflow. Use when evaluating refactor status, reviewing or synchronizing planning docs, detecting deviations, deciding next steps, generating or splitting Doc/Refactor-Implementation/Tasks.md tasks, assessing whether implementation is ready, or recording planning decisions. Always use grill-me for steering decisions, after inspecting repo state when facts are discoverable locally.
---

# JobMan Refactor Steer

Use this skill for planning, review, and direction-setting work on the JobManager calculation refactor.

Do not use this skill to implement AL production behavior. When a concrete implementation task is ready, hand off to `$jobman-refactor-dev`.

## Steering Preflight

Before recommending direction or editing planning docs:

1. Run `git status --short`.
2. Read the relevant active docs:
   - `Doc/Refactor-Implementation/Tasks.md`
   - `Doc/Refactor-Implementation/Refactor-Strategy.md`
   - `Doc/Refactor-Implementation/Design-Brief.md`
   - `Doc/Refactor-Implementation/Development-Guidelines.md`
   - `AGENTS.md` when workflow guidance or skill boundaries matter.
3. Treat `Doc/Historical/` as lookup material only, not active instruction.
4. If code behavior or test coverage matters, inspect the relevant source/tests before asking the user.
5. Do not overwrite unrelated worktree changes. If dirty files may affect steering, call them out before editing.

## Decision Workflow

Use `$grill-me` for every steering decision:

- deciding the next phase;
- generating or splitting tasks;
- changing task order or dependencies;
- updating architecture, contract, rollout, or workflow rules;
- resolving deviations between docs, tests, and implementation;
- deciding if work is ready to hand off to `$jobman-refactor-dev`.

Ask one decision question at a time and provide a recommended answer. If the answer can be discovered from repo state, inspect the repo instead of asking.

When enough decisions are agreed, update docs/tasks only if the user requested a concrete steering outcome such as "update", "generate", "record", "make this concrete", or "implement this skill".

## Boundary With Dev Skill

This skill may:

- review current status;
- detect stale docs or workflow contradictions;
- create, split, reorder, or clarify tasks;
- update planning docs and skill guidance;
- evaluate what has been done and what is missing;
- recommend the next implementation task.

This skill must not:

- implement replacement calculation business logic;
- run Red-Green-Refactor-Mutate as the primary workflow;
- activate production routing to the replacement engine;
- change frozen legacy behavior;
- commit unless the user explicitly asks.

Use `$jobman-refactor-dev` once the next step is writing tests, changing AL implementation, running AL gates, mutation testing, or completing an implementation task.

## Deviation Checklist

When reviewing status or generating tasks, check for:

- stale test inventory counts;
- multiple `In Progress` tasks;
- `Ready` tasks with unmet dependencies;
- active docs saying architecture, IDs, or scaffold are not done when they are done;
- implementation tasks without task-local Gherkin test plans;
- mutation-required tasks without mutation notes or commit fields;
- route activation before the full contract is green;
- approved bug-fix exceptions missing from tasks or tests;
- historical docs being treated as current instruction;
- docs contradicting `Refactor-Strategy.md`, `Design-Brief.md`, or `Development-Guidelines.md`;
- generated `JobManager/Layout/*.rdl` or `JobManager/Layout/*.rdlc` drift before any requested commit.

## Task Generation Rules

Generated tasks must be executable by `$jobman-refactor-dev` without hidden context.

Every task must include:

- unique task ID;
- status;
- type;
- scope;
- dependencies;
- mutation requirement;
- goal;
- acceptance criteria;
- notes or blockers when relevant.

Preserve the rule that only one task may be `In Progress`.

Split broad work before marking it `Ready`. If the split changes priorities or business expectations, use `$grill-me` first.

For implementation tasks, require a task-local Gherkin test plan before production behavior is implemented. For high-risk tasks, require `$grill-me` review of that plan before handoff.

## Contract Steering Rules

Full parity is proven by executable tests, not by a matrix.

When steering contract work:

- keep test names business-focused, not workflow-focused;
- require legacy-vs-legacy harness proof before legacy-vs-new implementation work;
- require full observable table snapshots rather than summary-only comparisons;
- make normalization rules explicit;
- keep dispatch and production-entry tests separate from direct old-vs-new contract tests;
- keep approved bug-fix differences explicit and tied to `Refactor-Strategy.md`;
- make the final gate "contract tests green plus approved bug-fix tests green", not "tasks touched".

## Output Patterns

For status or steering reviews, use:

```markdown
Current State
- ...

Decision Needed
- ...

Recommended Next Step
- ...

Task/Doc Updates
- ...
```

For task generation or task updates, use:

```markdown
New / Updated Tasks
- Txxx: ...

Why This Order
- ...

Open Decisions
- ...
```

Keep findings concrete and tied to files, task IDs, or docs.

## Validation

For docs-only steering edits:

1. Run `git diff --check`.
2. Run `git status --short`.
3. Do not run the AL gate unless AL code or tests changed.

For skill edits:

1. Run the skill validator on the skill folder when available.
2. Check `agents/openai.yaml` still matches the skill purpose.

For commits, only commit when explicitly requested:

1. Revert generated RDL/RDLC drift unless the task explicitly changes reports.
2. Run `git status --short`.
3. Stage only the intended docs/skill files.
4. Commit with a clear planning/workflow message.
