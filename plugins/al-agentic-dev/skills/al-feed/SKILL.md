---
name: al-feed
description: Shared branch-feed writer. A pipeline skill hands it a brief of a narratable moment; it composes one plain-language eli5 card and appends it to the branch's `feed.jsonl`, regenerating `feed.html`. Use from any narrating skill at a hand-wired card-firing moment — never on routine mechanical steps.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-feed, the branch feed writer

A per-branch HTML feed narrates the agent's work in plain language so a developer — especially one who does not fully trust agents — can re-orient and feel in control fast, without reading code or markdown. This skill is the shared writer for that feed. A caller hands it a brief of what just happened; it composes one card and appends it. The caller owns *when* to fire (bespoke, hand-wired per skill); this skill owns the *voice* (so every card reads the same calm way). That split is the trust surface: consistent cards firing at curated moments.

The gap it fills: no existing skill produces a durable, narrated, at-a-glance artifact of a branch's reasoning. `/al-steer` computes a live board in chat; `/al-agentic-dev-overview` emits a static tour. Neither persists the story of *why*.

Read-only toward the agent. The feed reports; it never drives anything. Where a card names a next action, that is text telling the developer what to type — the wheel stays in the terminal.

## What the caller hands over

A brief, not a template — meta-level, so this skill can shape the card to the moment:

- *what just happened*, in the caller's own terms (the AL specifics: object names, what the test proved, which rule got locked)
- *why it matters* to someone who has not read the diff
- the **kind**: `decision` (a commitment that constrains the future) · `verdict` (a gate / proof outcome) · `surprise` (a wall hit and how it was handled) · `landing` (a meaningful milestone)

Do not predefine scenarios or pass leading questions. Hand the moment; let the card take its own shape.

## The card it composes

One card, in the feed voice:

- A **mandatory, stand-alone punchline** — one plain-language sentence a non-coder understands. A developer reading *only* the closed punchlines, expanding nothing, must still get the whole story. This is the floor; everything else is optional depth.
- **0..N layers**, revealed one at a time, shallow → deep — each a short labeled beat. Free-length and free-label: a surprise narrates differently from a decision. A grammar, not fixed slots — do not pad a quiet landing to three layers, do not cram a rich decision into one.

Plain and calm throughout. The reader is wary; the voice earns trust by being legible, not impressive. The voice rules in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` apply — plain BC vocabulary, names as the address, no workflow chatter.

## Where it writes

Per branch, alongside the other Tier-2 artifacts:

- `specs/<NNN>-<slug>/feed.jsonl` — append-only source of truth, **committed**. The only durable home of the process narration git's result throws away.
- `specs/<NNN>-<slug>/feed.html` — a pure projection of the jsonl, regenerated on every append. al-build's `init.ps1` seeds `specs/*/feed.html` into the consumer `.gitignore`, so it stays untracked; delete it, rerun, it is back — it cannot rot away from the record.

## Invocation

Compose the punchline and layers, then call the append script. `-LayersJson` is a JSON array of `{label, body}` (empty `[]` for a punchline-only card). The script stamps `ts`, appends one json line, and regenerates the html.

Substitute the absolute path of this al-feed skill directory; Claude Code tells you that path at skill activation. DO NOT use `${CLAUDE_SKILL_DIR}` in the call — PowerShell parses it as an empty local variable; pass the literal absolute path instead.

```powershell
& '<absolute path of this al-feed skill directory>/scripts/feed-append.ps1' `
    -SpecDir   'specs/<NNN>-<slug>' `
    -Skill     '/al-implement' `
    -Kind      'verdict' `
    -Punchline 'A test caught a rounding mistake before it shipped.' `
    -LayersJson '[{"label":"What surprised me","body":"..."},{"label":"What I did","body":"..."}]' `
    -Branch    '<NNN>-<slug>' `
    -Title     '<feature title>'
```

The script at `scripts/feed-append.ps1` (over `scripts/feed.psm1`) is the source of truth for append, escaping, and render mechanics; it is validated by `Validate-PowerShell.ps1` and covered by `tests/al-feed/*.Tests.ps1`. Do not inline its logic into a caller — that bypasses both gates and scatters the voice this skill centralizes.

## Composition

| | |
|---|---|
| **Invoked from** | the 17 narrating skills, each at its own hand-wired card-firing moment (see the per-skill triggers in those skills) — never the 3 silent skills (`/al-build`, `/al-second-opinion`, `/al-agentic-dev-overview`) |
| **Returns to caller** | nothing for chat — a side-write of one card; the caller continues its own work |

A gate narrates its own card only when its verdict is self-describing (`/al-doc-verify`); a gate whose verdict is context-free stays silent and the caller that holds the phase context narrates (`/al-build`).
