# bc-replay recording YAML — format reference

Complete reference for the `.yml` recordings consumed by `@microsoft/bc-replay` and produced by
the BC web client **Settings ⚙ → Page scripting (Preview)** recorder.

> **No official schema exists.** Microsoft's `devenv-page-scripting` Learn article is prerelease,
> workflow-first, and shows only fragmentary YAML. The npm package ships the player as a closed
> DLL for `-UseServerReplay`, and the client-side interpreter (`window.DN.playRecording`) lives in
> the BC web-client JS bundle. This reference was **reverse-engineered from the platform** (mining
> `client.js` + cross-checking recorder output) and validated by replay.
>
> **Validated against BC platform `28.0.49873.0`.** The grammar is version-bound — treat anything
> here as "true for v28" and re-derive against newer platforms (mine the web-client bundle's
> recorder serializer + `playRecording` dispatch, then confirm by recording the gesture and reading
> the emitted `.yml`).

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

18 top-level `type:` values. Three are **containers** (carry nested `steps:`): `scope`, `for-each`,
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
`Edit`, `DrillDown`, `Lookup`, `Refresh`, `RunReport`, `CloseOk`, `Cancel`, `Yes`, `No`. A repeater
**row** invoke omits `invokeType` and instead carries `parameters: { AlwaysCommit: true }`.
[recorded · replayed: navigate/page-shown/input/focus/invoke/close-page/page-closed]

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
- type: set-current-row   # position a repeater's current row by a relative offset
  target: [ {page,runtimeRef}, {repeater: Control1} ]
  targetRecord: { relative: 1 }
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
- type: message           # assert a specific message dialog was shown
  automationId: ...
- type: autofill          # data-suggestion / autofill on a field
  action: invoke          # invoke | accept | reject | change
  target: [ {page,runtimeRef}, {field: ...} ]
```
[recorded: `set-current-row`, `copy-value` · source: `copy-rows`, `run-prompt`, `message`, `autofill`]

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

See the skill's `SKILL.md` › *Running a recording* for the full invocation, auth options, and the
Node 22–25 requirement. In short, from a folder with `@microsoft/bc-replay` installed:

```powershell
npx replay .\recordings\*.yml -StartAddress http://<host>/<instance>/ -ResultDir .\results
```

---

## 10. Authoring checklist for agents

1. **Targets bind to the live UI.** A perfectly-shaped recording still fails with
   `Field '<caption>' was not found.` if the `field`/`action`/`page` caption isn't a rendered
   control at replay time. Read the page AL for exact `Caption` values before authoring, then
   replay-and-fix. (A removed/obsoleted field is the classic silent rot — confirm it's on the page.)
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
| **Confirm / dialog** | `page: null` + `automationId` + `caption` (`modal: true`); answer = `invoke invokeType: Yes`\|`No` | recorded |
| **Modal vs content** | `page-shown.modal: true` (drilldown/RunModal/dialog) vs `false` (navigate/content) | recorded |

Behaviours beyond a locator variant:

- **Open a Card/Document from a list row** = `invoke` with `invokeType: Edit` + `parameters: {AlwaysCommit: false}`. Other row defaults: `New`, `DrillDown`.
- **Anonymous controls & dialogs** (no AL `designName`) target by `automationId` + `caption` instead of a `field`/`page` name.
- **Closing a page** = `invoke` with `invokeType: Cancel` (request page) or `CloseOk` (modal).
- **Wizard / assisted-setup** (NavigatePage) — `page-shown` (`modal: true`) opens the wizard; Back/Next/Finish are `invoke action: ActionBack`/`ActionNext`/`ActionFinish` that **swap content in place** (no per-step `page-shown`); exit X = `invoke CloseOk` → Confirm. Open an assisted-setup entry via `invoke invokeType: OpenTargetSettingsPage`.
- **Role Center** — navigate via a role-center action = `page: <X> Role Center` + `action: <name>`; cue-tile drilldown = a part-nested `action` invoke (`page: <X> Role Center → part: <CuePart> → page: <ActivitiesPage> → action: <Cue caption>`).
- **Message dialog** (`Message()`) — asserted by the `message` step (§4), same `automationId` model as the confirm dialog. *[message step source-only; confirm dialog recorded]*
- **Show more / Show less / FastTab expand-collapse are NOT recorded** — they're client-side rendering/density toggles; a session doing all three produces zero steps. And they don't need to be: a field hidden by Show-less (or a collapsed FastTab) is still **reachable on replay** — the player resolves controls via the logical page model, not the rendered DOM. Proven: a `copy-value` on a Show-less-hidden field replayed green. Target hidden fields by name directly; never try to author a Show-more step.

---

## 12. Authoring without the recorder ("blind")

You can hand-author a replayable recording from the AL source + this reference, with no recorder
pass, for the cases below (a blind-authored navigate + `page-shown` recording replays green).

**Works blind** (targets derivable from AL):
- `navigate` to a named page + `page-shown`.
- `input` / `validate` / `focus` on a named `field` — including Show-more-hidden fields (§11).
- **System actions** with stable names: `Control_New`, `Control_Refresh`, `Cancel`, `OK`, `CloseOk`, `Yes`, `No`; `invokeType: New|Edit|DrillDown|Lookup|Refresh`.
- Mint your own `runtimeId`/`runtimeRef` (file-local, §3); start self-contained (§10.7).

**Needs a recorder pass** (identifiers not derivable from AL):
- **Reports** — not pages: `navigate page: <Report>` fails (`metadata object … not found`); reached via search/an action.
- **Custom actions** that serialize as generated IDs (`Action37`) instead of their name — varies per page.
- **Repeater** control names (`Control1`), **cue** part-nests, **peek/lookup** repeaters, **NavigatePage wizard** paging.

Practical rule: page navigation + named-field input/validate is hand-authorable; do **one** recorder
pass per page to harvest its custom-action / repeater control IDs, then author the rest by hand.
