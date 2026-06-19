# al-agentic-dev plugin overview

Composable skills for AL/Business Central agentic development. One feature flows idea → merge through a pipeline of named skills, each owning a specific cut of the work. Skills compose by name; invoke them by typing `/<skill-name>`. A few read-only workers ship as **agents** instead — spawned by name (`al-agentic-dev:<name>`), not typed — so their tool envelope and model tier are enforced, not just described (see Agents below).

## Pipeline

```
/al-grill-adr  →  /al-event-model  →  /al-design     →  /al-scope                →  /al-refine    →  /al-implement   →  /al-code-review  →  /al-user-verification
(CONTEXT,         (event-model.md,    (architecture    (tasks/ folder, slices +    (per-task        (TDD per task,     (gate at slice-      (agent guides the user
 ADRs)             user/API-facing     .md, AL-shape    technical + verify per     task specs)       refactor +         done +               through verify task; flip
                   only, backend-only  only)            user/API-facing slice)                       mutate inner)      feature-done)        done or blocked → /al-steer)
                   skips this step)
```

| Lane | Skills |
|---|---|
| **Side-band** (invoked from any main-pipeline skill) | `al-research` agent, `al-doc-verify` agent, `/al-steer`, `/al-second-opinion`, `/al-feed` |
| **Infrastructure** | `/al-build` (compile, publish, run tests), `/al-debug-logging` (transient `FeatureTelemetry.LogUsage` probes) |
| **Ops** (bracket the feature; run an `/al-build` script + flip task status) | `/al-provision` (`T-001`, refresh the build environment), `/al-validate-breaking-changes` (last, validate against the released baseline) |
| **Shaping** (inside `/al-implement` or standalone on legacy) | `/al-refactor`, `/al-mutate`, `/al-page-script` |
| **Meta** | `/al-agentic-dev-overview` (this skill) |

Slice mechanics: `/al-refine` opens one `ready` task at a time. Technical tasks become `ready-for-implementation`, then `/al-implement` drives them to `done`. When a user/API-facing slice's technical tasks are done, `/al-implement` opens the verify task to `ready`; `/al-refine` writes its `Verification Plan` and flips it to `ready-for-verification`; `/al-code-review` validates that slice before page-script/user-verification. `/al-page-script` generates the slice's bc-replay recording from E2E Journey Examples, then `/al-user-verification` pre-flights the recording batch against a fresh container, runs Contract Examples, and guides you through Journey Examples / Exploration Charters in your own browser before the next slice opens to `ready` for refinement. Backend-only slices skip page-script and user-verification, chaining through `/al-code-review` into the next slice. `/al-scope` brackets the feature with two ops tasks: a `kind: provision` task first (`/al-provision` refreshes the build environment — compiler, symbols, breaking-change baseline) and a `kind: breaking-change` task last (`/al-validate-breaking-changes` checks the feature against the released baseline before merge); both run a script and flip status, bypassing `/al-refine`. At feature-done (every task in feature `done`), `/al-code-review` fires per-feature before merge. Separately, `al-doc-verify` agent checks newly written markdown artifacts for structure, boundary, and sibling consistency before the producer reports gate or hands off.

## Skills

| Skill | Role | When to invoke |
|---|---|---|
| `/al-agentic-dev-overview` | Tour of this plugin: pipeline, skills, persistence, cold-start. | "What is al-agentic-dev?", "show me the pipeline", "where do I start". |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only when a hard-to-reverse business rule earns one. | Idea is rough; you want it grilled before settling intent. |
| `/al-event-model` | User-facing journey: `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). | User- or API-facing feature, after `/al-grill-adr`. Backend-only features skip this. |
| `/al-design` | Feature architecture: `architecture.md`. Module map, BC patterns, R → P → W boundary, brownfield touchpoints, test strategy. | After `/al-event-model` for user/API features, or after `/al-grill-adr` for backend-only. |
| `/al-scope` | Decomposes `architecture.md` into a slice-grouped `tasks/` folder, one file per task, bracketed by a `provision` first task and a `breaking-change` last task. | After `/al-design`. |
| `/al-provision` | Runs the `kind: provision` task: refresh the build environment via `/al-build`'s `provision.ps1`, flip the task `done`/`blocked`. | The feature's first task, or any `kind: provision` task at `ready`. |
| `/al-validate-breaking-changes` | Runs the `kind: breaking-change` task: validate the feature against the released baseline via `validate-breaking-changes.ps1`; a detected break stops for a human. | The feature's last task, once all other work is `done`. |
| `/al-refine` | One task → `Test Specification` or `Verification Plan`. | Before working a specific task. |
| `/al-implement` | TDD per technical task: Unit cases → Integration cases → refactor → mutate. | After `/al-refine` produces a `Test Specification`. |
| `/al-user-verification` | Agent guides you step-by-step through the slice's verify task — it runs containers, publish, pre-flight, and Contract checks; you drive the browser and report what you see. Functional outcomes gate, usability observations → findings/tasks. Gates the next slice. | Verify task is `ready-for-verification` after `/al-refine` wrote a fresh `Verification Plan` and `/al-code-review` ran clean. |
| `/al-refactor` | Improve shape while green. No new behaviour. | After green inside `/al-implement`, or standalone on legacy code. |
| `/al-mutate` | Validate test rigor by injecting mutations one at a time. | Mandatory inside `/al-implement` for non-trivial work, or standalone on legacy before `/al-refactor`. |
| `/al-code-review` | Gate at slice-done and feature-done. Auto-runs `/grill-me` per surviving finding. | Auto-announced by `/al-implement` at slice-done and feature-done. |
| `/al-second-opinion` | Cross-family read-only advisory review (shells to GitHub Copilot CLI, pinned to a GPT model). | Before reconciling non-trivial `Test Specification`, `Verification Plan`, mutation lists, refactor checklists, or verification verdicts. |
| `/al-feed` | Branch-feed writer. Composes one plain-language card (punchline + optional layers) and appends it to the branch's `feed.jsonl`, regenerating `feed.html`. | Handed a brief by a narrating skill at a hand-wired card-firing moment (never the three silent skills). |
| `/al-steer` | Coach and navigator. Reads state, names next step, never edits code. Owns `.out-of-scope/`. Canonical replan venue. | "Where are we?", "what's next?", trigger fired in another skill. |
| `/al-build` | Compile, publish, run tests; writes results to `.output/TestResults/<dirName>/`. | After modifying AL code or tests. Required gate before commit. |
| `/al-debug-logging` | Temporary `DEBUG-*` `FeatureTelemetry.LogUsage` probes; read `telemetry.jsonl`; remove probes. Final state: zero `DEBUG-*` in tree. | Runtime behaviour diverges from source and tests can't reveal which path ran. |
| `/al-page-script` | Generate the slice's bc-replay recording (`.yml`) from the verify task's E2E Journey Examples; example-by-example inner loop against a fresh container; commits the file on green. Produces the recording `/al-user-verification` pre-flights. | After `/al-code-review` per-slice stamps `review: clean` on the verify task (user-facing slice only). |

## Agents

Read-only workers spawned by name (`al-agentic-dev:<name>`), not typed as `/commands`. The agent definition pins the tool envelope and model tier, so the read-only posture and cheap-model choice are enforced and ship to consumer repos.

| Agent | Role | Spawned by |
|---|---|---|
| `al-doc-verify` | Markdown integrity verifier (haiku). Checks canonical artifact structure and sibling consistency; blocks structural/boundary failures, warns wording or ambiguity. Returns a `verdict=` line; the caller fires any feed card. | `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine` after a canonical markdown write, or `/al-steer` after a `tasks/` restructure — before the gate report or downstream handoff. |
| `al-research` | Verify BC specifics from authoritative sources; the evidence bar's escalation seat (sonnet). Quotes, never paraphrases; cross-family before returning. | Any pipeline skill when sources disagree, a fuzzy question needs framing + cross-family verification, or a fact lands in a durable design artifact. Single-fact lookups go direct per the evidence bar. |
| `al-review-lens` / `al-review-lens-bc` | One focused read-only AL/BC review pass; the `-bc` variant adds bc-code-intelligence reach. Returns labeled findings; the orchestrator dedupes and scores. | `/al-code-review` (6 lenses) and `/al-refactor` (4 lenses), spawned per-lens with a goal + the diff. |

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-steer` (out-of-scope). `al-doc-verify` agent checks `CONTEXT.md` and domain ADR writes before handoff; `.out-of-scope/` is outside the document gate.
- **Branch-scoped, per in-flight feature**: `specs/<NNN>-<slug>/event-model.md` (present for user/API-facing features) + `architecture.md` + a `tasks/` folder. Slug matches the current git branch.

The `tasks/` folder holds one file per task plus a `000-feature.md` header (Goal + slice intent, no status). Each per-task file is `NNN-T-MMM-<slug>.md`: the `NNN` filename prefix is the run order (`ls tasks/` lists tasks as they execute, gapped by 10), `T-MMM` is a stable locator id. State and graph live in YAML frontmatter at the top of each file: `task:`, `status:`, `slice:`, `kind:`, `depends_on:`, `refactors:`, `fixes:`. Status values: `ready`, `ready-for-implementation`, `ready-for-verification`, `blocked`, `done`. `ready` means ready for `/al-refine`; executable tasks use `ready-for-implementation` or `ready-for-verification`. `T-MMM` ids monotonic, never reused. `kind: verify` marks the per-slice user-verification task; `kind: technical` marks technical tasks; `kind: provision` / `kind: breaking-change` mark the bracketing ops tasks (run a script, flip status, no `/al-refine`). Verify tasks gain a transient `review: clean` frontmatter field when `/al-code-review` per-slice runs clean; it strips on any status flip or when new technical work opens in the slice. There is no index file — the filesystem is the manifest, the board is grepped on demand and rendered by `/al-steer`.

## Cold-start: where do I begin from `main`?

You have an AL repo, no `specs/<NNN>-<slug>/` yet, on the default branch. The chain starts at:

- **User- or API-facing feature** → `/al-grill-adr` (grill the idea) → `/al-event-model` (settle the user-facing journey; creates the branch and spec folder) → `/al-design` → `/al-scope` → `/al-refine` on first task → `/al-implement`.
- **Backend-only feature** (no user/API surface) → `/al-grill-adr` → `/al-design` (skips event-model; creates the branch and spec folder) → `/al-scope` → `/al-refine` on first task → `/al-implement`.

`al-doc-verify` agent runs inside the document-writing skills after each canonical markdown write, not as a standalone cold-start step.

If the idea is already crystallised, skip `/al-grill-adr`. Most features benefit from it.

## State-aware navigation

This overview is static; it does not read your branch, the `tasks/` folder, or recent commits. For "where am I now?" / "what should I do next?" / "T-007 is blocked, walk me through it", invoke `/al-steer`. It reads state, names the next step, routes to the right skill.
