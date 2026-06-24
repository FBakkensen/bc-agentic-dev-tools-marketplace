---
name: al-feed
description: Shared branch-feed writer. A pipeline skill hands it a brief of a narratable moment; it composes one plain-language eli5 card and appends it to the branch's `feed.jsonl`, regenerating `feed.html`. Use from any narrating skill at a hand-wired card-firing moment — never on routine mechanical steps.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-feed, the branch feed writer

Shared writer for a per-branch HTML feed that narrates the agent's work in plain language. A caller hands a brief of what just happened; this skill composes one card and appends it. The caller owns *when* to fire (hand-wired per skill); this skill owns the *voice*, so every card reads the same calm way.

Read-only toward the agent. A card naming a next action is text telling the developer what to type — it never drives anything.

## The brief the caller hands over

Meta-level, not a template, so the card shapes to the moment:

- *what just happened*, in the caller's own AL terms (object names, what the test proved, which rule got locked)
- *why it matters* to someone who has not read the diff
- the **kind**: `decision` (a commitment that constrains the future) · `verdict` (a gate / proof outcome) · `surprise` (a wall hit and how it was handled) · `landing` (a meaningful milestone)

## The card it composes

- A **mandatory, stand-alone punchline** — one plain-language sentence a non-coder understands. A developer reading *only* the closed punchlines must still get the whole story. This is the floor; layers are optional depth.
- **0..N layers**, one short labeled beat each, shallow → deep. Free-length, free-label, sized to the moment — not fixed slots.

The voice rules in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` apply — plain BC vocabulary, names as the address, no workflow chatter.

## Where it writes

Per branch, alongside the other Tier-2 artifacts:

- `specs/<NNN>-<slug>/feed.jsonl` — append-only source of truth, **committed**. The only durable home of the process narration git's result throws away.
- `specs/<NNN>-<slug>/feed.html` — a pure projection of the jsonl, regenerated on every append. al-build's `init.ps1` seeds `specs/*/feed.html` into the consumer `.gitignore`, so it stays untracked; delete it, rerun, it is back — it cannot rot away from the record.

## Invocation

Compose the punchline and layers, then call the append script. `-LayersJson` is a JSON array of `{label, body}` (empty `[]` for a punchline-only card). The script stamps `ts`, appends one json line, and regenerates the html.

DO NOT use `${CLAUDE_SKILL_DIR}` in the call — PowerShell parses it as an empty local variable. Pass the literal absolute path Claude Code gives you at skill activation.

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

`scripts/feed-append.ps1` (over `scripts/feed.psm1`) owns append, escaping, and render mechanics. Do not inline its logic into a caller — that scatters the voice this skill centralizes.

## Next step

Terminal side-band. `Next:` return to the calling skill, which continues where it left off.

## Composition

Returns nothing for chat — a side-write of one card; the caller continues. The skill holding the phase context fires the card: a self-describing verdict (an inline check's or review subagent's finding) is carded verbatim; a context-free verdict (`/al-build`) the caller narrates with the context it holds. A read-only subagent never writes the feed itself — `/al-feed` is a write, outside its envelope, so the spawning skill fires the card from the returned finding.
