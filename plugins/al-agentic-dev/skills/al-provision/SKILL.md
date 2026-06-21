---
name: al-provision
description: Execute the `kind: provision` task in the `tasks/` folder for AL/Business Central — refresh the build environment (compiler, symbols, and — when enabled — the breaking-change baseline) by running al-build's `provision.ps1`, then flip the task `done` or `blocked`. Use on the first task of a feature, or whenever a `kind: provision` task sits at `status: ready`.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-provision — run the provision task

Execute one `kind: provision` task: refresh the build environment, flip its status. The `tasks/` folder ↔ script bridge — `/al-build` stays workflow-blind, so a workflow-aware skill owns running its `provision.ps1` and recording the outcome.

`kind: provision` is the feature's first task (`T-001`). Provision is a per-feature freshness refresh, not one-time machine setup: symbols and the breaking-change baseline advance per release, so each feature re-runs it before any `/al-refine` / `/al-implement` work compiles.

## Precondition

A `kind: provision` task at `status: ready`. No `/al-refine` — this kind carries no `Test Specification` or `Verification Plan`; it runs a script and flips status. If invoked on any other kind, **Stop**.

## Run

```powershell
pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/provision.ps1"
```

Delegate to one general subagent — provision output is verbose; keep it out of the main session. The worker runs exactly this one command and returns the exit code; it edits nothing.

## Flip

Map the exit code, then surgical-Edit the `status:` frontmatter line of the provision task's file per [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md) — `status:` is the only field that changes; leave `slice: provision`, `kind: provision`.

| Exit | Status |
|---|---|
| `0` | `done` |
| non-zero | `blocked` |

**On `done`, open the first slice.** `T-001` is the dependency the first slice's technical tasks wait on. After flipping `T-001` `done`, surgical-Edit the `status:` line of every first-slice technical task (those carrying `depends_on: [T-001]`) `blocked` → `ready`. Provision is the named owner of this `blocked` → `ready`; without it the first slice strands.

## Failure

`blocked` → environment is not ready. Route to `/al-steer`. Never flip `done` without a clean exit — a green flip with a stale environment poisons every downstream compile.

## Feed

Two hand-wired moments narrate to the branch feed. At each, hand `/al-feed` a brief — what just happened, why it matters to a wary dev, the kind — and `/al-feed` composes the punchline and layers and appends the card. Compose by name; never inline its mechanics.

- **verdict** · when `provision.ps1`'s exit is mapped and `T-001` flips — fires on both `done` and `blocked`. Captures whether the build environment is ready to work in: what it refreshed (compiler / symbols / baseline), or the concrete blocker and its route to `/al-steer`.
- **landing** · clean path only, after `T-001` lands `done` and the first slice's technical tasks flip `blocked` → `ready`. Captures that setup is finished and the first slice is now buildable — which/how many tasks opened.

## Composition

| | |
|---|---|
| **Runs after** | `/al-scope` emits `T-001 kind: provision`; this is the feature's first executed task |
| **Routes to** | first slice's technical tasks (`depends_on: [T-001]` opens on `done`) |
| **Failure venue** | `/al-steer` |
