---
name: al-event-model
description: Settle the user-facing journey for AL/Business Central before architecture commits. Reads CONTEXT.md, domain ADRs, intent, and the codebase; produces event-model.html in BC vocabulary (Role / Action / Business Event / View / Status) at the altitude of what an external observer sees. One timeline per feature, Role swimlanes when more than one Role participates. Optional skill, pure-backend features (no human, no API surface) skip it. Use after /al-grill-adr, before /al-design.
---

# /al-event-model, User-facing journey → event-model.html

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on.

Settle the user-facing journey before `/al-design` commits architecture. Read `CONTEXT.md`, domain ADRs, user intent, and the codebase; write `event-model.html` in BC vocabulary at the altitude of what an external observer sees.

Event Modeling (Dymitruk) is the lineage; the slice's user-facing slots, Role, Action, Business Event, View, Status, are what this skill settles. `/al-design` then consumes the artifact and settles the AL-shape (R → P → W, BC pattern per module, brownfield touchpoints) without re-litigating user-side picks.

**The gap this skill closes**: user flow used to settle inside `/al-design`, entangled with architectural picks, so it never settled cleanly as input. Downstream agents inferred from prose, and assumptions silently propagated between skills. This skill makes the user-side commit point explicit and per-feature.

`/al-design` reads `event-model.html` next.

## Preconditions

- `/al-grill-adr` ran for this idea. `CONTEXT.md` and domain ADRs sharpen vocabulary before the journey settles; without that, fuzzy terms compound into wrong Role names or fictitious Business Events. **Stop** and run it first.
- Feature has a user or API surface. Pure-backend features (no human, no API consumer, only internal batch work observable by no one) skip this skill entirely; `/al-design` proceeds and runs its missing-storm checkpoint.
- If `main` is the current branch, this skill is the first per-feature skill to run; it creates the branch and spec folder. If a feature branch already exists (replan path or `/al-design` ran first for a pure-backend feature that now grew a user surface), reshape `event-model.html` in place.
- If `event-model.html` already exists in the spec folder, you are reshaping; re-run with the user's awareness, not silently.

## What goes into event-model.html

The artifact's job: tell `/al-design` (and the next agent, weeks later, fresh session) what user-facing journey this feature delivers, end-to-end, in BC vocabulary. The shape that serves that job per feature is yours; the questions below name the answers that must be settled before you write.

- **Who is the Role at each chain step?** A user role from BC's Role Center taxonomy (Order Processor, Accountant, Warehouse Worker, Sales Manager) or an external API consumer / publisher. Verify standard Role names via `/al-research`; renamed Role Centers ship fiction downstream.
- **What is the Action they take?** The user-meaningful verb plus object: *Release Sales Order*, *Request Override*, *Approve Override*, *Post Item Journal*. Match BC's standard verb set (Insert / Modify / Delete / Post / Validate / Release / Reopen / Apply / Reverse) where the Action overlaps BaseApp.
- **What Business Event fires?** A past-tense fact, named in business language: *Sales Order Released*, *Credit Limit Breached*, *Override Approved*. Verify against BaseApp via `/al-research` when the Business Event already exists; inventing a name that overlaps BaseApp corrupts the seam.
- **What View does the user (or API consumer) then see?** The surface plus its location: *Sales Order page → Status flips to Released*, *Order Processor Role Center → Pending Overrides cue increments*, *API response carries the Override decision*. Surface type (page / factbox / list / card / cue / notification / API response) settles here; the AL control name settles in `/al-design`.
- **What Status changes?** When the Business Event flips a field on the aggregate's record, name the field and the new value: *Sales Header Status → Override Pending*. Status transitions tie events to data state in BC's natural vocabulary.
- **Where does the journey start, including BaseApp?** If the user's journey starts (or passes through) BaseApp, include the BaseApp portion as normal chain steps using canonical BaseApp names. Do not truncate to "our part only"; the seam between BaseApp and our extension is named by the canonical names themselves.

If a question stays unanswerable, the journey is not ready for `/al-design`. Resolve via `/al-research` (BaseApp behaviour), `/al-grill-adr` (domain rule), or `/grill-me` (intent the user must adjudicate).

## Disciplines

### Strictly user-facing or API-facing voice

The artifact uses BC vocabulary at the altitude of what an external observer sees. No AL pub/sub vocabulary (`OnAfter*`, `IntegrationEvent`, *Subscribes to*, *Publisher*), no page-extension idioms (`pageextension`, `tableextension`), no codeunit references. **Why**: AL-shape vocabulary belongs to `/al-design`'s `architecture.html`. Mixing altitudes here muddies the artifact's job and recreates the entanglement this skill exists to prevent. If a reader of `event-model.html` cannot tell what the user (or API consumer) experiences without consulting AL source, the artifact has failed.

### One timeline per feature, swimlanes by Role

The whole feature gets one timeline, in temporal order, with Role swimlanes when more than one Role participates. **Why**: Event Modeling's whole point is that the temporal sequence is the artifact, events between Actions are where the discovered behaviour lives. Carving the timeline into parallel chains discards the ordering and re-creates the assumption-propagation bug at smaller scale. When a feature genuinely spans two disjoint user journeys, the honest answer is two features, two branches, two timelines.

### BaseApp portions of the journey included as normal chain steps

When the user's journey starts (or passes through) BaseApp, include the BaseApp steps in canonical BaseApp names. **Why**: a reader who knows BC recognises *Sales Order Released* as BaseApp and *Credit Limit Breached* as the feature's contribution by the names themselves. Tagging every element *"(existing)"* or *"(new)"* is noise; the canonical naming carries the distinction. `/al-design` resolves the AL-shape mapping (subscribe vs publish, extend vs create) when it reads the artifact.

### Hybrid settlement, parallel-twice plus confess-your-guesses

Draft two candidate timelines that diverge on one structural decision; present both with a recommendation; after the user picks, name every leaf slot the agent had to invent (*"I picked Role Center notification for the View, email is an alternative, which?"*) and confirm each. **Why**: pure interrogation re-asks what the codebase or `CONTEXT.md` already answers and burns the user's time. Pure candidate-comparison settles structural shape but lets leaf-level guesses survive, which is the propagation bug at smaller scale. The hybrid keeps each posture in its lane.

### Citation chain in chat, before `event-model.html` writes

Before writing `event-model.html`, every Role / Action verb / Business Event name / View page caption / Status value introduced gets a chat-declared citation: `Researched: <name> → <source path / URL / topic id, verbatim one-liner>`. Route through `/al-research`; verify against current BaseApp via cross-source (Microsoft Learn for Role Center taxonomy, `/bc-standard-reference` for verbatim BaseApp event and page names, `al-symbols-mcp` for the workspace's actual dependency surface). **Why**: BC training data is thin and stale. A renamed Role Center, a removed BusinessEvent, a drifted Status enum lands in `event-model.html` and corrupts every downstream skill that reads it. **Why the chat binding**: a mention of `/al-research` reads as advice and gets skipped; a citation chain at write-time binds the gate to the artifact. The artifact stays clean of inline citations (names are the citation); the chain lives in the transcript as the audit trail. If research fails on a term, keep grilling or run `/al-research` deeper; do not write the term this session.

### Names are the citation

Every Role, Action, Business Event, View, Status value carries its canonical BC name. **Why**: downstream skills (`/al-design`, `/al-refine`) cite by name; stable canonical names make the citation work without inline `file:line` references. If the name is wrong, every reference downstream is wrong, and the fix is one rename here rather than a propagated correction across artifacts.

## Branch + folder + write

If already on `^\d{3}-`: skip branch creation, the spec folder exists. Reshape `event-model.html` in place.

If on `main`: this skill is the first per-feature skill to run. Resolve `<NNN>` per `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` (cross-branch scan, not a local-only scan of `specs/`). Derive a 2–4-word kebab-case slug; do not ask the user. Announce the branch name and slug, then create branch `<NNN>-<slug>` and `specs/<NNN>-<slug>/`. If the branch exists locally or remotely: **Stop**, the user resolves.

Then write `event-model.html`. Self-contained HTML, inline `<style>`, Google Fonts via CDN; full aesthetic and embedding constraints in `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md`. Voice contract in `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md`. Both are mandatory reads before writing.

## Floor

`event-model.html` carries no surgical-edit contract. Maintaining skills do not edit it; reshape happens by re-running `/al-event-model`. No Mermaid containers; Event Modeling's swimlane timeline does not render naturally as a Mermaid sequence diagram, and the artifact's primary reader is the next agent. Structured HTML with Role swimlanes expressed as grouping carries the timeline adequately. If a visual is wanted, `architecture.html`'s existing `data-graph="flow"` container can render it derived from this artifact.

Every other piece of structure (section order, swimlane layout, where Status transitions render relative to Business Events, whether each chain step gets a `<details>` or sits inline) is your call per feature. Inconsistency across features is fine and expected.

**Names are the citation.** No inline `(see: file.al:120)` annotations. Future readers grep; the IDE gives line numbers for free.

**Map, not memoir.** The artifact is the user-facing journey, not a log of how you arrived at it.

## Lazy reference reads

| Source (read-only) | Trigger |
|---|---|
| `${CLAUDE_SKILL_DIR}/../../references/LANGUAGE.md` | architectural vocabulary, *Slice* entry, throughout |
| `${CLAUDE_SKILL_DIR}/../../references/cross-branch-numbering.md` | before picking spec folder `NNN` (first per-feature skill only) |
| `${CLAUDE_SKILL_DIR}/../../references/html-spec-discipline.md` | before writing HTML |
| `${CLAUDE_SKILL_DIR}/../../references/voice-contract.md` | before writing HTML |
| most recently modified prior spec under `specs/*/` | before writing HTML, for visual coherence |

## Naming and BC vocabulary

- **Roles.** BC's Role Center taxonomy: Order Processor, Accountant, Warehouse Worker, Sales Manager, Project Manager, etc. Verify standard names via `/al-research`.
- **Actions.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Release (not Submit-for-approval). Apply (not Match). Reopen (not Unrelease). Reverse (not Cancel).
- **Business Events.** Past-tense facts: *Sales Order Released*, *Item Journal Posted*, *Customer Blocked*, *Override Approved*. Avoid generic phrasing (*"thing happened"*, *"status changed"*).
- **Views.** Page captions verbatim where the View is BaseApp (*Sales Order*, *Customer Card*, *Item List*); descriptive name for new surfaces (*Pending Overrides cue*).
- **Status values.** BC's `Status` field vocabulary per table: *Open*, *Released*, *Pending Approval*, *Posted*, *Closed*.

Full architectural vocabulary, including the *Slice* entry, in `LANGUAGE.md`.

## Composition

- `/al-grill-adr`, precondition. `CONTEXT.md` and domain ADRs sharpen vocabulary before the journey settles.
- `/al-research`, mandatory before naming any BaseApp Role, Action verb, Business Event, View page, or Status value. Same rule as `/al-grill-adr`'s, same reason.
- `/bc-standard-reference`, when the question is purely BaseApp behaviour (*does this Business Event already exist?*, *what does the standard Customer Card factbox look like?*).
- `/grill-me`, wraps the confess-your-guesses pass for leaf-level slots the agent could not resolve from `CONTEXT.md` or the codebase.
- `/al-second-opinion`, on non-trivial timelines (multiple Roles, branching paths, brownfield extension, integration touchpoints), between the agent's pick and the user's confirm.
- `/al-design`, consumes `event-model.html` next.
- `/al-steer`, replan venue when a user-facing fact surfaced downstream invalidates the timeline.

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing `event-model.html` for the first time. The artifact is load-bearing for `/al-design`'s AL-shape decisions; drift caught here costs minutes, drift caught at `/al-design` costs a feature.

</claude-only>

## Out of scope

- No code edits.
- No AL-shape decisions: module map, BC pattern per module, R → P → W boundary, AL object names, AL pub/sub mechanism. All `/al-design`.
- No architecture (`/al-design`), task breakdown (`/al-scope`), Gherkin (`/al-refine`), or mutations (`/al-mutate`).
- No `CONTEXT.md` or ADR updates. `/al-grill-adr` owns durable cross-feature vocabulary; this skill writes one per-feature artifact only.
- No tags marking *"(new)"* or *"(existing)"* on elements. Canonical naming carries the distinction; tagging is noise.
- No Mermaid graphs. Structured HTML carries the timeline; `architecture.html` renders the flow visual if one earns its place.
- No markdown-mode output. Legacy markdown specs are frozen.
