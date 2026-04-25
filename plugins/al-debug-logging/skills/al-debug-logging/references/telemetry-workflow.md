# Temporary Debug Logging Workflow

A short workflow for using `DEBUG-*` `FeatureTelemetry.LogUsage` probes to inspect AL runtime behavior. This is temporary scaffolding, not production telemetry.

## Why Probes At All

An AI agent reading AL source cannot watch a debugger step through code. When the runtime behavior diverges from what the source seems to say — a branch is unexpectedly skipped, a subscriber does not fire, a posting routine takes the wrong path — there is no built-in way to *see* what happened. `DEBUG-*` probes are the agent's substitute for stepping through code: they emit one fact per probe to `telemetry.jsonl`, where the agent can correlate events after the fact.

This is symmetric for both directions of confusion:

| Question | Probe answers |
|----------|---------------|
| "The result is wrong — which branch produced it?" | Probes on each branch reveal which one ran. |
| "The result is right — but did the code actually exercise the path I think?" | Probes confirm or refute the assumed path. |

A passing assertion (or a successful posting, or a clean upgrade) does not, by itself, prove which code ran. Probes do.

## Probes Are Always Temporary

Expected starting state: zero `DEBUG-*` calls anywhere in the working tree. If you see existing `DEBUG-*` calls when you start, they are leftover scaffolding from previous work — either finish that work or remove them before adding new probes.

Lifecycle:

1. Start clean (no `DEBUG-*` anywhere).
2. Add `DEBUG-*` probes for the current hypothesis.
3. Run the harness that exercises the AL path.
4. Read `.output/TestResults/telemetry.jsonl`.
5. Refine probes (move, narrow, add peer probes) until the question is answered.
6. Remove every `DEBUG-*` call before hand-off.

End state: zero `DEBUG-*` calls anywhere.

## The Hypothesis-Driven Loop

**Step 1 — name the question.** A vague "let me see what's happening" produces noisy probes that don't narrow anything down. Phrase the hypothesis as something a single probe can answer:

- "Does `OnAfterPostSalesDoc` fire when posting an order with zero lines?"
- "Is the `IsHandled` short-circuit on our pricing extension hit during a price calculation for customer X?"
- "Does the upgrade codeunit reach the migration branch on a database that already has rows?"

**Step 2 — add the smallest probe that answers it.** One probe at the decision point. If the answer is binary, prefer two peer probes (one per branch) over a single probe that has to reason about the answer.

```al
if SalesLine.FindFirst() then begin
    FeatureTelemetry.LogUsage('DEBUG-POSTING-LINES', 'Investigation', StrSubstNo('Count=%1', SalesLine.Count()));
    // ... lines path
end else begin
    FeatureTelemetry.LogUsage('DEBUG-POSTING-NOLINES', 'Investigation', 'No lines path');
    // ... no-lines path
end;
```

**Step 3 — emit a scope-identifying entry probe when correlation matters.** When several probes will fire and you need to distinguish runs (multiple tests, multiple posted documents, repeated subscriber invocations), emit a `DEBUG-ENTRY` (or `DEBUG-<Scope>-START`) at the start of the scope you control:

```al
FeatureTelemetry.LogUsage('DEBUG-ENTRY', 'Investigation', 'PostScenario: invoice with item charge');
```

In `telemetry.jsonl` everything between two `DEBUG-ENTRY` entries belongs to the first scope. This is the single most useful correlation tool when probes inside shared code (subscribers, library codeunits, BaseApp events) fire from many callers.

**Step 4 — pick a harness and run it.** The harness is whatever fires the AL code under observation. Common harnesses in BC:

- A manual page action.
- A posted document (sales, purchase, item journal, etc.).
- A web service / API call.
- An install or upgrade codeunit run.
- A scheduled job queue task.
- An event subscriber that fires under a standard BC flow.
- A test, run via `/al-build` — convenient because the BC test runner reliably produces `telemetry.jsonl`, but only one option among the above.

The probes work identically under any harness that runs in the same publisher.

**Step 5 — inspect.** Open `.output/TestResults/telemetry.jsonl` and look for the probe event IDs.

```text
# rg
rg "DEBUG-" .output/TestResults/telemetry.jsonl
rg "DEBUG-ENTRY" .output/TestResults/telemetry.jsonl
```

```powershell
# PowerShell
Select-String -Path .output/TestResults/telemetry.jsonl -Pattern "DEBUG-"
```

Useful fields per entry: `eventId`, `message`, `customDimensions`, `callStack`. When a test was the harness, `testCodeunit` and `testProcedure` are also populated.

**Step 6 — refine or remove.** If the probe answered the hypothesis, delete it and move on. If not, refine: tighten the message, add a peer probe at the next decision point, or move the probe earlier or later in the flow. Avoid leaving probes "just in case" — they will be forgotten and will pollute future telemetry.

## Correlation Example

```
DEBUG-ENTRY            → PostScenario: invoice with item charge
DEBUG-POSTING-LINES    → Count=3
DEBUG-PRICING-FALLBACK → V16 calculator returned UnitPrice=0
DEBUG-ENTRY            → PostScenario: credit memo
DEBUG-POSTING-NOLINES  → No lines path
```

Reading top-down: each `DEBUG-ENTRY` opens a new scope; everything until the next `DEBUG-ENTRY` belongs to the previous scope. This converts an undifferentiated stream of subscriber and branch events into per-scenario timelines.

## Mismatch Between Probe and Result

The most useful failure mode of probes: when the probes contradict the result. A document posted "successfully" but the probes show the no-lines branch ran — that mismatch is itself the diagnosis. Without probes, the symptom alone (success) hides the bug.

## Same-Publisher Constraint

`FeatureTelemetry.LogUsage` is captured by a Telemetry Logger codeunit that subscribes to the platform's telemetry events. Capture only happens when the emitting code and the Telemetry Logger live in extensions with the **same publisher** in `app.json`.

If probes produce no entries:

- Confirm the harness ran (test pass/fail, document posted, codeunit invoked).
- Check the publisher of the extension where the probe lives matches the publisher of the extension hosting the Telemetry Logger.
- Verify a `Telemetry Logger` codeunit is present and registered as a subscriber in that publisher's extension.

The constraint is on publishers, not on test-vs-app — production, test, upgrade, install, and subscriber code can all emit, as long as the publisher matches.

## Probe Hygiene

- Use `FeatureTelemetry.LogUsage` (not `Session.LogMessage`).
- Always start the event ID with `DEBUG-` so probes are trivial to grep and remove.
- Use stable, descriptive suffixes (`DEBUG-PRICING-FALLBACK`, not `DEBUG-1`).
- Use `Format()` for non-text values in the message or in custom dimensions.
- Do not include secrets, credentials, tokens, PII, or full record bodies. Log counts, IDs, enum values, booleans — shape, not contents.
- Before hand-off: `rg "DEBUG-"` should return nothing in the working tree (excluding this skill's own documentation). If a probe is intentionally left behind for ongoing investigation, add a comment naming the issue so a future cleanup pass knows it is deliberate.
