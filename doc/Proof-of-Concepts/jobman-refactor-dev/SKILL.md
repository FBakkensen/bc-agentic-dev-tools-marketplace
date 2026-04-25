---
name: jobman-refactor-dev
description: Repo-specific JobManager refactor implementation workflow. Use when working on the new calculation implementation, picking or updating Doc/Refactor-Implementation/Tasks.md tasks, enforcing strict Red-Green-Refactor-Mutate development, running AL build gates, validating tests with manual AL mutation testing, updating task status, or deciding when to use grill-me for blockers.
---

# JobMan Refactor Dev

Use this skill for implementation work on the JobManager calculation refactor.

This skill is procedural. It does not define the business contract or architecture. Read the live repo docs when needed:

- `Doc/Refactor-Implementation/Refactor-Strategy.md`
- `Doc/Refactor-Implementation/Design-Brief.md`
- `Doc/Refactor-Implementation/Development-Guidelines.md`
- `Doc/Refactor-Implementation/Tasks.md`

## Preflight

Before selecting or starting a task:

1. Run `git status --short`.
2. If unrelated changes exist, do not overwrite them. Ask the user if they affect the requested work.
3. Verify `git config --get core.hooksPath` is `.githooks`; if not, configure it.
4. Read `Doc/Refactor-Implementation/Tasks.md`.
5. Read the task-specific sections of the strategy/design docs.
6. Confirm the task does not require changing frozen legacy `CU 6182780 JobManTimeCalculation` unless the task explicitly says so.

## Research Precedence

Prefer local and Business Central specific sources over generic web search.

Before using `bc-code-intel` in a session:

1. Use `tool_search` if the needed BC Code Intelligence tools are not loaded.
2. Call `set_workspace_info` with the repo root and available MCP IDs. Include `bc-code-intel`, `microsoft_learn`, `al`, and `al-object-id-ninja` when they are available.
3. Treat the initialized workspace context as required for specialists, workflows, project layers, and ecosystem-aware recommendations.

Use this order:

1. Repo source, live docs, `Tasks.md`, and historical docs.
2. `bc-code-intel` MCP tools for Business Central development knowledge, specialists, and workflows:
   - `find_bc_knowledge` to discover relevant topics, specialists, and workflows.
   - `get_bc_topic` for detailed BC guidance and examples.
   - `ask_bc_expert` for specialist guidance such as architecture, legacy analysis, code review, testing, performance, security, configuration, and documentation.
   - `workflow_list`, `workflow_start`, `workflow_progress`, and `workflow_status` for systematic code review, proposal review, performance audit, security audit, onboarding, migrations, and upgrades.
   - `analyze_al_code` for AL quality, performance, security, pattern analysis, and workflow recommendations. Pass `workspace_path`, `file_path`, or `file_paths`; do not paste file contents when the MCP can read files directly.
   - `extract_bc_snapshot` for `.snap` debug traces when available.
   - Layer tools only when maintaining BC Code Intelligence knowledge layers, not for normal implementation work.
3. `microsoft_learn` MCP tools for official Microsoft and Business Central AL documentation, syntax, object properties, trigger semantics, locking guidance, platform behavior, and current best practices.
4. Generic web search only when the repo and MCP sources cannot answer the question.

When generating AL or Business Central code that depends on platform behavior, use official Microsoft Learn material through the `microsoft_learn` tools before relying on memory. If a first implementation attempt fails because of uncertain AL or BC platform behavior, research with Microsoft Learn before trying again.

When sources conflict, the repo docs define the JobManager business contract, Microsoft Learn defines platform semantics, and BC Code Intelligence guides BC-specific practices, specialists, and systematic workflows.

Before every commit:

1. Revert generated report layout drift unless the task explicitly changes reports:
   - `JobManager/Layout/*.rdl`
   - `JobManager/Layout/*.rdlc`
2. Run `git status --short`.
3. Do not commit staged layout files unless the user explicitly approves bypassing the hook.

## AL Build Gate And Sandbox

Use the `al-build` skill for AL compilation and test execution.

Always run AL build/test commands with escalation. The AL gate uses Docker/Business Central test containers, and the Codex desktop sandbox can block or misreport Docker access. Running escalated avoids false failures such as missing container images or denied Docker pipe access.

Do not treat these as valid red/green evidence:

- sandbox Docker permission errors;
- `bctest:snapshot` reported missing from inside the sandbox without an escalated Docker check;
- failures before the selected test starts running.

Valid red/green evidence requires the AL apps to compile and the selected test codeunit to run in the BC container.

## Task Selection

Use `Doc/Refactor-Implementation/Tasks.md` as the living queue.

Rules:

- Only one task may be `In Progress`.
- If a task is already `In Progress`, continue it unless the user directs otherwise.
- Otherwise pick the first `Ready` task whose dependencies are satisfied.
- If the selected task is too broad, split it before implementation.
- If new knowledge creates more work, add future tasks or notes to existing future tasks.
- If blocked by a business decision, architecture decision, or unclear parity rule, stop and use `$grill-me`.

When starting a task:

- Set `Status: In Progress`.
- Add a short `Progress` note with date and intent.
- For implementation tasks, add a task-local `Test Plan` section before changing production code.
- Keep the task update in the same working set as the task unless the user asks for a separate planning commit.

## Task-Local Test Plan

Every implementation task must have a written test plan in `Tasks.md` before production behavior is implemented.

Use Gherkin-style planning text. This is a planning format, not a requirement to introduce a Gherkin runner or duplicate every line as test comments.

The agent drafts the plan first. Before implementing production behavior, use `$grill-me` with the user to review the test plan when the task:

- changes business behavior;
- changes persistence or side effects;
- changes routing or rollout behavior;
- touches strict parity or an approved bug fix;
- establishes a pattern future tasks will copy;
- has any unclear expected behavior.

T004, the initial replacement scaffold, must be reviewed with `$grill-me` because it establishes the first implementation pattern. Purely mechanical follow-up scaffold tasks may proceed without user review only when every nontrivial group is explicitly `Not applicable` and the reason is recorded.

Required groups:

- Internal unit behavior.
- Positive behavior.
- Negative / guard behavior.
- Boundary / edge cases.
- Persistence or side effects.
- Explicit non-goals.
- Mutation targets.

Use this shape:

```markdown
### Test Plan

#### Internal Unit Behavior

Scenario: Short internal behavior name
Given ...
When ...
Then ...

#### Positive Behavior

Scenario: Short behavior name
Given ...
When ...
Then ...

#### Negative / Guard Behavior

Scenario: Short guard name
Given ...
When ...
Then ...

#### Boundary / Edge Cases

Scenario: Short boundary name
Given ...
When ...
Then ...

#### Persistence / Side Effects

Scenario: Short persistence name
Given ...
When ...
Then ...

#### Explicit Non-Goals

- ...

#### Mutation Targets

- Changing/removing ... must fail ...
- Expected killing layer: internal unit, old-vs-new snapshot, approved bug-fix acceptance, or deliberate combination.
```

For tiny scaffold tasks, groups may explicitly say `Not applicable`, but the agent must state why.

## Red-Green-Refactor-Mutate

Every implementation task uses this lifecycle.

### 1. Red

- Write or update the failing test first.
- Prefer internal unit tests for new calculation modules.
- Use integration/snapshot tests for persisted table output.
- Use acceptance tests for approved bug fixes.
- A compiler error is not a red test. Red-phase evidence requires the app and test app to compile, and the selected test to fail at runtime for the intended behavioral reason.
- If a test cannot compile because the required production object, procedure, enum, table, or field does not exist yet, first add the smallest inert scaffold needed for compilation. The scaffold must not add real business behavior or route production data to the new implementation.
- Run the smallest useful test target and confirm the runtime failure is for the intended reason.
- If the test passes before implementation, fix the test before writing production code.

### 2. Green

- Implement the smallest production change that makes the test pass.
- Keep the implementation aligned with the design brief.
- Run the targeted test, then the relevant broader AL gate.
- Do not route production data to the new implementation.

### 3. Refactor / Simplify

- Review the new test and implementation.
- Simplify names, structure, duplication, and boundaries.
- Remove temporary debug instrumentation unless the task explicitly keeps it.
- Re-run tests after simplification.
- Update `Tasks.md` with discoveries, splits, or future notes.

### 4. Pre-Mutation Commit

- Run the required AL gate.
- Revert RDL/RDLC drift.
- Commit the green, simplified implementation before mutation testing.
- This commit is the safe baseline for mutation reverts.

### 5. Mutation

Use the `al-mutation-test` workflow.

Mandatory rules:

- Start mutation only from a clean working tree.
- Run the full AL gate once before mutation if it has not just passed.
- Plan manual semantic mutations against production code touched by the task.
- For each mutation, record the expected killing layer before running it:
  - internal unit test for module logic, domain state, schedule/time decisions, interval splitting, diagnostics, allocation rules, counter decomposition, and writer command shape;
  - old-vs-new snapshot test for persisted fields, row counts, line ordering, trigger-mode effects, cleanup, and cross-module integration;
  - approved bug-fix acceptance test for intentional differences from legacy;
  - deliberate combination when more than one layer is expected to fail.
- For each mutation:
  - apply exactly one semantic change;
  - run the full AL gate;
  - classify killed, survived, or build-failure;
  - record the actual killing layer when the mutation is killed;
  - revert the mutated production file;
  - revert RDL/RDLC drift;
  - verify the tree is clean before the next mutation.
- If a domain/module mutation is killed only by an old-vs-new snapshot test, classify whether that is acceptable integration-only behavior or a unit-test gap.
- Non-equivalent survivors block the task until a test is added, the implementation is fixed, or the behavior is explicitly accepted.
- Write or update the mutation report under `.output/mutation-report/`.

### 6. Completion Commit

- Update `Tasks.md`:
  - status;
  - commit hash for the pre-mutation implementation;
  - mutation result;
  - final notes;
  - any added/split future tasks.
- Run a final relevant gate if code changed after mutation.
- Revert RDL/RDLC drift.
- Commit task completion metadata and any post-mutation fixes.

## Blockers

Use `$grill-me` when:

- a business rule is unclear;
- a task would change the approved bug-fix list;
- strict parity conflicts with clean design;
- mutation survivors appear genuine but the right expected behavior is unclear;
- the task scope should be split in a way that changes priorities;
- implementation requires modifying frozen legacy behavior.

Record the blocker in `Tasks.md` before asking.

## Commit Policy

Default per implementation task:

- Commit 1: green and simplified implementation before mutation.
- Commit 2: mutation validation, task status, and any mutation-driven fixes.

Small docs-only tasks may use one commit.

Never include generated RDL/RDLC drift in a commit unless the task explicitly changes report layouts and the user approves the hook bypass.
