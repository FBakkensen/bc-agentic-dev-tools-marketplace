---
name: al-event-model
description: Settle the user-facing journey for AL/Business Central as `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). Use after `/al-grill-adr` for user/API-facing features before `/al-design`; backend-only features skip.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-event-model, User-facing journey → event-model.md

Settle the journey at altitude of what an external observer sees, before `/al-design` commits architecture. Event Modeling (Dymitruk) is the lineage; this skill settles user-facing slots (Role, Action, Business Event, View, Status) so `/al-design` consumes them and settles AL-shape without re-litigating user-side picks.

`/al-design` reads `event-model.md` next.

## Artifact boundary

Writes only `event-model.md`.

Never write `architecture.md` or the `tasks/` folder. Branch and spec-folder creation do not grant permission to create sibling artifacts.

Do not choose implementation structure: no modules, codeunits, table fields, event subscribers, AL object responsibilities, or test surfaces. Do not write task proof: no task-level AAA cases, `Test Specification`, `Verification Plan`, Journey Examples, Contract Examples, or Exploration Charters.

## Preconditions

- `/al-grill-adr` ran for this idea; without sharpened `CONTEXT.md` and domain ADRs, fuzzy terms compound into wrong Role names or fictitious Business Events. **Stop**, run it first.
- Feature has user or API surface. Backend-only features (no human, no API consumer, internal batch only) skip this skill; `/al-design` runs its missing-storm checkpoint.
- On `main`: this skill creates branch + spec folder (first per-feature skill to run). On feature branch: reshape `event-model.md` in place.
- Existing `event-model.md` → reshaping; re-run with user's awareness.

## What goes into event-model.md

- **Role**: BC Role Center name (Order Processor, Accountant, Warehouse Worker, Sales Manager) or external API consumer / publisher. Verify standard names via `al-research` agent; renamed Role Centers ship fiction downstream.
- **Action**: user-meaningful verb + object (*Release Sales Order*, *Approve Override*). Match BC's standard verb set where it overlaps BaseApp (Insert / Modify / Delete / Post / Validate / Release / Reopen / Apply / Reverse).
- **Business Event**: past-tense fact in business language (*Sales Order Released*, *Credit Limit Breached*, *Override Approved*). Verify against BaseApp via `al-research` agent before naming.
- **View**: surface + its location (*Sales Order page → Status flips to Released*, *Pending Overrides cue increments*, *API response carries the Override decision*). Surface type settles here, AL control name settles in `/al-design`.
- **Status**: when Business Event flips a field on aggregate's record, name field + new value (*Sales Header Status → Override Pending*).
- **BaseApp portions**: if journey starts or passes through BaseApp, include those steps under canonical BaseApp names. Seam between BaseApp and our extension is named by canonical names themselves.
- **Which BC names verified this session?** Every Role / Action verb / Business Event name / View page caption / Status value landing in `event-model.md` meets the evidence bar in [voice-contract.md](../../references/voice-contract.md) (Role Center pages, Status enums, BaseApp captions are all workspace-resolvable). See *Citation chain in chat, before write* below.

Unanswerable → not ready for `/al-design`. Resolve via `al-research` agent, `/al-grill-adr`, or `/grill-me`.

## User-facing voice only

No AL pub/sub vocabulary (`OnAfter*`, `IntegrationEvent`, *Subscribes to*, *Publisher*), no page-extension idioms, no codeunit references; AL-shape belongs to `/al-design`'s `architecture.md` and mixing altitudes recreates the entanglement this skill exists to prevent. Reader who cannot tell what user experiences without consulting AL source → artifact has failed.

## One timeline, swimlanes by Role

Whole feature gets one timeline in temporal order, Role swimlanes when more than one Role participates; temporal sequence *is* the artifact, and carving it into parallel chains discards ordering and re-creates the assumption-propagation bug at smaller scale. A feature that genuinely spans two disjoint journeys is two features.

## BaseApp portions are normal chain steps

Include BaseApp steps in canonical names, no `(existing)` / `(new)` tags; a reader who knows BC recognises *Sales Order Released* as BaseApp and *Credit Limit Breached* as your contribution by the names themselves. `/al-design` resolves subscribe vs publish, extend vs create when it reads the artifact.

## Hybrid settlement, parallel-twice plus confess-your-guesses

Draft two timelines diverging on one structural decision, present both with recommendation; after user picks, name every leaf the agent invented (*"I picked Role Center notification for the View, email is an alternative, which?"*) and confirm each. Pure interrogation re-asks what codebase already answers and burns user's time; pure candidate-comparison lets leaf-level guesses survive (the propagation bug at smaller scale). Hybrid keeps each posture in its lane.

## Citation chain in chat, before write

Evidence bar per [voice-contract.md](../../references/voice-contract.md). `event-model.md` is a durable design artifact: workspace evidence covers what the dependency graph resolves; Role Centers, BaseApp BusinessEvents, and Status enums the workspace cannot answer route through `al-research` agent, mandatory. Renamed Role Centers and drifted Status enums in training data corrupt every downstream skill that reads the file.

## Branch + folder + write

On `^\d{3}-`: spec folder exists, reshape `event-model.md` in place. On `main`: first per-feature skill; resolve `<NNN>` per [cross-branch-numbering.md](../../references/cross-branch-numbering.md), derive 2–4-word kebab-case slug (do not ask), announce both, create branch `<NNN>-<slug>` + `specs/<NNN>-<slug>/`. Branch already exists locally or remotely → **Stop**.

Then write `event-model.md`. Markdown only; constraints in [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md). Voice in [voice-contract.md](../../references/voice-contract.md). Both mandatory reads before writing. Write telegraphic; drop articles, padding, hedges; fragments fine. No surgical-edit contract; reshape via re-running. Vocabulary in [LANGUAGE.md](../../references/LANGUAGE.md) (*Slice* entry).

## Document verification

After writing `event-model.md`, spawn the `al-agentic-dev:al-doc-verify` agent before the Gate report, with a brief naming:

```text
producer: al-event-model
artifact_paths: specs/<NNN>-<slug>/event-model.md
intended_handoff: al-design
```

`verdict=fail` blocks the Gate report and `/al-design` handoff; fix the structural/boundary issue or route to `/al-steer`. `verdict=warn` does not block; include the warning in the Gate report. This gate checks document integrity only, not whether the journey is the best product decision.

## Gate event

Once when `event-model.md` lands. Gate report describes user-facing journey in BC vocabulary (Role, Action, Business Event, View, Status), names application problem the journey addresses, names user's call to greenlight `/al-design`.

## Feed

Two moments narrate the journey to the branch feed; interior craft (name-verification, telegraphic writing, the citation chain) stays in markdown and never cards.

- **decision** — the hybrid-settlement fork resolves: two timelines diverged on one structural choice and the user picked. Card captures the one big fork in the journey and the path now locked before any code shape — the confessed leaf guesses and why this was *the* structural fork are the depth.
- **landing** — `event-model.md` lands clean, folding in the branch + spec-folder birth. Card captures the whole journey pinned in plain business terms on its fresh branch, design clear to start — the minted branch/slug and the journey timeline are the depth.

The `al-doc-verify` agent is read-only and returns a `verdict=` line rather than carding itself: on `verdict=fail`, fire a card naming the plain-language defect that blocked the docs; a clean pass folds into the `landing` card.

At each moment hand `/al-feed` a brief — what just happened, why it matters to someone who hasn't read the artifact, and the kind — and `/al-feed` composes the punchline and layers and appends the card.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-grill-adr` (CONTEXT + domain ADRs settled) |
| **Hands off to**   | `/al-design` (consumes `event-model.md`) |
| **Replan venue**   | `/al-steer` (downstream fact invalidates timeline) |
| **Sidebands**      | `al-research` agent (BaseApp Role / Action / Event / View / Status names), `bc-standard-reference` agent (pure BaseApp behaviour), `/grill-me` (confess-your-guesses pass), `/al-second-opinion` (non-trivial timelines: multi-Role, branching, brownfield, integration) |

**Advisor checkpoint.** Call `advisor()` before writing `event-model.md` for first time. Artifact is load-bearing for `/al-design`'s AL-shape decisions; drift caught here costs minutes, drift caught at `/al-design` costs a feature.
