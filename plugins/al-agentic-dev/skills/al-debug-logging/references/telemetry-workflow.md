# Temporary debug logging workflow

Reference for `/al-debug-logging`. The skill body has the contract; this expands the same-publisher constraint, the capture path, and correlation discipline. A passing assertion does not prove which code ran — probes do.

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

## Capture path

Probes work identically under any harness in the same publisher. A test via `/al-build` is convenient because the BC test runner reliably produces `telemetry.jsonl`.

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

## Read the mismatch

Most useful failure mode: probes contradict the result. Document posted "successfully" but probes show the no-lines branch ran. The mismatch is the bug. Without probes, the symptom alone (success) hides it.

## Same-publisher constraint

`FeatureTelemetry.LogUsage` is captured by a Telemetry Logger codeunit subscribing to the platform's telemetry events. Capture only happens when the emitting code and the Telemetry Logger live in extensions with the **same publisher** in `app.json`.

Probes silent:

1. Confirm the harness ran (test pass/fail, document posted, codeunit invoked).
2. Check the publisher of the extension where the probe lives matches the publisher hosting the Telemetry Logger.
3. Verify a `Telemetry Logger` codeunit exists and is registered as a subscriber in that publisher's extension.

Constraint is on publishers, not on test-vs-app. Production, test, upgrade, install, and subscriber code all emit, as long as the publisher matches.

Use `Format()` for non-text values in messages or custom dimensions. The drop list and hand-off zero-state are in the skill body.
