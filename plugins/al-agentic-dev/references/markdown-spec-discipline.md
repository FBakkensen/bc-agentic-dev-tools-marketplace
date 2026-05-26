# Markdown spec discipline

`event-model.md`, `architecture.md`, and `tasks.md` under `specs/<NNN>-<slug>/` are the reading surface. This file is what `/al-design`, `/al-event-model`, `/al-scope` consult before generating, and what every maintaining skill (`/al-refine`, `/al-implement`, `/al-mutate`, `/al-steer`) consults before editing.

<claude-only>
Runtime gate. Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it skip the block contents and move on.
</claude-only>

## Source of truth: examples

Three populated examples in [`examples/`](./examples/) carry the canonical shape:

| File | What it is |
|---|---|
| [`examples/event-model.example.md`](./examples/event-model.example.md) | User-facing journey, Role swimlanes, Action / Business Event / View / Status slots. |
| [`examples/architecture.example.md`](./examples/architecture.example.md) | Module map, R → P → W boundary, brownfield touchpoints. |
| [`examples/tasks.example.md`](./examples/tasks.example.md) | Slice-grouped tasks with comment anchors, technical + verify. |

Pattern-match against these before writing a feature's artifacts. Shape per feature is the writing skill's call within these constraints.

**Cross-links between sibling artifacts** drop the `.example` suffix: generated artifacts link to `event-model.md` / `architecture.md` / `tasks.md` inside the same `specs/<NNN>-<slug>/` folder.

## The surgical-edit floor

`tasks.md` carries one surgical-edit contract. Maintaining skills find a task by ID and flip its status. Everything else regenerates whole.

One HTML-comment line per task, immediately below the task's `### T-NNN` heading:

```markdown
### T-007 [ ] — Release order, valid item charge
<!-- task=T-007 status=ready slice=release-sales-order kind=technical -->
```

Four keys on the comment line, single space between each `key=value`, no quotes:

| Key | Locates | Used by | Written by |
|---|---|---|---|
| `task=T-NNN` | the per-task block | every skill that touches a task | `/al-scope` |
| `status=ready \| in-progress \| done \| blocked` | the status, single source of truth | `/al-implement`, `/al-user-verification`, `/al-steer` | `/al-scope` (`ready` for every technical task in the first slice, `blocked` for every other task); `/al-implement` flips technical tasks `in-progress` → `done` and the slice's verify task `blocked` → `ready` when the last sibling lands; `/al-user-verification` flips verify task `ready` → `in-progress` → `done` or `blocked`, and on `done` flips next-slice technical tasks `blocked` → `ready`; `/al-steer` flips to `blocked` on replan triggers |
| `slice=<slug>` | slice membership; matches one `event-model.md` timeline step (user-facing) or `architecture.md` slice (pure-backend) | `/al-implement` (detect last technical task in slice → flip verify ready), `/al-steer` (group by slice when reporting), `/al-code-review` (per-slice diff scope) | `/al-scope` |
| `kind=technical \| verify` | task kind; routes `/al-implement` vs `/al-user-verification` | `/al-implement` (stop on verify), `/al-refine` (branch by kind), `/al-user-verification` (precondition) | `/al-scope` |

`task=T-NNN` makes the line unique within the file. The status flip is an Edit on the full comment line where only the `status=` value differs; stale read trips the byte match.

The visible heading marker (`[ ]` ready, `[~]` in-progress, `[x]` done, `[!]` blocked) is a courtesy fallback; the comment-line `status=` attribute is source of truth. Writing skills keep the marker in sync on flip.

`slice` and `kind` are scope-time decisions. `/al-scope` writes them, downstream skills read them. A skill that needs to change `slice` (boundary moved) or `kind` (miscategorised) is doing replan work; route through `/al-steer`.

`event-model.md` and `architecture.md` carry **no** surgical-edit contract. `/al-design` and `/al-event-model` reshape them whole on re-run.

## Surgical-edit discipline

`/al-implement` and `/al-steer` flip `status=` via the Edit tool, anchored on the full comment line.

**Status flip example** (`/al-implement` from `in-progress` to `done` on T-007):

```
old_string: <!-- task=T-007 status=in-progress slice=release-sales-order kind=technical -->
new_string: <!-- task=T-007 status=done slice=release-sales-order kind=technical -->
```

One Edit, one attribute change. The line stays unique on `task=T-007`; the read-before-edit catches a stale assumption (if you think `in-progress` but the file says `ready`, Edit fails fast rather than corrupting state).

**Other writes regenerate, not surgical-edit.** When `/al-refine` fills the Tests area, `/al-mutate` writes a verdict, or `/al-implement` records a NOTE-style block alongside the task, the writing skill regenerates that portion of the task block whole.

**Forbidden:**

- Blind Edit calls with no prior Read of the task block.
- Anchoring status flips on visible text (the `[ ]` marker, the heading title) instead of the comment line; the marker is fallback rendering, not the anchor.
- Whole-file Read followed by whole-file Write for a status flip. Use Edit; whole-file rewrites lose bytes you forgot.
- Editing through a `task=T-NNN` collision. Task IDs are monotonic and never reused; if two task blocks share an ID (impossible by contract), halt and surface the duplicate.
