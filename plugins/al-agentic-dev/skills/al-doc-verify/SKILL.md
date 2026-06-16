---
name: al-doc-verify
description: Read-only cheap verifier for canonical markdown artifacts written by /al-grill-adr, /al-event-model, /al-design, /al-scope, and /al-refine, plus structural tasks/ folder rewrites by /al-steer. Checks document integrity and sibling consistency only; blocks structural and boundary failures, warns wording or ambiguity, and runs after write before gate report or downstream handoff.
---

**Style:** Concise — cut filler, keep grammar. Opinionated - pick a side. Arrows (->) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-doc-verify, Markdown artifact verifier

Run as the cheapest available read-only subagent when host tooling supports subagents. If no subagent is available, stay read-only and include `warnings=No cheap subagent available` in the verdict. Read the producer, the named artifact paths, and any directly linked sibling markdown in the same spec folder. Do not inspect source code, symbols, or research.

Verify document integrity only:

- artifact exists and matches the intended profile
- headings and task-file frontmatter are structurally sound
- sibling spec files agree on shared IDs, slice slug, and handoff wiring
- linked `CONTEXT.md` and `docs/adr/` references exist when the producer or links require them

Do not judge domain truth, BC fact truth, design quality, or test sufficiency. That stays with the writer and downstream skills.

## Inputs

- `producer`
- `artifact_paths`
- `intended_handoff`
- optional `task_id`
- optional `slice`

## Read scope

- named artifacts
- directly linked sibling artifacts in the same spec folder
- plugin grammar references
- `CONTEXT.md` and `docs/adr/` only when linked or when the producer is `/al-grill-adr`

No source-code walk, symbols, or research.

No model escalation unless the verifier cannot classify a structural ambiguity. Escalation still stays read-only and bounded to the same files.

## Profiles

- `CONTEXT.md` and ADR: durable intent, decision shape, and link integrity
- `event-model.md`: Role / Action / Business Event / View / Status structure
- `architecture.md`: module map, boundaries, and cross-file consistency. Slice-realisation objects without a `new` / `extends <existing>` marker at first mention — `(new)` suffix or inline `new <type>` / `extends <base>` both count -> warn: `/al-refine` seeds each task's `New and Modified Objects` ledes from them
- `tasks/` folder: per-task-file frontmatter, folder integrity, and proof sections.
  - **Frontmatter integrity** -> fail: every `NNN-T-MMM-<slug>.md` file must carry parseable YAML frontmatter with `task:`, `status:`, `slice:`, `kind:`; the filename's `T-MMM` must match the frontmatter `task:`. `kind:` is one of `technical | verify | provision | breaking-change`. `000-feature.md` carries Goal + slice intent and no task frontmatter — do not flag it for missing fields.
  - **Duplicate id** -> fail: two task files sharing a `task:` id. Ids are monotonic and never reused.
  - **Duplicate prefix** -> fail: two task files sharing an `NNN` prefix — a re-prefix run left a collision, and run order is now ambiguous.
  - **Dangling edge** -> fail: any id in a `depends_on:`/`refactors:`/`fixes:` list with no matching task file.
  - **Order vs edges** -> warn: a task whose `NNN` prefix is lower than a task it `depends_on:` (it would sort to run before its dependency). The edge is the hard truth; the prefix is the soft run order, so warn and let `/al-steer` re-prefix.
  - **Verify under-coverage** -> warn: a `kind: verify` task whose `depends_on:` omits a `kind: technical` file sharing its `slice:`. `/al-implement` reads the verify task's `depends_on:` to decide slice-done; a missing edge fires the gate early. The folder shape makes this easy to miss — dropping a task file in does not force a touch of the sibling verify file. Flags `verify gate under-covers slice; slice-done may fire early`.
  - **Ops-slug pairing** -> fail: `kind: provision` must carry `slice: provision` and `kind: breaking-change` must carry `slice: breaking-change`; no `kind: technical`/`verify` task may use a reserved slug. The proof-section exemption and `/al-refine`'s decline-redirect both key off this pairing, so a mismatch corrupts routing.
  - **Proof section** -> fail: the task under verification (`task_id`) with a populated `Test Specification` but no `New and Modified Objects`; blocks the `ready-for-implementation` flip. The bare labeled line `New and Modified Objects: none` is the valid test-only form; a section heading without entries fails. Scope to the named task's file only — `done` tasks may predate the grammar, task files without a `Test Specification` (not yet refined) are not flagged, no `task_id` -> skip this check. The two ops kinds (`provision`, `breaking-change`, on reserved `slice: provision` / `slice: breaking-change`) carry **no** proof section and never reach `ready-for-implementation`/`ready-for-verification` — do not flag them as missing a `Test Specification`/`Verification Plan`.
  - **Prose walls** -> warn: a proof-section paragraph splicing several independent facts with `;`-chained clauses (roughly 60+ words of multi-fact prose) flags `multi-fact wall; one fact per landing line`. Fires on paragraphs only — never on table cells, single bullets, or a dense-but-single-fact line.
  - **`review: clean` lifecycle** -> warn, two checks: the field in a file whose `status:` is not `ready-for-verification` flags `stale review marker; strip-on-flip missed`; the field on a verify task while any technical task sharing its `slice:` is not `done` flags `review marker predates open slice work; re-review due`. Warn, not block — a stale marker mis-routes one turn, it does not corrupt the task bus.

## Verdict

Return exactly:

- `verdict=pass|fail|warn`
- `blockers=...`
- `warnings=...`
- `checked=...`

Rules:

- `fail` when any structural or boundary blocker exists
- `warn` when wording is ambiguous or a handoff is underspecified, but structure holds
- `pass` when no blockers and no warnings remain
