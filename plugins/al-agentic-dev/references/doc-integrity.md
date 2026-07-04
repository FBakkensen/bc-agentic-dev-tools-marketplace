# Document integrity check (inline, before the gate report)

Read by the skills that write canonical planning markdown — `/al-grill-adr`, `/al-event-model`, `/al-design`, `/al-scope`, `/al-refine`, `/al-steer`. After you write or restructure such an artifact and **before** the gate report or downstream handoff, verify it against the checks below **yourself, inline** — no subagent. Fix every blocker before handoff; note warnings in the gate report.

Verify **document integrity only**: the artifact exists and matches its profile, headings and task-file frontmatter are structurally sound, sibling spec files agree on shared IDs / slice slug / handoff wiring, and linked `CONTEXT.md` / `docs/adr/` references exist. Do **not** judge domain truth, BC fact truth, design quality, or test sufficiency here — that stays with the writing step and downstream skills.

## Scope of the check

The artifact you just wrote, its directly linked sibling artifacts in the same spec folder, the plugin grammar references under `${CLAUDE_PLUGIN_ROOT}/references/`, and `CONTEXT.md` / `docs/adr/` when linked (or always, for `/al-grill-adr`). No source code, symbols, or research.

## Profiles

- **`CONTEXT.md` and ADR:** durable intent, decision shape, and link integrity.
- **`event-model.md`:** Role / Action / Business Event / View / Status structure.
- **`architecture.md`:** module map, boundaries, cross-file consistency. Slice-realisation objects without a `new` / `extends <existing>` marker at first mention — `(new)` suffix or inline `new <type>` / `extends <base>` both count → **warn**: `/al-refine` seeds each task's `New and Modified Objects` ledes from them.
- **`tasks/` folder:** per-task-file frontmatter, folder integrity, and proof sections —
  - **Frontmatter integrity** → **fail**: every `NNN-T-MMM-<slug>.md` file must carry parseable YAML frontmatter with `task:`, `status:`, `slice:`, `kind:`; the filename's `T-MMM` must match the frontmatter `task:`. `kind:` is one of `technical | verify | provision | breaking-change`. `000-feature.md` carries Goal + slice intent and no task frontmatter — do not flag it for missing fields.
  - **Duplicate id** → **fail**: two task files sharing a `task:` id. Ids are monotonic and never reused.
  - **Duplicate prefix** → **fail**: two task files sharing an `NNN` prefix — a re-prefix run left a collision, and run order is now ambiguous.
  - **Dangling edge** → **fail**: any id in a `depends_on:`/`refactors:`/`fixes:` list with no matching task file.
  - **Order vs edges** → **warn**: a task whose `NNN` prefix is lower than a task it `depends_on:` (it would sort to run before its dependency). The edge is the hard truth; the prefix is the soft run order — warn and re-prefix via `/al-steer`.
  - **Verify under-coverage** → **warn**: a `kind: verify` task whose `depends_on:` omits a `kind: technical` file sharing its `slice:`. The verify task's `depends_on:` should enumerate its slice's technical set so the dependency graph and `/al-steer`'s replan reasoning stay accurate; slice-done itself is read from `slice:` membership (every `slice:`-matched technical task `done`), so a missing edge is a graph-integrity gap, not an early-gate risk. Flag `verify gate under-covers slice; dependency graph incomplete`.
  - **Ops-slug pairing** → **fail**: `kind: provision` must carry `slice: provision` and `kind: breaking-change` must carry `slice: breaking-change`; no `kind: technical`/`verify` task may use a reserved slug.
  - **Proof section** → **fail**: the task under work, with a populated `Test Specification` but no `New and Modified Objects`; blocks the `ready-for-implementation` flip. The bare labeled line `New and Modified Objects: none` is the valid test-only form; a section heading without entries fails. Scope to the named task's file only — `done` tasks may predate the grammar, task files without a `Test Specification` (not yet refined) are not flagged, ops kinds (`provision`, `breaking-change`) carry **no** proof section and never reach `ready-for-implementation`/`ready-for-verification` — do not flag them.
  - **E2E `Record:` flag** → **fail**: a `kind: verify` task with a populated `Verification Plan` whose `Scope: E2E` Journey Example omits the mandatory `Record: yes` / `Record: no` line. The flag routes the example to `/al-page-script` (record) vs `/al-user-verification` (walk). Scope to a task file with a populated plan only; `Contract` / `Exploration` examples carry no `Record:` — do not flag them.
  - **Prose walls** → **warn**: a proof-section paragraph splicing several independent facts with `;`-chained clauses (roughly 60+ words of multi-fact prose) flags `multi-fact wall; one fact per landing line`. Fires on paragraphs only — never on table cells, single bullets, or a dense-but-single-fact line.
  - **`blocked-on:` lifecycle** → **warn**, two checks: a `status: blocked` task without a `blocked-on:` line flags `block without headline; developer can't see why` — the write belongs in the same Edit as the flip; a `blocked-on:` line on a non-`blocked` task flags `stale block headline; remove-on-unblock missed`.
  - **`review: clean` lifecycle** → **warn**, two checks: the field on a verify task whose `status:` is neither `ready` nor `ready-for-verification` flags `stale review marker; strip-on-flip missed` (`/al-code-review` stamps it at slice-done when it opens the verify task to `ready`, and it rides through to `ready-for-verification`); the field on a verify task while any technical task sharing its `slice:` is not `done` flags `review marker predates open slice work; re-review due`.

## Verdict (inline)

Resolve to one of:

- **fail** — any structural or boundary blocker exists. Fix it before the gate report; do not hand off a structurally broken artifact.
- **warn** — wording is ambiguous or a handoff underspecified, but structure holds. Note the warning in the gate report and proceed.
- **pass** — no blockers and no warnings remain.
