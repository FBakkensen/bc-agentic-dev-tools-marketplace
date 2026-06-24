# bc-code-intelligence dispatch

How to consume the `bc-code-intelligence` MCP for AL/Business Central writing, review, and refactor. Read by `/al-implement` (write-time construct lookup, narrowest fetch), `/al-refactor` (structural anti-patterns, light touch), `/al-code-review` (in-depth, broad sweep), and `/al-research` (BC fact verification). The MCP is knowledge plumbing: it surfaces relevance-ranked topics; the calling skill (you) is the reviewer. Fetch the topic, match its anti-pattern indicators against the diff yourself.

## The misread that wastes the tool

The MCP does **no server-side LLM inference**. It pattern-matches AL constructs in your query/code against a topic store and returns a ranked list. The topics are the value; apply them yourself. Three traps waste it:

- **Skipping init.** Every tool returns `⚠️ Server Not Yet Initialized` until `set_workspace_info` runs once. It is a mandatory first call, not an optional context hint.
- **Trusting rank over topicality.** Off-domain topics (AI-collaboration methodology, tool-upsell) pattern-match common AL constructs (`SetRange`, `FindFirst`, `repeat`) and score at the *top* of the list. Rank is real; subject-match is not. Drop the noise before fetching (see drop-list).
- **Asking the MCP to review for you.** It recommends topics; it does not find your bugs. A topic surfaced is a lead, not a finding.

## Call pattern

1. **`set_workspace_info`** once per session: `workspace_root` (absolute) + `available_mcps` (the MCP ids in context). Returns `Loaded N topics from M layers`. Skip it and everything else errors.

2. **`find_bc_knowledge`** per concern: `query` is BC-specific and names the construct/concern ("SetLoadFields placement before SetRange in a FindSet loop"), not "review this code". `search_type: "topics"`. Returns topics with a raw `relevance_score`.

3. **Drop the noise** before fetching anything. Unconditionally discard:
   - `parker-pragmatic/*` — AI-collaboration methodology, scores ~100 on any AL code.
   - `*/recommend-*` — tool-upsell topics ("I notice you don't have BC Telemetry Buddy / Object ID Ninja configured…").
   - Off-domain topics whose subject does not match the concern (e.g. `taylor-docs/*` on a performance scan).

4. **`get_bc_topic`** per surviving on-domain topic, top-ranked first: `topic_id`, `include_samples: true`. The response carries the rule markdown, correct/incorrect AL samples, `anti_pattern_indicators`, and a `finding_template`.

5. **Apply the rule yourself.** Pattern-match each `anti_pattern_indicator` against the diff. Where it matches, emit a finding in the topic's `finding_template` shape, citing the topic id. Where it does not match, drop the topic — a surfaced topic whose indicator the code does not exhibit is not a finding.

   **AL false-positive guards.** The indicator matches the *syntax*; it does not know the *context* that sometimes exempts the match. Do not emit a finding when:
   - **the record is `temporary`** — in-memory, zero DB cost, so every access-pattern / partial-record perf topic (`SetLoadFields`, `FindSet`-without-filter, `Get`-in-loop) is moot even though the construct matches.
   - **the field/object is `ObsoleteState = Pending`** with `ObsoleteReason` + `ObsoleteTag` and no upgrade code yet — the `Pending` → `Removed` window is the AppSource-safe deprecation path, the expected steady state, not an unfinished defect.
   - **the topic recommends `ModifyAll` / `DeleteAll`** over a loop whose `OnModify` / `OnDelete` triggers run deliberately — the bulk call bypasses triggers + validation (default `RunTrigger=false`), so swapping it in silently drops that business logic. Flag the trigger-bypass risk instead of recommending the swap.

6. **Vanilla pass alongside.** The MCP is the BC-specific lens; a vanilla pass on the same code catches generic wins it misses (memoize a DFS, dedupe a procedure, drop a dead parameter). Both passes, then dedupe.

**Topic caching within one run.** The topic universe is small; the same `setloadfields-placement-before-filters` resurfaces across files. Cache `get_bc_topic` responses within one `/al-implement` task / `/al-refactor` / `/al-code-review` / `/al-research` invocation; fetch fresh across invocations.

## `analyze_al_code` — optional whole-file signal scan

When you want a code-aware topic scan without crafting a query, call `analyze_al_code` with `file_path` (absolute, singular) + `analysis_type`. **Trust only `matched_signals` / `suggested_topics`** — they are the same code-matched topics `find_bc_knowledge` returns, minus the query. **Ignore `issues[]` and `optimization_opportunities[]`**: empirically it reports 0 issues on code with a real `FindFirst`-could-be-`Get` and missing `SetLoadFields`, and its "opportunities" are generic filler ("improve architecture with loose coupling"). The same drop-list applies to its `suggested_topics`. `file_path` is the live param; the old "use inline `code`, `file_paths` is broken" guidance is obsolete.

## Relevance scales and the backstop

There is **no universal threshold** — the entry tools report on incompatible scales:

| Tool | Score field | Scale |
|---|---|---|
| `find_bc_knowledge` | `relevance_score` | raw, unbounded (single digits → hundreds) |
| `analyze_al_code` | `relevance_score` | float `0.0–1.0` |

A fixed number (the former flat `>=70` / `>=50`) is meaningless across these and was the bug: it discarded real topics while noise outranked them. **The lever is the drop-list, not a cutoff** — once noise is gone, the genuinely relevant topics rank at the top of `find_bc_knowledge` natively. Take the top-ranked on-domain survivors and fetch them. Keep only a light per-tool floor as a backstop against a long tail, and tune it per call when context demands; the floor is a default, not a contract. `/al-implement` fetches narrowest: one query per construct class the task touches (the classes named in `voice-contract.md`'s evidence bar), top on-domain survivor only, before first RED — topics cached for the rest of the task; `/al-refactor` fetches fewer (structural anti-patterns to fix this pass); `/al-code-review` casts wider (gate can afford the sweep); `/al-research` fetches whatever answers the framed question.

**MCP absent or init fails** → the evidence bar stays satisfiable: quoted Microsoft Learn passage (constructs and names) or `bc-standard-reference` agent (names) per `voice-contract.md`. Do not block on the missing server.

## What the MCP catches that vanilla Claude misses

BC-specific execution-order and platform-cost knowledge:

- **SetLoadFields placement.** BC executes `SetLoadFields → filter → query`. `SetLoadFields` after `SetRange`/`SetFilter` is syntactically valid and the optimization is lost; vanilla Claude reads it as fine. Topic `dean-debug/setloadfields-placement-before-filters` (and `-before-case-statements`).
- **Lonely repeat** (`repeat…until` with no `Find` before).
- **SingleInstance subscriber memory model** — state persisting across the session; leak patterns vanilla Claude does not connect to subscriber lifecycle.
- **DeleteAll vs iterate** — performance vs business-logic-compliance tradeoff (DeleteAll bypasses `OnDelete` triggers + validation) that vanilla Claude treats as style.

Refactor wins vanilla Claude already catches (memoize, dedupe, dead-param, guard-before-recurse) do not earn the MCP cost.

## What the MCP does NOT do

- **Cross-file analysis.** Per-query calls return per-concern topics. Event publisher/subscriber signature mismatch, permission set vs new table field, AppSource public-surface additions need multiple files read together; `/al-code-review` does these as its own passes in per-feature mode.
- **Diff-aware review.** It cold-scans whatever you pass; diff scoping is the calling skill's job.
- **Workflow orchestration / layer scaffolding.** The `workflow_*` and `*_layer_*` tools are unused by these skills; the per-query dispatch is cheaper and gives the same signal.

## Composition

- Read by `/al-implement` (write-time construct lookup per the evidence bar in `voice-contract.md`), `/al-refactor` (structural-anti-pattern discipline), `/al-code-review` (per-file consultation + cross-file routing), `/al-research` (one of the source families, governed by its own topic-recommender discipline).
- Upstream source: `JeremyVyska/bc-code-intelligence-mcp` (server) and `JeremyVyska/bc-code-intelligence` (knowledge). Advisory-grade, single-maintainer; pair its output with the deterministic gates (`/al-build`, CodeCop/AppSourceCop) and never make a gate depend on it alone. When a call returns nothing useful, check the source for the handler shape before concluding the tool is broken.
