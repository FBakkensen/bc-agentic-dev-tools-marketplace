# Model selection

Which Claude model a spawned subagent runs on. One home: the subagent prompt blocks under
`subagents/` and the skills that spawn them name a tier and point here; this file owns the
ordering and the escalation rule so they do not drift. Set the tier with the spawn's `model`
parameter (`sonnet` | `opus` | `fable`).

## Tiers

Three models, ranked. Higher intelligence handles a harder problem unsupervised; higher taste
means better code shape, API design, and copy.

| model  | cost | intelligence | taste |
|--------|------|--------------|-------|
| sonnet | low  | base         | good  |
| opus   | mid  | higher       | higher|
| fable  | high | highest      | highest|

`sonnet` is the floor — never drop below it. When the choice is genuinely unclear, inherit the
spawning session's model.

## How to pick

- **Intelligence > taste > cost.** Cost breaks a tie; it never overrides a task that needs more
  intelligence. Escalating costs less than shipping wrong code.
- **Bulk / mechanical work → `sonnet`.** Clear-spec implementation (a single AAA case with its
  `New and Modified Objects` block), the build/publish/test gate, the mutate-build-revert cycle.
  The spec carries the judgment; the worker executes it.
- **Review of a whole implementation → the smart tier** (`opus` / `fable`) — *except the
  al-agentic-dev carve-out below.*
- **Escalate a cheap run that misses the bar.** Start at the mapped tier; if the output is wrong
  or the worker can't reach green, rerun the same work one tier up. Standing permission — judge
  the output, not the price tag.

## The al-agentic-dev carve-out — review runs cheap on purpose

A single smart reviewer is the usual way to review an implementation. This plugin doesn't use
one: `/al-code-review` and `/al-refactor` decompose the review into many **narrow single-goal
lenses**, each on `sonnet`, then adversarially judge the findings (skeptics prompted to refute)
and run a **cross-family veto** through `/al-second-opinion` (a GPT model — a structurally
different family that catches what same-family self-review misses). The decomposition plus the
veto substitutes for the one smart reviewer, so the lenses stay on `sonnet` deliberately. This
is not a downgrade of the review-→-smart-tier rule; it is a different shape that meets its intent.

## Where each worker lands

| Worker | Tier |
|---|---|
| `al-red-green` (one AAA case RED→GREEN) | `sonnet`; escalate → `opus`/`fable` only if a case can't reach green |
| `al-review-lens` / `al-review-lens-bc` (one focused review pass) | `sonnet` (carve-out) |
| build gate worker (`/al-build`) | `sonnet` |
| mutation worker (`/al-mutate`) | `sonnet` |

`/al-second-opinion` is orthogonal to this table: it pins a GPT model (`gpt-5.5`) for
cross-family independence, not for cost. Never re-tier it to a Claude model.
