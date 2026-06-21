# Recorder harness protocol

Escalation-only. Blind authoring is the default; open the recorder solely to harvest an unknown AL can't answer (generated action/repeater ID, uncertain invoke type). Chrome MCP (`claude-in-chrome`) drives it where available — agent signs in per the login grant; HTTP containers strand the download as `Unconfirmed *.crdownload` (bytes complete, copy it out). Headless (no Chrome MCP) → the plugin-local Playwright harness below.

```powershell
node <plugin>/scripts/bc-pagescript-recorder.mjs --repo-root <repo>
```

`<plugin>` is the installed `al-agentic-dev` plugin root. The target repo must contain `al-build.json` and `pagescripts/package.json` with `@microsoft/bc-replay` installed; the harness resolves Playwright from the target repo's `pagescripts/package.json`, not from plugin dependencies. It reads `serverInstance` and container auth from `al-build.json`, derives the default container host from the current branch like the AL build scripts, and accepts overrides: `--container` / `BC_CONTAINER`, `--company` / `BC_COMPANY`, `--page` / `BC_PAGE`, `--output`, `--headed`.

The harness only opens the BC Web Client, authenticates, opens Settings -> `Page scripting (Preview)`, starts recording, emits `READY_FOR_AGENT_FLOW`, stops/saves/downloads on command, and reads the YAML. It must not contain the business/user flow. After `READY_FOR_AGENT_FLOW`: smallest gesture that answers the unknown, coordinate clicks from screenshots, `stopSave`. Coordinate drive not yet session-proven — verify on first use.

Machine-readable JSON lines include:

```json
{ "event": "start", "url": "...", "runDir": "..." }
{ "event": "recording", "state": "started" }
{ "event": "READY_FOR_AGENT_FLOW" }
{ "event": "download", "path": "...", "suggestedFilename": "Recording.yml" }
{ "event": "yml", "path": "...", "bytes": 543, "preview": "..." }
```

Stdin commands: `screenshot`, `click`, `key`, `type`, `wait`, `stopSave`, `readYml`, `close` — JSON lines, e.g. `{"cmd":"click","x":640,"y":312}`, `{"cmd":"key","key":"Enter"}`. Locator forms (`{"cmd":"click","text":"Open"}`) reach recorder chrome and dialog buttons only; business-page controls sit behind the iframe stack → coordinates. Screenshots and `error.log` land under repo-local `.tmp/bc-pagescript-recorder/...`.

Successful proof shape for the first known harness capture: recording started; the agent opened a list row; the harness downloaded `Recording.yml`; the YAML contained the row `invoke` on the list's repeater and `page-shown` for the card. (Drive path unrecorded, predates the locator refutation → proves lifecycle, not drive mode.)
