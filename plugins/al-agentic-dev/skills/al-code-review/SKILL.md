---
name: al-code-review
description: AL/Business Central code review at gate points. Use when a slice's verify task lands (slice-done), when all tasks are done before merge (feature-done), or when the user asks for an in-depth code review.
---

# /al-code-review, In-depth gate review

A deliberate gate at slice-done and feature-done boundaries, where the code is finished enough to judge whole *and* a user has confirmed the slice's user-facing outcome. Parallel lens sub-agents run each with a narrow goal, a confidence pass suppresses noise, then findings auto-feed a per-finding `/grill-me` triage loop. The lens shape mirrors native `/code-review` but AL-shaped: lenses align with what trips AL reviewers, not generic ones.

Slice-done is the natural goldilocks. Per-task review (the pre-0.27 cadence) reviewed every TDD cycle's diff before the slice was end-to-end coherent, surfacing cross-task drift only after the slice closed anyway. Feature-done alone lets slice A's defects compound through slices B / C / D. Slice-done catches both: enough end-to-end shape to judge whole, small enough that defects don't ripple.

`/al-refactor` (auto inside `/al-implement`) handles structural reshape at a high relevance bar every cycle. `/al-code-review` lowers the bar and adds judgment-level lenses the refactor pass cannot afford.

## Preconditions

- Branch matches `^\d{3}-` and `specs/<branch>/tasks.html` exists; legacy `tasks.md` is frozen, hand-migrate before reviewing.
- `/al-build` green: the linter pipeline (CodeCop, AppSourceCop, UICop, AppSource Validation) has already cleared deterministic concerns, so review starts where linters stop. Red baseline stops the gate.
- Tree state matches reviewer intent. Uncommitted reshape from unrelated work pollutes the diff; confirm scope before proceeding.

If any precondition fails, stop and surface the gap. Do not review against an uncertain baseline.

## Scope and diff

Two modes, deduced from current state, recent `data-status` flips, working tree, and what the user said: **per-slice** (every technical task in one `data-slice` is `done` and the slice's verify task just flipped to `done`) or **per-feature** (full feature diff before merge). When inference is uncertain (mid-stream WIP commits, mixed in-flight/done), ask with concrete options: "diff for slice `<slug>`?" / "full branch vs `main`?" / "uncommitted working tree?" / "SHA range you name?"

Per-slice scope: the union of diffs for every `T-NNN` carrying the slice's `data-slice`, from each task's first commit through its `done` flip. Pure-backend features have no verify tasks; per-slice mode applies on a best-effort basis when slices are explicitly grouped in `architecture.html`, otherwise it degenerates to per-feature.

Pipeline commits carry `T-NNN <verb>: <message>` prefixes that associate commits with tasks; a `review:` commit or squash defeats the grep, which is when asking beats guessing.

## Lenses

Spawn all lenses in one message so they run concurrently. Each lens has a narrow focused goal; the synthesis pass dedupes across them.

| # | Lens | Focused goal | Mode |
|---|---|---|---|
| 1 | Project compliance + naming | Changes obey `CONTEXT.md`, design and domain ADRs under `docs/adr/`, the module map and boundaries in `architecture.html`, and the originating task's Gherkin in `tasks.html`. Naming check: objects, procedures, variables, fields, parameters use BC vocabulary AND project terminology; names that lie surface even when code is otherwise correct | both |
| 2 | Bug scan | Shallow scan for large bugs the LLM catches cold on a fresh read. Correctness and obvious logic faults only; skip nitpicks, skip style, skip anything a linter catches | both |
| 3 | BC-specific via bc-knowledge | Per `${CLAUDE_SKILL_DIR}/../../references/bc-knowledge-dispatch.md`: `ask_bc_expert(autonomous_mode=false)` per file with file-type-mapped specialist, fetch surfaced topics via `get_bc_topic`, apply each topic's `anti_pattern_indicators`. Lower relevance bar (`>= 50`) than `/al-refactor`'s `>= 70`; the gate can afford the broader sweep | both |
| 4 | Code comments + git history | Code comments in modified files state guidance (invariants, "do not X" warnings); changes comply. Recent commit history surfaces context: a previous fix the current change might re-break, a deliberate decision being undone | both |
| 5 | AppSource public-surface addition | New public procedure, public table field, or page action on a shipped object locks public contract into AppSource. Linters fire on removal (AS0011) and rename (AS0007), not on addition; read the changed object alongside `app.json` and judge intentional vs accidental lock-in | per-feature only |
| 6 | Verify ↔ code alignment | The slice's verify task scenarios in `tasks.html` name surfaces, Roles, and Status values; the changed code under the slice's `data-slice` actually exposes those surfaces with those names. Drift here means user verification just signed off on something other than what the code does | per-slice only |

Lenses state goals, not enumerated checklists. The specifics each lens catches depend on the code and what `bc-knowledge` surfaces.

## Confidence pass

After lenses return, a lighter-weight pass scores each finding 0-100 before showing the user. Five lenses on a 10-file diff produce 30+ findings if every lens reports everything; the filter makes the list short enough for `/grill-me` to triage cleanly. Findings `< 80` are suppressed; only `>= 80` reach triage.

| Score | Meaning |
|---|---|
| 0   | False positive, doesn't survive light scrutiny, or pre-existing |
| 25  | Might be real, might be false positive; the lens couldn't verify |
| 50  | Verified as real but a nitpick, or not important relative to the diff |
| 75  | Highly confident: real issue likely to be hit OR explicitly called out in `CLAUDE.md` / `CONTEXT.md` / ADRs |
| 100 | Confirmed real, will hit frequently in practice, direct evidence |

## What lands on screen

Finding bodies live inside each `/grill-me` invocation. The chat surface is chrome only because the captured pattern is "user reads findings list, immediately fires `/grill-me`"; pre-dumping bodies duplicates what the grill shows. Shapes per Tables-of-facts and Lists-of-findings in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`:

| | |
|---|---|
| **Opener** (always)        | one line with count above threshold, plus a 3-row scope chip (`**Scope**` / `**Baseline**` / `**Findings**`). One line per failed lens (`4/5 lenses returned, Lens 3 (BC-specific) errored: <reason>`) so the user knows review is incomplete before triage. |
| **Inter-grill chrome** (N>1) | one line per landed decision, `[2/5] noted on T-009 → next`. Skipped when N=1. |
| **Closer**                 | 3-row mini-summary (`**New tasks**` / `**Notes**` / `**Dropped**`). On abort: partial summary, no resume, untriaged findings die. |

## Auto-grill loop

After the confidence pass, the skill spawns `/grill-me` per surviving finding automatically. No "Run `/grill-me`" handoff sentence; the manual step adds a keypress, not judgment, and per-finding judgment happens inside each grill. Order is severity-then-confidence (correctness > performance > hygiene; confidence breaks ties) because the loop's failure mode is partial completion (context shift, session compaction); triaging the most consequential first means the dropped tail is least costly.

Per finding:

- **Spawn**: `/grill-me` with the finding body (Finding / Where / Source / Severity / Confidence / Slice when per-slice), the lens proposal (its `Recommended next`), and scope context.
- **Contract**: three outcomes: new task in `tasks.html`, note on a future task, drop.
- **References**: pass `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md` and `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` for writeback shape.
- **Exit**: when the decision lands.

Passing a proposal (not raw finding) lets `/grill-me` stress-test whether the proposal is right rather than invent one cold. The three outcomes:

- **New task**: append `<details class="task" data-task="T-NNN+1" data-status="ready" data-slice="<slug>">`, title naming the fix, body carrying `Where` and `Source` as seed for `/al-refine`. Slice slug is the just-reviewed slice (per-slice mode) or the slice the fix most naturally belongs to (per-feature mode); a fix that re-opens a closed slice flips that slice's verify task back to `blocked` and routes via `/al-steer`. Next `/al-implement` cycle picks it up.
- **Note on future task**: identify a not-yet-`done` task whose work touches the area; regenerate its NOTE callout block whole (the surgical-edit contract on `tasks.html` is `data-task` + `data-status` only).
- **Drop**: user accepts as known, not worth a task. The closer counts it.

Abort on explicit `stop` / `end loop` / `cancel`, off-topic shift, or compaction: emit partial-summary closer and exit, no resume (the queue is transient). Single-finding case: spawn one grill, skip the progress chip, straight to closer. `/grill-me` stays generic; the triage contract rides in via spawn prompt, no section is added to `grill-me`'s `SKILL.md`.

## Findings shape

Findings carry the slot set `Finding / Where / Source (lens name + topic id) / Severity / Confidence / Recommended next` per the Lists-of-findings rule in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. The body rides into its `/grill-me` invocation in this shape; the grill stress-tests it.

`/al-code-review` does not write durable artifacts before triage. Per-grilling materialization writes to `tasks.html` only. No `architecture.html`, `event-model.html`, ADR, `CONTEXT.md`, or `.out-of-scope/` writes. Findings address files by path + line or path + procedure; future readers grep on the symbol.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-user-verification` (slice done) or all tasks done (feature done) |
| **Hands off to**   | merge / next feature |
| **Replan venue**   | n/a; findings auto-loop into `/grill-me` per finding, never via `/al-steer` (review findings are not replan signals) |
| **Sidebands**      | `/al-second-opinion` (cross-runtime advisory on large findings lists), `/grill-me` (per-finding triage), `/al-research` (BaseApp behaviour or BC convention), `/bc-standard-reference` (BaseApp pattern correctness) |

## Delegation

Spawn each lens as a parallel sub-agent in one message. Lenses are independent and context-expensive; running them serially in the main session burns tokens on per-file content the synthesis doesn't need to retain. Per-feature mode benefits especially: five lenses across 20+ files is exactly the shape that wants parallelism. If delegation is unavailable, run serially.

Do not shadow a running lens. If a lens fails or returns nothing, note the gap in synthesis rather than re-running silently.
