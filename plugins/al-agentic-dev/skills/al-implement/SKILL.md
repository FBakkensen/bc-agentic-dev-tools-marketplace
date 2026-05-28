---
name: al-implement
description: Pick a Gherkin-ready task from `tasks.md` and drive it through TDD for AL/Business Central. Use after `/al-refine`, one task per session, red to green per Gherkin bullet, then refactor and mutate with `/al-build` between.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-implement, Pick a task, run TDD

Pick next ready task from `tasks.md`. TDD per Gherkin bullet. Refactor full task diff once. Mutate where decisions live. Flip status. One task per session.

## Preconditions

- Branch matches `^\d{3}-`. If not: **Stop**. Run `/al-event-model` (or `/al-design` for pure-backend).
- `specs/<branch>/` holds `tasks.md` + `architecture.md`. Missing → `/al-design`.
- User/API-facing: `event-model.md` present, canonical Role / Business Event / View names from there already in Gherkin via `/al-refine`; transcribe verbatim into test names + `[SCENARIO]` / `[GIVEN]` / `[WHEN]` / `[THEN]` comments.
- Target task `status=ready`, populated Tests. Empty Tests → `/al-refine <T-NNN>`. `blocked` → `/al-steer`.
- Target task `kind=verify`: **Stop**, route to `/al-page-script T-NNN`. Verify tasks not TDD; this skill writes AL. (`/al-page-script` generates the slice's bc-replay recording; `/al-user-verification` runs after the `.yml` exists.)

## What this session answers

- **Which task in flight?** One `T-NNN`, named in opener, status flipped `ready` → `in-progress` before first RED.
- **Where is the seam?** Read `architecture.md` R → P → W boundary, module map, brownfield touchpoints. Name seam in BC vocab (procedure to extract, event to subscribe, interface to implement). One line.
- **What flips at end?** `status=` goes `in-progress` → `done` on the comment-anchor line, heading marker `[~]` → `[x]`; final full `/al-build` (container) green. When this is slice's last technical task (all sibling `T-NNN` with same `slice=` also `done`): announce `/al-code-review` per-slice as next handoff. Do not touch the slice's verify task — `/al-code-review` owns the `blocked` → `ready` flip after clean review. When this is the feature's last task (every `T-NNN` across the feature `done`, no verify task pending): announce `/al-code-review` per-feature as next handoff.
- **Which BC names verified this session?** Every BC-specific name a Gherkin bullet rests on (procedure, event, table, field, codeunit, attribute): backed this session by `al-symbols-mcp` or `grep` hit, or `/al-research` citation. Recall does not satisfy. See *Citation chain in chat* below.

Unanswerable question → task not ready. Resolve via `/al-research`, `/al-refine`, or `/al-steer`.

## Workflow

### One Gherkin bullet at a time

RED → GREEN → gate, one bullet, then next. Bulk-RED locks test surface before seam understood; tests written ahead verify imagined behaviour. First bullet is tracer; pick whichever proves the seam end-to-end.

### Citation chain in chat, per Gherkin bullet before RED

Before first RED of any Gherkin bullet, every BC-specific name in the bullet either appears in `al-symbols-mcp` / `grep` result you ran this session, or cited via `/al-research`: `Researched: <fact> → <source path / URL / topic id>`. Workspace lookup is empirical anchor; memory of past sessions or training data is not. Test mechanics, Copilot APIs, platform behaviour around triggers / subscribers / `Insert(false)` semantics are highest-failure surfaces; training data ships confidently-wrong claims the compile loop only catches when the name itself is wrong. Your confidence about a BC name is not evidence the name exists, signs the right way, or behaves as recalled.

### Test the Process seam, not the implementation

Tests target P (`Access = Internal` for Pure, public surface for E2E). Read and Write collaborators, façade internals, private procedures inside P change freely. Assertions read posting outcomes, ledger entries, document flow; not table shape or call order. See [testability.md](../../references/testability.md) for three-phase decoupling + seam catalogue, [tdd.md](../../references/tdd.md) for five phases + no-touch invariants.

### `/al-build` gates every RED and every GREEN

Pure-tagged bullets → `/al-build -UnitTestOnly` (AL Runner, seconds). E2E-tagged → full `/al-build` (container). Both-tagged → Pure cycle first to drive implementation, then E2E through public surface to prove wiring. Final full `/al-build` precedes `done`.

AL Runner ERROR / exit 2 routes cheapest-first: review test (adjust to avoid unsupported call) → refactor production behind seam so unsupported call moves behind stub → reclassify as E2E (note override inside task block). Reclassification last (grows container surface). Run `al-runner --guide` when unsupported feature unclear.

### One `/al-refactor` pass on full task diff, after all bullets green

Mandatory before mutation. Inline renames + obvious dedupe land inside GREEN as you write; substantive reshape (cross-bullet naming drift, project-vocabulary slip, duplication that surfaced after third bullet, AppSource compliance) waits for full-diff pass. Cross-bullet shape only visible after third or fourth bullet; per-bullet refactor misses it, reshape after `/al-mutate` invalidates the mutation run.

### `/al-mutate` after refactor

Trigger fires when prod or tests moved this cycle. Prod moved → mutate to prove tests catch the new decision logic; tests moved → mutate to prove new assertions actually pin prod behaviour. Site selection (which lines within scope qualify) is `/al-mutate`'s call; see [tdd.md](../../references/tdd.md) for operators + qualifiers. Cross-check the mutation list via `/al-second-opinion` before it commits; prompt body: *"what mutations are missing or misaligned? AND does this surface any of the eight replan triggers? Return a bulleted list."* Reconcile each returned bullet.

Commit WIP before `/al-mutate`. Mutate-build-revert cycle assumes `git status` empty; uncommitted work bleeds into revert and corrupts every classification.

### AppSource compliance bites at implementation time

New objects get IDs via available allocator (never hand-pick). Shipped fields never rename in place (`ObsoleteState: Pending` → `Removed` over deprecation window). Catching at refactor → minutes; catching post-release → app version.

### Replan halts planning, not code

Eight triggers run as gate after mutation, before `done`. Trigger invalidates plan → flip `status=blocked` on the comment-anchor line, route to `/al-steer`. Trigger is new info plan absorbs → note inside task block and continue. Record trigger ID + one-line reason. Catalogue:

| # | Trigger | Detect |
|---|---|---|
| 1 | Task too big | Single task balloons past one TDD cycle's worth of scope |
| 2 | Hidden pre-req | Implementation needs table, codeunit, or permission with no covering task |
| 3 | Wrong order | Task can't land without later task's seam in place |
| 4 | Sibling now wrong | This task's code invalidates another task's context or scenarios |
| 5 | New behaviour emerges | Code path needs its own test, not bullet-extension |
| 6 | Architecture decomposition wrong | R → P → W boundary or module split surfaces as wrong |
| 7 | Goal drift | What's landing no longer matches feature Goal |
| 8 | Verification failed | User-facing scenario in `/al-user-verification` does not match observed behaviour; surfaced from verify task, not from technical cycle here |

Trivia absorbs inline: missing scaffolding (permission set entry, object ID, caption, BC-vocab rename) not a trigger. Apply, note, re-run `/al-build`, continue. Schema changes, new event publishers, new codeunits, test-outcome changes never absorb; route through `/al-steer`.

<claude-only>

Before flipping task to `done`, call `advisor()`. Final correctness check on implementation, refactor outcome, mutation result before durable status change.

</claude-only>

Flip surface: Edit anchored on the comment line `<!-- task=T-NNN status=... slice=... kind=... -->`. Status flip swaps the `status=` value byte-exact:

```
old_string: <!-- task=T-007 status=in-progress slice=release-sales-order kind=technical -->
new_string: <!-- task=T-007 status=done slice=release-sales-order kind=technical -->
```

Heading marker stays in sync (`[~]` → `[x]`) but is fallback rendering, not the anchor. Everything else inside task block (absorbed notes, mutation verdict, replan flag, layer overrides) is shape-per-task. See [notes-discipline.md](../../references/notes-discipline.md), [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md), [voice-contract.md](../../references/voice-contract.md).

## Composition

| | |
|---|---|
| **Runs after**     | `/al-refine` (filled Tests slot in `tasks.md`) |
| **Hands off to**   | `/al-code-review` per-slice at slice-done; `/al-code-review` per-feature at feature-done; else next ready technical task. |
| **Replan venue**   | `/al-steer` |
| **Sidebands**      | `/al-research` (BC facts), `/al-debug-logging` (execution path unclear), `/grill-me` (judgement needs user), `/bc-standard-reference` (pure BaseApp questions) |
