# Temporary debug logging workflow

Reference for `/al-debug-logging`. The skill body has the contract; this expands the loop, the same-publisher constraint, and correlation discipline.

## When to probe

An AI agent reading AL source cannot watch a debugger step through code. `DEBUG-*` probes emit one fact per call to `telemetry.jsonl`. Correlate after the fact. Symmetric on both directions of confusion:

| Question | Probe answers |
|---|---|
| Result is wrong — which branch produced it? | Probes on each branch reveal which one ran. |
| Result is right — but did the code exercise the path I think? | Probes confirm or refute the assumed path. |

A passing assertion does not prove which code ran. Probes do.

## Loop

Starting state: zero `DEBUG-*` calls in tree. End state: zero `DEBUG-*` calls in tree.

1. Add probes for the current hypothesis.
2. Run the harness that exercises the AL path.
3. Read telemetry from the harness's capture path (see Capture path below).
4. Refine — move, narrow, add a peer probe — until answered.
5. Remove every `DEBUG-*` call before hand-off.

## Hypothesis

Phrase the question so a single probe can answer:

- "Does `OnAfterPostSalesDoc` fire when posting an order with zero lines?"
- "Is the `IsHandled` short-circuit on our pricing extension hit during a price calculation for customer X?"
- "Does the upgrade codeunit reach the migration branch on a database that already has rows?"

Smallest probe that answers it. One probe at the decision point. Binary answer → two peer probes, one per branch.

```al
if SalesLine.FindFirst() then begin
    FeatureTelemetry.LogUsage('DEBUG-POSTING-LINES', 'Investigation', StrSubstNo('Count=%1', SalesLine.Count()));
    // ... lines path
end else begin
    FeatureTelemetry.LogUsage('DEBUG-POSTING-NOLINES', 'Investigation', 'No lines path');
    // ... no-lines path
end;
```

## Correlate with `DEBUG-ENTRY`

When several probes fire and runs need separating (multiple tests, multiple posted documents, repeated subscriber invocations), emit `DEBUG-ENTRY` (or `DEBUG-<Scope>-START`) at the start of the scope you control:

```al
FeatureTelemetry.LogUsage('DEBUG-ENTRY', 'Investigation', 'PostScenario: invoice with item charge');
```

Everything between two `DEBUG-ENTRY` entries belongs to the first scope. The single most useful correlation tool when probes inside shared code (subscribers, library codeunits, BaseApp events) fire from many callers.

```
DEBUG-ENTRY            -> PostScenario: invoice with item charge
DEBUG-POSTING-LINES    -> Count=3
DEBUG-PRICING-FALLBACK -> V16 calculator returned UnitPrice=0
DEBUG-ENTRY            -> PostScenario: credit memo
DEBUG-POSTING-NOLINES  -> No lines path
```

## Pick a harness

Whatever fires the AL code. Common in BC:

- A manual page action.
- A posted document (sales, purchase, item journal).
- A web service / API call.
- An install or upgrade codeunit run.
- A scheduled job queue task.
- An event subscriber that fires under a standard BC flow.
- A test via `/al-build` — convenient because the BC test runner reliably produces `telemetry.jsonl`. One option among the above, not the only one.

Probes work identically under any harness in the same publisher.

## Capture path

The capture path depends on the harness:

- `/al-build` test harness → `.output/TestResults/*/telemetry.jsonl`. Inspect with:

  ```text
  rg "DEBUG-" .output/TestResults/*/telemetry.jsonl
  rg "DEBUG-ENTRY" .output/TestResults/*/telemetry.jsonl
  ```

  ```powershell
  Select-String -Path .output/TestResults/*/telemetry.jsonl -Pattern "DEBUG-"
  ```

- Page action, posted document, web service, install/upgrade, job queue, manual subscriber trigger → no `telemetry.jsonl` produced by `/al-build`. Capture via Application Insights, the BC server's telemetry sink, or a local Telemetry Logger codeunit configured to write to a known path. Confirm where the host environment surfaces `FeatureTelemetry` events before running.

Useful fields per entry: `eventId`, `message`, `customDimensions`, `callStack`. When a test was the harness, `testCodeunit` and `testProcedure` are populated.

## Refine or remove

Answered: delete the probe. Not answered: tighten the message, add a peer probe at the next decision point, or move earlier / later in the flow.

_Avoid_:

- Probes left "just in case" — they pollute future telemetry.
- Probes wrapped around a decision instead of inside the chosen branch.
- More than two probes per question. Narrow the hypothesis.

## Read the mismatch

Most useful failure mode: probes contradict the result. Document posted "successfully" but probes show the no-lines branch ran. The mismatch is the bug. Without probes, the symptom alone (success) hides it.

## Same-publisher constraint

`FeatureTelemetry.LogUsage` is captured by a Telemetry Logger codeunit subscribing to the platform's telemetry events. Capture only happens when the emitting code and the Telemetry Logger live in extensions with the **same publisher** in `app.json`.

Probes silent:

1. Confirm the harness ran (test pass/fail, document posted, codeunit invoked).
2. Check the publisher of the extension where the probe lives matches the publisher hosting the Telemetry Logger.
3. Verify a `Telemetry Logger` codeunit exists and is registered as a subscriber in that publisher's extension.

Constraint is on publishers, not on test-vs-app. Production, test, upgrade, install, and subscriber code all emit, as long as the publisher matches.

## Hygiene

- `FeatureTelemetry.LogUsage`. Not `Session.LogMessage`.
- Event IDs start with `DEBUG-`. Cleanup is one `rg`.
- Stable, descriptive suffixes (`DEBUG-PRICING-FALLBACK`, not `DEBUG-1`).
- `Format()` for non-text values in messages or custom dimensions.
- Drop list: full record bodies, PII, credentials, tokens, secrets. Counts, IDs, enum values, booleans only — shape, not contents.
- Hand-off precondition: `rg "DEBUG-" --type al` returns nothing in the working tree. If a probe is deliberately retained, comment with the issue so the next pass sees it.
