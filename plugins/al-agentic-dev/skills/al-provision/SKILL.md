---
name: al-provision
description: Execute the `kind=provision` task in `tasks.md` for AL/Business Central — refresh the build environment (compiler, symbols, and — when enabled — the breaking-change baseline) by running al-build's `provision.ps1`, then flip the task `done` or `blocked`. Use on the first task of a feature, or whenever a `kind=provision` task sits at `status=ready`.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-provision — run the provision task

Execute one `kind=provision` task: refresh the build environment, flip its status. This is the `tasks.md` ↔ script bridge — `/al-build` stays workflow-blind (never reads `tasks.md`), so a workflow-aware skill owns running its `provision.ps1` and recording the outcome on the bus.

`kind=provision` is the feature's first task (`T-001`). Provision is a per-feature freshness refresh, not one-time machine setup: symbols and the breaking-change baseline advance per release, so each feature re-runs it before any `/al-refine` / `/al-implement` work compiles.

**Naming.** BC vocabulary, verb-first procedures, objects `"Prefix Feature Suffix"`. `tasks.md` status lives on the comment-anchor line `<!-- task=T-NNN status=… slice=provision kind=provision -->`.

## Precondition

A `kind=provision` task at `status=ready`. No `/al-refine` — this kind carries no `Test Specification` or `Verification Plan`; it runs a script and flips status. If invoked on any other kind, **Stop**.

## Run

```powershell
pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/provision.ps1"
```

Delegate to one general subagent — provision output is verbose; keep it out of the main session (same rule as `/al-build`). The worker runs exactly this one command and returns the exit code; it does not edit `tasks.md` or any source.

## Flip

Map the exit code, then surgical-Edit the comment-anchor line per [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md) — `status=` is the only attribute that changes; keep `slice=provision kind=provision`; sync the heading marker.

| Exit | Status | Marker |
|---|---|---|
| `0` | `done` | `[x]` |
| non-zero | `blocked` | `[!]` |

**On `done`, open the first slice.** `T-001` is the dependency the first slice's technical tasks wait on. After flipping `T-001` `done`, surgical-Edit every first-slice technical task (those carrying `Depends on: T-001` or sharing the first slice) `blocked` → `ready` — the same flip-owner discipline the cross-slice gate uses (`/al-user-verification` opens the next slice). Provision is the named owner of this `blocked` → `ready`; without it the first slice strands.

## Failure

`blocked` → environment is not ready (missing compiler/symbols, container down, `gh` auth, unreachable release for the baseline). Route to `/al-steer`. Under `/al-autopilot` (seat per `${CLAUDE_SKILL_DIR}/../../references/autonomy-seat.md`): the infrastructure ladder (restart container → recreate via `new-agent-container.ps1` → `AUTONOMY STOP REPORT`). Never flip `done` without a clean exit — a green flip with a stale environment poisons every downstream compile.

## Composition

| | |
|---|---|
| **Runs after** | `/al-scope` emits `T-001 kind=provision`; this is the feature's first executed task |
| **Routes to** | first slice's technical tasks (`Depends on: T-001` opens on `done`) |
| **Calls** | `/al-build`'s `provision.ps1` (standalone helper; al-build never reads `tasks.md`) |
| **Failure venue** | `/al-steer` (manual) · infrastructure ladder then stop report (`/al-autopilot`) |
