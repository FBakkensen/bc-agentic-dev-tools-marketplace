---
name: al-code-review
description: AL/Business Central code review at gate points. Use when a slice's last technical task lands (slice-done), when all tasks are done before merge (feature-done), or when the user asks for an in-depth code review.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-code-review, In-depth gate review

Deliberate gate at slice-done and feature-done boundaries, where code is finished enough to judge whole. Parallel lens sub-agents run each with a narrow goal, confidence pass suppresses noise, findings auto-feed per-finding `/grill-me` triage loop. Lens shape mirrors native `/code-review` but AL-shaped: lenses align with what trips AL reviewers, not generic ones.

Slice-done is natural goldilocks. Per-task review (pre-0.27 cadence) reviewed every TDD cycle's diff before slice was end-to-end coherent → cross-task drift surfaced only after slice closed anyway. Feature-done alone lets slice A's defects compound through slices B / C / D. Slice-done catches both: enough end-to-end shape to judge whole, small enough that defects don't ripple.

Programmatic gate runs before `/al-user-verification`. For user/API-facing slices the chain is implement → code-review → user-verification → next slice; for backend-only slices it is implement → code-review → next slice. Code-review surfaces structural defects, BC anti-patterns, naming-that-lies, AppSource lock-in before the user spends time walking checks that the same defects would invalidate.

`/al-refactor` (auto inside `/al-implement`) handles structural reshape at high relevance bar every cycle. `/al-code-review` lowers the bar and adds judgment-level lenses the refactor pass cannot afford.

## Preconditions

- Branch matches `^\d{3}-` and `specs/<branch>/tasks.md` exists.
- `/al-build` green: linter pipeline (CodeCop, AppSourceCop, UICop, AppSource Validation) has already cleared deterministic concerns → review starts where linters stop. Red baseline stops the gate.
- Tree state matches reviewer intent. Uncommitted reshape from unrelated work pollutes diff; confirm scope before proceeding.
- Read [`test-specification.md`](../../references/test-specification.md) before lens synthesis; lens 1 consumes `Test Specification`, lens 6 consumes `Verification Plan`.
- Per-slice user/API-facing mode requires the slice verify task to contain a populated `Verification Plan` before review. Empty plan → **Stop**, `Next: /al-refine T-NNN`; the review would otherwise run before lens 6 has an artifact to validate.

Any precondition fails → stop, surface the gap. Do not review against uncertain baseline.

## Scope and diff

Two modes, deduced from current state, recent `status=` flips, working tree, and what user said: **per-slice** (every technical task in one `slice=` is `done` and slice's gate flip has not landed yet — verify task still `blocked` for user-facing, or next slice's technical tasks still `blocked` for backend-only) or **per-feature** (full feature diff before merge). When inference uncertain (mid-stream WIP commits, mixed in-flight/done), ask with concrete options: "diff for slice `<slug>`?" / "full branch vs `main`?" / "uncommitted working tree?" / "SHA range you name?"

Per-slice scope: union of diffs for every `T-NNN` carrying slice's `slice=` value, from each task's first commit through its `done` flip. Backend-only slices use the same per-slice mode; they differ only in the gate flip (next slice's technical task set vs. verify task) and skip lens 6.

Pipeline commits carry `T-NNN <verb>: <message>` prefixes that associate commits with tasks; `review:` commit or squash defeats the grep, which is when asking beats guessing.

## Lenses

Spawn all lenses in one message so they run concurrently. Each lens has narrow focused goal; synthesis pass dedupes across them.

| # | Lens | Focused goal | Mode |
|---|---|---|---|
| 1 | Project compliance + naming + scope | Changes obey `CONTEXT.md`, design and domain ADRs under `docs/adr/`, module map and boundaries in `architecture.md`, originating task's `Test Specification` in `tasks.md`. Naming check: objects, procedures, variables, fields, parameters use BC vocabulary AND project terminology; names that lie surface even when code is otherwise correct. Scope check: behaviour in the diff not traceable to `Expected Behaviors`, `Decision Matrix`, or AAA cases is a finding — code doing more than asked (scope creep), and requirements that look implemented but wrong (present but defective), are each distinct from missing | both |
| 2 | Bug scan | Shallow scan for large bugs the LLM catches cold on a fresh read. Correctness and obvious logic faults only; skip nitpicks, skip style, skip anything a linter catches. Ad-hoc conditionals bolted into unrelated flows ("weird if statements in random places") escalate as a design problem, not a style nit | both |
| 3 | BC-specific via bc-code-intelligence | Per `${CLAUDE_SKILL_DIR}/../../references/bc-code-intelligence-dispatch.md`: `find_bc_knowledge` per concern → drop noise (`parker-pragmatic/*`, `*/recommend-*`, off-domain) → `get_bc_topic` → match each topic's `anti_pattern_indicators` against the diff. Cast wider than `/al-refactor`: the gate can afford the broader sweep | both |
| 4 | Code comments + git history | Code comments in modified files state guidance (invariants, "do not X" warnings); changes comply. Recent commit history surfaces context: previous fix the current change might re-break, deliberate decision being undone | both |
| 5 | AppSource public-surface addition | New public procedure, public table field, or page action on shipped object locks public contract into AppSource. Linters fire on removal (AS0011) and rename (AS0007), not on addition; read changed object alongside `app.json` and judge intentional vs accidental lock-in | per-feature only |
| 6 | Verify ↔ code alignment | Slice's verify task `Verification Plan` in `tasks.md` names surfaces, Roles, Status values, clients, and observable checks; changed code under slice's `slice=` actually exposes those surfaces with those names. Drift caught here means `/al-user-verification` would have failed when the user walked or checked it — preempt before the user spends the time. Skip for backend-only slices (no verify task) | per-slice only |

Lenses state goals, not enumerated checklists. Specifics each lens catches depend on code and what `bc-code-intelligence` surfaces. Structural and coupling vocabulary the lenses name (Connascence, CQS, Depth, Seam) lives in `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md`; use it exactly.

## Confidence pass

After lenses return, lighter-weight pass scores each finding 0-100 before showing user. Five lenses on a 10-file diff produce 30+ findings if every lens reports everything; filter makes list short enough for `/grill-me` to triage cleanly. Findings `< 80` suppressed; only `>= 80` reach triage. Prefer a few high-conviction findings over a long list of cosmetic notes; when a structural issue is in play, do not flood the list with nits beneath it.

| Score | Meaning |
|---|---|
| 0   | False positive, doesn't survive light scrutiny, or pre-existing |
| 25  | Might be real, might be false positive; lens couldn't verify |
| 50  | Verified as real but a nitpick, or not important relative to diff |
| 75  | Highly confident: real issue likely to hit OR explicitly called out in `CLAUDE.md` / `CONTEXT.md` / ADRs |
| 100 | Confirmed real, will hit frequently in practice, direct evidence |

## What lands on screen

Finding bodies live inside each `/grill-me` invocation. Chat surface is chrome only because captured pattern is "user reads findings list, immediately fires `/grill-me`"; pre-dumping bodies duplicates what grill shows. Shapes per Tables-of-facts and Lists-of-findings in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`:

| | |
|---|---|
| **Opener** (always)        | One line with count above threshold, plus 3-row scope chip (`**Scope**` / `**Baseline**` / `**Findings**`). One line per failed lens (`4/5 lenses returned, Lens 3 (BC-specific) errored: <reason>`) so user knows review is incomplete before triage. |
| **Inter-grill chrome** (N>1) | One line per landed decision, `[2/5] noted on T-009 → next`. Skipped when N=1. |
| **Closer**                 | 3-row mini-summary (`**New tasks**` / `**Notes**` / `**Dropped**`). On abort: partial summary, no resume, untriaged findings die. |

## Auto-grill loop

After confidence pass, skill spawns `/grill-me` per surviving finding automatically. No "Run `/grill-me`" handoff sentence; manual step adds keypress, not judgment, and per-finding judgment happens inside each grill. Order is severity-then-confidence (correctness > performance > hygiene; confidence breaks ties) because loop's failure mode is partial completion (context shift, session compaction); triaging most consequential first means dropped tail is least costly.

Per finding:

- **Spawn**: `/grill-me` with finding body (Finding / Where / Source / Severity / Confidence / Slice when per-slice), lens proposal (its `Recommended next`), scope context. Spawn prompt requires grill's first message to open with the finding body verbatim, then a short representative excerpt quoted from each cited `Where` (enough to ground the rule violation, not the full diff), then exploration, then first question — so user sees subject under interrogation before being asked to judge it. Scope chip lives in al-code-review's opener; grill does not re-emit it.
- **Contract**: three outcomes: new task in `tasks.md`, note on future task, drop.
- **References**: pass `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md` and `${CLAUDE_SKILL_DIR}/../../references/markdown-spec-discipline.md` for writeback shape.
- **Exit**: when decision lands.

Passing proposal (not raw finding) lets `/grill-me` stress-test whether proposal is right rather than invent one cold. Three outcomes:

- **New task**: append a new `### T-NNN+1 [ ] — <title>` heading with `<!-- task=T-NNN+1 status=ready slice=<slug> kind=technical -->` underneath, body carrying `Where` and `Source` as seed for `/al-refine`. Slice slug is just-reviewed slice (per-slice mode) or slice the fix most naturally belongs to (per-feature mode). Per-slice mode: new task in current slice re-opens slice — gate flip is suppressed (verify task stays `blocked`, next slice's first task stays `blocked`), handoff routes to `/al-implement` so the slice closes properly and `/al-code-review` re-runs on the updated diff. Per-feature mode: new task in any earlier closed slice is a defect — flip that slice's verify task back to `blocked` and route via `/al-steer`. Otherwise the new task waits for next `/al-implement` cycle.
- **Note on future task**: identify not-yet-`done` task whose work touches area; regenerate its NOTE callout block whole (surgical-edit contract on `tasks.md` is the comment-line `task=` + `status=` keys only).
- **Drop**: user accepts as known, not worth a task. Closer counts it.

Abort on explicit `stop` / `end loop` / `cancel`, off-topic shift, or compaction: emit partial-summary closer and exit, no resume (queue is transient). Single-finding case: spawn one grill, skip progress chip, straight to closer. `/grill-me` stays generic; triage contract rides in via spawn prompt, no section added to `grill-me`'s `SKILL.md`.

## Gate flip on clean review

Per-slice mode, no new tasks materialized in current slice: code-review owns the gate flip the slice depends on to advance.

- **User/API-facing slice** (verify task exists in slice with `kind=verify`): flip its `status=` from `blocked` to `ready` on the comment-anchor line, sync heading marker to `[~]`. Next handoff is state-conditional on the verify task's `Verification Plan` and the slice's bc-replay recording at `pagescripts/recordings/<NNN>-<slug>__<slice>.yml`: `Journey Examples` present and `.yml` missing → `Next: /al-page-script T-NNN`; `.yml` exists or no E2E recording is needed → `Next: /al-user-verification T-NNN`.
- **Backend-only slice** (no verify task): identify the next slice by the first technical task carrying `Depends on:` this slice's last technical task, then flip every technical task in that next slice from `blocked` to `ready`. File order plus in-slice `Depends on:` edges tell `/al-implement` which one to pick first. Announce `/al-implement` (or `/al-refine` if the first selected task has no `Test Specification`) as next handoff. If this was the feature's last slice (no next slice): announce `/al-code-review` per-feature as next handoff.
- **Last user-facing slice**: still flip verify task ready; same state-conditional next handoff as any user-facing slice. `/al-user-verification` then announces `/al-code-review` per-feature.

Edit shape for the user-facing flip:

```
old_string: <!-- task=T-NNN status=blocked slice=<slug> kind=verify -->
new_string: <!-- task=T-NNN status=ready slice=<slug> kind=verify -->
```

Cross-slice gate (backend-only) follows the same surgical-edit contract on each technical task in the next slice: `<!-- task=T-MMM status=blocked slice=<next-slug> kind=technical -->` → `status=ready`.

Per-feature mode: no gate flip; closer announces merge.

## Findings shape

Findings carry slot set `Finding / Where / Source (lens name + topic id) / Severity / Confidence / Recommended next` per Lists-of-findings rule in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. Body rides into its `/grill-me` invocation in this shape; grill displays then stress-tests it.

`/al-code-review` does not write durable artifacts before triage. Per-grilling materialization writes to `tasks.md` only. No `architecture.md`, `event-model.md`, ADR, `CONTEXT.md`, or `.out-of-scope/` writes. Findings address files by path + line or path + procedure; future readers grep on the symbol.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-implement` at slice-done (last technical task in slice flipped `done`) or at feature-done (last task in feature flipped `done`) |
| **Hands off to**   | per-slice: `/al-implement` if grill loop added new tasks in current slice; else state-conditional after the gate flip — user/API-facing slice routes to `/al-page-script` (`Journey Examples` present, `.yml` missing) or `/al-user-verification` (`.yml` exists or no E2E recording is needed); backend-only slice routes to next slice's technical tasks; `/al-code-review` per-feature if this was last slice and no `/al-user-verification` follows. per-feature: merge. |
| **Replan venue**   | n/a; findings auto-loop into `/grill-me` per finding, never via `/al-steer` (review findings are not replan signals) |
| **Sidebands**      | `/al-second-opinion` (cross-runtime advisory on large findings lists), `/grill-me` (per-finding triage), `/al-research` (BaseApp behaviour or BC convention), `/bc-standard-reference` (BaseApp pattern correctness) |

## Delegation

Spawn each lens as parallel sub-agent in one message. Lenses independent and context-expensive; running serially in main session burns tokens on per-file content synthesis doesn't need to retain. Per-feature mode benefits especially: five lenses across 20+ files is exactly the shape that wants parallelism. Delegation unavailable → run serially.

After lens outputs are collected and synthesized, close completed lens sub-agent threads before the confidence pass. Do not leave completed lens agents open as passive state.

Do not shadow a running lens. Lens fails or returns nothing → note gap in synthesis rather than re-running silently.
