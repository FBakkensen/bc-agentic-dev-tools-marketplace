---
name: al-build
description: 'Build and test AL apps for Business Central. Compiles locally, runs tests on remote Azure VM. Use for: verifying code changes, running test suites, debugging test failures, checking compilation warnings/errors.'
---

# AL Build - Test Execution

Compiles AL apps locally and executes tests on a remote Azure VM.

## Timeout Requirement

**CRITICAL: Always use a minimum 20-minute timeout (1200000ms) when calling `run_in_terminal`.**

Container creation and test execution on a remote Azure VM can take significant time. Shorter timeouts cause premature termination.

```
timeout: 1200000  // 20 minutes minimum
```

## Usage

Paths are relative to the skill root.
If needed, set it with: `Set-Location ".agents/skills/al-build"`

Run all tests:
```powershell
pwsh "scripts/test.ps1"
```

Run specific codeunit:
```powershell
pwsh "scripts/test.ps1" -TestCodeunit 50100
```

Force republish (even if unchanged):
```powershell
pwsh "scripts/test.ps1" -Force
```

## Outputs

- `.output/TestResults/last.xml` - JUnit test results
- `.output/TestResults/telemetry.jsonl` - Test telemetry (DEBUG-* markers)

## Exit Codes

- `0` - Success (all tests passed)
- `1` - Build or test failure

## Troubleshooting

| Error | Action |
|-------|--------|
| SSH connection failed | Retry once, then report to user |
| Compiler not provisioned | Instruct user to run `provision.ps1` |
| Symbol cache not found | Instruct user to run `provision.ps1` |

See [README.md](./README.md) for prerequisites and manual setup (user-facing).
