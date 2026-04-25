---
name: al-debug-logging
description: "AL Debug Logging / Runtime Observability — temporarily add `DEBUG-*` `FeatureTelemetry.LogUsage` probes to AL code (production, posting, validation, install/upgrade, event subscribers, tests) to inspect runtime state via `.output/TestResults/telemetry.jsonl`. Use when stuck on AL behavior you cannot see in source alone. Probes are temporary; remove before final delivery."
---

# AL Debug Logging

A short loop for inspecting AL runtime behavior the agent cannot see from the source. Drop in a few `DEBUG-*` `FeatureTelemetry.LogUsage` probes, exercise the AL path, then read `.output/TestResults/telemetry.jsonl` to confirm what actually happened.

## Invocation

| Command | Action |
|---------|--------|
| `/al-debug-logging` | Add or remove temporary `DEBUG-*` probes and inspect runtime behavior |

## When to Use

Reach for this skill when:

- A change appears correct in source but the runtime result is surprising.
- It is unclear which branch, event, or subscriber is firing.
- Posting, validation, or upgrade logic behaves differently than reading the code suggests.
- A test passes (or fails) and you need to confirm which production path actually ran.
- A standard BC integration point is opaque and you need eyes on it without modifying BaseApp.

The code under observation can be production code, validation logic, posting routines, setup, install/upgrade code, event subscribers, integration handlers, or tests. Tests are one harness — not the purpose.

## The Debug Loop

1. **Form a hypothesis.** Name the specific question — e.g. "is `OnAfterValidateEvent` for `Customer."Credit Limit"` firing during posting?", "is the `IsHandled` short-circuit in our pricing extension hit?", "does the posting routine reach the secondary branch when the document has no lines?"
2. **Add the smallest useful probes.** One or two `DEBUG-*` `FeatureTelemetry.LogUsage` calls is usually enough. Place them only where the answer to the hypothesis is decided.
3. **Execute the AL path.** Run whatever harness exercises that code: a manual page action, a posted document, a web service call, an install/upgrade codeunit, a job queue task, or a test (via `/al-build`). The harness is whatever fires the code — it does not have to be a test.
4. **Inspect telemetry.** Read `.output/TestResults/telemetry.jsonl` and look for the probe event IDs.
5. **Refine or remove.** If the probes did not answer the question, move them or add a peer probe at the next decision point. When the question is answered, delete the probes.

## Probe Convention

- Use `FeatureTelemetry.LogUsage` (not `Session.LogMessage`).
- Prefix every event ID with `DEBUG-` so probes are trivial to grep and remove.
- Pick descriptive suffixes: `DEBUG-POSTING-PRECHECK`, `DEBUG-PRICING-FALLBACK`, `DEBUG-UPGRADE-MIGRATEROW`, `DEBUG-SUBSCRIBER-ONAFTERMODIFY`.
- For correlation across multi-step flows, emit one entry-scope probe at the start of the flow you are investigating (e.g. `DEBUG-ENTRY` in the procedure or test under observation), then branch probes inside.
- Use `Format()` for non-text values placed in the message or custom dimensions.

## Quick Snippet

```al
var
    FeatureTelemetry: Codeunit "Feature Telemetry";
begin
    FeatureTelemetry.LogUsage('DEBUG-ENTRY', 'Investigation', 'CalculateDiscount, Customer 10000');
    // ...code under observation...
    if SalesLine.FindFirst() then
        FeatureTelemetry.LogUsage('DEBUG-LINES-FOUND', 'Investigation', StrSubstNo('Lines: %1', SalesLine.Count()))
    else
        FeatureTelemetry.LogUsage('DEBUG-LINES-EMPTY', 'Investigation', 'Empty document path');
end;
```

## Inspecting Telemetry

Telemetry is written to `.output/TestResults/telemetry.jsonl` because the BC test runner is the capture mechanism in this stack. The path is named after the runner, not the use case — any AL flow that runs under that runner produces entries here.

```text
# Example (rg)
rg "DEBUG-" .output/TestResults/telemetry.jsonl
rg "DEBUG-ENTRY" .output/TestResults/telemetry.jsonl
```

```powershell
# Example (PowerShell)
Select-String -Path .output/TestResults/telemetry.jsonl -Pattern "DEBUG-"
```

Useful telemetry fields: `eventId`, `message`, `customDimensions`, `callStack`, plus `testCodeunit` / `testProcedure` when a test was the harness.

## Same-Publisher Constraint

`FeatureTelemetry.LogUsage` is captured by a Telemetry Logger codeunit that subscribes to the platform's telemetry events. The subscriber and the emitting code must live in extensions with the **same publisher** in `app.json`. If probes silently produce no entries in `telemetry.jsonl`, mismatched publishers between the emitting extension and the extension hosting the Telemetry Logger is the most common cause.

This is a constraint on where probe code can live, not on what kind of code it is — production, test, upgrade, or subscriber code all work as long as the publisher matches.

## Cleanup and Safety

- Probes are scaffolding, not production telemetry. Remove every `DEBUG-*` call before final delivery.
- Long-lived feature telemetry should not start with `DEBUG-` and is out of scope for this skill.
- Do not log secrets, personal data, credentials, tokens, customer PII, or full record bodies. Log shape (counts, IDs, enum values, booleans) — not contents.
- If a probe needs to stay across a longer investigation, leave a comment naming the issue/PR it relates to so a future cleanup pass knows it is intentional.

Final state at hand-off: zero `DEBUG-*` calls in the working tree (unless the user has explicitly asked you to keep one for ongoing work).

## Edge Cases

- **Probes never appear:** check the same-publisher constraint, then confirm the harness actually ran the code path (a test that early-exits, a page action that errors before the call, etc.).
- **Too much noise:** narrow the probes. Remove peer branches once one is confirmed; tighten the message to the one fact that matters.
- **Code is in standard BaseApp / System Application:** you cannot edit it. Use a temporary event subscriber as a probe — see [bc-event-subscriber-pattern.md](references/bc-event-subscriber-pattern.md).

## Reference Documentation

| Topic | Reference |
|-------|-----------|
| Hypothesis-driven probe workflow, lifecycle, correlation | [telemetry-workflow.md](references/telemetry-workflow.md) |
| Probing standard BC and production flows via event subscribers | [bc-event-subscriber-pattern.md](references/bc-event-subscriber-pattern.md) |

## Related Skills

| Skill | Purpose |
|-------|---------|
| `/al-build` | Run the test runner harness and produce `telemetry.jsonl` |
| `/bc-standard-reference` | Find BC events to subscribe to as probe attachment points |
