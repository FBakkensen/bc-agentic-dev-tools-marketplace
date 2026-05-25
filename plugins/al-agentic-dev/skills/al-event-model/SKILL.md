---
name: al-event-model
description: Settle the user-facing journey for AL/Business Central as `event-model.html` in BC vocabulary (Role / Action / Business Event / View / Status). Use after `/al-grill-adr` for user/API-facing features before `/al-design`; pure-backend features skip.
---

# /al-event-model, User-facing journey → event-model.html

Settle the journey at the altitude of what an external observer sees, before `/al-design` commits architecture. Event Modeling (Dymitruk) is the lineage; this skill settles the user-facing slots (Role, Action, Business Event, View, Status) so `/al-design` consumes them and settles the AL-shape without re-litigating user-side picks.

`/al-design` reads `event-model.html` next.

## Preconditions

- `/al-grill-adr` ran for this idea; without sharpened `CONTEXT.md` and domain ADRs, fuzzy terms compound into wrong Role names or fictitious Business Events. **Stop** and run it first.
- Feature has a user or API surface. Pure-backend features (no human, no API consumer, internal batch only) skip this skill; `/al-design` runs its missing-storm checkpoint.
- On `main`: this skill creates the branch and spec folder (first per-feature skill to run). On a feature branch: reshape `event-model.html` in place.
- An existing `event-model.html` means you are reshaping; re-run with the user's awareness.

## What goes into event-model.html

- **Role**: a BC Role Center name (Order Processor, Accountant, Warehouse Worker, Sales Manager) or an external API consumer / publisher. Verify standard names via `/al-research`; renamed Role Centers ship fiction downstream.
- **Action**: user-meaningful verb plus object (*Release Sales Order*, *Approve Override*). Match BC's standard verb set where it overlaps BaseApp (Insert / Modify / Delete / Post / Validate / Release / Reopen / Apply / Reverse).
- **Business Event**: past-tense fact in business language (*Sales Order Released*, *Credit Limit Breached*, *Override Approved*). Verify against BaseApp via `/al-research` before naming.
- **View**: the surface plus its location (*Sales Order page → Status flips to Released*, *Pending Overrides cue increments*, *API response carries the Override decision*). Surface type settles here, the AL control name settles in `/al-design`.
- **Status**: when a Business Event flips a field on the aggregate's record, name field and new value (*Sales Header Status → Override Pending*).
- **BaseApp portions**: if the journey starts or passes through BaseApp, include those steps under canonical BaseApp names. The seam between BaseApp and our extension is named by the canonical names themselves.

Unanswerable question → not ready for `/al-design`. Resolve via `/al-research`, `/al-grill-adr`, or `/grill-me`.

## User-facing voice only

No AL pub/sub vocabulary (`OnAfter*`, `IntegrationEvent`, *Subscribes to*, *Publisher*), no page-extension idioms, no codeunit references; AL-shape belongs to `/al-design`'s `architecture.html` and mixing altitudes recreates the entanglement this skill exists to prevent. If a reader cannot tell what the user experiences without consulting AL source, the artifact has failed.

## One timeline, swimlanes by Role

The whole feature gets one timeline in temporal order, Role swimlanes when more than one Role participates; the temporal sequence *is* the artifact, and carving it into parallel chains discards ordering and re-creates the assumption-propagation bug at smaller scale. A feature that genuinely spans two disjoint journeys is two features.

## BaseApp portions are normal chain steps

Include BaseApp steps in canonical names, no `(existing)` / `(new)` tags; a reader who knows BC recognises *Sales Order Released* as BaseApp and *Credit Limit Breached* as your contribution by the names themselves. `/al-design` resolves subscribe vs publish, extend vs create when it reads the artifact.

## Hybrid settlement, parallel-twice plus confess-your-guesses

Draft two timelines diverging on one structural decision, present both with a recommendation; after the user picks, name every leaf the agent invented (*"I picked Role Center notification for the View, email is an alternative, which?"*) and confirm each. Pure interrogation re-asks what the codebase already answers and burns the user's time; pure candidate-comparison lets leaf-level guesses survive (the propagation bug at smaller scale). The hybrid keeps each posture in its lane.

## Citation chain in chat, before write

Before writing `event-model.html`, declare every Role / Action verb / Business Event name / View page caption / Status value via `/al-research`: `Researched: <name> → <source path / URL / topic id>`. Renamed Role Centers, removed BusinessEvents, and drifted Status enums in training data will corrupt every downstream skill that reads the file.

## Branch + folder + write

On `^\d{3}-`: spec folder exists, reshape `event-model.html` in place. On `main`: this is the first per-feature skill; resolve `<NNN>` per [cross-branch-numbering.md](../../references/cross-branch-numbering.md), derive a 2–4-word kebab-case slug (do not ask), announce both, then create branch `<NNN>-<slug>` and `specs/<NNN>-<slug>/`. Branch already exists locally or remotely: **Stop**.

Then write `event-model.html`. Self-contained HTML, inline `<style>`, Google Fonts via CDN; constraints in [html-spec-discipline.md](../../references/html-spec-discipline.md). Voice in [voice-contract.md](../../references/voice-contract.md). Both are mandatory reads before writing. No surgical-edit contract; reshape via re-running. No Mermaid containers; the swimlane timeline does not render as a Mermaid sequence diagram, and `architecture.html`'s `data-graph="flow"` can render a derived visual if wanted. Vocabulary in [LANGUAGE.md](../../references/LANGUAGE.md) (*Slice* entry). Pull visual coherence from the most recently modified prior `specs/*/` artifact.

## Gate event

Once when `event-model.html` lands. The Gate report describes the user-facing journey in BC vocabulary (Role, Action, Business Event, View, Status), names the application problem the journey addresses, and names the user's call to greenlight `/al-design`.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-grill-adr` (CONTEXT + domain ADRs settled) |
| **Hands off to**   | `/al-design` (consumes `event-model.html`) |
| **Replan venue**   | `/al-steer` (downstream fact invalidates the timeline) |
| **Sidebands**      | `/al-research` (BaseApp Role / Action / Event / View / Status names), `/bc-standard-reference` (pure BaseApp behaviour), `/grill-me` (confess-your-guesses pass), `/al-second-opinion` (non-trivial timelines: multi-Role, branching, brownfield, integration) |

<claude-only>

**Advisor checkpoint.** Call `advisor()` before writing `event-model.html` for the first time. The artifact is load-bearing for `/al-design`'s AL-shape decisions; drift caught here costs minutes, drift caught at `/al-design` costs a feature.

</claude-only>
