---
name: al-refine
description: Turn an idea, issue, or vague task into concrete tasks in tasks.md for AL/Business Central work. Decomposes by ZOMBIES order, writes Gherkin test bullets, runs /grill-me to extract requirements. Use at the start of any new feature, when an existing task is too large or underspecified, or when domain rules need to be pinned down before implementation.
---

# /al-refine — Idea → tasks.md

Turn an idea, issue, or vague task into concrete tasks in `tasks.md`. Use `/grill-me` to extract requirements until each task is implementable. Output goes ONLY to `tasks.md` — no code edits.

## Decomposition

- One task = one demonstrable behaviour. If it can't be stated in one imperative sentence, split it.
- Apply **ZOMBIES** order: Zero, One, Many, Boundaries, Interfaces, Exceptions, Simple scenarios. Start trivial, walk outward.
- Both **positive AND negative** cases for every behaviour. Boundaries when ranges, thresholds, or guards exist.
- Prefer tests against the pure Process layer (Read → Process → Write) over integration tests when the behaviour can be expressed in isolation.
- **Prefer parallel subagents for independent work.**

## Tests in tasks.md

Each test is a Gherkin bullet:

```
- Given <preconditions>, When <action>, Then <expected outcome>
```

Plain English, plain Markdown. **No AL code in `tasks.md`.** The bullet is the contract — `/al-implement` transcribes it into an AL test procedure with `[SCENARIO]/[GIVEN]/[WHEN]/[THEN]` body comments.

## Grilling

- `/grill-me` when intent is ambiguous, when the goal admits multiple solutions, or when domain rules aren't explicit.
- **Do not invent business rules.** If grilling can't resolve a question, leave a Notes line flagging it; the task is not ready.

## tasks.md format

```markdown
### [ ] T-001 — Post sales order with blocked customer is rejected
A blocked customer must not allow posting; the posting routine needs a guard.

**Tests**
- Given Customer.Blocked = All, When posting, Then a clear error is raised
- Given Customer.Blocked = Invoice, When posting, Then shipment is allowed, invoice is blocked

**Notes** (only when carries information)
- Existing OnBeforePostSalesDoc subscriber already checks Blocked for ship-to — reuse pattern
```

Status: `[ ]` ready, `[~]` in progress, `[x]` done.

## tasks.md hygiene

- **Numbering:** `T-001`, `T-002`, … monotonic, **never reused**.
- **On split:** replace the original task with new tasks at the next available numbers. Update `Depends-on` cross-references in other tasks.
- **Goal section:** keep aligned with the tasks; update when drift appears.
- Keep the file scannable — no empty section stubs, no boilerplate.

## Composition

- `/grill-me` whenever a decision needs the user.
- `/al-research` for non-trivial BC areas before writing tests against them.
- `/bc-standard-reference` when grounding a refinement in BaseApp behaviour.

## Out of scope

- No code edits.
- No mutation lists at refine time — mutations are discovered during `/al-implement`.
- No assignees, dates, estimates, or status states beyond ready / in-progress / done.
