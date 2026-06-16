# al-agentic-dev

Composable skills for AL/Business Central agentic development.

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**, markdown: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-steer` (out-of-scope). `/al-doc-verify` checks `CONTEXT.md` and domain ADR writes before handoff; `.out-of-scope/` is outside the document gate.
- **Branch-scoped, per in-flight feature**, markdown: `specs/<NNN>-<slug>/event-model.md` (user-facing journey, present for user/API-facing features) + `architecture.md` + a `tasks/` folder. Slug matches the current git branch.

The `tasks/` folder is the per-feature task bus: one file per task plus a `000-feature.md` header (Goal + slice intent, no status, no rows). Each per-task file is `NNN-T-MMM-<slug>.md` — the `NNN` filename prefix is the run order (gapped by 10; `ls tasks/` = run order; the sole order owner), `T-MMM` is a monotonic, never-reused locator id. State and graph live in YAML frontmatter at the top of each file, single source of truth: `task:`, `status:`, `slice:`, `kind:`, `depends_on:`, `refactors:`, `fixes:`. `status:` values are `ready`, `ready-for-implementation`, `ready-for-verification`, `blocked`, `done`. `ready` means the task is ready for `/al-refine` only. `ready-for-implementation` means a technical task has a fresh `Test Specification`. `ready-for-verification` means a verify task has a fresh `Verification Plan`. `blocked` means dependency or context is missing. `done` means downstream evidence exists. `task:` ids are monotonic and never reused. `slice: <slug>` groups tasks by one `event-model.md` timeline step (user-facing) or `architecture.md` slice (backend-only); `kind: verify` marks the per-slice verification task, `kind: technical` marks technical tasks. Two **ops kinds** bracket the feature: `kind: provision` (first, `slice: provision`) and `kind: breaking-change` (last, `slice: breaking-change`) on reserved non-feature slugs; they carry no proof artifact, bypass `/al-refine`, and run `ready` → `done` (or `blocked`) via `/al-provision` / `/al-validate-breaking-changes`. Each `blocked` → `ready` flip has a named owner like the cross-slice gate: `/al-provision` opens the first slice on its `done`; the skill landing the feature's final terminal task `done` (`/al-user-verification` last verify, or `/al-code-review` last backend slice) opens the breaking-change task. `review: clean` is an optional transient frontmatter field on verify tasks: written only by `/al-code-review` on a clean per-slice review (the durable evidence `/al-page-script`, `/al-user-verification`, and `/al-steer` read — `ready-for-verification` alone reads identically before and after review), stripped in the same Edit by any flip off `ready-for-verification` and by any skill opening a technical task in the slice. There is no index file: the filesystem is the manifest, the board is grepped on demand and rendered by `/al-steer`. `/al-doc-verify` checks the written markdown artifacts before handoff.

**Branch creation is shared between `/al-event-model` and `/al-design`.** The first per-feature skill to run from `main` creates the branch and `specs/<NNN>-<slug>/`. For user/API-facing features that runs `/al-event-model` first; backend-only features skip `/al-event-model` and `/al-design` does it.

## Pipeline

User-facing pipeline diagram, skills catalogue, and cold-start guidance live in [`references/overview.md`](references/overview.md). That file is the single source of truth, emitted verbatim by `/al-agentic-dev-overview`. The slice-cycle prose below carries dev-time editing depth (gate flip mechanics, suppression rules) not duplicated in the tour.

Slice cycle: `/al-refine` selects one named `ready` technical task, writes its `Test Specification` from the current app/tests, and flips it to `ready-for-implementation`. `/al-implement` works through `ready-for-implementation` technical tasks in Unit-first order and flips each to `done` only after downstream evidence exists.

When the last user/API-facing technical task lands, `/al-implement` opens the slice verify task from `blocked` to `ready`. `/al-refine` writes the `Verification Plan` and flips to `ready-for-verification`. `/al-code-review` runs per-slice; a clean review stamps `review: clean` in the verify task's frontmatter. If its `/grill-me` auto-loop materializes new technical tasks, `/al-refine` writes fresh proof before `/al-implement` resumes and `/al-code-review` re-runs.

**Page-script (user-facing slices).** `/al-page-script` generates `pagescripts/recordings/<NNN>-<slug>__<slice>.yml` from `Scope: E2E` Journey Examples — example-by-example inner loop, one fresh container per invocation, commits on green. A page-script red that proves a production bug leaves verify task status unchanged and routes to `/al-steer`. `/al-steer` opens the integration fix task and strips `review: clean` from the verify task (the only signal re-routing the slice through `/al-code-review`); `/al-implement` drives the fix red-first before the recording re-greens.

**User verification (user-facing slices).** `/al-user-verification` runs three spawns:

- **Spawn #1.** Fresh container → publish → regression batch (`pagescript-replay.ps1`, every `pagescripts/recordings/*.yml`). Green → spawn #2. Red → verify task `blocked`, route `/al-steer` (trigger #4 prior-slice red, trigger #8 current-slice red); spawn #3 exits.
- **Spawn #2.** Fresh container → publish → Contract Examples (agent-run) → guided user walk. Agent instructs one step at a time, asks observed value before naming expected (ask-before-reveal). User drives Journey Examples and Exploration Charters; functional outcomes gate, subjective usability → findings/tasks. `/al-second-opinion` reviews verdict coverage. Red → verify task `blocked`, route `/al-steer` (trigger #8).
- **Spawn #3.** Always runs at exit regardless of outcome — leaves a fresh container for the next consumer.

Verify pass → verify task `done`, next slice tasks `ready`, loop continues. Feature-done → `/al-code-review` per-feature before merge.

**Backend-only.** No `event-model.md`, no page-script, no user verification. Chain: refine → implement → code-review → next slice.

## Skills

User-facing catalogue (20 skills, role + when-to-invoke) lives in [`references/overview.md`](references/overview.md). Edit it in lockstep when adding, removing, renaming, or repurposing a skill.

Skills compose by name. When you change a skill, scan the others for cross-references and update in lockstep. Cross-skill orchestration depth (gate flip mechanics, replan triggers, slice-cycle suppression rules) lives in the owning skill's `SKILL.md` and in the dev-time slice-cycle paragraph above; the user-facing overview stays tour-shape.

## Replan

`/al-steer` is the canonical replan venue. The eight triggers as named patterns to learn: task too big, hidden pre-req, wrong order, sibling now wrong, new behaviour emerges, architecture decomposition wrong, goal drift, verification failed. Replan checks in `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification` map the trigger to response per situation: when the trigger means the plan is invalid as planned, flip `status:` to `blocked` and route to `/al-steer`; when the trigger means new info that doesn't invalidate, note it inside the task and continue. Trigger #8 is binary: a failed user verification always flips the verify task to `blocked` and routes; there is no absorb-and-continue variant. `/al-code-review` findings themselves are NOT replan signals; the skill auto-invokes `/grill-me` per finding for triage into new tasks or notes on future tasks.

## Editing rules

- **Naming, BC vocabulary, and the evidence bar live in `references/voice-contract.md`.** One runtime home; writing skills read it before writing, and skills that spawn sub-agents (`/al-refactor`, `/al-code-review`) carry the vocabulary line verbatim in every spawn prompt — sub-agents inherit neither hooks nor CLAUDE.md. Skills run in projects without this CLAUDE.md present. Do not lean on it.
- **No inline citations in durable artifacts.** `(see: file.al:120)` is forbidden in `architecture.md`, the per-task files under `tasks/`, `CONTEXT.md`, ADRs, `.out-of-scope/`. Names are the citation; `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address. Future readers grep; the IDE gives line numbers for free. One carve-out: `Researched: <fact> → <source>` provenance bullets in a task's `Contract notes`, written at `/al-implement` reconcile, read by `/al-code-review` — without them, skipped research is indistinguishable from research that ran. Location pointers stay forbidden.
- **Spec artifacts are text-only.** Name relationships in prose; gates in the `depends_on:` frontmatter list on each task file. No mermaid fences; Claude Desktop's markdown preview and other viewers lack mermaid support, and a second encoding alongside text just drifts.
- **Spec artifacts are pure markdown.** Visual polish is a separate dev-server concern; the spec is text.
- **`architecture.md` is reshape-only.** Written by `/al-design`, read by everyone downstream. Never edit in place; re-run `/al-design`. No surgical-edit contract.
- **Each per-task file carries one surgical-edit contract.** Maintaining skills find a task by its `T-MMM` filename (or `task:` in frontmatter) and flip its `status:` frontmatter field, stripping `review: clean` in the same Edit when the file carries it. `/al-scope` writes `slice: <slug>` and `kind:` (`technical` / `verify` / `provision` / `breaking-change`) on every task; downstream skills read these but do not change them (a slice or kind change is replan work, routes through `/al-steer`). `/al-code-review` is the sole writer of `review: clean`. There is no `[ ]`/`[x]` heading marker; the `status:` frontmatter field is the only state, and the `status:` line is the byte the Edit anchors on. See `references/markdown-spec-discipline.md`.
- **New skills need a stated gap.** _Avoid_: spinning up a skill that an existing one can absorb, or that fits as a brief note inside an existing task file, an `/al-research` finding, or a side-band reference. Propose only when no existing skill fits, and say so in one line.
- **Express intent and rationale, not enumerated rules with skip conditions.** SKILLs and references state *why a discipline exists and what problem it solves*; the agent maps rationale to situation. Slot prescriptions, `_When earned:_` / `_Skip when:_` enumerations, and templates the agent must fill are rejected by name. The agent is capable of shaping output per feature.
- **`telemetry.jsonl` is a producer/consumer contract between `/al-build` and `/al-debug-logging`.** `/al-build`'s `test.ps1` produces `.output/TestResults/<dirName>/telemetry.jsonl`; `/al-debug-logging`'s Inspect step reads it. Path, per-app subfolder layout, and `FeatureTelemetry.LogUsage` JSON shape are coupled. Change one side, scan the other in the same edit. The coupling lives here because it crosses skill boundaries; per-skill CLAUDE.md cannot enforce it alone.

## Reference layout

Two tiers, on purpose.

- **Plugin-level shared**, `plugins/al-agentic-dev/references/`. Cross-skill resources read by more than one skill. Path from any SKILL.md: `${CLAUDE_SKILL_DIR}/../../references/<file>`.
- **Skill-local**, `plugins/al-agentic-dev/skills/<skill>/references/`. Resources only one skill reads. Path from that SKILL.md: `${CLAUDE_SKILL_DIR}/references/<file>`.

**Rule**: a resource read by two or more skills lives in plugin-level `references/`. Skill-local references stay inside the skill that owns them. DO NOT put a shared resource inside one skill's folder; owner ambiguity invites drift.

| File | Tier | Notes |
|---|---|---|
| `overview.md` | plugin-level | user-facing tour: pipeline diagram, 20-skill catalogue (role + when-to-invoke), persistence layers paragraph, cold-start guidance, pointer to `/al-steer` for state-aware nav; emitted verbatim by `/al-agentic-dev-overview`; edit in lockstep with any skill addition / removal / rename |
| `voice-contract.md` | plugin-level | non-voice rules: BC vocab, names-as-citation, evidence bar (citation chain: names → workspace, constructs → fetched topic, `/al-research` escalation, `Contract notes` trace), lists-of-findings, tables-of-facts, chat carve-out, no-workflow-chatter, 4 chat shape skeletons (Opener / Gate report / Answer / Stop); style itself lives at top of each SKILL.md as a one-line Style declaration; read by every skill that writes prose or AL names |
| `testability.md` | plugin-level | three-phase decoupling, three default seams (IEnvironment / IApiRequest / IFinance), five-kind test-double taxonomy with AL code shapes; read by `/al-design`, `/al-implement`, `/al-refactor` |
| `test-specification.md` | plugin-level | `Test Specification` / `Verification Plan` grammar: New and Modified Objects, Expected Behaviors, Decision Matrix, AAA cases, Contract notes, Out of automated reach, scopes, traceability, closeout summaries with mutation verdict table; read by `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, `/al-user-verification` |
| `tdd.md` | plugin-level | three layers of trust, three laws, five phases, Unit-first execution, mutation operators + revert cycle, no-touch invariants; read by `/al-implement`, `/al-mutate` |
| `test-strategy.md` | plugin-level | test-execution pyramid mapped to the BC tech stack (Unit=AL-Runner, Integration=container+TestPage, E2E=page-script, Contract=client/harness, Exploration=guided user walk); push-down / oracle-problem / checking-vs-testing feedback rules; frames the verification skills (the *execution* axis, distinct from `tdd.md`'s *cycle* axis); read by `/al-build`, `/al-implement`, `/al-mutate`, `/al-refine`, `/al-page-script`, `/al-user-verification` |
| `test-layout.md` | plugin-level | two-peer-test-app layout (`unit-tests/` + `integration-tests/`, no dependency edge, doubles per app), placement rule ("AL Runner-runnable iff" — reclassify, never relax), AL Runner capability map (runs / auto-stubs / throws, provenance-dated), container `TestIsolation = Codeunit` semantics, `TransactionModel::AutoCommit` false-pass rule, authoring contract (mandatory attributes, `Initialize()` guard, handlers on the test codeunit, integration-library discipline incl. duplicate-before-share); the *placement* axis, distinct from `test-strategy.md`'s *execution* axis and `tdd.md`'s *cycle* axis; read by `/al-scope`, `/al-refine`, `/al-implement`, `/al-refactor` (carried into lens spawn prompts when the diff touches tests) |
| `notes-discipline.md` | plugin-level | what lives in the per-task file vs commit / ADR / `.out-of-scope/`; the eight replan triggers as named patterns; read by skills that write the `tasks/` folder |
| `markdown-spec-discipline.md` | plugin-level | pointer to `examples/`, the `tasks/` folder shape, surgical-edit floor (`status:` frontmatter field per task file; `task:` + `slice:` + `kind:` + edge lists alongside it), status-flip Edit shape; read by `/al-design`, `/al-event-model`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-code-review`, `/al-user-verification`, `/al-mutate`, `/al-steer` |
| `examples/` (folder) | plugin-level | populated example artifacts (`event-model.example.md`, `architecture.example.md`, and a `tasks/` folder of frontmatter task files); pattern-match source for writing skills |
| `cross-branch-numbering.md` | plugin-level | algorithm for picking `NNN` (spec folders) and `NNNN` (ADRs) across parallel branches; read by `/al-design`, `/al-event-model`, `/al-grill-adr` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue; read by `/al-design` |
| `bc-code-intelligence-dispatch.md` | plugin-level | bc-code-intelligence MCP call pattern (`find_bc_knowledge` → drop-noise → `get_bc_topic`), noise drop-list, relevance scales; read by `/al-implement` (write-time construct lookup), `/al-refactor`, `/al-code-review`, `/al-research` |
| `LANGUAGE.md` | plugin-level | architectural vocabulary (incl. Connascence, CQS), testability pillars; read by `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-refactor`, `/al-code-review` |
| `CONTEXT.template.md` | plugin-level | template materialised into the target repo's `CONTEXT.md` |
| `adr.template.md` | plugin-level | template materialised into the target repo's `docs/adr/NNNN-<slug>.md` |
| `out-of-scope.template.md` | `/al-steer`-local | template materialised into `.out-of-scope/<concept>.md` |
| `legacy-refactor-plan.md` | `/al-refactor`-local | reference plan for legacy code without tests |

Templates are materialised lazily on first need by the owning flow. `markdown-spec-discipline.md` is read but never materialised; it is a discipline reference, not a template.

Cross-skill paths within this plugin (when reaching into another skill's local references): `${CLAUDE_SKILL_DIR}/../<skill>/references/<file>`. Reach for plugin-level first; cross-skill paths are a smell to be migrated.

## Skill-only runtime

**Rule**: Ship runtime behavior as skills only. DO NOT add Claude-only plugin agents or Codex-invisible runtime prompts. Put reusable runtime rules in `SKILL.md` or in a `references/*.md` file a skill explicitly reads.

The two former agent-shaped workflows now live as skills:

- **`skills/al-mutate/SKILL.md`**, mutate-build-revert cycle, mutation kinds, survivor classification, BC safety.
- **`skills/al-second-opinion/SKILL.md`** is the contract; **`skills/al-second-opinion/scripts/Invoke-AlSecondOpinion.ps1`** is the execution. Dispatched by runtime. `$env:CLAUDECODE -eq '1'` → `codex exec --sandbox read-only --skip-git-repo-check --color never --json --enable fast_mode -m gpt-5.4 -c model_reasoning_effort=low`. Else → `claude -p --output-format json --no-session-persistence --disable-slash-commands --strict-mcp-config '{}' --model sonnet --effort low --tools ""`. 600s timeout via `Start-Job` / `Wait-Job`. Skip lines name the target CLI. SKILL.md documents the sandbox flags so the security envelope stays visible without reading the script. **Windows-only**; `Start-Job` / `Wait-Job` targets pwsh on Windows; portability is a future concern.

## Layout

```
references/                      # Plugin-level shared, read by ≥2 skills, or cited by shared templates
├── overview.md                  # User-facing tour: pipeline + 20-skill catalogue + persistence + cold-start; emitted by /al-agentic-dev-overview
├── voice-contract.md            # Non-voice rules + evidence bar + 4 chat shape skeletons; voice declared inline at top of each SKILL.md
├── testability.md               # Three-phase decoupling, three default seams, five-kind test-double taxonomy
├── test-specification.md        # Test Specification + Verification Plan grammar (incl. New and Modified Objects, Contract notes, Out of automated reach, mutation verdict table)
├── tdd.md                       # Three layers, three laws, five phases, Unit-first execution, mutation operators, no-touch invariants
├── test-strategy.md             # Test-execution pyramid (Unit/Integration/E2E/Contract/Exploration → tech stack) + push-down/oracle/checking-vs-testing; frames verification skills
├── test-layout.md               # Two-peer-test-app layout, placement rule, AL Runner capability map, isolation/AutoCommit semantics, authoring contract (the placement axis)
├── LANGUAGE.md                  # Architectural vocabulary (incl. Connascence, CQS), testability pillars
├── bc-patterns.md               # BC pattern catalogue (read by /al-design)
├── bc-code-intelligence-dispatch.md     # bc-code-intelligence MCP call pattern (find→drop-noise→get_bc_topic), noise drop-list, relevance scales
├── notes-discipline.md          # What lives in the per-task file vs commit / ADR / .out-of-scope/, eight replan triggers
├── markdown-spec-discipline.md  # Pointer to examples/, tasks/ folder shape, surgical-edit floor (status: frontmatter field per task file)
├── cross-branch-numbering.md    # NNN / NNNN picking algorithm across parallel branches
├── CONTEXT.template.md
├── adr.template.md
└── examples/                    # Populated example artifacts
    ├── README.md                # Index
    ├── event-model.example.md
    ├── architecture.example.md
    └── tasks/                   # 000-feature.md header + one NNN-T-MMM-<slug>.md frontmatter file per task
skills/
├── al-agentic-dev-overview/SKILL.md  # Reads ../../references/overview.md, emits verbatim
├── al-build/
│   ├── CLAUDE.md                # Skill-local dev-time rules (smoke tests, container recovery, config priority)
│   ├── AGENTS.md                # Codex bridge to CLAUDE.md
│   ├── SKILL.md
│   ├── README.md                # Human-facing prerequisites + quick start
│   ├── config/                  # al-build.json template (the live copy lives in the consumer repo root)
│   └── scripts/                 # PowerShell 7.2+: init.ps1, provision.ps1, test.ps1, new-bc-container.ps1, ...
├── al-code-review/SKILL.md
├── al-doc-verify/SKILL.md
├── al-debug-logging/
│   ├── CLAUDE.md                # Skill-local dev-time rules (same-publisher constraint, DEBUG- prefix, transient-only)
│   ├── AGENTS.md                # Codex bridge to CLAUDE.md
│   ├── SKILL.md
│   └── references/
│       ├── telemetry-workflow.md
│       └── bc-event-subscriber-pattern.md
├── al-design/SKILL.md
├── al-event-model/SKILL.md
├── al-grill-adr/SKILL.md
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
├── al-page-script/SKILL.md
├── al-provision/SKILL.md        # Run kind: provision task → al-build provision.ps1 → flip status
├── al-refactor/
│   ├── SKILL.md
│   └── references/
│       └── legacy-refactor-plan.md
├── al-refine/SKILL.md
├── al-research/SKILL.md
├── al-scope/SKILL.md
├── al-second-opinion/
│   ├── SKILL.md
│   └── scripts/
│       └── Invoke-AlSecondOpinion.ps1
├── al-steer/
│   ├── SKILL.md
│   └── references/
│       └── out-of-scope.template.md
├── al-user-verification/SKILL.md
└── al-validate-breaking-changes/SKILL.md  # Run kind: breaking-change task → validate-breaking-changes.ps1 → flip status
```

Tests live at repo root (`tests/<target>/*.Tests.ps1`), not inside any plugin. `plugins/` carries only deliverables.

No build scripts. Skill bodies, reference templates, and PowerShell helpers under `skills/al-build/scripts/` are the entire product.
