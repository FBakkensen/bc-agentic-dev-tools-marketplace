# Recorder gestures — coaching a re-runnable recording

How the user produces a `.yml` in BC's **Page Scripting (Preview)** recorder, and the handful of re-runnability rules the agent states *before* each scenario so the recording is born replayable rather than patched after. The recorder is the generator; this file is what the agent coaches, not what it authors. Read-only.

The agent's job: turn each `Record: yes` Journey Example into a card whose **Check** bullets name the recorder gesture that asserts each `Observable Check`, and whose tip carries the one re-runnability rule that scenario most needs. Sourced from Microsoft Learn (`devenv-page-scripting`) plus the replay-proven findings the format reference (`bc-replay-yaml-format.md`) captured.

## The recorder, end to end

1. In the Web Client, **Settings ⚙ → Page Scripting**. The pane opens on the right.
2. **Record** (control bar). Perform the scenario's gestures in the UI; the recorder captures each step live.
3. Add **validations** and **value captures** via right-click → **Page Scripting** (below) — these are the assertions, recorded inline.
4. **Save** → the `.yml` downloads. On an HTTP container the browser leaves it as **`Unconfirmed <name>.crdownload`** — the bytes are complete; copy it out of the Downloads folder and paste the agent the path.
5. The agent replays it on a **fresh** container. Green seals; red → the agent coaches a re-record (or asks approval for a one-line surgical edit).

Permission: recording needs the **`PAGESCRIPTING - REC`** permission set; the container's `admin`/SUPER user carries it.

## The re-runnability rules (coach one per card, before recording)

A recording is a regression guard only if it replays green on **clean** data, every time. The recorder captures *gestures*, so the way the user performs the scenario decides whether it re-runs. Each rule below is a gesture the user does instead of the brittle thing.

- **No. Series — let it auto-assign; never type a number.** "Create a Customer" → leave the No. blank, let the series fill it. The recorder records the auto-assign, and replay assigns a fresh No. each run. Typing `C00010` bakes in a literal that collides on the second replay (`already exists`) or asserts a value that won't recur.

- **Need a value in a later step? Capture it, don't retype it.** Right-click the source control → **Page Scripting → Copy** (saves to the recorder's clipboard). Later, right-click the target → **Paste** (creates an input step) or, to assert, → **Validate → is equal to clipboard entry**. This is how "create an order, then find *that* order and check its Status" stays re-runnable — the auto-assigned No. is captured, not hardcoded.

- **Selecting a just-created row — anchor by value, never by position.** A new row inserts *above* the current row, not at the bottom, and "click row 3" drifts when demo data differs. Sort the column **newest-first** (click the No. column header to sort descending) before selecting, or set a **column filter** on the captured No. Don't pick a row positionally.

- **Validate the stored field, not the rounded display.** Two fields linked by a conversion round on the stored side (a typed `80` can read back `79.99999`); the recorder's `Validate` has no tolerance. Validate the canonical stored field, or pick fixture values that round-trip exactly (markup `100` ↔ margin `50`).

- **Uniqueness comes from Power Fx, not a magic string.** Where a field legitimately needs a unique value, use a Power Fx expression in the step (`"Customer " & Today()`), set via the step's **... → Properties**. Power Fx is for real expressions (date filters, current user); it is *not* a place to fake uniqueness a No. Series should own.

- **One written grid row per page visit.** A pending new grid row commits on **row-leave** (close the page, or click another row). A second new-row gesture before leaving silently discards the first. Add one row → leave/re-open → add the next. Don't read a cell value immediately after typing it — the cursor sits on the blank placeholder; re-open or re-anchor first.

- **Start self-contained — from the Role Center, navigate in.** Replay starts from a fresh session, so a recording captured mid-flow that assumes a page is already open reds (`Unexpected page`). Begin each recording at the role center (or a deep link) and navigate to the page.

- **Answer the dialogs the scenario triggers.** A Confirm (`Yes`/`No`) or an `Error()` the scenario raises must be answered *during recording* — right-click/click the dialog button so the recorder captures the answer. An unanswered dialog hangs replay. (An *unexpected* dialog the AL shouldn't raise is a finding, not a gesture — report it.)

## Recorder features that become Check bullets

| Observable Check shape | Recorder gesture |
|---|---|
| A field equals a value | right-click control → **Page Scripting → Validate → Current Value** (`is <value>`) |
| A field equals a captured value | **Validate → is equal to clipboard entry** (after a Copy) |
| A value reused downstream | **Copy** the source, **Paste** into the target |
| "Only when there are no rows…" | right-click column → **Add conditional steps when → Row count → is 0** |
| A `Message()` toast appeared | the recorder captures it as a message assertion — just trigger it during recording |
| A unique/derived input | **... → Properties** on the step → Power Fx expression |

## What stays out of a recording

- **Look-and-feel, error-message tone, accessibility** — no assertion encodes these. They belong in an **Exploration Charter** (the guided user walk in `/al-user-verification`), not a recording.
- **Control add-ins / canvas / embedded Power BI** — the page scripting tool captures AL-driven UI only; it cannot see inside a canvas. A behaviour that paints there is `Record: no` and gets walked, or pinned by another oracle.
- **Behaviour an AL test already covers** — generation-time push-down: `/al-refine` marks it `Record: no`. A recording that doubles a unit/integration test is waste.
