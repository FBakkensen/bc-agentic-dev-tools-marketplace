# al-debug-logging

Temporary `DEBUG-*` `FeatureTelemetry.LogUsage` probes for inspecting AL runtime behaviour via `.output/TestResults/telemetry.jsonl`.

## Layout

```
skills/al-debug-logging/
├── SKILL.md
└── references/
    ├── telemetry-workflow.md
    └── bc-event-subscriber-pattern.md
```

## Editing rules

- **Same-publisher constraint** is load-bearing — the emitting extension and the Telemetry Logger subscriber must share a publisher in `app.json`. Any change to probe placement guidance must preserve this warning.
- All probe event IDs start with `DEBUG-` so cleanup is a `grep` away. Don't introduce examples that drop the prefix.
- `telemetry.jsonl` is produced by `al-build`'s test runner — that's the only currently documented capture mechanism. If a new harness is introduced, update SKILL.md's "Inspecting Telemetry" section.
- Probes are scaffolding, not production telemetry. Hand-off state = zero `DEBUG-*` calls in tree.
