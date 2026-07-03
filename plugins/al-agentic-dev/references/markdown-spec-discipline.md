# Markdown spec discipline

`event-model.md`, `architecture.md`, and the `tasks/` folder under `specs/<NNN>-<slug>/` are the reading surface. This file is what `/al-design`, `/al-event-model`, `/al-scope` consult before generating, and what every maintaining skill (`/al-refine`, `/al-implement`, `/al-mutate`, `/al-steer`) consults before editing its owned markdown surface.

## Source of truth: examples

Three populated examples in [`examples/`](./examples/) carry the canonical shape:

| File | What it is |
|---|---|
| [`examples/event-model.example.md`](./examples/event-model.example.md) | User-facing journey, Role swimlanes, Action / Business Event / View / Status slots. |
| [`examples/architecture.example.md`](./examples/architecture.example.md) | Module map, R → P → W boundary, brownfield touchpoints. |
| [`examples/tasks/`](./examples/tasks/) | The `tasks/` folder shape: a `000-feature.md` header plus one frontmatter file per task, technical + verify across two slices. |

Pattern-match against these before writing a feature's artifacts. Shape per feature is the writing skill's call within these constraints.

**Cross-links between sibling artifacts** drop the `.example` suffix: generated artifacts link to `event-model.md` / `architecture.md` / the `tasks/` folder inside the same `specs/<NNN>-<slug>/` folder.

## The `tasks/` folder

`/al-scope` writes `specs/<NNN>-<slug>/tasks/` as a folder, one file per task plus one header:

```
specs/035-foo/tasks/
  000-feature.md                          # Goal + slice-intent. No status, no per-task rows.
  010-T-001-provision.md
  020-T-004-release-order-valid-charge.md
  030-T-007-pending-overrides-cue.md
```

- **`000-feature.md`** — the feature header: Goal (lifted from `event-model.md` journey or `architecture.md` trigger-source) plus per-slice intent prose. No task rows, no status, no board. It sorts to the top of the folder and is read first.
- **Per-task file** `NNN-T-MMM-<slug>.md`:
  - `NNN` — execution-order prefix, **gapped by 10** (`010`, `020`, `030`). The filesystem sort *is* the run order; `ls tasks/` shows tasks in the order they execute. Insert between two tasks by picking a gap (`025`); when a gap fills, re-prefix the minimum local run. The prefix is the *sole* owner of order — no second ordering encoding anywhere.
  - `T-MMM` — monotonic, never reused, never renumbered. The stable locator. The gap lives on the prefix, never on the id, so ids stay dense even as order shifts.
  - `<slug>` — kebab-case, for human scanning.

There is **no index file**. The filesystem is the ordered manifest (`ls` = run order); the live status board, the dependency graph, and "next actionable task" are all computed on demand by grepping across the folder. `/al-steer` renders the board.

## The surgical-edit floor

Each per-task file carries one surgical-edit contract: maintaining skills find a task by its `T-MMM` filename (or by `task:` in frontmatter) and flip its `status:` field. Everything else regenerates whole.

YAML frontmatter at the top of every per-task file, then an H1 title, then the body:

```markdown
---
task: T-007
status: ready
slice: release-sales-order
kind: technical
depends_on: [T-004]
refactors: []
fixes: []
---
# T-007 — Release order, valid item charge

<description, then Test Specification / Verification Plan, …>
```

Frontmatter fields, single source of truth for state and graph:

| Field | Locates | Used by | Written by |
|---|---|---|---|
| `task: T-NNN` | the task; matches the filename's `T-MMM` | every skill that touches a task | `/al-scope` |
| `status: ready \| ready-for-implementation \| ready-for-verification \| blocked \| done` | the status, single source of truth | `/al-refine`, `/al-implement`, `/al-code-review`, `/al-page-script`, `/al-user-verification`, `/al-steer` | `/al-scope` writes unrefined tasks as `ready` when they have enough context for `/al-refine`, otherwise `blocked`; `/al-refine` flips technical tasks `ready` → `ready-for-implementation` after writing a fresh `Test Specification`, and verify tasks `ready` → `ready-for-verification` after writing a fresh `Verification Plan`; downstream evidence flips executable tasks to `done`; `/al-code-review` opens a user/API-facing slice's verify task `blocked` → `ready` on a clean first review; missing dependency or context flips tasks to `blocked` |
| `slice: <slug>` | slice membership; matches one `event-model.md` timeline step (user/API-facing) or `architecture.md` slice (backend-only) | `/al-implement` (detect last technical task in slice → announce `/al-code-review`), `/al-code-review` (per-slice diff scope, gate flip target), `/al-steer` (group by slice when reporting) | `/al-scope` |
| `kind: technical \| verify \| provision \| breaking-change` | task kind; routes `technical`→`/al-implement`, `verify`→`/al-code-review` (slice-done gate) then `/al-page-script`+`/al-user-verification`, `provision`→`/al-provision`, `breaking-change`→`/al-validate-breaking-changes` | `/al-implement` (stop on non-technical), `/al-refine` (branch by kind; the two ops kinds bypass it), `/al-page-script` + `/al-user-verification` (preconditions), `/al-provision` + `/al-validate-breaking-changes` (run-and-flip) | `/al-scope` |
| `depends_on: [T-NNN, …]` | hard dependency edges — cannot land without those | `/al-refine`, `/al-implement` (gate readiness), `/al-steer` (graph for replan), cross-slice gate | `/al-scope`; `/al-steer` on replan |
| `refactors: [T-NNN, …]` | reshapes shipped code under invariant | `/al-code-review`, `/al-steer` | `/al-scope`; `/al-steer` |
| `fixes: [T-NNN, …]` | corrects a defect or wrong contract | `/al-code-review`, `/al-steer` | `/al-scope`; `/al-steer` |
| `review: clean` *(optional, `kind: verify` only)* | durable clean per-slice `/al-code-review` evidence, stamped at slice-done when code-review opens the verify task; the status value alone cannot carry it across the refine + record + walk steps that follow | `/al-refine` (rides untouched through the flip), `/al-page-script` + `/al-user-verification` (precondition), `/al-steer` (state read) | `/al-code-review` only, on a clean per-slice review of a user/API-facing slice |

Empty edge lists may be written as `[]` or omitted; a present list holds bare `T-NNN` ids (the id is the citation — no file paths, no line numbers). Any human-facing *rationale* for an edge stays as body prose; the *edge itself* is a frontmatter field.

Status meanings are fixed: `ready` is ready for `/al-refine` only; `ready-for-implementation` means a technical task has a fresh `Test Specification`; `ready-for-verification` means a verify task has a fresh `Verification Plan`; `blocked` means dependency or context is missing; `done` means downstream evidence exists.

**Ops kinds** (`provision`, `breaking-change`) are the exception to the `/al-refine` lifecycle: they carry no proof artifact and sit on reserved slugs `slice: provision` / `slice: breaking-change` (not feature slices). Their lifecycle is `ready` → `done` (or `blocked` on failure) — they never pass through `ready-for-implementation`/`ready-for-verification`. `/al-scope` emits `kind: provision` as `T-001` (opens `ready`) and `kind: breaking-change` last (opens `blocked`, `depends_on:` the final terminal task). For them, `ready` means run the owning skill (`/al-provision`/`/al-validate-breaking-changes`), and `/al-refine` declines them with a redirect. Each `blocked` → `ready` flip has a named owner, like the cross-slice gate: `/al-provision` opens the first slice's technical tasks on its `done`; the per-feature `/al-code-review` opens the breaking-change task on a clean pass.

`review: clean` is transient: it exists from the moment `/al-code-review` reviews the slice clean — stamped when code-review opens the verify task to `ready` at slice-done — and lives across the `ready` → `ready-for-verification` window until the verify walk signs off or the slice re-opens. Strip rules, all write-side: a flip to `blocked` or `done` deletes the field **in the same Edit** (the slice is re-opening or signing off); the `/al-refine` flip `ready` → `ready-for-verification` **preserves** it (refine moves no production code, so the review still vouches); and any skill opening a technical task in the slice (`/al-steer`'s push-down fix task after a page-script red, or a replan inserting technical work) deletes it too — and a still-`ready` verify task, opened by the review but not yet refined, flips back to `blocked` in the same edit (the slice re-opened before refinement). New slice code invalidates the review, and the push-down path moves no status byte, so the strip cannot ride on a flip. `/al-page-script` green deliberately leaves the field alone: the commit adds a recording, no production AL, so the review still vouches for the slice diff. Absence means not-reviewed or re-review due; presence is the only durable clean-review evidence for user/API-facing slices. Backend-only slices carry no field — their clean review flips the next slice `blocked` → `ready`, which is durable by itself.

`task: T-NNN` is unique across the folder (it matches the filename). The status flip is an Edit on the `status:` line; on technical tasks only the `status:` value differs, on verify tasks carrying `review: clean` a flip to `blocked`/`done` also strips that line in the same Edit (the `ready` → `ready-for-verification` refine flip leaves it). Stale read trips the byte match.

There is no visible `[ ]`/`[x]` heading marker — `status:` in frontmatter is the only state, and the file is short enough to read it at the top. The H1 is just the title (`# T-007 — Release order, valid item charge`).

`slice` and `kind` are scope-time decisions. `/al-scope` writes them, downstream skills read them. A skill that needs to change `slice` (boundary moved) or `kind` (miscategorised) is doing replan work; route through `/al-steer`. The `NNN` prefix and edge lists are also scope-time; `/al-steer` owns later re-prefixing on insert.

`event-model.md` and `architecture.md` carry **no** surgical-edit contract. `/al-design` and `/al-event-model` reshape them whole on re-run.

## Surgical-edit discipline

`/al-implement` and `/al-steer` flip `status:` via the Edit tool, anchored on the `status:` frontmatter line of the task's file.

**Status flip example** (`/al-implement` from `ready-for-implementation` to `done` on T-007, in `tasks/070-T-007-derive-audit-reason.md`):

```
old_string: status: ready-for-implementation
new_string: status: done
```

One Edit, one field. The read-before-edit catches a stale assumption (if you think `ready-for-implementation` but the file says `ready`, Edit fails fast rather than corrupting state). Read the whole short file first; the `status:` line is unambiguous within one task file.

**Verify-task flip with field strip** (`/al-user-verification` from `ready-for-verification` to `blocked` on T-010, stripping `review: clean`): two Edits in the same write — flip `status:` and delete the `review: clean` line — or regenerate the frontmatter block whole. The field is stripped on any flip to `blocked` or `done`; it survives only the `/al-refine` flip `ready` → `ready-for-verification` (refine moves no production code). A stale `review: clean` on a re-opened or signed-off task would vouch for a diff it never saw, so the strip is not optional.

`examples/tasks/` stays free of `review: clean` on purpose: the field is transient runtime state written mid-cycle by `/al-code-review`, not scope-time shape `/al-scope` generates.

**Other writes regenerate, not surgical-edit.** When `/al-refine` fills the `Test Specification` or `Verification Plan`, `/al-mutate` writes a verdict, or `/al-implement` records a NOTE-style block in the task body, the writing skill regenerates that portion of the file whole.

**Forbidden:**

- Blind Edit calls with no prior Read of the task file.
- Anchoring status flips on the H1 title or body text instead of the `status:` frontmatter line.
- Whole-folder or whole-file rewrites for a status flip. Use a targeted Edit on the `status:` line.
- Two task files sharing a `task: T-NNN`. Task IDs are monotonic and never reused; if two files share an id (impossible by contract), halt and surface the duplicate.
- A second place that encodes order. The `NNN` prefix is the only order source; never reintroduce order into an index, into the id, or into a separate list.
