# al-debug-logging

Temporary `DEBUG-*` `FeatureTelemetry.LogUsage` probes for inspecting AL runtime behaviour via `.output/TestResults/*/telemetry.jsonl`. Scaffolding, not production telemetry.

## Layout

```
skills/al-debug-logging/
├── SKILL.md
└── references/
    ├── telemetry-workflow.md
    └── bc-event-subscriber-pattern.md
```

## Editing rules

- **Same-publisher constraint is load-bearing.** The emitting extension and the Telemetry Logger subscriber must share a publisher in `app.json`. Any change to probe placement guidance must preserve this and the silent-probes hard-stop in `SKILL.md` step 4.
- **`DEBUG-` prefix is non-negotiable.** Every example uses it; cleanup is `rg "DEBUG-" --type al`. Never introduce examples that drop it.
- **`FeatureTelemetry.LogUsage`, not `Session.LogMessage`.** Examples and prose stay on `FeatureTelemetry`.
- **`telemetry.jsonl` capture path.** Currently produced only by `/al-build`'s test runner in per-app subfolders (`.output/TestResults/*/telemetry.jsonl`). If a new harness lands, update `SKILL.md`'s Inspect step and `telemetry-workflow.md`.
- **Hand-off state is zero `DEBUG-*` in tree.** Probes are temporary. Reinforce, don't soften.

_Avoid_:

- Hedging the same-publisher constraint with "usually" / "often". It is a hard requirement.
- New canonical examples that log full record bodies, PII, credentials, or tokens.
- Adding probe placement guidance that wraps a decision instead of sitting at it.
