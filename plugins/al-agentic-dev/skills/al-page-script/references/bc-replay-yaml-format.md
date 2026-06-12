# bc-replay recording YAML — format reference

Complete reference for the `.yml` recordings consumed by `@microsoft/bc-replay` and produced by
the BC web client **Settings ⚙ → Page scripting (Preview)** recorder.

> **No official schema exists.** Microsoft's `devenv-page-scripting` Learn article is prerelease,
> workflow-first, and shows only fragmentary YAML. The npm package ships the player as a closed
> DLL for `-UseServerReplay`, and the client-side interpreter (`window.DN.playRecording`) lives in
> the BC web-client JS bundle. This reference was **reverse-engineered from the platform** (mining
> `client.js` + cross-checking recorder output) and validated by replay.
>
> **Reverse-engineered on BC v28** (first mined on `28.0.49873.0`; verified stable across minor
> bumps — recordings replay green on later `28.1.x` builds with no change; §4 grid-lifecycle and
> column-filter findings captured on `28.1` w1, bc-replay 0.1.139). Treat the grammar as
> "true for v28." A platform version number alone is **not** a reason to re-derive or to stop;
> re-derive only when a replay red is a grammar-**shape** mismatch (a nesting or step type the
> player rejects), not a missing control or a dialog. To re-derive: mine the web-client bundle's
> recorder serializer + `playRecording` dispatch, then confirm by recording the gesture and reading
> the emitted `.yml`.

Worked, replay-green recordings live in [`examples/`](examples/) — read those alongside this grammar;
agents author far more reliably by pattern-matching a full file than from prose.

How to read the validation tags used below:

| Tag | Meaning |
|---|---|
| **replayed** | a recording using it replayed green against a live container |
| **recorded** | captured verbatim from the v28 recorder |
| **source** | read from the v28 `client.js` recorder/player source; not separately replayed |

---

## 1. Recording envelope

```yaml
name: Smoke - new item validates No.   # display name; defaults to "Recording" if unnamed
description: ...                        # REQUIRED — a recording without it is rejected as invalid
telemetryId: e8f45a3f-...              # GUID, recorder-generated; optional for hand-authored
start:
  profile: ORDER PROCESSOR             # ONLY `profile` is read; set as the ?profile= start param
parameters: { ... }                    # see §7
timeout: 120                           # optional, SECONDS (player does setTimeout(timeout*1000))
test: { skip: "flaky on CI" }          # optional Playwright passthrough: fail | fixme | skip
steps:                                 # REQUIRED — the step array
  - type: navigate
    ...
```

`description` + `steps` are the only hard requirements (`Recording.js` `validateRecording`). `log:`
is **engine-appended** on replay (`start`, `duration`, `video`, and per-step `error`) — never author it.
[source: `Recording.js`, `Commands.js` · recorded: every example]

---

## 2. The `target:` locator

A `target:` (and the `source:` on `page-shown`/`page-closed`/`copy-*`) is an **ordered list** that
walks from a page down to a control:

```yaml
target:
  - page: Sales Order        # a page; the FIRST element. Carries runtimeRef (see §3).
    runtimeRef: b1s6
  - part: SalesLines         # (optional) a page part / subpage…
  - page: Sales Order Subform   # …whose own page name
  - repeater: Control1       # (optional) a repeater control (by control name)
  - field: Description        # the leaf control
```

Leaf kinds: **`field:`** (a control), **`action:`** (an action). Special page forms:

| Form | Meaning |
|---|---|
| `page: lookup:Attribute Name` | the lookup page opened from a field's drilldown |
| `page: Order Processor Role Center` + `action: Items` | navigate via a role-center action |

[recorded · replayed]

---

## 3. `runtimeId` / `runtimeRef` — page-instance correlation

`runtimeId`/`runtimeRef` are **file-local correlation tokens, not server control IDs.** A
`page-shown` step mints `runtimeId: <tok>`; every later step acting on that open page carries
`runtimeRef: <tok>`. The tokens only need to be internally consistent — recorded values are base-36
(`b71`), but invented tokens (`pg1`, `setup1`) replay green. **This is why an agent can author
recordings from scratch.** [replayed: synthetic-token swap]

---

## 4. Step types

19 top-level `type:` values. Three are **containers** (carry nested `steps:`): `scope`, `for-each`,
`include`. The rest are leaf steps. (`navigate`/`invoke`/`input`/`focus`/`validate`/`close-page` are
*actions*; `page-shown`/`page-closed` are *observed results* the recorder emits in pairs with them.)

### Core navigation & interaction

```yaml
- type: navigate          # open a page (by name, or via role-center action — see §2)
  target: [ { page: ... } ]
- type: page-shown        # observed: a page surfaced. mints runtimeId.
  source: { page: Item List }
  modal: false            # true for modal dialogs (drilldowns, RunModal pages)
  runtimeId: b71
- type: focus             # move focus to a control
  target: [ {page,runtimeRef}, {field: No.} ]
- type: input             # set a control value
  target: [ {page,runtimeRef}, {field: Template} ]
  value: false            # literal, or =PowerFx (see §6). `=""` = empty string.
- type: invoke            # run an action / lookup / drilldown / row-select
  target: [ {page,runtimeRef}, {action: Control_New} ]
  invokeType: New         # SystemAction enum NAME: New | DrillDown | Lookup | Refresh | …
  silent: true            # (optional) suppress the expected page/dialog (e.g. on Refresh)
  parameters: {}          # (optional) invoke flags; for a row-select: { AlwaysCommit: true }
- type: close-page        # close a page (action) — paired with a page-closed result
  target: [ {page,runtimeRef} ]
- type: page-closed       # observed: a page closed
  source: { page: Item List }
  runtimeId: b71
- type: wait              # delay
  time: 1000              # milliseconds; may be =Parameters.'Wait time'
```

`invokeType` is the *name* of the platform `SystemAction` enum member. Common values: `New`,
`Edit`, `DrillDown`, `Lookup`, `Refresh`, `RunReport`, `CloseOk`, `Cancel`, `Yes`, `No`,
`SortColumn` (column-header sort; carries `parameters: { sortOrder: 1|2 }` — see *Anchoring a
just-created row*, §4), `FilterByColumn` (column filter — see *Column filter*, §4). A repeater
**row** invoke omits `invokeType` and instead carries `parameters: { AlwaysCommit: true }`.
[recorded · replayed: navigate/page-shown/input/focus/invoke/close-page/page-closed]

### Column filter — `FilterByColumn` + the Apply Filter dialog  [recorded · replayed]

Setting a column filter on a list is one composition (recorder-verbatim):

```yaml
- type: invoke                # open the filter dialog from the column
  target:
    - page: Item List
      runtimeRef: pg1
    - repeater: Control1      # the page's repeater control name
    - field: No.              # the column to filter
  invokeType: FilterByColumn
  parameters: { UseAdvancedFiltering: true }
- type: page-shown            # anonymous Apply Filter dialog
  source:
    page: null
    automationId: f51cf5e3-31d1-4644-8a26-043efefc68d7   # platform Apply-Filter dialog id
    caption: Apply Filter     # documentation only — matcher ignores caption
  modal: true
  runtimeId: flt1
- type: input                 # type the filter value into the dialog's field
  target:
    - page: null
      automationId: f51cf5e3-31d1-4644-8a26-043efefc68d7
      runtimeRef: flt1
    - field: No.
  value: "1000"
- type: invoke                # the dialog's OK — leaf is `action: null`, NO invokeType
  target:
    - page: null
      automationId: f51cf5e3-31d1-4644-8a26-043efefc68d7
      runtimeRef: flt1
    - action: null
- type: page-closed
  source: { page: null }
  runtimeId: flt1
```

Third anonymous-dialog id alongside Error (`00000000-…836bd2d2`) and Confirm (`8da61efd-…`). Like
those, the automationId is platform-generated — stable within a platform version, re-harvest on a
BC bump if it reds as a reference mismatch. Do **not** author a filter via `part: null` /
`page: null` / `{scope: filter}` spacer chains — that shape reds
`error: { type: reference, message: "Part 'null' was not found." }`.

### Editable-grid new-row lifecycle  [replayed — both directions]

- A new row with a typed value commits on **row-leave** — click another row, or `close-page`.
- Leaving the pending row via a second `invoke action: Control_New` **discards** the row buffer:
  no error, the row silently never inserts, downstream `validate`s read fewer rows than authored.
- A grid `input` advances the cursor onto the trailing blank new-row placeholder — an immediate
  `validate` reads the placeholder (`Was expecting '37.5' but got '0'`), not the written row.
  Read row values after a fresh re-open of the page, or re-anchor first.
- A new row inserts **above** the current row (AutoSplitKey midpoint), not at the bottom.

Authoring rule: **one written row per page visit** — `Control_New` → `input` one cell →
`close-page`; re-open the page for the next row.

### `validate` — assert a control value  [replayed: `=`,`<>` · source: rest]

```yaml
- type: validate
  target: [ {page,runtimeRef}, {field: No.} ]
  operation: "<>"          # operator — see §5
  value: ""               # literal or =PowerFx; compared against the control's current value
```

### Containers

```yaml
- type: scope             # conditional / optional-page — nested steps run only if condition holds
  condition: { ... }      # see §5; OMIT condition for an always-run grouping scope
  steps: [ ... ]
- type: for-each          # iterate rows of a repeater (a loop)
  target: [ {page,runtimeRef}, {repeater: Control1} ]
  steps: [ ... ]          # run once per row; "For each selected row…" variant iterates selection
- type: include           # run another recording inline — see §8
  name: setup
  file: ./includes/setup.yml
```
[recorded: `scope`(value cond), `for-each`]

### Rich steps

```yaml
- type: set-current-row   # position a repeater's current row — RELATIVE-ONLY, no absolute/bookmark
  target: [ {page,runtimeRef}, {repeater: Control1} ]
  targetRecord: { relative: 1 }   # can silently fail to move — see Anchoring a just-created row
- type: filter            # recorder filter-pane artifact — author filters via the FilterByColumn composition (§4 Column filter), not this
  target: [ {page,runtimeRef} ]
  operation: add
  column: { field: No., scope: filter }
- type: copy-value        # copy a control value to the page-scripting clipboard
  source: [ {page,runtimeRef}, {repeater: Control1}, {field: Description} ]
  name: Item List - Description   # clipboard key → later read via Clipboard.'Item List - Description'
  valueType: string
- type: copy-rows         # copy repeater rows to clipboard (name) or a parameter array (destination)
  source: [ {page,runtimeRef}, {repeater: Control1} ]
  name: Items
  scope: current          # current | all
  valueType: string
- type: run-prompt        # run a Copilot prompt (SaaS tenants only; gated by Features.RunPrompt); outputs → Variables.
  name: My prompt
  prompt: [ { type: literal, text: "Your prompt" } ]
- type: message           # ASSERT a Message() toast was shown — assert-only, never invoked
  automationId: ...       # same automationId targeting as a dialog, but no invokeType exists for it
  text: ...               # optional content assertion (recorder-emitted); automationId-only replays green
- type: autofill          # data-suggestion / autofill on a field
  action: invoke          # invoke | accept | reject | change
  target: [ {page,runtimeRef}, {field: ...} ]
```
[recorded: `set-current-row`, `copy-value`, `filter` · replayed: `message` (automationId-only) ·
source: `copy-rows`, `run-prompt`, `autofill`]

`Message()` is fire-and-forget: assert, move on. Converting `message` to the Confirm pattern
(`page-shown` + `invoke Ok`) reds `No page found … but no form was found` — a Confirm blocks for
`Yes`/`No`; a Message is never answered. [replayed: mis-conversion red → revert green]

**`Error()` dialog** [recorded · replayed] — not a step type, a composition (recorder-verbatim):

```yaml
- type: page-shown            # catch — MUST immediately follow the triggering step
  source:
    page: null
    automationId: 00000000-0000-0000-0800-0000836bd2d2   # platform Error-dialog id
    caption: Error            # documentation only — matcher ignores caption
  modal: true
  runtimeId: b4e
- type: invoke
  target:
    - page: null
      automationId: 00000000-0000-0000-0800-0000836bd2d2
      caption: Error
      runtimeRef: b4e
  invokeType: Ok
- type: page-closed
  source: { page: null }
  runtimeId: b4e
```

Mechanics (client.js module 90531): an uncaught dialog reds `Invalid state: Unexpected error
dialog. <value>{error text}</value>` on the first later step carrying a foreign `runtimeRef` —
`page-shown` is the only exempt step type → the only catcher; `invoke Ok` is safe (targets the
dialog's own ref). Anonymous-dialog matching: `automationId` or `runtimeRef` only, `caption:`
ignored, neither → `No page found`; Confirm/Message's `8da61efd-…` id does NOT match Error. Error
text not assertable (caption is literal `Error`, no `contains` — §5) → wording checks stay
Exploration-Charter territory (the guided user walk). The automationId is platform-generated — stable within a platform version, re-harvest
on a BC bump if it reds as a reference mismatch.

Message = assert via `message`, never invoked · Confirm = `invoke Yes`\|`No` · Error = catch
`page-shown`, dismiss `invoke Ok`.

**Anchoring a just-created row.** Row selection is never serialized — the recorder emits **no**
step for clicking a row (selection and commit are implicit). Under replay `set-current-row` is
relative-only AND can silently fail to move: `targetRecord.relative: 1` left the cursor on the
prior row, the `validate` read the wrong record, no error [replayed-red]. A new row also inserts
*above* the current row (AutoSplitKey midpoint), never at the bottom. Positional walks are safe
only when every row asserts the SAME expected value (the `for-each` pattern). For a distinguishing
read, anchor by value:

- **SortColumn toggle** [replayed; re-confirmed on 28.1] — `invoke invokeType: SortColumn` on the
  No. column, `parameters: { sortOrder: 1 }` then `sortOrder: 2` → forced re-sort, cursor on top
  row = highest No. Load-bearing: works only because No. Series sorts monotonic-ascending and the
  toggle ends descending — any other sort key silently anchors the wrong row.
- **Column-filter pin** [recorded · replayed] — the *Column filter* composition (above) with the
  `copy-value`-captured No. as the filter value → exact row, sort-independent.

---

## 5. Operators (`operation:`) and conditions

The validate/condition operator enum is **complete** (client.js module 58223):

| `operation` | meaning | note |
|---|---|---|
| `=` | equal | **default** if omitted |
| `<>` | not equal | |
| `>` `>=` `<` `<=` | numeric/ordinal comparison | |
| `isTrue` | expected value (an expression) evaluates true | the value is treated as a Power Fx **expression** |

There is **no** `contains`/`startsWith`. [replayed: `=`,`<>` · source: rest]

A `scope.condition` is one of three shapes (recorder menu: *Add conditional steps when →
Current value / Row count / Expression is true*):

```yaml
# value — "When <field> <op> <value>"   [recorded]
condition: { type: value, target: [...], operation: "=", value: Bicycle }

# page-shown — "make this an optional page": nested steps run only if the page shows   [source]
condition: { type: page-shown, source: { page: Confirm }, runtimeId: c1 }

# powerFx — "When expression … is true"   [source]
condition: { type: powerFx, expression: <expr> }
```

---

## 6. Power Fx expressions

Any `value:` / `time:` / condition is a **literal** unless prefixed with `=`, which makes it a
Microsoft Power Fx expression. Available namespaces:

| Namespace | Source | Example |
|---|---|---|
| `Parameters.` | the `parameters:` block (§7) | `=Parameters.'Sales Order.Document Date'` |
| `Session.` | session info | `=Session.'User ID'` |
| `Clipboard.` | `copy-value` / `copy-rows` `name` keys | `=Clipboard.'Item List - Description'` |
| `Variables.` | `run-prompt` outputs | `=Variables.myOutput` |

Single-quote any name containing spaces or dots. Demonstrated functions/operators: `Today()`, `&`
(concat), `+`, and the comparison set. Internally an expression is an AST of nodes
(`literal {type,text}`, `reference`, `object`, `filter`, `value`) — you rarely author these by hand;
the recorder emits them, and `=`-strings cover normal use. [source · MS Learn]

---

## 7. `parameters:` block

```yaml
parameters:
  Sales Order.Document Date:        # the key IS the parameter name
    type: string                    # only `string` is documented
    default: 9/4/2025               # used at replay if not supplied
    description: Posting date       # prompt text shown when unset
```

Reference with `=Parameters.'<name>'`. An unset parameter prompts the user at replay. To pass a
value into an `include`d script, define the parameter in **both** the host and the included file.
[source · MS Learn]

---

## 8. `include` — sub-recordings

```yaml
steps:
  - type: include
    name: create-customer
    file: ./includes/create-customer.yml   # relative to THIS file's directory
    description: Run <file>create-customer</file>
```

`file` is resolved relative to the containing file's directory; backslashes are normalized to `/`.
Each included file is validated independently (`description`+`steps`) and its own includes load
recursively. Failures surface as `fileError`: `fileNotFound`, `fileInvalid`, or `fileCircularInclude`
(circular includes are detected and rejected). Included steps are read-only from the host.
[source: `Recording.js`]

---

## 9. Running recordings

From a folder with `@microsoft/bc-replay` installed (the Node 22–25 requirement lives in `SKILL.md` › *Running a recording*):

```powershell
npx replay .\recordings\*.yml -StartAddress http://<host>/<instance>/ -ResultDir .\results
```

**Option surface** (`Replay.ps1`, bc-replay 0.1.139):

| Option | Meaning |
|---|---|
| `-Tests` (mandatory) | file-glob of recordings to run |
| `-StartAddress` (mandatory) | BC web-client URL |
| `-Authentication` | `Windows` (default) \| `AAD` \| `UserPassword` |
| `-UserNameKey` / `-PasswordKey` | names of the env vars holding the credentials (never hard-code) |
| `-MultiFactorType` / `-MultiFactorSecretKey` | `None` (default) \| `TOTP` \| `Certificate`; AAD only |
| `-ResultDir` | where `results.xml` + `playwright-report/` are written (defaults to cwd) |
| `-Headed` | show the browser |
| `-UseServerReplay` | swap the browser for the bundled .NET client-service engine |

**`-UseServerReplay`** runs against `Microsoft.BusinessCentral.Replay.dll` over the UI-client protocol — headless, faster, no browser. It **cannot render control add-ins / canvas**: a feature whose deliverable paints inside a canvas is unverifiable this way (use browser mode, or the exploratory guided user walk). `npx replay` runs `npx playwright install` **unconditionally**, even under `-UseServerReplay` — so the Chromium download (and the Node-26 install hang) still applies regardless of the flag. *(Minor upstream bug: the script's `-Headed` guard and doc comment reference `$UseClientService`, but the parameter is `$UseServerReplay`.)*

`replay` exits **non-zero** if any recording fails — that is the green/red gate.

### Reading a failure

Don't trust the exit code alone — read the artifacts. They split across two locations:

- **`-ResultDir`** gets only `results.xml` (JUnit) + `playwright-report/` (the HTML report; `npx playwright show-report` to open).
- **`<cwd>/test-results/dist-player--<hash>-<recording>-yml--chromium/`** gets the **diagnosis** artifacts (failure-only):
  - **`error-context.md`** — a Playwright ARIA snapshot of the *frozen surface* at failure (a YAML accessibility tree). This is where an **unexpected dialog is visible** — a hang (timeout with no error string) almost always means a BC platform Confirm (`RecordChangeDialog`: "Your change might update related records…", default focus No) is sitting open, and the snapshot shows it.
  - **`replay-log.yml`** + **`attachments/Replay-log-<hash>.yml`** — the full step list with engine-appended `log:` blocks; the failing step carries an inline `error:` node, e.g. `error: { type: reference, message: "Field 'X' was not found.", target: [...] }`.
  - **`video.webm`** — the run.

A red is classified from these, not from the console: an `error:` node on a step is a locator/shape or missing-control problem; a timeout with an open dialog in `error-context.md` is the unexpected-dialog case. (Routing: `SKILL.md` › *Failure classification*.)

With Playwright retries enabled, `error-context.md` freezes the **last** attempt's surface while
`replay-log.yml` carries the failing step — the two can describe different attempts. The
replay-log `error:` node is authoritative for *which step* failed.

---

## 10. Authoring checklist for agents

1. **Targets bind to the AL control/field NAME on the live UI, not the display caption.**
   [replayed: `field: Profit %` bound a column captioned 'Margin %'] The recorder writes captions
   only into `description:`. A perfectly-shaped recording still fails with
   `Field '<name>' was not found.` if the named control isn't rendered at replay time. Read the
   page AL for the exact field/control **name** before authoring, then replay-and-fix. (A
   removed/obsoleted field is the classic silent rot — confirm it's on the page.)
2. **Mint a `runtimeId` on every `page-shown`; reuse it as `runtimeRef`** on every step acting on
   that page. Tokens are arbitrary but must be consistent within the file.
3. **`copy-*` use `source:`; everything else uses `target:`.** Don't mix them.
4. **Containers nest via `steps:`.** `scope`/`for-each`/`include` hold child steps.
5. **Default operator is `=`.** Use `isTrue` for boolean/expression assertions.
6. **Validate the file by replay**, not by inspection — the interpreter is server-side and
   version-bound.
7. **Recordings must be self-contained.** Start from a known state (the role center) and
   `navigate` in. A recording captured mid-session that assumes a page is already open fails on
   replay with `Unexpected page. Was expecting '<X>' but got '<role center>'`. *(The canonical
   recordings in [`examples/`](examples/) all replay green on BC 28.0.49873.0.)*
8. **Don't inflate `timeout:` to force a slow scenario green.** The default per-test cap is 120s
   (`playwright.config.js`); a scenario that needs more is usually too long — split it. A recording
   that only passes at `timeout: 600` is a smell, not a tuning need: it often means an unanswered
   platform dialog is eating the clock (see §9 *Reading a failure*), not that the work is genuinely
   that slow.

---

## 11. Locator patterns by page kind

The `target:`/`source:` vocabulary (§2) is **page-type-agnostic**: every BC page kind composes the
same elements (`page` / `part` / `repeater` / `field` / `action`). Page "type" changes *which*
elements appear, not the grammar. Empirically captured shapes (BC 28.0.49873.0):

| Page kind | Locator shape (leaf in **bold**) | Evidence |
|---|---|---|
| **List** + repeater | `page` → `repeater` → **`field`** | recorded |
| **Card** field | `page` → **`field`** (FastTab grouping is not in the path) | recorded |
| **Document + Lines subpage** | `page` → `part` → `page`(subform) → `repeater` → **`field`** | recorded (real Sales Order) |
| **Journal / Worksheet** | `page` → `repeater` → **`field`** (same shape as a List) | recorded (Item Journal) |
| **FactBox** | `page` → `part` → `page`(factbox) → **`field`** (part nest, no repeater) | source (same `part` mechanism as subpage) |
| **Action** (promoted/menu/close) | `page` → **`action: <ControlName>`** — e.g. `Control_New`, `Action37`, `Post`, `SalesOrders`, `CloseOk`; promotion is UI-only | recorded |
| **Lookup / peek page** | `source.page: lookup:<Field>` or `peek:<Field>`; caption "Select" | recorded |
| **Request page** (report) | run it: `invoke invokeType: RunReport` on `action: <Report>` (from a list's Report menu) → `page-shown source.page: <Report>` (`modal: true`) → `invoke invokeType: Cancel`. Reports are NOT `page:`-navigable. | recorded |
| **Analysis / Query page** | open via a list/role-center action → `page-shown`; close = `invoke invokeType: CloseOk`. Navigate may carry `props: {navigationTreeContext, replaceForm}`. | recorded |
| **Confirm / dialog** | `page: null` + `automationId` + `caption` (`modal: true`); answer = `invoke invokeType: Yes`\|`No`; its `8da61efd-…` id does NOT match Error dialogs | recorded |
| **Error dialog** (`Error()`) | `page: null` + `automationId: 00000000-0000-0000-0800-0000836bd2d2` (`modal: true`); catch = `page-shown` (only exempt step), dismiss = `invoke invokeType: Ok` → `page-closed` — §4 | recorded + replayed |
| **Apply Filter dialog** (column filter) | open = `invoke invokeType: FilterByColumn` + `parameters: {UseAdvancedFiltering: true}` on `repeater`→`field`; dialog = `page: null` + `automationId: f51cf5e3-31d1-4644-8a26-043efefc68d7` (`modal: true`); OK = `invoke` with leaf `action: null`, no invokeType — §4 | recorded + replayed |
| **Modal vs content** | `page-shown.modal: true` (drilldown/RunModal/dialog) vs `false` (navigate/content) | recorded |

Behaviours beyond a locator variant:

- **Open a Card/Document from a list row** = `invoke` with `invokeType: Edit` + `parameters: {AlwaysCommit: false}`. Other row defaults: `New`, `DrillDown`.
- **Anonymous controls & dialogs** (no AL `designName`) target by `automationId` + `caption` instead of a `field`/`page` name.
- **Closing a page** = `invoke` with `invokeType: Cancel` (request page) or `CloseOk` (modal).
- **Wizard / assisted-setup** (NavigatePage) — `page-shown` (`modal: true`) opens the wizard; Back/Next/Finish are `invoke action: ActionBack`/`ActionNext`/`ActionFinish` that **swap content in place** (no per-step `page-shown`); exit X = `invoke CloseOk` → Confirm. Open an assisted-setup entry via `invoke invokeType: OpenTargetSettingsPage`.
- **Role Center** — navigate via a role-center action = `page: <X> Role Center` + `action: <name>`; cue-tile drilldown = a part-nested `action` invoke (`page: <X> Role Center → part: <CuePart> → page: <ActivitiesPage> → action: <Cue caption>`).
- **Message dialog** (`Message()`) — asserted by the `message` step (§4), same `automationId` model as the confirm dialog. *[message step replayed (automationId-only); confirm dialog recorded]*
- **Column filter** — the §4 *Column filter* composition (`FilterByColumn` → Apply Filter dialog → `input` → `invoke action: null`). Never a `part: null`/`page: null`/`{scope: filter}` spacer chain — that reds `Part 'null' was not found.`
- **Show more / Show less / FastTab expand-collapse are NOT recorded** — they're client-side rendering/density toggles; a session doing all three produces zero steps. And they don't need to be: a field hidden by Show-less (or a collapsed FastTab) is still **reachable on replay** — the player resolves controls via the logical page model, not the rendered DOM. Proven: a `copy-value` on a Show-less-hidden field replayed green. Target hidden fields by name directly; never try to author a Show-more step.

---

## 12. Authoring without the recorder ("blind")

You can hand-author a replayable recording from the AL source + this reference, with no recorder
pass, for the cases below (a blind-authored navigate + `page-shown` recording replays green).

**Works blind** (targets derivable from AL):
- `navigate` to a named page + `page-shown`.
- `input` / `validate` / `focus` on a named `field` — including Show-more-hidden fields (§11).
  Use the AL control/field **name**, not the caption (§10.1).
- **System actions** with stable names and already-proven invoke types: `Control_New`, `Control_Refresh`, `Cancel`, `OK`, `CloseOk`, `Yes`, `No`; `invokeType: New|Edit|DrillDown|Lookup|Refresh`.
- **Column filter** via the §4 composition — `FilterByColumn` + the constant Apply-Filter `automationId`.
- Mint your own `runtimeId`/`runtimeRef` (file-local, §3); start self-contained (§10.7).

**Needs recorder evidence** (identifiers or invoke shapes not derivable from AL):
- **Reports** — not pages: `navigate page: <Report>` fails (`metadata object … not found`); reached via search/an action.
- **Custom actions** that serialize as generated IDs (`Action37`) instead of their name — varies per page.
- **Repeater** control names (`Control1`), **cue** part-nests, **peek/lookup** repeaters, **NavigatePage wizard** paging.
- **Uncertain modal close actions / invoke types**. Lookup modal close actions, for instance, record as `invokeType: LookupOk` / `invokeType: LookupCancel` — recorder-discovered, not in the AL.

Practical rule: author blind first — this grammar + [`examples/`](examples/) + the repo's
committed `pagescripts/recordings/*.yml` (replayed green against this very app → local ground
truth for IDs and invoke shapes). Recording = escalation for an unknown (custom-action ID,
repeater ID, modal close invoke type, unclear gesture), never journey pre-recording — a pass is
slow, and the replay loop already proves the file. One pass per unknown → smallest gesture → back
to authoring.

### Recorder harvesting for un-derivable IDs

Recorder capture is an evidence technique, not the replay oracle. Know what it can't show: row
clicks are **never serialized** — selection/commit are implicit, so a harvested gesture that only
selects a row yields no step (§4 *Anchoring a just-created row*). **Drive by pixel coordinates,
whatever the path**: BC's iframe stack defeats Playwright locator selectors — every
role/text/title click → `No visible element found across frames for click target`, recorder
captured `steps: []` [refuted]. Trusted coordinate input is what the recorder captures
[replayed→captured].

Two paths:

- **Chrome MCP** (`claude-in-chrome`) — proven end-to-end: screenshot → coordinate click →
  capture. Agent signs in itself: `container.username` / `container.password` from repo-root
  `al-build.json` (defaults `admin` / `P@ssw0rd`), local container hosts only. Caveat: HTTP
  containers strand the download as `Unconfirmed *.crdownload` — bytes complete, copy it out.
- **Plugin harness** (below) — when Chrome MCP is absent (Codex, headless). Lifecycle, auth,
  download capture [proven]. Coordinate click `{"cmd":"click","x":<n>,"y":<n>}` →
  `page.mouse.click` [not yet session-proven — verify on first use]; locator commands reach
  recorder chrome and dialog buttons only.

```powershell
node <plugin>/scripts/bc-pagescript-recorder.mjs --repo-root <repo>
```

`<plugin>` is the installed `al-agentic-dev` plugin root. The harness resolves Playwright from the
target repo's `pagescripts/package.json`, reads auth and `serverInstance` from
`<repo>/al-build.json`, derives the default container host from the current branch, and allows
`BC_CONTAINER`, `BC_COMPANY`, and `BC_PAGE` overrides. It saves the downloaded YAML under a
repo-local `.tmp/bc-pagescript-recorder/...` run directory unless `--output` is passed.

The harness owns only recorder lifecycle:

1. Open the BC Web Client for the target container/company.
2. Open Settings -> Page scripting (Preview).
3. Start a recording.
4. Emit `READY_FOR_AGENT_FLOW`.
5. Let the coding agent perform the task-specific flow.
6. Stop the recorder.
7. Save/download `Recording.yml`.
8. Read and return the YAML path and preview.

The harness must not contain the business/user flow. After `READY_FOR_AGENT_FLOW`, the coding agent
drives the smallest representative gesture that produces the uncertain YAML shape, then sends
`stopSave` — capture answers the unknown; it does not pre-record the journey. The downloaded `.yml`
carries the real `repeater`/`action` IDs and invoke types verbatim; use it as syntax ground truth,
then replay the final authored recording with `pagescript-replay.ps1 -File` and the full batch gate.

The harness emits JSON lines such as `start`, `recording`, `READY_FOR_AGENT_FLOW`, `download`, and
`yml`. Its stdin commands are `screenshot`, `click`, `key`, `type`, `wait`, `stopSave`, `readYml`, and
`close`.

Known proof shape: recording started; the agent opened a list row; the harness downloaded
`Recording.yml`; the YAML contained the row `invoke` on the list's repeater and `page-shown` for
the card. (Drive path unrecorded, predates the locator refutation → proves lifecycle, not drive
mode.)

If the harness cannot open BC or the recorder, report the exact limitation and fall back to
user-provided recorder YAML or hand-authored YAML plus replay.
