---
name: al-quiz
description: Quiz the developer on recently landed AL/Business Central changes — one question at a time, in chat — to keep their mental model in contact with the codebase. Use after a long agentic run, before merging a feature, when returning to a project after time away, or standalone on any diff, slice, or object area the user names.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-quiz, Stay in contact with the codebase

Agentic work lands faster than a human absorbs it. Reading the diff gives a light pass; much of the behaviour rides on existing code paths the diff never shows. This skill closes that gap by quizzing the developer on what actually shipped — the developer proves the mental model, or discovers where it is wrong, before the wrongness costs anything. It verifies the *human*, not the code: `/al-code-review` judges the diff, `/al-user-verification` walks the behaviour; neither checks whether the developer could explain the change to a colleague tomorrow.

Read-only. No status writes, no durable artifact, no gate held. Never invoked by another skill — the user reaches for it.

## Scope

The user names it, or default to the work least likely absorbed: the diff since the user last engaged (recent branch commits), a completed slice, the whole feature before merge, or a named object area on legacy code. Read the diff and the relevant task files (`Test Specification`, `Contract notes`) — the questions come from what shipped, not from what was planned.

## The quiz

One question at a time, in chat, ask-before-reveal: pose the question, wait for the user's answer, then give the verdict — punchline first, and on a miss, the corrective explanation anchored in the actual code (object and procedure names are the citation).

What makes a question worth asking: a wrong answer would cost something. Target the decisions — why a seam sits where it sits, what happens on the edge case the tests pin, which existing code path the change rides, what a shipped contract now promises. Skip trivia a grep answers (counts, names, line placement). Prefer "what happens when …" over "what is …" — behaviour questions expose a broken model; definition questions reward recall.

Calibrate depth to scope: a slice earns a handful of questions, a feature more; stop when the answers show the model is sound rather than grinding through a fixed count. The user can stop, skip, or dig deeper at any question.

## Verdict

End with the punchline: model sound, or where it is off — the specific decisions the user misheld, each with its one-line correction. A miss is information, not failure; a *cluster* of misses on one area is a signal the user may want `/al-code-review` on that area or a walk through its task files. Nothing is recorded; the contact was the point.

## Composition

| | |
|---|---|
| **Runs after**     | anything — typically `/al-implement`/`/al-refactor` runs the user watched loosely, feature-done before merge, or time away from the project |
| **Hands off to**   | nothing — advisory; a miss-cluster may motivate `/al-code-review` or `/al-steer` |
| **Calls directly** | none |
| **Replan venue**   | not applicable — no plan is touched |
