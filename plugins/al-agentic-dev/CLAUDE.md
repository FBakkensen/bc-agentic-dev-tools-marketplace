# al-agentic-dev

Composable skills for AL/Business Central agentic development.

*Dev-time only — this file never ships. The shipped surface is the plugin's `SKILL.md`s, `hooks/`, `references/`, and `scripts/`; see the root `CLAUDE.md` "Shipped artefacts vs dev-time files".*

## Persistence layers

Two layers, on purpose.

- **Repo-root, durable across features**, markdown: `CONTEXT.md`, `docs/adr/`, `.out-of-scope/`. Owners: `/al-grill-adr` (CONTEXT + domain ADRs), `/al-steer` (out-of-scope). The writing skills run the inline document-integrity check (`references/doc-integrity.md`) on `CONTEXT.md` and domain ADR writes before handoff; `.out-of-scope/` is outside the document gate.
- **Branch-scoped, per in-flight feature**, markdown: `specs/<NNN>-<slug>/event-model.md` (user-facing journey, present for user/API-facing features) + `architecture.md` + a `tasks/` folder. Slug matches the current git branch.

The `tasks/` folder is the per-feature task bus: one file per task plus a `000-feature.md` header (Goal + slice intent, no status, no rows). Each per-task file is `NNN-T-MMM-<slug>.md` — the `NNN` filename prefix is the run order (gapped by 10; `ls tasks/` = run order; the sole order owner), `T-MMM` is a monotonic, never-reused locator id. State and graph live in YAML frontmatter at the top of each file, single source of truth: `task:`, `status:`, `slice:`, `kind:`, `depends_on:`, `refactors:`, `fixes:`, plus two runtime fields — `blocked-on:` (one-line block headline, present iff `blocked`, written/removed in the same Edit as the flip) and `deviations:` (append-only one-line entries for unknowns a skill absorbed inline without asking). Task files are agent-facing; the developer's standing view is the dashboard (`references/dashboard.md`, rebuilt whole from frontmatter by whoever changes it). `status:` values are `ready`, `ready-for-implementation`, `ready-for-verification`, `blocked`, `done`. `ready` means the task is ready for `/al-refine` only. `ready-for-implementation` means a technical task has a fresh `Test Specification`. `ready-for-verification` means a verify task has a fresh `Verification Plan`. `blocked` means dependency or context is missing. `done` means a technical task is green and reconciled to its diff (reshape and mutation are the user's follow-up steps, not part of the flip), or a verify/ops task's evidence exists. `task:` ids are monotonic and never reused. `slice: <slug>` groups tasks by one `event-model.md` timeline step (user-facing) or `architecture.md` slice (backend-only); `kind: verify` marks the per-slice verification task, `kind: technical` marks technical tasks. Two **ops kinds** bracket the feature: `kind: provision` (first, `slice: provision`) and `kind: breaking-change` (last, `slice: breaking-change`) on reserved non-feature slugs; they carry no proof artifact, bypass `/al-refine`, and run `ready` → `done` (or `blocked`) via `/al-provision` / `/al-validate-breaking-changes`. Each `blocked` → `ready` flip has a named owner like the cross-slice gate: `/al-provision` opens the first slice on its `done`; the skill landing the feature's final terminal task `done` (`/al-user-verification` last verify, or `/al-code-review` last backend slice) opens the breaking-change task. More generally, the skill that flips a task `done` opens any task it thereby unblocks whose open does not cross a gate: `/al-implement` opens same-slice **technical** dependents at `done` — but **not** the slice's verify task, whose open sits behind the per-slice code-review gate. The gated opens, by slice type: `/al-code-review` opens a user/API-facing slice's verify task on a clean review (`blocked` → `ready`) and opens a backend-only next slice; `/al-user-verification` on its verify pass opens a user-facing next slice; the next slice (and the verify task) never opens on a bare `done` flip. The open is provable from frontmatter and reversible, so the closing skill owns it inline; a `blocked` task with deps unsatisfied or a replan flag set stays `/al-steer`'s. `review: clean` is an optional transient frontmatter field on verify tasks: written only by `/al-code-review` on a clean per-slice review at slice-done — when it opens the verify task to `ready` (the durable evidence `/al-refine`, `/al-page-script`, `/al-user-verification`, and `/al-steer` read; the status byte alone reads identically before and after review). It rides untouched through the `/al-refine` flip `ready` → `ready-for-verification`, and strips in the same Edit on any flip to `blocked`/`done` or when any skill opens a technical task in the slice. There is no index file: the filesystem is the manifest, the board is grepped on demand and rendered by `/al-steer`. The writing skills run the inline document-integrity check (`references/doc-integrity.md`) on the written markdown artifacts before handoff.

**Branch creation is shared between `/al-event-model` and `/al-design`.** The first per-feature skill to run from `main` creates the branch and `specs/<NNN>-<slug>/`. For user/API-facing features that runs `/al-event-model` first; backend-only features skip `/al-event-model` and `/al-design` does it.

## Pipeline

User-facing pipeline diagram, skills catalogue, and cold-start guidance live in [`references/overview.md`](references/overview.md). That file is the single source of truth, emitted verbatim by `/al-agentic-dev-overview`. The slice-cycle prose below carries dev-time editing depth (gate flip mechanics, suppression rules) not duplicated in the tour.

**User drives the pipeline.** No skill auto-invokes the next; each ends by naming the next step and the user takes it. A skill calls another skill only for `/al-research` (BC fact escalation), `/al-build` (compile/test), and `/al-second-opinion` (cross-family advisory — autonomous so a cheap model can lean on it mid-step) — the three blessed exceptions. Everything else is a handoff. Skills still spawn subagents (review lenses, the red-green worker) and still write task `status:` frontmatter inline (a state write, not a cross-skill call), so the board mechanics keep working without chaining.

Slice cycle: `/al-refine` selects one named `ready` technical task, writes its `Test Specification` from the current app/tests, and flips it to `ready-for-implementation`. `/al-implement` works through `ready-for-implementation` technical tasks in Unit-first order, spawning the red-green subagent (`references/subagents/al-red-green.md`) per AAA case, and flips each to `done` at full green + reconcile. It **stops at green** and names `/al-refactor` (reshape) then `/al-mutate` (rigor) as the next steps — strongly directed for non-trivial work, but the user invokes them; the inner orchestration that used to run them is gone.

When the last technical task in a slice lands `done` (slice-done), `/al-implement` announces `/al-code-review` per-slice — it reviews the code, not the user walk, so it runs before the verify task is opened. `/al-code-review` runs per-slice, **report-only by default**: it spawns the review-lens subagents (`references/subagents/al-review-lens.md`, `al-review-lens-bc.md`), dedups, adversarially judges, cross-family-vets via `/al-second-opinion`, then reports the must-fix queue (each routed to `/al-implement T-NNN`), the nits, and the gate decision — the user drives fixes. `--fix` additionally lands the must-fix findings in-loop by spawning the red-green subagent per finding, commits under the originating `T-NNN`, and **re-reviews once** (not an unbounded loop). A clean review stamps `review: clean`; for a user/API-facing slice it also opens the verify task `blocked` → `ready`, then `/al-refine` writes the `Verification Plan` → `ready-for-verification` before page-script/user-verification. Escalation classes (replan-class finding, a fix that won't go green, a recurrence, a `needs-a-decision` finding) route to `/al-steer`, writing nothing durable.

**Page-script (user-facing slices).** `/al-page-script` is **not an authoring skill** — it guides the user to *record* the slice's framework-limited E2E Journey Examples (those `/al-refine` marked `Record: yes`) in BC's Page Scripting recorder, one scenario at a time, punchline first; the user records and downloads each `.yml` to `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml`, the agent replays each on a **fresh** container (the re-runnability gate) and commits on batch-green. The recorder is the generator because the bc-replay YAML format is reverse-engineered and undocumented — blind authoring is a token-and-error sink; the agent's one write is a surgical, approval-gated edit to an existing recorder file. `Record: yes` is reserved for behaviour no AL test layer can automate (generation-time push-down — most examples are `Record: no` and walked, not recorded). A replay red classifies three ways: bad recording → guided re-record (the default in-loop fix), real production bug → push down, status unchanged, route `/al-steer`, or oracle-blind/unscriptable → escalate `/al-steer`. On the production-bug route `/al-steer` opens the integration fix task and strips `review: clean`; `/al-implement` drives the fix red-first before the recording re-greens. Recorder-gesture coaching lives in `skills/al-page-script/references/recorder-gestures.md`; the YAML grammar (now read-only, for classifying a red or scoping a surgical edit) in `skills/al-page-script/references/bc-replay-yaml-format.md`.

**User verification (user-facing slices).** `/al-user-verification` runs three spawns:

- **Spawn #1.** Fresh container → publish → regression batch (`pagescript-replay.ps1`, every `pagescripts/recordings/*.yml`). Green → spawn #2. Red → verify task `blocked`, route `/al-steer` (trigger #4 prior-slice red, trigger #8 current-slice red); spawn #3 exits.
- **Spawn #2.** Fresh container → publish → Contract Examples (agent-run) → guided user walk, one scenario at a time, punchline first. Agent instructs, asks observed value before naming expected (ask-before-reveal). User walks the **`Record: no`** Journey Examples and Exploration Charters; the **`Record: yes`** examples were eyeballed live during `/al-page-script` recording and are re-confirmed by the spawn #1 replay batch, not re-walked (sign-off accounts for them explicitly). Functional outcomes gate, subjective usability → findings/tasks. `/al-second-opinion` reviews verdict coverage. Red → verify task `blocked`, route `/al-steer` (trigger #8).
- **Spawn #3.** Always runs at exit regardless of outcome — leaves a fresh container for the next consumer.

Verify pass → verify task `done`, next slice tasks `ready`, loop continues. Feature-done → `/al-code-review` per-feature before merge.

**Backend-only.** No `event-model.md`, no page-script, no user verification. Chain: refine → implement → code-review → next slice.

## Skills

User-facing catalogue (20 skills, role + when-to-invoke) lives in [`references/overview.md`](references/overview.md). Edit it in lockstep when adding, removing, renaming, or repurposing a skill. `al-research` is a skill (one of the two another skill may call); the read-only workers that were once skills/agents are now subagent prompt blocks under `references/subagents/` (red-green, the two review lenses), and `al-doc-verify` is folded into the inline document-integrity check (`references/doc-integrity.md`). None of these are listed in the skill catalogue except `/al-research`.

Skills compose by name. When you change a skill, scan the others for cross-references and update in lockstep. Cross-skill orchestration depth (gate flip mechanics, replan triggers, slice-cycle suppression rules) lives in the owning skill's `SKILL.md` and in the dev-time slice-cycle paragraph above; the user-facing overview stays tour-shape.

## Replan

`/al-steer` is the canonical replan venue — for changes that make a *new decision*: re-scope, reorder, a new architectural seam, decompose, or clear a block whose cause is a missing edge or an unsettled rule. Mutations that only *apply a decision already made* — open a task whose `depends_on:` is now `done`, flip the active task `done` on a green gate, fix a non-semantic review finding inline, reuse a seam pattern a sibling task already established — are provable from current state and reversible; the active skill acts on them inline and announces them, never routing through the venue. The test is *new decision or not*, not *touches the task ledger or not*; routing the provable case through the venue is the friction this floor removes.

The eight triggers as named patterns to learn: task too big, hidden pre-req, wrong order, sibling now wrong, new behaviour emerges, architecture decomposition wrong, goal drift, verification failed. Replan checks in `/al-refine`, `/al-implement`, `/al-refactor`, `/al-user-verification` map the trigger to response per situation: when the trigger means the plan is invalid as planned, flip `status:` to `blocked` and route to `/al-steer`; when the trigger means new info that doesn't invalidate, note it inside the task and continue. A trigger resting on a tool *diagnosis* (compile-error class, AL Runner gap, heuristic) is re-confirmed once before it flips `status: blocked` — a first-pass diagnosis is often a cascade artifact (an AL0305 missing-dependency reads as an AL0327 runner gap); a trigger resting on a recorded fact (`depends_on:`, Goal text, observed verification mismatch) is trusted as-is. Trigger #8 is binary: a failed user verification always flips the verify task to `blocked` and routes; there is no absorb-and-continue variant. `/al-code-review` findings are not replan signals by default: report-only routes each fixable finding to `/al-implement T-NNN`, and `--fix` lands it inline via the red-green subagent (folding into the originating task) without routing through `/al-steer`. Only a finding `--fix` *cannot* resolve — replan-class (new decision, decomposition wrong, new behaviour), a fix that won't go green, a finding recurring after its own fix, or a `needs-a-decision` — escalates to `/al-steer`.

## Editing rules

- **Skills call only `/al-research`, `/al-build`, and `/al-second-opinion`; everything else is a handoff.** A skill never invokes a sibling skill to chain the pipeline — it ends by naming the next step and the user takes it. Three skills are exempt because each is a within-step tool, not a pipeline stage: `/al-research` (BC fact escalation), `/al-build` (compile/publish/test), and `/al-second-opinion` (cross-family advisory). The last is load-bearing for the cheap-model goal — a smaller model running a skill leans on an autonomous cross-family second read to stay honest, so it must call it without a user round-trip. This rule keeps the plugin harness-portable and the user in control. Writing task `status:` frontmatter inline is a state *write*, not a call — it stays. Spawning a subagent from a `references/subagents/` prompt block is not a cross-skill call either.
- **Naming, BC vocabulary, and the evidence bar live in `references/voice-contract.md`.** One runtime home; writing skills read it before writing. The review lenses spawned by `/al-refactor` and `/al-code-review` carry the BC vocabulary in their own prompt blocks (`references/subagents/al-review-lens.md`, `al-review-lens-bc.md`), which ship to consumer repos — so the spawning skill injects only the per-lens goal, not the vocabulary line. Skills and subagent prompt blocks run in consumer projects without this dev-time CLAUDE.md present, so the prompt blocks must be self-contained. Do not lean on it.
- **No inline citations in durable artifacts.** `(see: file.al:120)` is forbidden in `architecture.md`, the per-task files under `tasks/`, `CONTEXT.md`, ADRs, `.out-of-scope/`. Names are the citation; `NALICFCopyDocSubscribers.OnAfterInsertToSalesLine` is the address. Future readers grep; the IDE gives line numbers for free. One carve-out: `Researched: <fact> → <source>` provenance bullets in a task's `Contract notes`, written at `/al-implement` reconcile, read by `/al-code-review` — without them, skipped research is indistinguishable from research that ran. Location pointers stay forbidden.
- **Spec artifacts are text-only.** Name relationships in prose; gates in the `depends_on:` frontmatter list on each task file. No mermaid fences; Claude Desktop's markdown preview and other viewers lack mermaid support, and a second encoding alongside text just drifts.
- **Spec artifacts are pure markdown.** Visual polish is a separate dev-server concern; the spec is text.
- **`architecture.md` is reshape-only.** Written by `/al-design`, read by everyone downstream. Never edit in place; re-run `/al-design`. No surgical-edit contract.
- **Each per-task file carries one surgical-edit contract.** Maintaining skills find a task by its `T-MMM` filename (or `task:` in frontmatter) and flip its `status:` frontmatter field, stripping `review: clean` in the same Edit on a flip to `blocked`/`done` (the `ready` → `ready-for-verification` refine flip preserves it). `/al-scope` writes `slice: <slug>` and `kind:` (`technical` / `verify` / `provision` / `breaking-change`) on every task; downstream skills read these but do not change them (a slice or kind change is replan work, routes through `/al-steer`). `/al-code-review` is the sole writer of `review: clean`. There is no `[ ]`/`[x]` heading marker; the `status:` frontmatter field is the only state, and the `status:` line is the byte the Edit anchors on. See `references/markdown-spec-discipline.md`.
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
| `overview.md` | plugin-level | user-facing tour: pipeline diagram, 20-skill catalogue (role + when-to-invoke), subagent prompt-block table, persistence layers paragraph, cold-start guidance, pointer to `/al-steer` for state-aware nav; emitted verbatim by `/al-agentic-dev-overview`; edit in lockstep with any skill addition / removal / rename |
| `voice-contract.md` | plugin-level | non-voice rules: BC vocab, names-as-citation, evidence bar (citation chain: names → workspace, constructs → fetched topic, `/al-research` escalation, `Contract notes` trace), lists-of-findings, tables-of-facts, chat carve-out, no-workflow-chatter, 5 chat shape skeletons (Opener / Gate report / Answer / Stop / Push-up report); style itself lives at top of each SKILL.md as a one-line Style declaration; read by every skill that writes prose or AL names |
| `doc-integrity.md` | plugin-level | the inline document-integrity check (was the `al-doc-verify` agent): artifact profiles + `tasks/`-folder structural checks; run inline by the writing skills (`/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-steer`) before the gate report |
| `subagents/` (folder) | plugin-level | spawnable subagent prompt blocks (was the `agents/` folder): `al-red-green.md` (one AAA case RED→GREEN), `al-review-lens.md` + `al-review-lens-bc.md` (one focused review pass); spawned in harness-neutral language by `/al-implement`, `/al-code-review`, `/al-refactor`; self-contained (ship to consumer repos), advisory model tier |
| `thrift-rules.md` | plugin-level | token-thrift canon: chat lede-first default + payload-preserving cuts (one decisive error line, no log dumps, no tool-call narration, keep grammar) and production-AL "build the least that works" (platform-first, no abstraction for one caller, production-only carve-outs); the **single home** — voice-contract.md and al-implement point here, the review lenses carry their own self-contained over-build block; re-emitted verbatim by the `SessionStart` hook (`hooks/`); read by `/al-implement` at generation and by every prose-writing skill |
| `testability.md` | plugin-level | three-phase decoupling, three default seams (IEnvironment / IApiRequest / IFinance), five-kind test-double taxonomy with AL code shapes; read by `/al-design`, `/al-implement`, `/al-refactor` |
| `test-specification.md` | plugin-level | `Test Specification` / `Verification Plan` grammar: New and Modified Objects, Expected Behaviors, Decision Matrix, AAA cases, Contract notes, Out of automated reach, scopes, the E2E `Record:` flag (generation-time push-down — recorded vs walked), traceability, closeout summaries with mutation verdict table; read by `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, `/al-user-verification` |
| `tdd.md` | plugin-level | three layers of trust, three laws, five phases, Unit-first execution, mutation operators + revert cycle, no-touch invariants; read by `/al-implement`, `/al-mutate` |
| `test-strategy.md` | plugin-level | test-execution pyramid mapped to the BC tech stack (Unit=AL-Runner, Integration=container+TestPage, E2E=page-script, Contract=client/harness, Exploration=guided user walk); push-down / oracle-problem / checking-vs-testing feedback rules; frames the verification skills (the *execution* axis, distinct from `tdd.md`'s *cycle* axis); read by `/al-build`, `/al-implement`, `/al-mutate`, `/al-refine`, `/al-code-review`, `/al-page-script`, `/al-user-verification` |
| `test-layout.md` | plugin-level | two-peer-test-app layout (`unit-tests/` + `integration-tests/`, no dependency edge, doubles per app), placement rule ("AL Runner-runnable iff" — reclassify, never relax), AL Runner capability map (runs / auto-stubs / throws, provenance-dated), container `TestIsolation = Codeunit` semantics, `TransactionModel::AutoCommit` false-pass rule, authoring contract (mandatory attributes, `Initialize()` guard, handlers on the test codeunit, integration-library discipline incl. duplicate-before-share); the *placement* axis, distinct from `test-strategy.md`'s *execution* axis and `tdd.md`'s *cycle* axis; read by `/al-scope`, `/al-refine`, `/al-implement`, `/al-refactor` (carried into lens spawn prompts when the diff touches tests) |
| `dashboard.md` | plugin-level | the human-facing feature dashboard: rebuilt-whole HTML projection of task frontmatter (never body prose) to `.output/dashboard.html` (+ optional hosted live page), attention-panel-first layout, and the render invariant (whoever changes task frontmatter re-renders, same working step); read via `markdown-spec-discipline.md`/`notes-discipline.md` by every skill that writes task frontmatter |
| `notes-discipline.md` | plugin-level | what lives in the per-task file vs commit / ADR / `.out-of-scope/`; the eight replan triggers as named patterns; read by skills that write the `tasks/` folder |
| `markdown-spec-discipline.md` | plugin-level | pointer to `examples/`, the `tasks/` folder shape, surgical-edit floor (`status:` frontmatter field per task file; `task:` + `slice:` + `kind:` + edge lists alongside it), status-flip Edit shape; read by `/al-design`, `/al-event-model`, `/al-scope`, `/al-refine`, `/al-implement`, `/al-code-review`, `/al-user-verification`, `/al-mutate`, `/al-steer` |
| `examples/` (folder) | plugin-level | populated example artifacts (`event-model.example.md`, `architecture.example.md`, and a `tasks/` folder of frontmatter task files); pattern-match source for writing skills |
| `cross-branch-numbering.md` | plugin-level | algorithm for picking `NNN` (spec folders) and `NNNN` (ADRs) across parallel branches; read by `/al-design`, `/al-event-model`, `/al-grill-adr` |
| `bc-patterns.md` | plugin-level | BC pattern catalogue; read by `/al-design` |
| `bc-code-intelligence-dispatch.md` | plugin-level | bc-code-intelligence MCP call pattern (`find_bc_knowledge` → drop-noise → `get_bc_topic`), noise drop-list, relevance scales; read by `/al-implement` (write-time construct lookup), `/al-refactor`, `/al-code-review`, `/al-research`, and the review-lens / red-green subagent prompt blocks |
| `LANGUAGE.md` | plugin-level | architectural vocabulary (incl. Connascence, CQS), testability pillars; read by `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-refactor`, `/al-code-review` |
| `CONTEXT.template.md` | plugin-level | template materialised into the target repo's `CONTEXT.md` |
| `adr.template.md` | plugin-level | template materialised into the target repo's `docs/adr/NNNN-<slug>.md` |
| `out-of-scope.template.md` | `/al-steer`-local | template materialised into `.out-of-scope/<concept>.md` |
| `legacy-refactor-plan.md` | `/al-refactor`-local | reference plan for legacy code without tests |

Templates are materialised lazily on first need by the owning flow. `markdown-spec-discipline.md` is read but never materialised; it is a discipline reference, not a template.

Cross-skill paths within this plugin (when reaching into another skill's local references): `${CLAUDE_SKILL_DIR}/../<skill>/references/<file>`. Reach for plugin-level first; cross-skill paths are a smell to be migrated.

## Runtime surface

This plugin is **authored harness-portable** and **distributed via the Claude marketplace**. It ships no custom-agent definitions (the `agents/` folder is gone): the read-only workers are subagent **prompt blocks** under `references/subagents/`, spawned in harness-neutral language ("spawn a subagent with the prompt in `<path>`"), and the model tier is advisory, not pinned — so a small/fast model can run most steps and the harness, not a hardcoded envelope, picks. Skills cross-invoke nothing except `/al-research`, `/al-build`, and `/al-second-opinion` (the last autonomous, so a cheap model gets a cross-family read without a user round-trip); every other transition is a user-taken handoff. Inline `mcp__` calls stay (cross-harness, degrade gracefully when a server is absent) and the AL language-server `.lsp.json` stays. What's banned now is Claude-only orchestration syntax in skill bodies — `Agent()` fan-out written literally, the `Workflow` primitive, namespaced `/al-*` auto-chaining — replaced by neutral prose and the explicit handoff model. Prefer skills for runtime behavior by default; reach for a spawned subagent only when fan-out or context isolation earns it.

**Keep skills project-agnostic across consumer repos.** A skill must run in any AL/BC project without hardcoding this marketplace's paths or a specific repo's layout. This is *consumer-repo* portability (orthogonal to any runtime concern) — soft guidance, not a CI gate.

**One plugin hook.** `hooks/hooks.json` registers a single `SessionStart` hook (matcher `startup|resume|compact`) that runs `hooks/emit-thrift-rules.js` to re-emit `references/thrift-rules.md` verbatim — the only mechanism that re-asserts the thrift canon after a compaction wipes it mid-loop (skills otherwise re-read it on invocation). Auto-activates on enable; bundled-file path via `${CLAUDE_PLUGIN_ROOT}`. The hook **only injects, never verifies** — enforcement stays prompt-resident, matching the plugin's all-advisory model. Node-on-PATH (already required by `/al-second-opinion`); if `node` is absent the hook command fails, but a `SessionStart` hook failure is non-blocking by design — the session proceeds and the change degrades to prompt-resident-only (skills re-read the file on invocation). The emitter additionally exits 0 on an unreadable rules file, so a present-but-broken read never blocks either. The emitter never restates the rules — it re-reads the one file, so there is no second copy to drift. The hook is a Claude Code enhancement, not a dependency: a harness that doesn't read `hooks.json` simply never runs it and the thrift canon stays prompt-resident-only (skills re-read the file on invocation) — the same graceful degradation. This is the plugin's sole hook; adding more is a deliberate decision, not a default.

Notable script-backed skills:

- **`skills/al-mutate/SKILL.md`**, mutate-build-revert cycle, mutation kinds, survivor classification, BC safety.
- **`skills/al-second-opinion/SKILL.md`** is the contract; **`skills/al-second-opinion/scripts/Invoke-AlSecondOpinion.ps1`** is the execution. It always shells to the GitHub Copilot CLI (`@github/copilot`) **pinned to a GPT model** — `node <npm-root>/@github/copilot/npm-loader.js --model gpt-5.5 --reasoning-effort low --allow-all-tools --deny-tool=write --deny-tool=shell --deny-tool=url --no-ask-user --disable-builtin-mcps --no-custom-instructions --no-color --output-format json`, prompt piped via stdin — for an independent, different-model-family read. **Copilot is a CLI tool dependency here — not a host runtime, not a publish target.** Copilot *can* run Claude models, so the `--model gpt-5.5` pin is load-bearing: it **is** the cross-family independence guarantee. Do not let it run a `claude-*` model or `--model auto`; do not widen the envelope. Read-only is assembled (no single sandbox flag exists in copilot): `--deny-tool` blocks write/shell/url (reads survive — native `view`/grep are separate tools, so the reviewer still verifies against the codebase), and `COPILOT_HOME=<temp>` isolates from the user's `~/.copilot` MCP fleet (otherwise write-capable MCP tools leak into the review). The script invokes `npm-loader.js` through `node` directly to bypass the VS Code-bundled bootstrapper shim (Windows-PowerShell-with-profile + interactive `Read-Host` prompts that would hang). 600s timeout via `Start-Job` / `Wait-Job`. Skip line names the copilot CLI. SKILL.md documents the envelope flags so the security posture stays visible without reading the script. **Windows-only**; `Start-Job` / `Wait-Job` targets pwsh on Windows; portability is a future concern.

## Layout

```
hooks/                           # Plugin's sole hook: SessionStart re-injection of the thrift canon
├── hooks.json                   # SessionStart (startup|resume|compact) → emit-thrift-rules.js
└── emit-thrift-rules.js         # node: re-reads references/thrift-rules.md, writes to stdout; missing node exits 0 (degrades, never blocks)
references/                      # Plugin-level shared, read by ≥2 skills, or cited by shared templates
├── overview.md                  # User-facing tour: pipeline + 20-skill catalogue + subagent table + persistence + cold-start; emitted by /al-agentic-dev-overview
├── voice-contract.md            # Non-voice rules + evidence bar + 5 chat shape skeletons; voice declared inline at top of each SKILL.md
├── doc-integrity.md             # Inline document-integrity check (was the al-doc-verify agent); run by the writing skills before the gate report
├── thrift-rules.md              # Token-thrift canon (chat lede-first + production-AL build-the-least); single home, re-emitted by the SessionStart hook
├── testability.md               # Three-phase decoupling, three default seams, five-kind test-double taxonomy
├── test-specification.md        # Test Specification + Verification Plan grammar (incl. New and Modified Objects, Contract notes, Out of automated reach, mutation verdict table)
├── tdd.md                       # Three layers, three laws, five phases, Unit-first execution, mutation operators, no-touch invariants
├── test-strategy.md             # Test-execution pyramid (Unit/Integration/E2E/Contract/Exploration → tech stack) + push-down/oracle/checking-vs-testing; frames verification skills
├── test-layout.md               # Two-peer-test-app layout, placement rule, AL Runner capability map, isolation/AutoCommit semantics, authoring contract (the placement axis)
├── LANGUAGE.md                  # Architectural vocabulary (incl. Connascence, CQS), testability pillars
├── bc-patterns.md               # BC pattern catalogue (read by /al-design)
├── bc-code-intelligence-dispatch.md     # bc-code-intelligence MCP call pattern (find→drop-noise→get_bc_topic), noise drop-list, relevance scales
├── dashboard.md                 # Human-facing dashboard: frontmatter projection to .output/dashboard.html, render invariant
├── notes-discipline.md          # What lives in the per-task file vs commit / ADR / .out-of-scope/, eight replan triggers
├── markdown-spec-discipline.md  # Pointer to examples/, tasks/ folder shape, surgical-edit floor (status: frontmatter field per task file)
├── cross-branch-numbering.md    # NNN / NNNN picking algorithm across parallel branches
├── CONTEXT.template.md
├── adr.template.md
├── subagents/                   # Spawnable subagent prompt blocks (was agents/): harness-neutral, advisory model tier, self-contained
│   ├── al-red-green.md          # One AAA case RED→GREEN; spawned per case by /al-implement and per finding by /al-code-review --fix
│   ├── al-review-lens.md        # One focused read-only AL/BC review pass; spawned N× by /al-code-review + /al-refactor
│   └── al-review-lens-bc.md     # The BC-specific review lens variant (bc-code-intelligence MCP reach)
└── examples/                    # Populated example artifacts
    ├── README.md                # Index
    ├── event-model.example.md
    ├── architecture.example.md
    └── tasks/                   # 000-feature.md header + one NNN-T-MMM-<slug>.md frontmatter file per task
skills/
├── al-agentic-dev-overview/SKILL.md  # Reads ../../references/overview.md, emits verbatim
├── al-build/
│   ├── CLAUDE.md                # Skill-local dev-time rules (smoke tests, container recovery, config priority)
│   ├── SKILL.md
│   ├── README.md                # Human-facing prerequisites + quick start
│   ├── config/                  # al-build.json template (the live copy lives in the consumer repo root)
│   └── scripts/                 # PowerShell 7.2+: init.ps1, provision.ps1, test.ps1, new-bc-container.ps1, ...
├── al-code-review/SKILL.md
├── al-debug-logging/
│   ├── CLAUDE.md                # Skill-local dev-time rules (same-publisher constraint, DEBUG- prefix, transient-only)
│   ├── SKILL.md
│   └── references/
│       ├── telemetry-workflow.md
│       └── bc-event-subscriber-pattern.md
├── al-design/SKILL.md
├── al-event-model/SKILL.md
├── al-grill-adr/SKILL.md
├── al-implement/SKILL.md
├── al-mutate/SKILL.md
├── al-page-script/
│   ├── SKILL.md
│   └── references/
│       ├── recorder-gestures.md         # Recording-coaching canon: re-runnability rules as recorder UI gestures
│       └── bc-replay-yaml-format.md     # bc-replay YAML format — read-only, for classifying a red or scoping a surgical edit
├── al-provision/SKILL.md        # Run kind: provision task → al-build provision.ps1 → flip status
├── al-quiz/SKILL.md             # Quiz the developer on landed changes; read-only, no gate
├── al-refactor/
│   ├── SKILL.md
│   └── references/
│       └── legacy-refactor-plan.md
├── al-refine/SKILL.md
├── al-research/SKILL.md         # BC fact verification, evidence-bar escalation seat (was an agent); callable from a session and by another skill
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
