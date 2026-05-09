---
name: al-debug-logging
description: Temporarily add `DEBUG-*` `FeatureTelemetry.LogUsage` probes to AL code to inspect runtime state via `.output/TestResults/*/telemetry.jsonl`. Use when runtime behaviour diverges from source and tests alone can't reveal which path ran. Probes are temporary; remove before delivery.
---

# /al-debug-logging — Temporary runtime probe loop

Drop `DEBUG-*` `FeatureTelemetry.LogUsage` probes, exercise the AL path, read `telemetry.jsonl`, remove probes. One question per iteration. Final state: zero `DEBUG-*` calls in tree.

## Precondition

`rg "DEBUG-" --type al` returns nothing in the working tree. If existing `DEBUG-*` calls show up, they are leftover scaffolding. `Stop.` Finish the prior investigation or remove them before adding new probes.

## Flow

1. **Hypothesis.** Name the specific question — which branch, which subscriber, which code path. A vague "let me see what's happening" produces noise that narrows nothing.
2. **Probe.** One or two `FeatureTelemetry.LogUsage` calls. Prefix every event ID `DEBUG-`. Place at the decision point, not around it. Binary branch → two peer probes, one per branch.
3. **Run.** Exercise the AL path: page action, posted document, web service call, install/upgrade codeunit, job queue task, event subscriber under a standard flow, or a test via `/al-build`. Harness is whatever fires the code.
4. **Inspect.** `rg "DEBUG-" .output/TestResults/*/telemetry.jsonl`. Path applies when `/al-build` is the harness; other harnesses require a different capture path — see `references/telemetry-workflow.md`. Probes silent → `Stop.` Same-publisher first — see `references/telemetry-workflow.md`.
5. **Refine or remove.** Answer found: delete probes. Not found: move the probe or add a peer probe at the next decision point. Never leave probes "just in case".

## Canonical probe

```al
var
    FeatureTelemetry: Codeunit "Feature Telemetry";
begin
    FeatureTelemetry.LogUsage('DEBUG-PRICING-FALLBACK', 'Investigation', StrSubstNo('UnitPrice=%1', SalesLine."Unit Price"));
end;
```

**Yes / No on the same call:**

- No: `LogUsage('LOG1', 'Debug', Format(SalesLine))` — no `DEBUG-` prefix, vague event ID, full record body.
- Yes: `LogUsage('DEBUG-POSTING-LINES', 'Investigation', StrSubstNo('Count=%1', SalesLine.Count()))`

**Probe message — drop list.** Log counts, IDs, enum values, booleans. Drop full record bodies, PII, credentials, tokens, secrets. Shape, not contents.

**`DEBUG-ENTRY` for correlation.** When several probes fire across multiple runs (multi-test, repeated subscriber, BaseApp shared code), emit `DEBUG-ENTRY` at the start of the scope you control. Everything between two `DEBUG-ENTRY` entries belongs to the first scope.

_Avoid_:

- Probe wrapped *around* a decision (logs both branches' entry, neither's outcome). Place *inside* the chosen branch.
- More than two probes per question — narrow the hypothesis instead.
- Numeric suffixes (`DEBUG-1`, `DEBUG-2`). Use stable descriptive ones (`DEBUG-PRICING-FALLBACK`).
- `Session.LogMessage`. Use `FeatureTelemetry.LogUsage`.

## Edge cases

| Situation | Action |
|---|---|
| Probes never appear | Same-publisher constraint — see `references/telemetry-workflow.md`. Confirm harness ran. |
| Too much noise | Remove confirmed-wrong branches. Narrow each message to one fact. Add `DEBUG-ENTRY` to scope. |
| Code lives in BaseApp / third-party / unmodifiable extension | Temporary event subscriber probe — see `references/bc-event-subscriber-pattern.md`. |

**Anti-pattern: log everything and grep.** Probes are not tracing. Each probe maps to one prediction.

**Anti-pattern: log full record bodies.** PII, credentials, tokens leak this way. Counts, IDs, enums, booleans only.

**Anti-pattern: leave `DEBUG-*` in tree at handoff.** Final state is zero matches on `rg "DEBUG-" --type al`. If a probe is intentionally retained, comment with the issue/scope so the next pass sees it is deliberate.

## Composition

- `/al-build` — runs the test harness, produces `.output/TestResults/*/telemetry.jsonl`.
- `/bc-standard-reference` — finds BaseApp events for subscriber-based probes.

## Out of scope

- Long-lived production telemetry. Probes are scaffolding.
- PII, credentials, tokens, full record bodies — see drop list above.
- Diagnosing without a hypothesis.
