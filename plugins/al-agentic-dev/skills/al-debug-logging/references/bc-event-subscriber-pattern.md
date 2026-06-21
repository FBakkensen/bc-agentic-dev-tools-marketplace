# Probing standard BC and production flows via event subscribers

Reference for `/al-debug-logging` when the code under observation lives in BaseApp, the System Application, a third-party app, or any extension you cannot edit. The in-place `DEBUG-*` probe pattern needs source access. Subscribe to the events the inaccessible code already publishes; emit `DEBUG-*` `FeatureTelemetry.LogUsage` calls from your subscriber. The subscriber is itself a probe — attached to a real published extension point.

Pattern is general — any BC subsystem that publishes events can be observed this way. When you do control the source, prefer an in-place probe: closer to the decision, easier to remove.

## Find the event

Use `bc-standard-reference` agent to locate published events near the suspected behaviour. Look for events on either side of the suspected branch (`OnBefore*` and `OnAfter*` of the same operation) so the order in `telemetry.jsonl` reveals which path ran.

## Pattern

Place the subscriber codeunit in a non-shipping extension of your project (so it does not reach production). Prefix every emitted event ID with `DEBUG-BC-` so cleanup is one `rg`:

```al
codeunit 50XXX "Debug [Subsystem] Subsc"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"[BC Codeunit]", '[EventName]', '', false, false)]
    local procedure OnAfter[Event](var [Params])
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage(
            'DEBUG-BC-[SUBSYSTEM]-[EVENT]',
            '[Investigation]',
            StrSubstNo('[Shape, not contents]: %1', [RelevantValue]));
    end;
}
```

Run whatever harness exercises the BaseApp flow (posting a document, running a workflow, opening a page action), then read `.output/TestResults/*/telemetry.jsonl`:

```text
rg "DEBUG-BC-" .output/TestResults/*/telemetry.jsonl
```

```powershell
Select-String -Path .output/TestResults/*/telemetry.jsonl -Pattern "DEBUG-BC-"
```

When the investigation is done, delete the subscriber codeunit. Scaffolding, not production code.

A negative result is a result. Subscribing to `Price Calculation - V16`'s `OnAfterFindLines` once produced a `telemetry.jsonl` where the subscriber never fired — the silence *was* the diagnosis: the V16 calculator was not enabled, and the fix lived in test setup, not in the calculator. The probe does not need to *catch* something to answer the question.

## Hygiene

The `DEBUG-BC-*` prefix distinguishes subscriber probes from in-place `DEBUG-*` probes and from production telemetry. The same-publisher constraint applies — the subscriber's extension publisher must match the Telemetry Logger's, see [telemetry-workflow.md](telemetry-workflow.md). A `DEBUG-ENTRY` probe in your harness paired with `DEBUG-BC-*` probes in the subscriber gives per-scenario timelines.
