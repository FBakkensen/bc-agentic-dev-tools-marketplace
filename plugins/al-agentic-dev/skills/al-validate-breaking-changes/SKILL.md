---
name: al-validate-breaking-changes
description: Execute the `kind: breaking-change` task in the `tasks/` folder for AL/Business Central — run al-build's `validate-breaking-changes.ps1` against the provisioned baseline, then flip the task `done` or `blocked`. Use as the feature's last task; a detected break stops for a human, never self-resolved.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-validate-breaking-changes — run the breaking-change gate task

Execute one `kind: breaking-change` task: run the AppSource-style validation (per-country install/upgrade via `Run-AlValidation`) against the cached baseline release, flip its status. It catches "did this feature break a previously-released public API" before merge — the broader sim the compile-time AppSourceCop pass cannot do. `/al-build` stays workflow-blind, so this workflow-aware skill owns running its `validate-breaking-changes.ps1` and recording the verdict.

`kind: breaking-change` is the feature's last task, `depends_on:` the final terminal task (last `verify`, or last technical for backend-only) → the per-feature `/al-code-review` opens it `ready` on a clean pass, so it validates the post-review bytes.

## Precondition

A `kind: breaking-change` task at `status: ready`. If still `blocked`, the feature is not done or the per-feature `/al-code-review` has not yet passed clean; route to `/al-steer`. No `/al-refine` — runs a script, flips status. If invoked on any other kind, **Stop**.

## Run

```powershell
pwsh "${CLAUDE_SKILL_DIR}/../al-build/scripts/validate-breaking-changes.ps1"
```

Delegate to one general subagent — verbose; keep it out of the main session. The script reads the baseline cache `/al-provision` populated (never downloads), and **self-skips** when `breakingChange.enabled=false` (exit `0`, "disabled"). The worker returns the exit code; it edits nothing.

## Flip

Map the exit code, then surgical-Edit the `status:` frontmatter line of the breaking-change task's file per [`markdown-spec-discipline.md`](../../references/markdown-spec-discipline.md) — change `status:` only; leave `slice:`, `kind:`.

| Exit | Meaning | Status |
|---|---|---|
| `0` | no break, or detection disabled | `done` |
| `3` (`Analysis`) | **breaking change detected** | `blocked` |
| `4` (`Contract`) | prerequisite failure (empty/missing baseline cache → re-run `/al-provision`; missing `AppSourceCop.json` affixes/countries; current app not built) | `blocked` |
| any other non-zero (`1`) | environment or unexpected failure (container creation, image pull, current-app compile error) — **no verdict on breaking changes**; fix, re-run | `blocked` |

## Breaking change detected → stop for a human

A confirmed break is an **intent decision** the human makes at merge — *intended* (major bump → accept) vs *accidental* (fix the schema change) — not a defect to auto-patch. So on exit `3`: `blocked`, route to `/al-steer`. Never auto-fix (may revert an intended break); never auto-accept (may ship an accidental one).

A `4` (`Contract`) or other non-zero prerequisite failure → `blocked`, fix the prereq (re-run `/al-provision` for an empty cache), re-run.

## Next step

- **`done` (exit `0`):** the feature's last gate is clear. `Next:` merge.
- **Break detected (exit `3`), task `blocked`:** `Next: /al-steer` for the human's intent call.
- **`4`/other prereq failure, task `blocked`:** fix the prereq (`/al-provision` for an empty cache), re-run `/al-validate-breaking-changes`.
