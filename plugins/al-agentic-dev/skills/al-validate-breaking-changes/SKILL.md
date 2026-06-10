---
name: al-validate-breaking-changes
description: Execute the `kind=breaking-change` task in `tasks.md` for AL/Business Central — run al-build's `validate-breaking-changes.ps1` against the provisioned baseline, then flip the task `done` or `blocked`. Use as the feature's last task; a detected break stops for a human, never self-resolved.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-validate-breaking-changes — run the breaking-change gate task

Execute one `kind=breaking-change` task: run the heavyweight AppSource-style validation (per-country, install/upgrade via `Run-AlValidation`) against the cached baseline release, flip its status. The `tasks.md` ↔ script bridge — `/al-build` stays workflow-blind, so a workflow-aware skill owns running its `validate-breaking-changes.ps1` and recording the verdict.

`kind=breaking-change` is the feature's last task, `Depends on:` the final terminal task (last `verify`, or last technical for backend-only) → it opens to `ready` only when all feature work is `done`. It catches "did this feature break a previously-released public API" before merge — the broader sim the compile-time AppSourceCop pass cannot do.

**Naming.** BC vocabulary, verb-first procedures. `tasks.md` status lives on the comment-anchor line `<!-- task=T-NNN status=… slice=breaking-change kind=breaking-change -->`.

## Precondition

A `kind=breaking-change` task at `status=ready`. It opens `blocked` at scope time and is flipped `blocked` → `ready` by the skill that lands the feature's final terminal task `done` (`/al-user-verification` on the last verify task, or `/al-code-review` on the last backend slice) — not by this skill. If it is still `blocked`, the feature is not done; route to `/al-steer`. No `/al-refine` — runs a script, flips status. If invoked on any other kind, **Stop**.

## Run

```powershell
pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/validate-breaking-changes.ps1"
```

Delegate to one general subagent — verbose; keep it out of the main session. The script reads the baseline cache `/al-provision` populated (never downloads), and **self-skips** when `breakingChange.enabled=false` (exit `0`, "disabled"). The worker runs this one command and returns the exit code; it edits nothing.

## Flip

Map the exit code, then surgical-Edit the comment-anchor line per [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md) — change `status=` only; keep `slice=breaking-change kind=breaking-change`; sync the marker.

| Exit | Meaning | Status | Marker |
|---|---|---|---|
| `0` | no break, or detection disabled | `done` | `[x]` |
| `3` (`Analysis`) | **breaking change detected** | `blocked` | `[!]` |
| `4` (`Contract`) | prerequisite failure (empty/missing baseline cache → re-run `/al-provision`; missing `AppSourceCop.json` affixes/countries; current app not built) | `blocked` | `[!]` |
| any other non-zero (`1`) | environment or unexpected failure (container creation, image pull, current-app compile error) — **no verdict on breaking changes**; fix, re-run | `blocked` | `[!]` |

## Breaking change detected → stop for a human

A confirmed break is an **intent decision**, not a defect to auto-patch: *intended* (major bump → accept) vs *accidental* (fix the schema change). Neither this skill nor `/al-autopilot` can read that intent.

- **Manual** → `blocked`, route to `/al-steer`.
- **`/al-autopilot`** (seat per `${CLAUDE_SKILL_DIR}/../../references/autonomy-seat.md`) → `AUTONOMY STOP REPORT` (breaking change is a hard-to-reverse pick). Never auto-fix — that may revert an intended break; never auto-accept — that may ship an accidental one. The human decides at merge.

A `4` (`Contract`) or other non-zero prerequisite failure → `blocked`, fix the prereq (re-run `/al-provision` for an empty cache), re-run.

## Composition

| | |
|---|---|
| **Runs after** | every feature task `done` (its `Depends on:` dependency satisfied) — the last task |
| **Calls** | `/al-build`'s `validate-breaking-changes.ps1` (standalone helper; reads the `/al-provision` baseline cache) |
| **Break / failure venue** | `/al-steer` (manual) · `AUTONOMY STOP REPORT` (`/al-autopilot`) |
