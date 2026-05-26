# al-agentic-dev

Composable skills for AL/Business Central agentic development.

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**, markdown: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-design` (design ADRs), `/al-steer` (out-of-scope).
- **Branch-scoped, per in-flight feature**, markdown: `specs/<NNN>-<slug>/event-model.md` (user-facing journey, present for user/API-facing features) + `architecture.md` + `tasks.md`. Slug matches the current git branch.

`tasks.md` is the per-feature task bus. Status lives on a one-line HTML comment immediately under each `### T-NNN` heading, single source of truth: `<!-- task=T-NNN status=ready slice=<slug> kind=technical -->`. `status=` values are `ready`, `in-progress`, `done`, `blocked`. `T-NNN` IDs are monotonic and never reused. `slice=<slug>` groups tasks by one `event-model.md` timeline step (user-facing) or `architecture.md` slice (pure-backend); `kind=verify` marks the per-slice user-verification task, `kind=technical` marks technical tasks.

**Branch creation is shared between `/al-event-model` and `/al-design`.** The first per-feature skill to run from `main` creates the branch and `specs/<NNN>-<slug>/`. For user/API-facing features that runs `/al-event-model` first; pure-backend features skip `/al-event-model` and `/al-design` does it.

## Pipeline

```
/al-grill-adr  →  /al-event-model  →  /al-design     →  /al-scope                →  /al-refine    →  /al-implement   →  /al-refactor  →  /al-mutate  →  /al-user-verification
(CONTEXT,         (event-model.md,    (architecture    (tasks.md, slices +         (per-task        (TDD per task)     (improve        (test-rigor    (user walks slice's
 ADRs)             user/API-facing     .md, AL-shape    technical + verify per     scenarios)                          shape)          gate)          verify task; flip done
                   only, pure backend  only)            user/API-facing slice)                                                                         or blocked → /al-steer)
                   skips this step)

gates: /al-code-review (user-invoked at slice-done after user verification, and at feature-done; combines vanilla review + bc-knowledge MCP topic surfacing; auto-runs /grill-me per surviving finding for triage)
side-band: /al-research, /al-steer (replan venue + .out-of-scope), /al-second-opinion
```

Slice cycle: `/al-implement` works through the slice's technical tasks (ZOMBIES inside the slice); when the last technical task lands, the slice's verify task flips `ready`; `/al-user-verification` walks it with the user; on pass, `/al-code-review` runs per-slice and the next slice's first task becomes ready; on fail, the verify task flips `blocked` and `/al-steer` routes (trigger #8). Pure-backend features have no `event-model.md` and skip verify tasks entirely.

## Skills

| Skill | Role |
|---|---|
| `/al-steer` | Coach/navigator. Reads state, names next step, never edits code. Owns `.out-of-scope/`. |
| `/al-grill-adr` | Domain-aware grilling. Sharpens BC vocabulary, updates `CONTEXT.md`, offers domain ADRs only. |
| `/al-event-model` | User-facing journey settlement. BC-vocabulary chains (Role / Action / Business Event / View / Status), one timeline per feature, Role swimlanes when more than one Role participates. Writes `event-model.md`. Optional, pure-backend features skip it. |
| `/al-design` | `event-model.md` → feature architecture. Module map, BC patterns, R→P→W boundary, brownfield touchpoints, test strategy, parallel design-twice. Writes `architecture.md`; creates branch when `/al-event-model` did not. |
| `/al-scope` | `architecture.md` → slice-grouped task list in `tasks.md`. Goal + technical `T-NNN`s with `slice=<slug>` + one verify `T-NNN` per slice (user/API-facing features only). Slices follow event-model timeline order; ZOMBIES inside each slice. |
| `/al-refine` | One task → numbered scenarios. Technical task → ZOMBIES Gherkin for `/al-implement`. Verify task → ZOMBIES user test plan (numbered user-action steps citing event-model slots) for `/al-user-verification`. |
| `/al-implement` | Pick a Gherkin-ready technical task, run TDD: red → green → refactor → mutate. Stops on `kind=verify` and routes to `/al-user-verification`. Flips the slice's verify task `ready` when its last technical sibling lands. |
| `/al-user-verification` | Walk a slice's verify task with the user. ZOMBIES scenarios with numbered user-action steps; per-step pass/fail capture. All pass → `done`, hand off to `/al-code-review` at slice-done. Any fail → `blocked`, route to `/al-steer` with trigger #8. |
| `/al-refactor` | Improve shape while green. No new behaviour. Consults bc-knowledge MCP for structural anti-patterns (SetLoadFields placement, subscriber lifecycle, SIFT) at high relevance bar. |
| `/al-code-review` | In-depth gate at slice-done (after user verification) and feature-done boundaries. Vanilla review + bc-knowledge at lower bar + per-slice verify ↔ code alignment + per-feature cross-file checks (perm set vs new table field, publisher vs subscriber signature, AppSource public-surface additions). Auto-runs `/grill-me` per surviving finding for triage; materialises new tasks or notes on future tasks. Never routes via `/al-steer`. |
| `/al-mutate` | Inject mutations to validate test rigor. Mandatory for non-trivial work. Owns the mutate-build-revert cycle. |
| `/al-research` | Verify BC specifics from authoritative sources. |
| `/al-second-opinion` | Cross-runtime read-only advisory gate for non-trivial scenarios, mutation lists, and refactor checklists. From Claude Code: `codex exec`. From Codex: `claude -p`. |
| `/al-build` | Build/test gate. Compile, publish, run tests, write results to `.output/TestResults/<dirName>/`. Called by `/al-implement`, `/al-refactor`, `/al-mutate` between steps; full gate before commit. |
| `/al-debug-logging` | Temporary runtime probes. Inject `DEBUG-*` `FeatureTelemetry.LogUsage`, exercise the path, read `.output/TestResults/*/telemetry.jsonl`, remove probes. Final state: zero `DEBUG-*` in tree. |

Skills compose by name. When you change a skill, scan the others for cross-references and update in lockstep.

## Replan

`/al-steer` is the canonical replan venue. The eight triggers as named patterns to learn: task too big, hidden pre-req, wrong order, sibling now wrong, new behaviour emerges, architecture decomposition wrong, goal drift, verification failed. Replan checks in `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification` map the trigger to response per situation: when the trigger means the plan is invalid as planned, flip `status=` to `blocked` and route to `/al-steer`; when the trigger means new info that doesn't invalidate, note it inside the task and continue. Trigger #8 is binary: a failed user verification always flips the verify task to `blocked` and routes; there is no absorb-and-continue variant. `/al-code-review` findings themselves are NOT replan signals; the skill auto-invokes `/grill-me` per finding for triage into new tasks or notes on future tasks.

## Editing rules

- **Each SKILL.md states naming and BC vocabulary inline.** Skills run in projects without this CLAUDE.md present. Do not lean on it.
- **No inline citations in durable artifacts.** `(see: file.al:120)` is forbidden in `architecture.md`, `tasks.md`, `CONTEXT.md`, ADRs, `.out-of-scope/`. Names are the citation; `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address. Future readers grep; the IDE gives line numbers for free.
- **Spec artifacts are text-only.** Name relationships in prose; gates in `Depends on:` lines on tasks. No mermaid fences; Claude Desktop's markdown preview and other viewers lack mermaid support, and a second encoding alongside text just drifts.
- **Spec artifacts are pure markdown.** Visual polish is a separate dev-server concern; the spec is text.
- **`architecture.md` is reshape-only.** Written by `/al-design`, read by everyone downstream. Never edit in place; re-run `/al-design`. No surgical-edit contract.
- **`tasks.md` carries one surgical-edit contract.** Maintaining skills find a task by `<!-- task=T-NNN ... -->` and flip its `status=` value. `/al-scope` writes `slice=<slug>` on every task and `kind=verify` on per-slice verify tasks (technical tasks carry `kind=technical`); downstream skills read these but do not change them (a slice or kind change is replan work, routes through `/al-steer`). The heading `[ ]`/`[~]`/`[x]`/`[!]` marker is a visible fallback; the comment-line `status=` value is source of truth. The agent flips both; the comment-line attribute is the byte the Edit anchors on. See `references/markdown-spec-discipline.md`.
- **New skills need a stated gap.** _Avoid_: spinning up a skill that an existing one can absorb, or that fits as a brief note inside an existing task block, an `/al-research` finding, or a side-band reference. Propose only when no existing skill fits, and say so in one line.
- **Express intent and rationale, not enumerated rules with skip conditions.** SKILLs and references state *why a discipline exists and what problem it solves*; the agent maps rationale to situation. Slot prescriptions, `_When earned:_` / `_Skip when:_` enumerations, and templates the agent must fill are rejected by name. The agent is capable of shaping output per feature.
- **`telemetry.jsonl` is a producer/consumer contract between `/al-build` and `/al-debug-logging`.** `/al-build`'s `test.ps1` produces `.output/TestResults/<dirName>/telemetry.jsonl`; `/al-debug-logging`'s Inspect step reads it. Path, per-app subfolder layout, and `FeatureTelemetry.LogUsage` JSON shape are coupled. Change one side, scan the other in the same edit. The coupling lives here because it crosses skill boundaries; per-skill CLAUDE.md cannot enforce it alone.

## Reference layout

Two tiers, on purpose.

- **Plugin-level shared**, `plugins/al-agentic-dev/references/`. Cross-skill resources read by more than one skill. Path from any SKILL.md: `${CLAUDE_SKILL_DIR}/../../references/<file>`.
- **Skill-local**, `plugins/al-agentic-dev/skills/<skill>/references/`. Resources only one skill reads. Path from that SKILL.md: `${CLAUDE_SKILL_DIR}/references/<file>`.

**Rule**: a resource read by two or more skills lives in plugin-level `references/`. Skill-local references stay inside the skill that owns them. DO NOT put a shared resource inside one skill's folder; owner ambiguity invites drift.

| File | Tier | Notes |
|---|---|---|
| `voice-contract.md` | plugin-level | non-voice rules: BC vocab, names-as-citation, lists-of-findings, tables-of-facts, chat carve-out, no-workflow-chatter, 3 chat shape skeletons (Opener / Gate report / Stop); style itself lives at top of each SKILL.md as a one-line Style declaration; read by every skill that writes prose |
| `testability.md` | plugin-level | three-phase decoupling, three default seams (IEnvironment / IApiRequest / IFinance), five-kind test-double taxonomy with AL code shapes; read by `/al-design`, `/al-implement`, `/al-refactor` |
| `tdd.md` | plugin-level | three layers of trust, three laws, five phases, ZOMBIES ordering, mutation operators + revert cycle, no-touch invariants; read by `/al-refine`, `/al-implement`, `/al-mutate` |
| `notes-discipline.md` | plugin-level | what lives in the task block vs commit / ADR / `.out-of-scope/`; the eight replan triggers as named patterns; read by skills that write `tasks.md` |
| `markdown-spec-discipline.md` | plugin-level | pointer to `examples/`, surgical-edit floor (`task=` + `status=` + `slice=` + `kind=` on the comment-anchor line), status-flip Edit shape; read by `/al-design`, `/al-event-model`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-user-verification`, `/al-mutate`, `/al-steer` |
| `examples/` (folder) | plugin-level | three populated `*.example.md` artifacts; pattern-match source for writing skills |
| `cross-branch-numbering.md` | plugin-level | algorithm for picking `NNN` (spec folders) and `NNNN` (ADRs) across parallel branches; read by `/al-design`, `/al-event-model`, `/al-grill-adr` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue; read by `/al-design` |
| `bc-knowledge-dispatch.md` | plugin-level | bc-knowledge MCP call pattern, specialist mapping, thresholds; read by `/al-refactor` and `/al-code-review` |
| `LANGUAGE.md` | plugin-level | architectural vocabulary, testability pillars; read by `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-refactor` |
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
- **`skills/al-second-opinion/SKILL.md`** is the contract; **`skills/al-second-opinion/scripts/Invoke-AlSecondOpinion.ps1`** is the execution. Dispatched by runtime. `$env:CLAUDECODE -eq '1'` → `codex exec --sandbox read-only --skip-git-repo-check --color never --json -c model_reasoning_effort=medium`. Else → `claude -p --output-format json --no-session-persistence --disable-slash-commands --strict-mcp-config '{}'`. 600s timeout via `Start-Job` / `Wait-Job`. Skip lines name the target CLI. SKILL.md documents the sandbox flags so the security envelope stays visible without reading the script. **Windows-only**; `Start-Job` / `Wait-Job` targets pwsh on Windows; portability is a future concern.

## Layout

```
references/                      # Plugin-level shared, read by ≥2 skills, or cited by shared templates
├── voice-contract.md            # Non-voice rules + 3 chat shape skeletons; voice declared inline at top of each SKILL.md
├── testability.md               # Three-phase decoupling, three default seams, five-kind test-double taxonomy
├── tdd.md                       # Three layers, three laws, five phases, ZOMBIES, mutation operators, no-touch invariants
├── LANGUAGE.md                  # Architectural vocabulary, testability pillars
├── bc-patterns.md               # BC pattern catalogue (read by /al-design)
├── bc-knowledge-dispatch.md     # bc-knowledge MCP call pattern, specialist mapping, thresholds
├── notes-discipline.md          # What lives in the task block vs commit / ADR / .out-of-scope/, eight replan triggers
├── markdown-spec-discipline.md  # Pointer to examples/, surgical-edit floor (task= + status= + slice= + kind= on comment line)
├── cross-branch-numbering.md    # NNN / NNNN picking algorithm across parallel branches
├── CONTEXT.template.md
├── adr.template.md
└── examples/                    # Populated example artifacts
    ├── README.md                # Index
    ├── event-model.example.md
    ├── architecture.example.md
    └── tasks.example.md
skills/
├── al-build/
│   ├── CLAUDE.md                # Skill-local dev-time rules (smoke tests, container recovery, config priority)
│   ├── AGENTS.md                # Codex bridge to CLAUDE.md
│   ├── SKILL.md
│   ├── README.md                # Human-facing prerequisites + quick start
│   ├── config/                  # al-build.json template (the live copy lives in the consumer repo root)
│   └── scripts/                 # PowerShell 7.2+: init.ps1, provision.ps1, test.ps1, new-bc-container.ps1, ...
├── al-code-review/SKILL.md
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
└── al-user-verification/SKILL.md
```

Tests live at repo root (`tests/<target>/*.Tests.ps1`), not inside any plugin. `plugins/` carries only deliverables.

No build scripts. Skill bodies, reference templates, and PowerShell helpers under `skills/al-build/scripts/` are the entire product.
