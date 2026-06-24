---
name: al-code-review
description: AL/Business Central code review at gate points. Report-only by default; pass --fix to land must-fix findings and re-review once. Use when a slice's last technical task lands (slice-done), when all tasks are done before merge (feature-done), or when the user asks for an in-depth code review.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-code-review, Review gate (report-only, optional --fix)

Deliberate gate at slice-done and feature-done boundaries, where code is finished enough to judge whole. **Default is report-only:** spawn the review lenses, dedup, adversarially judge, cross-family-vet, then report the must-fix queue, the nits, and the gate decision — the user drives fixes (`/al-implement` on the named task). **`--fix`** additionally lands the must-fix findings in-loop (reusing the red-green subagent) and re-reviews once. This skill invokes no other skill except `/al-second-opinion` (cross-family veto) and `/al-build`; it spawns subagents for the lenses and, under `--fix`, for the red-green case work.

Runs before `/al-user-verification`. The order a user walks (each step user-invoked, nothing auto-chained): implement → refine verify task → code-review → page-script/user-verification → next slice (user/API-facing), or implement → code-review → next slice (backend-only); `/al-refactor` and `/al-mutate` slot in after implement on non-trivial work, at the user's discretion. Surfaces structural defects, BC anti-patterns, naming-that-lies, and AppSource lock-in before the user walks checks the same defects would invalidate.

`/al-refactor` reshapes structure at a high relevance bar; `/al-code-review` lowers the bar and adds judgment-level lenses the refactor pass cannot afford.

## Preconditions

- Branch matches `^\d{3}-` and `specs/<branch>/tasks/` exists.
- `/al-build` green: the linter pipeline (CodeCop, AppSourceCop, UICop, AppSource Validation) has already cleared deterministic concerns → review starts where linters stop. Red baseline stops the gate.
- Tree state matches reviewer intent. Uncommitted reshape from unrelated work pollutes the diff; confirm scope before proceeding. Under `--fix`, the tree must be clean to start (it commits its own fixes).
- Read [`test-specification.md`](../../references/test-specification.md) before lens synthesis; lens 1 consumes `Test Specification`, lens 6 consumes `Verification Plan`.
- Per-slice user/API-facing mode requires the slice verify task at `status: ready-for-verification` with a populated `Verification Plan`. Plain `ready` → **Stop**, `Next: /al-refine T-NNN`. `ready-for-verification` with an empty plan → **Stop**, `Next: /al-steer`; status and proof disagree. `blocked` → **Stop**, `Next: /al-steer`. `done` → verify evidence already exists; per-slice review is no longer the gate.

Any precondition fails → **Stop**, surface the gap. Do not review against an uncertain baseline.

## Scope and diff

Two modes, deduced from current state, recent `status:` flips, working tree, and what the user said: **per-slice** (every technical task in one `slice:` is `done`; user/API-facing verify task is `ready-for-verification`, or backend-only next slice's technical tasks are still `blocked`) or **per-feature** (full feature diff before merge). When inference is uncertain (mid-stream WIP commits, mixed state), ask with concrete options: "diff for slice `<slug>`?" / "full branch vs `main`?" / "uncommitted working tree?" / "SHA range you name?"

Per-slice scope: union of diffs for every `T-NNN` carrying the slice's `slice:` value, from each task's first commit through its `done` flip, **plus any `--fix` commits this run lands**. Backend-only slices use the same per-slice mode; they differ only in the clean-review outcome (next slice's technical task set opens) and skip lens 6.

Pipeline commits carry `T-NNN <verb>: <message>` prefixes that associate commits with tasks; `--fix` commits carry the originating `T-NNN` prefix so re-review attributes them. A squash that defeats the grep is when asking beats guessing.

## Review pass

Run the lenses, then resolve findings. The same pass runs in both modes; only what happens *after* differs (report vs fix).

1. **Find** — spawn the lenses below in parallel, one subagent per lens, each with its focused goal plus the diff/scope. File-read lenses use the prompt in [`subagents/al-review-lens.md`](../../references/subagents/al-review-lens.md); the BC-specific lens (3) uses [`subagents/al-review-lens-bc.md`](../../references/subagents/al-review-lens-bc.md) for its bc-code-intelligence reach (a small/fast model suffices — see the tier note in those files). The spawn prompt carries only the per-lens goal plus the diff/scope; vocabulary and findings shape live in the prompt block. Lens 1's spawn additionally carries the evidence bar's **Constructs** bullet verbatim.
2. **Dedup** — merge the overlap (lenses surface the same issue more than once) into a unique, ranked list.
3. **Judge** — per unique finding, adversarially test it (skeptics prompted to *refute*, spawned in parallel or judged inline); default to false-positive when it can't be substantiated. The judge is what stands where the human grill used to, so it must be at least as skeptical. Per finding it resolves: real or not; **must-fix or nit** (must-fix is correctness, contract/AppSource lock-in, behaviour, scope violation, or skipped evidence; a borderline finding defaults to **nit**); and **fixable-in-loop or needs-a-decision** (a replan-class finding — new seam, decomposition wrong, new behaviour — has no red-first test that pins a decision nobody made, so `--fix` cannot land it).
4. **Cross-family pass** — `/al-second-opinion` (GPT-pinned, one call on the must-fix survivor list) refutes the set. The only non-Claude eye, so it runs before anything is reported as must-fix or fixed: a finding it refutes drops to **escalate** (don't act on cross-family doubt); a real finding it raises that the judges missed re-enters judging.

Survivors partition: real + must-fix + fixable → **fix queue**; real + nit → **nit list**; not-real → **dropped**; cross-family-refuted or needs-a-decision → **escalate** (→ `/al-steer`).

## Lenses

| # | Lens | Focused goal | Mode |
|---|---|---|---|
| 1 | Project compliance + naming + scope | Changes obey `CONTEXT.md`, design and domain ADRs under `docs/adr/`, module map and boundaries in `architecture.md`, originating task's `Test Specification` in its file under `tasks/`. Naming: objects, procedures, variables, fields, parameters use BC vocabulary AND project terminology; names that lie surface even when code is otherwise correct. Evidence: a task whose diff adds a BC construct class (per the bar's Constructs bullet, carried in this lens's spawn prompt) with no `Researched:` bullet in its `Contract notes` is a finding — evidence bar skipped (`voice-contract.md`). Push-up: an `Integration` AAA case whose `Contract notes` states no wall and names no seam is a finding (`test-strategy.md`). Scope: behaviour in the diff not traceable to `Expected Behaviors`, `Decision Matrix`, or AAA cases is a finding. Rigor: a non-trivial task's `Closeout` with no mutation verdict table surfaces as an **advisory note**, not a must-fix — mutation (`/al-mutate`) is user-directed and does not hold this gate; the note recommends `/al-mutate T-NNN` so the user can prove test rigor before merge (never routed to `/al-implement`, which would reject the `done` task). Surface: reconciled `New and Modified Objects` matches the production diff — match per task via `T-NNN` commit prefixes, fall back to the union of reviewed tasks' sections when fuzzy; a production object in the diff absent from the section(s), or a section entry the diff never landed, is a finding | both |
| 2 | Bug scan | Shallow scan for large bugs the LLM catches cold on a fresh read. Correctness and obvious logic faults only; skip nitpicks, skip style, skip anything a linter catches. Ad-hoc conditionals bolted into unrelated flows escalate as a design problem | both |
| 3 | BC-specific via bc-code-intelligence | Per [`bc-code-intelligence-dispatch.md`](../../references/bc-code-intelligence-dispatch.md): `find_bc_knowledge` per concern → drop noise (`parker-pragmatic/*`, `*/recommend-*`, off-domain) → `get_bc_topic` → match each topic's `anti_pattern_indicators` against the diff. Cast wider than `/al-refactor`: the gate can afford the broader sweep | both |
| 4 | Code comments + git history | Code comments in modified files state guidance (invariants, "do not X" warnings); changes comply. Recent commit history surfaces context: previous fix the current change might re-break, deliberate decision being undone | both |
| 5 | AppSource public-surface addition | New public procedure, public table field, or page action on a shipped object locks public contract into AppSource. Linters fire on removal (AS0011) and rename (AS0007), not on addition; read the changed object alongside `app.json` and judge intentional vs accidental lock-in | per-feature only |
| 6 | Verify ↔ code alignment | Slice's verify task `Verification Plan` names surfaces, Roles, Status values, clients, observable checks; changed code under the slice's `slice:` actually exposes those surfaces with those names. Drift caught here means `/al-user-verification` would have failed — preempt it. Push-up: a `Record: yes` E2E or `Contract` example whose `Contract notes` states no wall and names no seam is a finding; `Record: no` E2E and `Exploration` charters are not push-ups. Skip for backend-only slices | per-slice only |

Lenses state goals, not enumerated checklists. Structural/coupling vocabulary (Connascence, CQS, Depth, Seam) lives in [`LANGUAGE.md`](../../references/LANGUAGE.md); use it exactly. A lens that fails or returns nothing → note the gap in the summary rather than re-running silently.

## Report-only (default)

The pass resolves; report and stop. No code moves. The closer lists:

- **Fix queue** — each must-fix survivor as `Finding / Where / Why / Recommended next`, the recommended next being `/al-implement T-NNN` on the originating task (traced via the `T-NNN` commit prefix on the flagged code; fall back to the most natural owner when fuzzy). Hygiene-class findings (provably non-semantic — comment scrub, local/private rename, formatting) are named as such so the user can apply them without a test.
- **Nits** — real-but-cosmetic, listed once, left alone.
- **Rigor notes** — a non-trivial `done` task whose `Closeout` lacks a mutation verdict → `Next: /al-mutate T-NNN`. Advisory: mutation is user-directed, so this does not hold the gate or block the `review: clean` stamp.
- **Escalations** — needs-a-decision or cross-family-refuted findings, routed `Next: /al-steer`.
- **Gate** — clean (no must-fix) stamps the gate (below); otherwise the gate is held until the fix queue is cleared. A rigor note alone does not hold the gate.

Report-only never writes a durable artifact except the clean-review `review: clean` stamp (below). Escalations write nothing — `/al-steer` is where a human mints whatever the decision needs.

## --fix (opt-in)

After the review pass, land the fix queue in the working tree, then re-review **once**. Serial, in the skill — builds and containers can't safely parallelize. Each fix-queue finding folds into its **originating task** (traced via the `T-NNN` prefix). Two paths, by whether the finding moves decision logic:

- **Substantive** (moves behaviour, a decision, design judgement, or a public/shipped surface): reopen the originating task in working memory, then **spawn a subagent with [`subagents/al-red-green.md`](../../references/subagents/al-red-green.md)**, passing the missing/adjusted AAA case and the originating task file path — the case is the durable proof that stops the next review re-flagging it. Reconcile `New and Modified Objects` + `Researched:` bullets so lens 1 reads truth on re-review, and commit under the originating `T-NNN` prefix. Mutation of the changed sites is a recommended follow-up (`/al-mutate`), not run here — `--fix` stops at green, like `/al-implement`. A public/shipped-surface rename is an AS0007 decision, never hygiene → substantive or escalate.
- **Hygiene** (provably non-semantic): apply, rerun `/al-build` to confirm green, commit as a standalone hygiene fix. No test. If the build reds (a rename collided, a pragma comment mattered), revert and re-judge as substantive or escalate.

A substantive fix that can't go green → **escalate** (don't leave the tree red). A `needs-a-decision` finding → **escalate**; `--fix` does not invent the decision.

**Re-review once.** After the fixes land, run the review pass again on the updated diff (fixes now in scope), so a bad fix is caught. This is a single re-review, **not** an autonomous loop: report what the second pass finds. Clean → stamp the gate. Still-must-fix or recurs-after-fix → report it with `Next: /al-implement T-NNN` (or `/al-steer` for a recurrence) and let the user decide; do not re-fix.

**Per-feature mode under --fix.** A substantive must-fix finding here lands in a slice the user already walked in `/al-user-verification`; auto-fixing it would invalidate that slice's verify evidence and force a re-walk. So `--fix` does **not** land it — it **escalates** it (→ `/al-steer`), where the human decides the fix and the slice re-enters verification deliberately. Hygiene findings still auto-apply. Backend-only slices in a per-feature diff carry no verify walk, so their substantive findings land via the red-green block normally.

## Gate outcome on clean review

A clean review (no must-fix — in `--fix`, after the single re-review) stamps the gate. Per-slice mode validates the already-refined gate; it does not flip verify tasks from `blocked` to `ready`.

- **User/API-facing slice** (verify task with `kind: verify` in the slice): preserve `status: ready-for-verification` and add a `review: clean` line to the verify task's frontmatter, one Edit. This is the durable clean-review evidence — without it the status byte reads identically before and after review. Lifecycle/strip rules live in [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md); this skill is the field's only writer. Next handoff is state-conditional on the slice's per-scenario recordings at `pagescripts/recordings/<NNN>-<slug>__<slice>__NN.yml`: a `Record: yes` Journey Example whose recording is missing → `Next: /al-page-script T-NNN`; all `Record: yes` recordings present (or no `Record: yes` example) → `Next: /al-user-verification T-NNN`.
- **Backend-only slice** (no verify task): identify the next slice by the first technical task carrying `depends_on:` this slice's last technical task, then flip every technical task in that next slice from `blocked` to `ready` (a state write this skill owns inline). `Next: /al-refine` on the first opened task. If this was the feature's last slice: open the `kind: breaking-change` task `blocked` → `ready` (this skill is its named flip-owner for a backend-only feature), `Next: /al-validate-breaking-changes`, then `/al-code-review` per-feature.
- **Last user-facing slice**: still preserve `ready-for-verification`; same state-conditional next handoff. `/al-user-verification` then announces `/al-code-review` per-feature.
- **Per-feature clean** (no must-fix): `Next:` merge.

## What lands on screen

Chat stays chrome-only during the pass; lens churn and the judge stay out of context. Shapes per Tables-of-facts and Lists-of-findings in [`voice-contract.md`](../../references/voice-contract.md):

| | |
|---|---|
| **Opener** (always) | One line, plus a 3-row scope chip (`**Scope**` / `**Baseline**` / `**Mode**`). One line per failed lens so the user knows the review was partial. |
| **Closer** | Mini-summary: `**Fix queue**` (report-only: each with `Next: /al-implement`; `--fix`: `**Fixed**` with commits) / `**Nits**` (left, once) / `**Escalated**` (→ `/al-steer`, with why) / `**Gate**` (clean stamp + next handoff, or merge, or held). On abort: partial summary, no resume. |

## Findings shape

Each lens returns a raw finding — `Finding / Where / Why / Source (lens name + topic id)`, per Lists-of-findings in [`voice-contract.md`](../../references/voice-contract.md). The judge attaches the verdict — must-fix or nit, fixable or needs-a-decision; no numeric confidence score, the adversarial judge replaced it.

`/al-code-review` writes no durable artifact except the clean-review `review: clean` field and (under `--fix`) the reconciled originating task file + fix commits. No `architecture.md`, `event-model.md`, ADR, `CONTEXT.md`, or `.out-of-scope/` writes; escalation routes to `/al-steer` and writes nothing.

## Next step

Read off the gate outcome:

- **Must-fix queue non-empty (report-only or after `--fix` re-review):** `Next: /al-implement T-NNN` on the highest-priority originating task; user applies hygiene findings directly. Re-run `/al-code-review` after.
- **Rigor note present (a `done` task missing a mutation verdict):** `Next: /al-mutate T-NNN` to prove test rigor — advisory, runs alongside the clean stamp rather than blocking it.
- **Clean, user/API-facing slice:** `Next: /al-page-script T-NNN` (a `Record: yes` recording missing) or `/al-user-verification T-NNN` (all present or none needed).
- **Clean, backend-only slice:** `Next: /al-refine` on the first opened next-slice task; or `/al-validate-breaking-changes` if the feature's last slice.
- **Clean, per-feature:** `Next:` merge.
- **Escalations present:** `Next: /al-steer` for the decision-class findings.

If state can't be read, fall back: report-only → `/al-implement` on the named findings; clean → `/al-steer` to confirm the next gate.

## Feed

Three moments narrate to the branch feed. At each, hand `/al-feed` a brief — what happened in BC terms, why it matters to a dev who hasn't read the diff, the kind — and `/al-feed` composes. Routine lens churn, the judge pass, and per-lens spawns never card.

- **surprise** · a precondition fails and the gate Stops before review (red `/al-build` baseline, slice not `ready-for-verification`, polluted tree). Captures which precondition tripped, what has to happen first.
- **verdict** · the review pass resolves with its fix-queue / nit counts (and, under `--fix`, what landed). Captures what the review found and the gate decision; any errored lens so the dev knows it was partial.
- **landing** · the gate stamps clean and the next chunk opens, or the run escalates to `/al-steer`, or a per-feature finding re-opens verification. Captures the slice passing and the next work unlocked, or review sending something back.

## Composition

| | |
|---|---|
| **Runs after**     | user/API-facing per-slice: `/al-refine` filled the slice verify task and flipped it to `ready-for-verification`; backend-only per-slice: `/al-implement` flipped the last technical task in the slice to `done`; per-feature: last task in feature flipped `done` |
| **Hands off to**   | report-only: `/al-implement` on the named must-fix tasks. Clean per-slice: user/API-facing → `/al-page-script` or `/al-user-verification`; backend-only → next slice's tasks to `ready` (`/al-refine`), or `/al-validate-breaking-changes` if last slice. Clean per-feature: merge. Escalation: `/al-steer` |
| **Calls directly** | `/al-second-opinion` (cross-family veto, one call/pass), `/al-build` (baseline + `--fix` green checks) — the only skills it invokes |
| **Spawns**         | review-lens subagents from [`subagents/al-review-lens.md`](../../references/subagents/al-review-lens.md) / [`al-review-lens-bc.md`](../../references/subagents/al-review-lens-bc.md); under `--fix`, the red-green subagent from [`subagents/al-red-green.md`](../../references/subagents/al-red-green.md) |
| **Replan venue**   | `/al-steer` — escalation classes only; fixable findings go to `/al-implement` (report-only) or land in `--fix` |
