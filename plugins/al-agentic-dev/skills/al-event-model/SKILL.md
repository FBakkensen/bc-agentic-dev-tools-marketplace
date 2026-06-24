---
name: al-event-model
description: Settle the user-facing journey for AL/Business Central as `event-model.md` in BC vocabulary (Role / Action / Business Event / View / Status). Use after `/al-grill-adr` for user/API-facing features before `/al-design`; backend-only features skip.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-event-model, User-facing journey → event-model.md

Settle the journey at altitude of what an external observer sees, before `/al-design` commits architecture. Event Modeling (Dymitruk) is the lineage; this skill settles user-facing slots (Role, Action, Business Event, View, Status) so `/al-design` consumes them without re-litigating user-side picks.

## Artifact boundary

Writes only `event-model.md`; never `architecture.md` or the `tasks/` folder.

No implementation structure (modules, codeunits, table fields, event subscribers, AL responsibilities, test surfaces) and no task proof (AAA cases, `Test Specification`, `Verification Plan`, Journey/Contract Examples, Exploration Charters) — those belong to `/al-design` and the task skills.

## Preconditions

- `/al-grill-adr` ran for this idea; without sharpened `CONTEXT.md` and domain ADRs, fuzzy terms compound into wrong Role names or fictitious Business Events. **Stop**, run it first.
- Feature has user or API surface. Backend-only features (no human, no API consumer, internal batch only) skip this skill; `/al-design` runs its missing-storm checkpoint.
- On `main`: this skill creates branch + spec folder (first per-feature skill to run). On feature branch: reshape `event-model.md` in place, with user's awareness.

## What goes into event-model.md

- **Role**: BC Role Center name (Order Processor, Accountant, Warehouse Worker, Sales Manager) or external API consumer / publisher. Verify standard names via `/al-research`; renamed Role Centers ship fiction downstream.
- **Action**: user-meaningful verb + object (*Release Sales Order*, *Approve Override*). Match BC's standard verb set where it overlaps BaseApp (Insert / Modify / Delete / Post / Validate / Release / Reopen / Apply / Reverse).
- **Business Event**: past-tense fact in business language (*Sales Order Released*, *Credit Limit Breached*, *Override Approved*). Verify against BaseApp via `/al-research` before naming.
- **View**: surface + its location (*Sales Order page → Status flips to Released*, *Pending Overrides cue increments*, *API response carries the Override decision*). Surface type settles here, AL control name settles in `/al-design`.
- **Status**: when Business Event flips a field on aggregate's record, name field + new value (*Sales Header Status → Override Pending*).
- **BaseApp portions**: if journey starts or passes through BaseApp, include those steps under canonical BaseApp names. Seam between BaseApp and our extension is named by canonical names themselves.

Unanswerable → not ready for `/al-design`. Resolve via `/al-research`, `/al-grill-adr`, or `/grill-me`.

## User-facing voice only

No AL pub/sub vocabulary (`OnAfter*`, `IntegrationEvent`, *Subscribes to*, *Publisher*), no page-extension idioms, no codeunit references; AL-shape belongs to `/al-design`. A reader who cannot tell what the user experiences without consulting AL source → artifact has failed.

## One timeline, swimlanes by Role

Whole feature gets one timeline in temporal order, Role swimlanes when more than one Role participates; the temporal sequence *is* the artifact. A feature that genuinely spans two disjoint journeys is two features.

## BaseApp portions are normal chain steps

Include BaseApp steps in canonical names, no `(existing)` / `(new)` tags; a reader who knows BC recognises *Sales Order Released* as BaseApp and *Credit Limit Breached* as your contribution by the names themselves.

## Hybrid settlement, parallel-twice plus confess-your-guesses

Draft two timelines diverging on one structural decision, present both with recommendation; after user picks, name every leaf the agent invented (*"I picked Role Center notification for the View, email is an alternative, which?"*) and confirm each. Pure interrogation burns user time; pure candidate-comparison lets leaf guesses survive — hybrid keeps each posture in its lane.

## Citation chain in chat, before write

Evidence bar per [voice-contract.md](../../references/voice-contract.md). `event-model.md` is a durable design artifact: workspace evidence covers what the dependency graph resolves; Role Centers, BaseApp BusinessEvents, and Status enums the workspace cannot answer route through `/al-research`, mandatory.

## Branch + folder + write

On `^\d{3}-`: spec folder exists, reshape `event-model.md` in place. On `main`: first per-feature skill; resolve `<NNN>` per [cross-branch-numbering.md](../../references/cross-branch-numbering.md), derive 2–4-word kebab-case slug (do not ask), announce both, create branch `<NNN>-<slug>` + `specs/<NNN>-<slug>/`. Branch already exists locally or remotely → **Stop**.

Then write `event-model.md`, telegraphic (drop articles, padding, hedges; fragments fine). Markdown-only constraints in [markdown-spec-discipline.md](../../references/markdown-spec-discipline.md), voice in [voice-contract.md](../../references/voice-contract.md) — both mandatory reads before writing. No surgical-edit contract; reshape via re-running. Vocabulary in [LANGUAGE.md](../../references/LANGUAGE.md) (*Slice* entry).

## Document verification

After writing `event-model.md`, run the document-integrity check yourself, inline (no subagent), before the Gate report — verify the artifact against [`doc-integrity.md`](../../references/doc-integrity.md): the `event-model.md` profile (Role / Action / Business Event / View / Status structure) and sibling consistency in the spec folder.

A **fail** (structural or boundary blocker) blocks the Gate report and `/al-design` handoff; fix it or route to `/al-steer`. A **warn** does not block; include it in the Gate report. This gate checks document integrity only, not whether the journey is the best product decision.

## Gate event

Once when `event-model.md` lands. Gate report describes the journey in BC vocabulary (Role, Action, Business Event, View, Status), names the application problem it addresses, names the user's call to greenlight `/al-design`.

## Next step

`event-model.md` landed clean and the branch + spec folder exist. `Next: /al-design` — it consumes the journey into `architecture.md`. A downstream fact invalidated the timeline, or a name won't ground → `Next: /al-research` (BC fact) or `/al-steer` (replan).

## Feed

Two moments narrate the journey to the branch feed; interior craft (name-verification, telegraphic writing, the citation chain) stays in markdown and never cards.

- **decision** — the hybrid-settlement fork resolves: two timelines diverged on one structural choice and the user picked. Depth: the confessed leaf guesses and why this was *the* structural fork.
- **landing** — `event-model.md` lands clean, folding in the branch + spec-folder birth. Depth: the minted branch/slug and the journey timeline.

On a document-integrity **fail**, fire a card naming the plain-language defect that blocked the docs; a clean pass folds into the `landing` card.

At each moment hand `/al-feed` a brief — what happened, why it matters to someone who hasn't read the artifact, and the kind.

## Composition

| | |
|---|---|
| **Runs after**     | `/al-grill-adr` (CONTEXT + domain ADRs settled) |
| **Hands off to**   | `/al-design` (consumes `event-model.md`) |
| **Calls directly** | `/al-research` (BaseApp Role / Action / Event / View / Status names), `/al-second-opinion` (non-trivial timelines: multi-Role, branching, brownfield, integration) — the only skills it invokes |
| **Replan venue**   | `/al-steer` (downstream fact invalidates timeline) |
| **Sidebands**      | `bc-standard-reference` (pure BaseApp behaviour), `/grill-me` (confess-your-guesses pass) |

**Advisor checkpoint.** Before the first write of `event-model.md`, do a final shape check (`/al-second-opinion` for non-trivial timelines: multi-Role, branching, brownfield, integration). Drift caught here costs minutes; caught at `/al-design`, a feature.
