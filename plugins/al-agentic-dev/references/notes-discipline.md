# Notes discipline

Placement rules for `tasks.md` Notes — what qualifies, what doesn't, where rejected content goes instead.

Voice for the prose itself comes from `voice-contract.md`. This file is destination-only: where content lives, not how prose is shaped.

## What a Notes line is

A `tasks.md` Notes line is scaffolding for the next agent on the in-flight TDD cycle. Branch-scoped. Dies at `[x]`. Forward-facing fact, not a log of how it was reached.

## Trigger test — before writing

→ Will this line be useful past `[x]`?

- **Yes** → DO NOT write to Notes. Halt. Take it to `/al-steer` to clear, then `/al-design` (architecture or design ADR) or `/al-grill-adr` (domain ADR or `CONTEXT.md`).
- **No** → Notes, one line, valid shape below.

## Valid Notes-line shapes

- **Deferred decision** — `Implementation choice: X vs Y — /al-implement decides`. Delete the line once decided.
- **Per-scenario layer override** — `T-NNN#K: layer = component (override; reads real DB)`.
- **Replan soft-flag** — `**Replan** trigger #N: <one-line reason>`.
- **Trivia absorption** — `**Absorbed**: <one line>`. Cap one per task.
- **Non-obvious BC constraint specific to this task** — hidden invariant, guard in an unexpected place.
- **Mutation result** — `**Mutations:** N killed, M equivalent (reason: …), K survivors.` One line, written by the al-mutate agent.

Anything else fails the trigger test → not a Notes line.

## Content that goes elsewhere, not Notes

This is destination routing. Prose-form rules (declarative, no workflow chatter) live in `voice-contract.md`.

- **Process IDs** — issue numbers, PR numbers, "the current fix", "this PR". Goes in the commit message and PR description, not the artifact.
- **Environment lessons** — "`-Force` is mandatory on this workstation", "the container needs republishing". Goes in `scripts/` or a local `CLAUDE.md`, not the artifact.
- **Lessons learned** — `Lesson:` entries, post-mortems, "Note for next time". Goes in the PR description if cross-cutting, or a retrospective doc — never in `tasks.md` Notes.
- **Session-internal reasoning** — second-opinion accept/reject lists, advisor cross-checks, mutation rationale not selected. Stays in the session; the durable artifact carries the outcome, not the deliberation.

## Escalation routing

| Surface | Route to |
|---|---|
| Architectural decision with cross-task or future-feature impact | `/al-steer` → `/al-design` (architecture update or design ADR) |
| BC vocabulary, business rule, cross-feature truth | `/al-steer` → `/al-grill-adr` (domain ADR or `CONTEXT.md`) |
| Recurring scope rejection with substantive reason | `/al-steer` (`.out-of-scope/<concept>.md`) |
| Branch-scoped scaffolding the next agent needs | `tasks.md` Notes — one line, valid shape above |
