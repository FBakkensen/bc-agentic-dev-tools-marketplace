# Voice contract

Direct, opinionated, no padding. Same voice, every line you write to a durable artifact.

## Voice

- Direct second-person voice. No hedging — kill "perhaps", "you might want to", "I think we could maybe".
- Short declarative sentences. Fragments OK when they land.
- No filler: "just", "really", "basically", "actually", "simply".
- No pleasantries: "Sure!", "Happy to help", "Of course".
- **Bold for openers and key terms** — `**Default**:`, `**Why**:`, `**Exception**:`, `**Rule**:`.
- Em-dash for clarification — like this.
- Arrows (→) for causality: bad cache key → stale read → wrong UI.
- Prescriptive form. "DO NOT X. Do Y." beats "I'd recommend Y over X".
- Opinionated. Pick a side, state it, explain. Don't enumerate options without recommending one.
- One-line opener that states the answer. No preamble.
- No closing summary.

## BC vocabulary

DO NOT use generic programming terms. Use BC vocabulary everywhere — names, prose, slot fills, ADR bodies.

- Insert / Modify / Delete — not Create / Update / Remove (record operations).
- Post — not Submit. Validate — not Check. Get / Find — not Fetch.
- Ledger Entry — not Transaction. No. — not ID. Procedure — not Method.

State the specific object and procedure when describing a change. "Refactor the codeunit" is too vague. "Extract `PostSalesOrder` from codeunit 80 into a new `Sales-Post Impl`" is right.

## Lists of findings

When you write a multi-item list where the reader has to decide which item to look at next — code review findings, replan analyses, audit results — write so they can skim, not slow-read.

- Each item multi-line, not a paragraph.
- Blank line between multi-line items.
- Every line has a leading label, including the headline.
- Lede first — impact, not measurement or cause.
- Uniform shape across items in the list.
- **Bold + labels together**: `**Finding**:`, `**Where**:`, `**Action**:`, `**Note**:`.

Default slot set: `Finding:` (what) / `Where:` (file:line or location) / `Action:` (what to do) / `Note:` (severity, effort, caveat). Adapt slots to the list — uniform shape is the principle, not these specific labels.

## No workflow chatter in artifact prose

DO NOT write workflow-narrative prose into any durable artifact. The voice rule applies regardless of which file you're writing to.

- DO NOT prefix lines with the agent that decided — `/al-implement decision (filter placement):`, `/al-refine second opinion:`.
- DO NOT narrate TDD steps as prose — "bullet 1 went red on stub, green on body fill".
- DO NOT cite advisor cross-checks, second-opinion accept/reject reasoning, or session-internal reconciliation.

Workflow log belongs in the commit message and PR description. The artifact carries the forward-facing fact in declarative voice.

## Anti-pattern — do not write this

> `/al-implement decision (filter placement): T-005 pre-filters TempSourceLink to sub-config edges; planner trusts caller-shaped input — no internal filter. Rationale: bullets do not exercise a planner-internal Comp. Type / Line Configuration No. filter, so a coverage gap would surface at /al-mutate.`

What's wrong, by voice rule: workflow-step prefix → process noise. Walkthrough prose → not declarative. References the agent that decided → not forward-facing. Multi-line for one fact → padding.

## Right shape — write this

> `LoadConfigurationIntoTemps` stays generic; deep-clone callers pre-filter `TempSourceLink` to sub-config edges before passing it to the planner — chosen over a planner-internal filter so the loader stays reusable across ADR-0007 future-import composition.

Single declarative line. Names the decision and the hinge. No agent prefix. No archaeology.
