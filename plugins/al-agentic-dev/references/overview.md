# al-agentic-dev plugin overview

Composable skills for AL/Business Central agentic development. One feature flows idea → merge through a pipeline of named skills, each owning a specific cut of the work. Skills compose by name; invoke them by typing `/<skill-name>`.

## Pipeline

```
/al-grill-adr  →  /al-event-model  →  /al-design     →  /al-scope                →  /al-refine    →  /al-implement   →  /al-code-review  →  /al-user-verification
(CONTEXT,         (event-model.md,    (architecture    (tasks.md, slices +         (per-task        (TDD per task,     (gate at slice-      (user walks slice's
 ADRs)             user/API-facing     .md, AL-shape    technical + verify per     scenarios)        refactor +         done +               verify task; flip done
                   only, pure backend  only)            user/API-facing slice)                       mutate inner)      feature-done)        or blocked → /al-steer)
                   skips this step)
```

| Lane | Skills |
|---|---|
| **Side-band** (invoked from any main-pipeline skill) | `/al-research`, `/al-steer`, `/al-second-opinion` |
| **Infrastructure** | `/al-build` (compile, publish, run tests), `/al-debug-logging` (transient `FeatureTelemetry.LogUsage` probes) |
| **Shaping** (inside `/al-implement` or standalone on legacy) | `/al-refactor`, `/al-mutate`, `/al-page-script` |
| **Meta** | `/al-agentic-dev-overview` (this skill) |

Slice mechanics: `/al-implement` works through one slice's technical tasks, then `/al-code-review` fires automatically at slice-done. For user/API-facing slices, `/al-user-verification` walks the user through the slice's verify task before the next slice opens. Pure-backend slices skip user-verification and chain directly into the next slice. At feature-done (every task in feature `done`), `/al-code-review` fires per-feature before merge.

## Skills

| Skill | Role | When to invoke |
|---|---|---|
| `/al-agentic-dev-overview` | Tour of this plugin: pipeline, skills, persistence, cold-start. | "What is al-agentic-dev?", "show me the pipeline", "where do I start". |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only when a hard-to-reverse business rule earns one. | Idea is rough; you want it grilled before settling intent. |
| `/al-event-model` | User-facing journey: `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). | User- or API-facing feature, after `/al-grill-adr`. Pure-backend features skip this. |
| `/al-design` | Feature architecture: `architecture.md`. Module map, BC patterns, R → P → W boundary, brownfield touchpoints, test strategy. | After `/al-event-model` for user/API features, or after `/al-grill-adr` for pure-backend. |
| `/al-scope` | Decomposes `architecture.md` into a slice-grouped, ZOMBIES-ordered task list in `tasks.md`. | After `/al-design`. |
| `/al-refine` | One task → numbered scenarios. Technical task → Gherkin for `/al-implement`. Verify task → user test plan for `/al-user-verification`. | Before working a specific task. |
| `/al-implement` | TDD per task: red → green → refactor → mutate. | After `/al-refine` produces scenarios for a technical task. |
| `/al-user-verification` | User walks the slice's verify task. Per-step pass/fail capture; gates the next slice. | Verify task ready (after `/al-code-review` flipped it from `blocked`). |
| `/al-refactor` | Improve shape while green. No new behaviour. | After green inside `/al-implement`, or standalone on legacy code. |
| `/al-mutate` | Validate test rigor by injecting mutations one at a time. | Mandatory inside `/al-implement` for non-trivial work, or standalone on legacy before `/al-refactor`. |
| `/al-code-review` | Gate at slice-done and feature-done. Auto-runs `/grill-me` per surviving finding. | Auto-announced by `/al-implement` at slice-done and feature-done. |
| `/al-research` | Verify BC specifics from authoritative sources. | When prior AL/BC knowledge is unverified and a downstream skill needs the fact. |
| `/al-second-opinion` | Cross-runtime read-only advisory review. | Before reconciling non-trivial plans, scenarios, mutation lists, or refactor checklists. |
| `/al-steer` | Coach and navigator. Reads state, names next step, never edits code. Owns `.out-of-scope/`. Canonical replan venue. | "Where are we?", "what's next?", trigger fired in another skill. |
| `/al-build` | Compile, publish, run tests; writes results to `.output/TestResults/<dirName>/`. | After modifying AL code or tests. Required gate before commit. |
| `/al-debug-logging` | Temporary `DEBUG-*` `FeatureTelemetry.LogUsage` probes; read `telemetry.jsonl`; remove probes. Final state: zero `DEBUG-*` in tree. | Runtime behaviour diverges from source and tests can't reveal which path ran. |
| `/al-page-script` | Author or validate a BC Page Scripting recording (`.yml` replayed by `@microsoft/bc-replay`). | Web-client UI smoke or regression recording needed. |

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-design` (design ADRs), `/al-steer` (out-of-scope).
- **Branch-scoped, per in-flight feature**: `specs/<NNN>-<slug>/event-model.md` (present for user/API-facing features) + `architecture.md` + `tasks.md`. Slug matches the current git branch.

`tasks.md` carries one HTML-comment status line per task: `<!-- task=T-NNN status=ready slice=<slug> kind=technical -->`. Status values: `ready`, `in-progress`, `done`, `blocked`. `T-NNN` IDs monotonic, never reused. `kind=verify` marks the per-slice user-verification task; `kind=technical` marks technical tasks.

## Cold-start: where do I begin from `main`?

You have an AL repo, no `specs/<NNN>-<slug>/` yet, on the default branch. The chain starts at:

- **User- or API-facing feature** → `/al-grill-adr` (grill the idea) → `/al-event-model` (settle the user-facing journey; creates the branch and spec folder) → `/al-design` → `/al-scope` → `/al-refine` on first task → `/al-implement`.
- **Pure-backend feature** (no user surface) → `/al-grill-adr` → `/al-design` (skips event-model; creates the branch and spec folder) → `/al-scope` → `/al-refine` on first task → `/al-implement`.

If the idea is already crystallised, skip `/al-grill-adr`. Most features benefit from it.

## State-aware navigation

This overview is static; it does not read your branch, `tasks.md`, or recent commits. For "where am I now?" / "what should I do next?" / "T-007 is blocked, walk me through it", invoke `/al-steer`. It reads state, names the next step, routes to the right skill.
