# bc-knowledge dispatch

> **Runtime gate.** Content inside `<claude-only>...</claude-only>` blocks applies only to Claude Code (which has an `advisor()` tool). Codex and other runtimes without it: skip the block contents and move on.

How to consume the `bc-knowledge` MCP for AL/Business Central review and refactor. Read by `/al-refactor` (structural anti-patterns, light touch) and `/al-code-review` (in-depth, multi-specialist). The MCP is knowledge plumbing: it surfaces topics; the calling skill applies them.

## The misread that wastes the tool

Treating `ask_bc_expert` as an autonomous reviewer returns vacuous output. The tool is a **persona router plus a context-aware topic recommender**. It does not do server-side LLM inference. The calling skill (the agent reading this) is the reviewer; the MCP supplies role priming and a ranked list of relevant knowledge topics. Apply the topics to the code yourself.

**Why this matters.** A skill that calls `ask_bc_expert(autonomous_mode=true)` reads the empty `steps: []` and concludes the MCP is broken. It is not. `autonomous_mode=false` returns the persona body + `RECOMMENDED TOPICS` block with relevance scores. The topics are the value.

## Call pattern

Per file under review:

1. **`ask_bc_expert`** with:
   - `question`: BC-specific, names the concern in BC vocabulary (not "review this code", but "find performance pitfalls in this persisted-graph DFS over Rule Set Entries").
   - `context`: the file content (or the relevant procedures if the file is large; ~10 KB is comfortable, the relevance engine pattern-matches against the code).
   - `preferred_specialist`: from the mapping below; one per call, several calls if the file warrants multiple lenses.
   - `autonomous_mode`: **`false`**. Always.

2. Read the response. Extract the `RECOMMENDED TOPICS` list with relevance scores.

3. **`get_bc_topic`** per topic above the threshold (see "Thresholds" below). The response carries the full rule markdown, AL code samples (correct + incorrect patterns), `anti_pattern_indicators`, and a `finding_template`.

4. **Apply the rule yourself.** Pattern-match each `anti_pattern_indicator` against the file. Where the indicator matches, emit a finding using the topic's `finding_template` shape, citing the topic id as the source.

5. **Vanilla pass alongside.** The MCP is the BC-specific lens; a vanilla review pass on the same file catches generic refactor wins the MCP misses (memoize a DFS, dedupe a duplicate procedure, drop a dead parameter). Both passes, then dedupe.

**Topic caching within a single review run.** The topic universe is small; the same `setloadfields-placement-before-filters` will keep surfacing across files. The agent may cache `get_bc_topic` responses within one `/al-code-review` or `/al-refactor` invocation and reuse them. Across invocations, fetch fresh; topic content may change.

## Specialist mapping

| File type | Primary specialist | Secondary (when relevant) |
|---|---|---|
| Codeunit | `roger-reviewer` (code quality & standards) | `dean-debug` (performance), `eva-errors` (when error paths touched), `seth-security` (when permission / temporary tables touched) |
| Page | `uma-ux` (UX) | `seth-security` (when actions / pages with sensitive data) |
| Table | `alex-architect` (solution design) | `seth-security` (when new field with sensitive data), `dean-debug` (when key changes / FlowField changes) |
| PermissionSet | `seth-security` | none |
| Interface | `alex-architect` | `jordan-bridge` (event / integration design) |
| Enum | `alex-architect` | none |
| Subscribers codeunit | `jordan-bridge` (event-driven) | `roger-reviewer` |
| Report / Query / XmlPort | `roger-reviewer` (fallback) | `dean-debug` (when query/report scans large) |
| Test codeunit | `quinn-tester` | none |

**Why this mapping.** Specialists are persona priming with different topic weights baked into the relevance engine. `dean-debug` weights performance topics highly; `seth-security` weights permission and data-protection topics; `quinn-tester` weights test-design topics. Picking the wrong specialist on a file biases topic recommendations toward the wrong domain. The mapping above selects by the dominant concern of each object type.

**Known limitation.** Only the Codeunit mapping (`roger-reviewer` + `dean-debug`) is empirically verified against real code. The other file-type rows are plausible defaults derived from each specialist's stated expertise; the first real per-feature `/al-code-review` run touching Pages, Tables, PermissionSets, Subscribers codeunits, and Interfaces should refine these mappings and fold corrections back into this table.

## Thresholds

| Calling skill | Threshold | Why |
|---|---|---|
| `/al-refactor` | `relevance >= 70` | Refactor runs every TDD cycle. High bar keeps the MCP cost down and constrains findings to structural anti-patterns the agent should fix in the same pass. |
| `/al-code-review` (per-task) | `relevance >= 50` | Gate runs once per task; can afford the broader sweep. Catches BC-specific concerns refactor's high bar skipped. |
| `/al-code-review` (per-feature) | `relevance >= 50` plus cross-file checks | End-of-spec gate; widest net. Cross-file checks (perm set vs new table field, publisher vs subscriber signature, AppSource public-surface additions) are this mode's responsibility, not single-file MCP calls. |

Adjust per call when context demands. The threshold is a default, not a contract.

## What the MCP catches that vanilla Claude misses

BC-specific execution-order and platform-cost knowledge. Examples surfaced in evaluation:

- **SetLoadFields placement.** BC executes `SetLoadFields → filter → query`. SetLoadFields after `SetRange` / `SetFilter` is syntactically valid and the optimization benefit is lost. Vanilla Claude reads it as a valid call and moves on. Topic `dean-debug/setloadfields-placement-before-filters` names it.
- **Lonely repeat patterns** (`repeat...until` with no `Find` before). Tool flags structural inconsistency that vanilla pattern-matching skips.
- **SingleInstance subscriber memory model.** Subscriber codeunits with `SingleInstance = true` persist state across the session; pattern that produces leaks vanilla Claude does not connect to subscriber lifecycle.
- **DeleteAll vs iterate.** Performance vs business-logic-compliance tradeoff that vanilla Claude treats as a style choice.

These are the kind of findings the MCP earns its place for. Refactor wins (memoize, dedupe, dead-param, guard-before-recurse) vanilla Claude catches; do not pay MCP cost on those.

## What the MCP does NOT do

- **Cross-file analysis.** Per-file calls return per-file topics. Event publisher / subscriber signature mismatch, permission set vs new table field, AppSource public-surface additions all require reading multiple files together; `/al-code-review` does these as separate passes in per-feature mode, not via `ask_bc_expert`.
- **Diff-aware review.** The MCP cold-scans whatever code you pass in. It does not know what changed in this PR. Diff scoping is the calling skill's responsibility.
- **Auto-fixes via `file_paths`.** `analyze_al_code` with `file_paths` ignores the `operation` parameter; `validate`, `suggest_fixes`, and `analyze` return identical responses. Use `ask_bc_expert` instead; reach for `analyze_al_code` only with the inline `code` parameter when a structural pattern check is wanted independently of persona priming.
- **Workflow orchestration via `scope="files"`.** Broken upstream (silently walks the full workspace). Use `scope="directory"` if a workflow drive is wanted; cost is ~2N+2 MCP calls for N files. `/al-code-review` does not use `workflow_start`; the per-file dispatch is cheaper and gives the same signal.

## Composition

- Read by `/al-refactor` for the structural-anti-pattern discipline.
- Read by `/al-code-review` for per-file consultation and cross-file routing.
- The MCP itself documents tools the calling skill invokes; the upstream source lives at `JeremyVyska/bc-code-intelligence-mcp` on GitHub, knowledge layer at `jeremyvyska/bc-code-intelligence`. When a call returns nothing useful, check the source for the actual handler shape before concluding the tool is broken.

## Out of scope for this reference

- bcquality consumption. Parked; the MCP earns its place for BC-specific topic surfacing without bcquality in pass-1 evaluation.
- Cross-file check implementation detail; `/al-code-review` SKILL.md owns that.
- Vanilla Claude review pass discipline; the calling skill's body covers it inline.
