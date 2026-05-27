---
name: al-page-script
description: Author or validate a BC Page Scripting recording (`.yml` replayed by `@microsoft/bc-replay`) from a known grammar — navigate, page-shown, input, invoke, validate, for-each, scope, copy-value, conditions, Power Fx. Use when you need a web-client UI smoke/regression recording and want correct syntax without trial-and-error. The format has no official schema; the reference here is reverse-engineered and replay-validated.
---

**Style:** Drop articles, filler, hedging. Fragments OK. Arrows for causality. Technical terms exact, code unchanged, errors quoted exact. **Exception**: shift to prose where clarity or safety would be hurt.

# /al-page-script — Author bc-replay recording YAML

Mechanical skill: emit valid Page Scripting `.yml` from the reverse-engineered grammar, then verify by replay. The grammar (envelope, `target:` locator, 18 step types, operators, Power Fx, `include`, locator-by-page-kind) lives in [`references/bc-replay-yaml-format.md`](references/bc-replay-yaml-format.md). Six worked, replay-green recordings live in [`references/examples/`](references/examples/) — pattern-match a full file before authoring from prose.

## Precondition

Reference is **version-bound** to BC platform `28.0.49873.0`. Replaying on a newer platform → re-derive the grammar first (the reference's intro says how). Author against the page AL: `field`/`action`/`page` names must be live rendered controls at replay time, or replay fails `Field '<caption>' was not found.`

## Authoring flow

1. **Start self-contained.** First step is `navigate` from the role center in. A recording that assumes a page is already open fails `Unexpected page. Was expecting '<X>' but got '<role center>'`.
2. **One `page-shown` per page opened.** Mint a `runtimeId` on it; reuse as `runtimeRef` on every later step acting on that page. Tokens are file-local — any consistent value works.
3. **Build each `target:` by page kind.** Walk `page → part → page → repeater → field|action` per the reference §2/§11 table. `copy-*` use `source:`; everything else `target:`. Default operator is `=`.
4. **Pick the gesture's serialization** from §11/§12: open card from row = `invoke invokeType: Edit`; dialog = `page: null` + `automationId` + `caption`; report = `invoke invokeType: RunReport`; wizard Next = `invoke action: ActionNext`.
5. **Verify by replay** (below), never by inspection — the interpreter is server-side.

**Blind reliability envelope:** hand-authoring is reliable for `navigate` + named `field`/system-action (`Control_New`, `Cancel`, `CloseOk`, `Yes`/`No`); custom-action generated IDs (`Action37`) and repeater control names (`Control1`) are **not** derivable from AL — do one recorder pass per page to harvest those, then author the rest by hand.

## Canonical example

```yaml
name: Smoke - Item List opens and No. is set
description: Navigate to Items, open first row's card, assert No. is non-empty.
start:
  profile: ORDER PROCESSOR
steps:
  - type: navigate
    target: [ { page: Order Processor Role Center }, { action: Items } ]
  - type: page-shown
    source: { page: Item List }
    runtimeId: pg1
  - type: invoke
    target: [ { page: Item List, runtimeRef: pg1 }, { repeater: Control1 } ]
    invokeType: Edit
    parameters: { AlwaysCommit: false }
  - type: page-shown
    source: { page: Item Card }
    runtimeId: pg2
  - type: validate
    target: [ { page: Item Card, runtimeRef: pg2 }, { field: No. } ]
    operation: "<>"
    value: ""
```

## Running a recording

Replay needs **Node 22–25** (the bundled Playwright's browser-install step hangs on Node 26+) and the `@microsoft/bc-replay` package. From a folder with it installed (`npm install @microsoft/bc-replay`):

```powershell
npx replay .\recordings\*.yml -StartAddress http://<host>/<instance>/ -ResultDir .\results
```

- **Auth** (supplied at invocation, never hard-coded): `-Authentication Windows` (default) | `AAD` | `UserPassword`, plus `-UserNameKey` / `-PasswordKey` naming the env vars that hold the values.
- `replay` exits **non-zero** if any recording fails — that is your green/red gate.
- Inspect the run: `npx playwright show-report .\results\playwright-report` (native bc-replay HTML report + `results.xml`).

## Composition

- The grammar + worked files are this skill's own [`references/`](references/) — no external lookup needed for syntax.
- Verifying that a target field/action exists → read the page AL (`grep`/al-symbols) before authoring; that is the only thing the grammar can't tell you.

## Out of scope

- **Generating scenarios from spec/task files.** This skill is mechanical authoring of syntax, not a spec→recording pipeline. Bring the intended steps; it shapes them into valid YAML.
- **Copilot `run-prompt`.** SaaS-tenant feature (gated by `Features.RunPrompt`); not runnable in a container. Grammar documented in the reference, not exercised here.
- **Harvesting custom-action / repeater control IDs.** Do that with one recorder pass in the web client; this skill consumes the result.
