---
name: al-code-review
description: AL/Business Central code review at gate points. Use when a slice's last technical task lands (slice-done), when all tasks are done before merge (feature-done), or when the user asks for an in-depth code review.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-code-review, Autonomous review-and-fix gate

Deliberate gate at slice-done and feature-done boundaries, where code is finished enough to judge whole. The gate is a **bounded autonomous loop**: a read-only review Workflow finds and adversarially judges issues, then the skill drives the survivors to fixed code through `/al-implement`, re-reviews the new diff, and repeats — up to three rounds, or until only nits remain. No per-finding human triage, no manual re-kickoff; the human re-enters only on escalation and reads the final summary.

Runs before `/al-user-verification`: chain is implement → refine verify task → code-review → page-script/user-verification → next slice (user/API-facing), or implement → code-review → next slice (backend-only). Surfaces structural defects, BC anti-patterns, naming-that-lies, and AppSource lock-in before the user walks checks the same defects would invalidate.

`/al-refactor` (auto inside `/al-implement`) reshapes structure at a high relevance bar every cycle; `/al-code-review` lowers the bar, adds judgment-level lenses the refactor pass cannot afford, and — unlike refactor — fixes what it finds.

## Preconditions

- Branch matches `^\d{3}-` and `specs/<branch>/tasks/` exists.
- `/al-build` green: linter pipeline (CodeCop, AppSourceCop, UICop, AppSource Validation) has already cleared deterministic concerns → review starts where linters stop. Red baseline stops the gate.
- Tree state matches reviewer intent. Uncommitted reshape from unrelated work pollutes diff; confirm scope before proceeding. The loop commits its own fixes per round, so it requires a clean tree to start.
- Read [`test-specification.md`](../../references/test-specification.md) before lens synthesis; lens 1 consumes `Test Specification`, lens 6 consumes `Verification Plan`.
- Per-slice user/API-facing mode requires the slice verify task to have `status: ready-for-verification` and a populated `Verification Plan` before review. Plain `ready` → **Stop**, `Next: /al-refine T-NNN`. `ready-for-verification` with an empty plan → **Stop**, route to `/al-steer`; status and proof disagree. `blocked` → **Stop**, route to `/al-steer` or complete the missing technical dependency. `done` → verify evidence already exists; per-slice review is no longer the gate.

Any precondition fails → stop, surface the gap. Do not review against uncertain baseline.

## Scope and diff

Two modes, deduced from current state, recent `status:` flips, working tree, and what user said: **per-slice** (every technical task in one `slice:` is `done`; user/API-facing verify task is `ready-for-verification`, or backend-only next slice's technical tasks are still `blocked`) or **per-feature** (full feature diff before merge). When inference uncertain (mid-stream WIP commits, mixed done/ready-for-* state), ask with concrete options: "diff for slice `<slug>`?" / "full branch vs `main`?" / "uncommitted working tree?" / "SHA range you name?"

Per-slice scope: union of diffs for every `T-NNN` carrying slice's `slice:` value, from each task's first commit through its `done` flip, **plus any review-fix commits the loop lands this run**. Backend-only slices use the same per-slice mode; they differ only in the clean-review outcome (next slice's technical task set opens) and skip lens 6.

Pipeline commits carry `T-NNN <verb>: <message>` prefixes that associate commits with tasks; the loop's own fix commits carry the originating `T-NNN` prefix so re-review attributes them. A squash that defeats the grep is when asking beats guessing.

## The loop

The skill owns the round counter and the stop decision. Each round:

1. **Review phase** — spawn the read-only review Workflow (below). It returns a judged, deduped, cross-family-vetted **fix queue** (must-fix survivors) and a **nit list** (real-but-cosmetic, left alone).
2. **Fix phase** — drive each fix-queue finding to fixed, committed code, serially (below).
3. **Re-review** — the next round reviews the updated diff (fixes now in scope), so a bad fix is caught like any other defect.

**Stop** when a round's fix queue is empty — clean, or only nits remain. **Cap at three rounds**; the cap only fires when substantive findings keep surfacing across rounds.

**Carry verdicts forward — never re-judge stable code.** The original slice code does not change between rounds; only the fix commits do. So a finding whose `Where` sits in a region no fix touched this run keeps its prior round's verdict (a nit stays a nit) — it does not reach the judge or the cross-family pass again. Only findings in *changed* regions (this run's fix commits) or genuinely new ones are judged. The lenses may still scan broadly (a fix can break distant code), but the spend — judging, cross-family refutation — fires on the delta, not the stable remainder. This is the same cross-round finding ledger the recurrence guard uses (Termination); judging a nit once, not once per round, is what keeps a noisy slice from paying three times for the same cosmetics.

## Review phase (Workflow)

A read-only Workflow, so the finder/judge churn stays out of the main context. Stages:

- **Find** — the lenses (below) fan out in parallel, each a narrow goal, each returning raw findings.
- **Dedup** — one pass merges the overlap (lenses surface the same issue more than once) into a unique, ranked list.
- **Judge** — per unique finding, parallel adversarial skeptics prompted to *refute*; default to false-positive when the finding can't be substantiated. The judge is the only thing standing where the human grill used to, so it must be at least as skeptical. It returns, per finding: real or not; **must-fix or nit** (the nit cutoff is the judge's call — must-fix is correctness, contract/AppSource lock-in, behaviour, scope violation, or skipped evidence; a borderline finding defaults to **nit**, because under autonomy a wrongly-applied fix costs more than a wrongly-deferred one); and **fixable-in-loop or needs-a-decision** (a replan-class finding — new seam, decomposition wrong, new behaviour — has no red-first test that pins a decision nobody made, so it cannot be fixed autonomously).
- **Cross-family pass** — `/al-second-opinion` (GPT-pinned, one call on the survivor list) refutes the must-fix set. It is the only non-Claude eye in an otherwise all-Claude loop, so it runs **every round** before any fix lands. Its verdict is a **veto on autonomous action**: a finding it refutes drops out of the fix queue and escalates (don't auto-fix on cross-family doubt); a real finding it raises that the Claude judges missed re-enters judging.

Survivors partition: real + must-fix + fixable → **fix queue**; real + nit → **nit list** (reported once, never fixed, never re-armed); not-real → **dropped** (no action); cross-family-refuted or needs-a-decision → **set aside** (escalated at run end, below).

## Lenses

Each lens is the `al-agentic-dev:al-review-lens` agent, except lens 3 (BC-specific) which spawns `al-agentic-dev:al-review-lens-bc` for its bc-code-intelligence reach. Each has a narrow focused goal; the dedup stage merges across them. The spawn prompt carries only the per-lens goal below plus the diff/scope; the read-only envelope, model pin, BC vocabulary, and findings shape live in the agent body and ship to consumer repos. Lens 1's spawn prompt additionally carries the evidence bar's **Constructs** bullet verbatim.

| # | Lens | Focused goal | Mode |
|---|---|---|---|
| 1 | Project compliance + naming + scope | Changes obey `CONTEXT.md`, design and domain ADRs under `docs/adr/`, module map and boundaries in `architecture.md`, originating task's `Test Specification` in its file under `tasks/`. Naming check: objects, procedures, variables, fields, parameters use BC vocabulary AND project terminology; names that lie surface even when code is otherwise correct. Evidence check: a task whose diff adds a BC construct class (per the bar's Constructs bullet, carried in this lens's spawn prompt) with no `Researched:` bullet in its `Contract notes` is a finding — evidence bar skipped (`voice-contract.md`). Scope check: behaviour in the diff not traceable to `Expected Behaviors`, `Decision Matrix`, or AAA cases is a finding — scope creep, and present-but-defective, are each distinct from missing. Surface check: reconciled `New and Modified Objects` matches the production diff — match per task via `T-NNN` commit prefixes (loop fix commits carry the originating prefix), fall back to the union of reviewed tasks' sections when attribution is fuzzy; a production object in the diff absent from the section(s), or a section entry the diff never landed, is a finding (dishonest reconcile) | both |
| 2 | Bug scan | Shallow scan for large bugs the LLM catches cold on a fresh read. Correctness and obvious logic faults only; skip nitpicks, skip style, skip anything a linter catches. Ad-hoc conditionals bolted into unrelated flows escalate as a design problem, not a style nit | both |
| 3 | BC-specific via bc-code-intelligence | Per `${CLAUDE_SKILL_DIR}/../../references/bc-code-intelligence-dispatch.md`: `find_bc_knowledge` per concern → drop noise (`parker-pragmatic/*`, `*/recommend-*`, off-domain) → `get_bc_topic` → match each topic's `anti_pattern_indicators` against the diff. Cast wider than `/al-refactor`: the gate can afford the broader sweep | both |
| 4 | Code comments + git history | Code comments in modified files state guidance (invariants, "do not X" warnings); changes comply. Recent commit history surfaces context: previous fix the current change might re-break, deliberate decision being undone | both |
| 5 | AppSource public-surface addition | New public procedure, public table field, or page action on shipped object locks public contract into AppSource. Linters fire on removal (AS0011) and rename (AS0007), not on addition; read changed object alongside `app.json` and judge intentional vs accidental lock-in | per-feature only |
| 6 | Verify ↔ code alignment | Slice's verify task `Verification Plan` in its file under `tasks/` names surfaces, Roles, Status values, clients, and observable checks; changed code under slice's `slice:` actually exposes those surfaces with those names. Drift caught here means `/al-user-verification` would have failed — preempt before the user spends the time. Skip for backend-only slices (no verify task) | per-slice only |

Lenses state goals, not enumerated checklists. Structural and coupling vocabulary the lenses name (Connascence, CQS, Depth, Seam) lives in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`; use it exactly. A lens that fails or returns nothing → note the gap in the round's summary rather than re-running silently.

## Fix phase

Serial, in the skill — builds, commits, and containers can't safely parallelize, and `/al-mutate` demands clean git state. Each fix-queue finding folds into its **originating task** (traced via the `T-NNN` commit prefix on the code it flags; fall back to the most natural owner when attribution is fuzzy). Two paths, by whether the finding moves decision logic:

- **Substantive** (moves behaviour, a decision, design judgement, or a public/shipped surface): drive `/al-implement` **fix-mode** on the finding. It reopens the originating task, lands the fix red-first (a coverage-gap finding adds the missing AAA case — the test *is* the durable proof that stops the next review re-flagging it), mutates, reconciles `New and Modified Objects` + `Researched:` bullets so lens 1 reads truth next round, and commits — all under the originating `T-NNN` prefix. Fix-mode is **mute**: it announces no slice-gate handoff and triggers no review; this loop owns re-review. A public/shipped-surface rename is an AS0007 AppSource decision, never hygiene → substantive or escalation.
- **Hygiene** (provably non-semantic — comment scrub, *local/private* rename, formatting, process-noise cleanup): apply, rerun `/al-build` to confirm green, commit as a standalone hygiene fix. No test, no `/al-refine`, no `/al-mutate` — the mutation trigger assumes the move changes decision logic, and a non-semantic move has none to pin (carve-out; the same absorb `/al-implement` already grants a local rename). If the build reds (a rename collided, a pragma comment mattered), revert and re-judge as substantive or escalate.

If a substantive fix can't go green, **escalate** the finding (below) — never leave the tree red.

## Termination and escalation

Two distinct events: a single finding **set aside**, and the **run** ending. They are not the same — setting one finding aside does not stop the loop, it keeps fixing the rest.

A finding the loop cannot resolve autonomously is **set aside**: pulled from the fix queue and collected. At run end the collected set is reported in the final summary and routed to `/al-steer`, **writing nothing durable** (the loop's only durable outputs are ever code + commits; `/al-steer` is where a human mints whatever artifact the decision needs). A finding is set aside when it is:

- **needs-a-decision** (replan-class) — can't be a red-first fix;
- **cross-family-refuted** — `/al-second-opinion` vetoed it, so it doesn't get auto-fixed on cross-family doubt;
- **can't-go-green** — a substantive fix attempt left the build red and was reverted;
- **recurs-after-fix** — it reappears in a later round's review, proving the fix didn't take. Set aside *that finding* immediately; do not re-attempt. The loop carries per-finding identity across rounds (fuzzy match on `Where` + finding text) to detect this.
- **per-feature, in an already-verified slice** — auto-fixing code the user already walked in `/al-user-verification` would invalidate that evidence and force a re-walk regardless, so the fix is not worth doing autonomously (see Per-feature mode).

The **run** ends when the fix queue empties (clean, or only nits remain) or the **round cap (3)** is hit with substantive findings still surfacing — the cap is the backstop for genuinely new findings each round, not for a stuck one. Either way the closer reports fixed / nits / set-aside.

## Gate outcome on clean review

The loop terminates clean when a round's fix queue is empty. Because fixes fold in and re-review *within* the loop, there is no external re-arm cycle — a clean terminal round stamps the gate directly.

Per-slice mode: code-review validates the already-refined gate. It does not flip verify tasks from `blocked` to `ready`.

- **User/API-facing slice** (verify task exists in slice with `kind: verify`): preserve `status: ready-for-verification` and add a `review: clean` line to the verify task's frontmatter, one Edit. The field is the durable clean-review evidence — without it the status byte reads identically before and after review. Lifecycle and strip rules live in `${CLAUDE_SKILL_DIR}/../../references/markdown-spec-discipline.md`; this skill is the field's only writer. Next handoff is state-conditional on the verify task's `Verification Plan` and the slice's per-scenario recordings at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml`: a `Record: yes` Journey Example whose recording is missing → `Next: /al-page-script T-NNN`; all `Record: yes` recordings present (or no `Record: yes` example) → `Next: /al-user-verification T-NNN`.
- **Backend-only slice** (no verify task): identify the next slice by the first technical task carrying `depends_on:` this slice's last technical task, then flip every technical task in that next slice from `blocked` to `ready`. Announce `/al-refine` on the first opened task. If this was the feature's last slice: open the `kind: breaking-change` task `blocked` → `ready` (this skill is its named flip-owner for a backend-only feature), announce `/al-validate-breaking-changes`, then `/al-code-review` per-feature.
- **Last user-facing slice**: still preserve `ready-for-verification`; same state-conditional next handoff. `/al-user-verification` then announces `/al-code-review` per-feature.

Cross-slice gate (backend-only) follows the surgical-edit contract on each technical task in the next slice: locate the file by its `T-MMM` filename and flip its `status:` line `blocked` → `ready`.

**Per-feature mode.** A substantive must-fix finding here lands in a slice the user already walked in `/al-user-verification`; auto-fixing it would invalidate that slice's verify evidence and force a re-walk regardless. So the loop does **not** auto-fix it — it **sets the finding aside** (escalated at run end to `/al-steer`), where the human decides the fix and the slice re-enters verification deliberately rather than the loop churning a fix before the mandatory re-walk. Hygiene (non-semantic) findings still auto-apply — they move no behaviour the walk verified. Backend-only slices in a per-feature diff carry no verify walk, so their substantive findings auto-fix via fix-mode normally. A clean per-feature run with no must-fix findings: closer announces merge.

## What lands on screen

Chat stays chrome-only during the run; the loop's detail lives in commits and `/al-steer`. Shapes per Tables-of-facts and Lists-of-findings in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`:

| | |
|---|---|
| **Opener** (always)     | One line, plus 3-row scope chip (`**Scope**` / `**Baseline**` / `**Mode**`). One line per failed lens so the user knows the review was partial. |
| **Per-round chrome** (rounds > 1) | One line per round: `[round 2/3] 3 fixed, 1 nit, re-reviewing`. Skipped on a single-round run. |
| **Closer**              | Mini-summary: `**Fixed**` (with commits) / `**Nits**` (left, listed once) / `**Escalated**` (→ `/al-steer`, with why) / `**Gate**` (clean stamp + next handoff, or merge, or re-verification re-opened). On abort: partial summary, no resume. |

## Findings shape

Each lens returns a raw finding — `Finding / Where / Why / Source (lens name + topic id)`, the shape its agent body defines, per the Lists-of-findings rule in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. The judge attaches the verdict — must-fix or nit, fixable or needs-a-decision; there is no numeric confidence score, the adversarial judge replaced the old confidence pass. A fix-queue survivor seeds `/al-implement` fix-mode as `Finding / Where / Source / Recommended next` (matching fix-mode's contract) — the judge already resolved must-fix, so severity does not cross the boundary.

`/al-code-review` writes no durable artifact before a fix lands. Fix-phase materialization (the reconciled originating task file, the fix commit, a hygiene commit) and the clean-review `review: clean` field are the only writes. No `architecture.md`, `event-model.md`, ADR, `CONTEXT.md`, or `.out-of-scope/` writes; escalation routes to `/al-steer` and writes nothing. Findings address files by path + line or path + procedure; future readers grep on the symbol.

## Feed

Four moments narrate to the branch feed. At each, hand `/al-feed` a brief — what just happened in BC terms, why it matters to a developer who has not read the diff, and the kind — and `/al-feed` composes the punchline and layers and appends. Routine lens churn, the judge pass, per-round re-reviews, and per-lens spawns never card.

- **surprise** · a precondition fails and the gate Stops before any round runs (red `/al-build` baseline, slice not `ready-for-verification`, polluted tree). Captures: the gate refused to start — which precondition tripped, what has to happen first.
- **verdict** · a round's review phase resolves with its fix-queue / nit counts. Captures: what the review found this round and what the loop is about to fix; any errored lens so the developer knows the round was partial.
- **landing** · a fix-queue finding reaches fixed, committed code. Captures: for this one finding, what was wrong and how the fix proves itself (the red-first case or the hygiene scrub) — the developer's veto point on an autonomous change.
- **landing** · the loop terminates — clean gate stamps `review: clean` and the next chunk opens, or the run escalates to `/al-steer`, or a per-feature fix re-opens verification. Captures: the slice passed and the next work unlocked, or review sent something back, and the next handoff.

## Composition

| | |
|---|---|
| **Runs after**     | user/API-facing per-slice: `/al-refine` filled the slice verify task and flipped it to `ready-for-verification`; backend-only per-slice: `/al-implement` flipped the last technical task in slice to `done`; per-feature: last task in feature flipped `done` |
| **Hands off to**   | per-slice clean: state-conditional after validation — user/API-facing slice routes to `/al-page-script` (a `Record: yes` Journey Example's recording missing) or `/al-user-verification` (all `Record: yes` recordings present, or none needed); backend-only slice opens the next slice's technical tasks to `ready` (→ `/al-refine`), or — if last backend slice — opens the `kind: breaking-change` task and routes to `/al-validate-breaking-changes`, then `/al-code-review` per-feature. per-feature clean: merge. Escalation (any mode): `/al-steer`. |
| **Drives**         | `/al-implement` fix-mode (per fix-queue survivor, serial), the read-only review Workflow (per round), `/al-second-opinion` (cross-family veto, per round) |
| **Replan venue**   | `/al-steer` — only the escalation classes reach it; fixable findings never route there, the loop fixes them inline |
| **Sidebands**      | `al-research` agent (BaseApp behaviour or BC convention), `bc-standard-reference` agent (BaseApp pattern correctness) |
