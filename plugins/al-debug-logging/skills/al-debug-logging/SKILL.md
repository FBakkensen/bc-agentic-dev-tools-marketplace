---
name: al-debug-logging
description: Temporarily add `DEBUG-*` `FeatureTelemetry.LogUsage` probes to AL code to inspect runtime state via `.output/TestResults/telemetry.jsonl`. Use when runtime behavior diverges from source and tests alone can't reveal which path ran. Probes are temporary; remove before final delivery.
---

# /al-debug-logging — Temporary runtime probe loop

Drop `DEBUG-*` `FeatureTelemetry.LogUsage` probes, exercise the AL path, read `telemetry.jsonl`, remove probes. One question per iteration. Final state: zero `DEBUG-*` calls in tree.

## Flow

1. **Hypothesis.** Name the specific question — which branch, which subscriber, which code path.
2. **Probe.** One or two `FeatureTelemetry.LogUsage` calls (not `Session.LogMessage`). Prefix every event ID `DEBUG-`. Place at the decision point, not around it.
3. **Run.** Exercise the AL path: page action, posted document, web service call, install/upgrade codeunit, job queue, or test via `/al-build`. Harness is whatever fires the code.
4. **Inspect.** Read `.output/TestResults/telemetry.jsonl`: `rg "DEBUG-" .output/TestResults/telemetry.jsonl`. Probes silent → check same-publisher in `app.json` first — see `telemetry-workflow.md`.
5. **Refine or remove.** Answer found: delete probes. Not found: move probe or add a peer probe at the next decision point.

## Canonical probe

```al
var
    FeatureTelemetry: Codeunit "Feature Telemetry";
begin
    FeatureTelemetry.LogUsage('DEBUG-PRICING-FALLBACK', 'Investigation', StrSubstNo('UnitPrice=%1', SalesLine."Unit Price"));
end;
```

## Edge cases

| Situation | Action |
|---|---|
| Probes never appear | Same-publisher — see `telemetry-workflow.md`; confirm harness ran |
| Too much noise | Remove confirmed-wrong branches; narrow message to one fact |
| Code is in BaseApp | Temporary event subscriber — see `bc-event-subscriber-pattern.md` |

## Composition

- `/al-build` — run harness, produce `telemetry.jsonl`
- `/bc-standard-reference` — find BC events for subscriber-based probes

## Out of scope

- Long-lived production telemetry.
- PII, credentials, tokens, full record bodies — log shape only (counts, IDs, enum values, booleans).
