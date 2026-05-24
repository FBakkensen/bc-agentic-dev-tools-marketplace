---
name: al-code-review
description: In-depth AL/Business Central code review at gate points. Use after /al-implement marks a task done (per-task scope) or after all tasks done before merge (per-feature scope). Spawns parallel lens-focused sub-agents (project compliance, bug scan, BC-specific via bc-knowledge, code comments + git history, AppSource public-surface for per-feature), then a confidence-scoring pass to suppress noise before findings reach /grill-me triage. Materializes accepted findings as new tasks or notes on future tasks in tasks.html. Stays out of linter territory (covered by /al-build). Never routes via /al-steer.
---

# /al-code-review, In-depth gate review

A deliberate gate, not a constant companion. Runs at task-done and feature-done boundaries, where the code is finished enough to judge as a whole. Spawns parallel lens-focused sub-agents, each with a narrow goal, then a confidence pass suppresses noise before findings reach the user. The pattern mirrors native `/code-review`'s 5-lens structure, AL-shaped: lenses align with what trips AL reviewers, not what trips generic ones.

`/al-refactor` (auto inside `/al-implement`) carries the structural reshape work at high relevance bar. `/al-code-review` lowers the bar and adds judgment-level lenses the refactor pass cannot afford to run every cycle.

## Preconditions

- Branch matches `^\d{3}-` and `specs/<branch>/tasks.html` exists. Legacy markdown specs (`tasks.md` without `tasks.html`) are frozen; hand-migrate before review.
- `/al-build` green. The build gate already ran the AL linter pipeline (CodeCop, AppSourceCop, UICop, AppSource Validation, per-tenant cops); review starts where linters stop. Red baseline = stop, surface, do not review.
- Tree state matches reviewer intent. Uncommitted reshape from an unrelated task pollutes the diff; the agent confirms what to review against before proceeding (see "Scope and diff" below).

If any precondition fails, **Stop** and surface the gap. Do not "review what's there" against an uncertain baseline.

## Scope and diff

Two modes, picked from context:

- **Per-task**: the agent reviews the diff of one just-completed task.
- **Per-feature**: the agent reviews the full feature's diff before merge.

The agent deduces which mode applies from current state, the most recent `data-status` flips in `tasks.html`, the working tree, and what the user said when invoking. **Don't pretend to a state machine.** When the inference is uncertain (mid-stream WIP commits, a mix of in-flight and done tasks, an unclear range), ask the user with concrete options: "review the diff for `T-NNN`?" / "review the full branch vs `main`?" / "review the uncommitted files in the working tree?" / "review a specific SHA range you'll name?"

Convention used by the al-agentic-dev pipeline: commits carry a `T-NNN <verb>: <message>` prefix. The agent can use that to associate commits with tasks, but the prefix is a hint, not a contract; a `review:` commit or a squash will defeat the grep, which is exactly when asking the user beats guessing.

## Lenses

Spawn one sub-agent per lens, in parallel. Each lens has a narrow focused goal; the synthesis pass dedupes and filters across lenses.

| # | Lens | Focused goal | Mode |
|---|---|---|---|
| 1 | **Project compliance + naming** | Changes adhere to `CONTEXT.md` (BC vocabulary, business rules), to the design and domain ADRs under `docs/adr/`, to `architecture.html`'s module map and boundaries, and to the originating task's Gherkin scenarios in `tasks.html` (the code does what the bullets said it would). Naming check: objects, procedures, variables, fields, parameters use BC vocabulary (Insert/Modify/Delete, Post, Validate, Get/Find) AND project terminology; names that lie surface as findings even when the code is otherwise correct | both |
| 2 | **Bug scan** | Shallow scan for large bugs the LLM catches cold on a fresh read. Focus on correctness and obvious logic faults. Skip nitpicks; skip style; skip anything a linter would catch | both |
| 3 | **BC-specific via bc-knowledge** | Per `${CLAUDE_SKILL_DIR}/../../references/bc-knowledge-dispatch.md`: `ask_bc_expert(autonomous_mode=false)` per file with file-type-mapped specialist, fetch surfaced topics via `get_bc_topic`, apply each topic's `anti_pattern_indicators`. Lower relevance bar (around `>= 50`) than `/al-refactor`'s `>= 70` because the gate can afford the broader sweep | both |
| 4 | **Code comments + git history** | Code comments in modified files state guidance (constraints, invariants, "do not X" warnings); changes comply with that guidance. Recent commit history on the touched files surfaces context (a previous fix the current change might re-break, a deliberate decision being undone) | both |
| 5 | **AppSource public-surface addition** | Cross-file judgment: new public procedure, new public table field, or new page action on a shipped object locks the public contract into AppSource. Linters fire on removal (AS0011) and rename (AS0007) of shipped surface; they do **NOT** fire on addition. Read the changed object alongside `app.json` to know it ships; judge whether the new public surface is intentional or accidental lock-in | per-feature only |

Lenses are focused goals, not enumerated checklists. The specifics each lens catches depend on the code and what `bc-knowledge` surfaces; the SKILL.md states the goal, the sub-agent figures out what to look for. The spawn pattern follows the host's subagent contract: launch all lenses in one message so they run concurrently.

## Confidence pass

After lenses return their findings, run a confidence-scoring pass before showing the user. For each finding, a lighter-weight pass (Haiku-equivalent on hosts that support it) scores the finding 0-100 against the rubric below. Findings with score `< 80` are suppressed; only `>= 80` reach `/grill-me` triage.

| Score | Meaning |
|---|---|
| 0   | False positive; doesn't stand up to light scrutiny, or is pre-existing |
| 25  | Might be real, might be false positive; the lens couldn't verify |
| 50  | Verified as real but a nitpick, or not important relative to the rest of the diff |
| 75  | Highly confident: real issue likely to be hit in practice OR explicitly called out in CLAUDE.md / CONTEXT.md / ADRs |
| 100 | Confirmed real, will hit frequently in practice, direct evidence |

**Why the confidence pass.** Five lenses on a 10-file diff produce 30+ findings if every lens reports everything it considered. Most are pre-existing, style nits, or low-impact concerns. The filter is what makes the findings list short enough for `/grill-me` to triage cleanly. Native `/code-review` uses the same pattern for the same reason.

## What this pass produces

What the next reader needs from you, expressed as questions you must have answers to:

- **What was reviewed, and against which baseline?** Files + SHA range or working-tree slice. The diff is the contract.
- **Which lenses ran?** All applicable (4 for per-task, 5 for per-feature). Skipped lenses (e.g. no `app.json` found) named with the reason.
- **What survived the confidence pass?** The filtered finding list, severity-ordered (correctness, performance, hygiene). Linter territory excluded; the build gate handled it.
- **What is the recommended response per finding?** Fix in a new task | note on an existing future task | dropped. The user runs `/grill-me` to land each decision; the skill recommends, the grilling crystallizes.

If a question cannot be answered, the pass is not done. Resolve via a re-run on a tighter scope, a clarifying read of a referenced file, or `/grill-me` on the ambiguous finding.

## Disciplines

Beyond the lens-and-filter structure, three disciplines govern how findings move from the skill to durable artifacts.

### Stay out of linter territory

The AL linter pipeline (CodeCop, AppSourceCop, UICop, AppSource Validation, per-tenant cops, the project's `al.ruleset.json`) catches 200+ deterministic concerns. `/al-build` runs these; a green build gate already cleared them. **Why**: re-running deterministic checks the build already ran wastes the gate and creates confusion about which check is authoritative. Each lens above is LLM-judgment focused; if a finding could be expressed as a linter rule, it likely already is one and belongs in the build pipeline, not this gate.

### Handoff to /grill-me for triage

The skill terminates with a list of confidence-filtered findings in chat and a one-line instruction: "Run `/grill-me` on these findings to decide per-finding response." The user invokes `/grill-me`; the grilling session interviews per-finding, lands on one of:

- **New task in tasks.html**: append a `T-NNN+1` entry, `data-status="ready"`, title naming the fix, body carrying the finding's `Where` and `Source` as the seed for `/al-refine` to write Gherkin against. The next `/al-implement` cycle picks it up via TDD.
- **Note on a future task**: identify a not-yet-`done` task in tasks.html whose work will naturally touch the area; add an inline NOTE callout inside that task's block, citing the finding. The next agent on that task sees the carry-over before starting.
- **Dropped**: the user accepts the finding as known, not worth a task. No tasks.html write; the chat record carries the deliberation.

**Why grilling, not auto-creation.** Auto-creating a task per finding floods tasks.html with low-signal entries the user did not validate. Grilling forces per-finding triage; the user lands on the right response, the skill materializes the decision.

### tasks.html as the durable surface, /al-steer is not in this loop

Findings the user accepts as actionable land in tasks.html (new task or note on existing). The findings list itself is **transient chat output**, not a durable artifact. **Why durability lives only post-triage**: per-feature reviews on a large spec produce many findings; durable persistence of every finding adds maintenance debt for content that lives only until triaged. Grilled decisions are durable; raw findings are not.

`/al-steer` is the **replan venue**, triggered by one of the seven replan triggers inside in-flight work. `/al-code-review` runs at gate boundaries on completed work; its findings are not replan signals. **Why /al-steer stays out**: routing review findings through `/al-steer` confuses two distinct surfaces (replan queue vs review-driven task backlog). The user runs `/grill-me` to triage; the grilling session writes directly to tasks.html. `/al-steer` stays focused on replan.

### Findings format follows the voice contract

The "Lists of findings" rule in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` is the contract: labelled lines, blank line between items, uniform shape across the list, lede first. Shape the labels per pass (a typical set: `Finding` / `Where` / `Source` (lens name + topic id if applicable) / `Severity` / `Confidence` / `Recommended next`); the format is what makes `/grill-me` able to triage cleanly per finding.

## Delegation

The lens structure is the delegation pattern. Spawn each lens as a parallel sub-agent in a single message; each lens owns its narrow goal and returns findings. The main session synthesises, runs the confidence pass, and presents the filtered list. **Why**: lenses are independent and context-expensive; running them serially in the main session burns tokens on per-file content the synthesis doesn't need to retain. Per-feature mode especially benefits, since five lenses across 20+ files is exactly the shape that wants parallelism. The host's subagent support is the only constraint; if delegation is unavailable, run lenses serially in the main session.

Do not shadow a running lens worker. If a lens fails or returns nothing, note the gap in the findings synthesis rather than re-running silently.

## Floor

`/al-code-review` does not write durable artifacts before triage. Per-grilling materialization writes to `tasks.html` only:

- **New task append**: `<details class="task" data-task="T-NNN+1" data-status="ready">` ... `</details>`, monotonic ID. Body shape per `notes-discipline.md`.
- **Note on existing task**: regenerate that task's NOTE callout block whole; do not surgical-edit prose. Surgical-edit contract on `tasks.html` is `data-task` + `data-status` only; everything else regenerates per `html-spec-discipline.md`.

No `architecture.html` edits. No `event-model.html` edits. No ADR writes. No `CONTEXT.md` writes. No `.out-of-scope/` writes.

**Names are the citation.** Findings address files by path + line or path + procedure name; the IDE gives line numbers for free, future readers grep on the symbol.

## Composition

- **`/al-build`** as the precondition gate. Red baseline = stop, surface, do not review. Linter pipeline runs here; review starts where it stops.
- **`/al-refactor`** carries the structural reshape work at the high relevance bar; review picks up the long tail at the lower bar.
- **`/grill-me`** consumes the findings list; the grilling session triages per-finding into new task | note | dropped.
- **`/al-research`** when a finding needs BaseApp behaviour or BC convention verified before triage.
- **`/bc-standard-reference`** when a finding turns on BaseApp pattern correctness.
- **`/al-implement`** picks up new tasks the grilling session writes.

<claude-only>

- **`/al-second-opinion`** for cross-runtime review of the findings list when the review is large; returns a bulleted gap list verbatim or `Second opinion skipped: <reason>`.

</claude-only>

## Lazy reference reads

| Source (read-only) | Trigger |
|---|---|
| `${CLAUDE_SKILL_DIR}/../../references/bc-knowledge-dispatch.md` | always; before the BC-specific lens spawns |
| `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` | before emitting findings (the "Lists of findings" format is binding) |
| `${CLAUDE_SKILL_DIR}/../../references/notes-discipline.md` | before writing a new task or a note via grilling materialization |
| `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` | before any `tasks.html` write |
| `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` | when a finding turns on architectural vocabulary (Module, Seam, Adapter, Depth) |

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Events.** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.
- **Findings prose** in BC vocabulary, not generic CRUD. A finding that says "the procedure creates a customer" instead of "the procedure inserts a Customer record" corrupts the artifact downstream.

## Out of scope

- **No code edits.** Findings inform triage; fixes ride into new tasks or future-task notes via grilling, then `/al-implement` writes the code.
- **No deterministic checks.** Linter territory belongs to `/al-build`'s linter pass. This skill is LLM-judgment only.
- **No durable findings persistence pre-triage.** Findings are transient chat output; durability lives in tasks.html after `/grill-me` lands the decision.
- **No `/al-steer` routing.** Review findings are not replan signals.
- **No new artifact** (`review.html`, `docs/review/*.md`, or otherwise). The durable surface is tasks.html.
- **No bcquality consumption.** Parked; bc-knowledge MCP covers BC-specific topic surfacing for v1.
- **No auto-grilling.** The skill produces the findings list and instructs the user to invoke `/grill-me`; the user invokes it. Auto-invocation strips the user's per-finding judgement that grilling exists to crystallize.
