---
name: al-doc-verify
description: Read-only cheap verifier for canonical markdown artifacts written by /al-grill-adr, /al-event-model, /al-design, /al-scope, and /al-refine, plus structural tasks.md rewrites by /al-steer. Checks document integrity and sibling consistency only; blocks structural and boundary failures, warns wording or ambiguity, and runs after write before gate report or downstream handoff.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated - pick a side. Arrows (->) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-doc-verify, Markdown artifact verifier

Run as the cheapest available read-only subagent when host tooling supports subagents. If no subagent is available, stay read-only and include `warnings=No cheap subagent available` in the verdict. Read the producer, the named artifact paths, and any directly linked sibling markdown in the same spec folder. Do not inspect source code, symbols, or research.

Verify document integrity only:

- artifact exists and matches the intended profile
- headings, anchors, and task comment markers are structurally sound
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
- `architecture.md`: module map, boundaries, and cross-file consistency
- `tasks.md`: task anchors, status line, slice, kind, and proof sections. `kind=` is one of `technical | verify | provision | breaking-change`; the two ops kinds (`provision`, `breaking-change`, on reserved `slice=provision` / `slice=breaking-change`) carry **no** proof section and never reach `ready-for-implementation`/`ready-for-verification` — do not flag them as missing a `Test Specification`/`Verification Plan`. Proof-section prose walls -> warn: a paragraph splicing several independent facts with `;`-chained clauses (roughly 60+ words of multi-fact prose) flags `multi-fact wall; one fact per landing line`. Fires on paragraphs only — never on table cells, single bullets, or a dense-but-single-fact line. File volume -> warn: `tasks.md` past ~10k words flags `tasks.md bloating; route to /al-steer to restructure`. Downstream skills re-read the whole file every turn; restructuring is `/al-steer`'s call and never deletes closeout proof. Warn, not block — volume degrades every consumer but corrupts nothing. `review=clean` lifecycle -> warn, two checks: the key on a line whose `status` is not `ready-for-verification` flags `stale review marker; strip-on-flip missed`; the key on a verify task while any technical task sharing its `slice=` is not `done` flags `review marker predates open slice work; re-review due`. Warn, not block — a stale marker mis-routes one turn, it does not corrupt the task bus.

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
