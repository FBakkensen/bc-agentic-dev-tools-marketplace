---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources, quote them, return. Use when prior AL/BC knowledge is unverified, the workspace itself does not answer, and a downstream skill (`/al-design`, `/al-grill-adr`, `/al-implement`, `/al-refactor`, `/al-refine`) is about to lean on the fact.
---

**Style:** Be extremely concise. Sacrifice grammar for concision. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-research, Verify BC specifics

Treat your own AL/BC knowledge as untrusted. Verify the specific BC fact the caller leans on, quote the canonical source, return. Read-only: never writes AL, never edits artifacts, never picks designs. Side-band only, never standalone.

## Preconditions

- Caller already looked in workspace. Workspace symbols, source, tests are the cheapest and most current truth for anything in repo or its dependencies; verifying what AL symbols already answer wastes motion and risks contradicting truth on disk.
- Claim is BC-specific: AL syntax, BaseApp behaviour, event signatures, table fields, posting flows, install/upgrade contracts, AppSource gates, AI/Copilot capabilities, dimension propagation, permission inheritance, RDLC conventions. General programming questions do not earn a pass.
- Question is framed. Fuzzy question → frame via `/grill-me` first; research a fuzzy question → ship precisely-cited answer to wrong thing.

## Verify, do not recall

BC moves fast and training data is always behind a recent release: renamed events, removed procedures, drifted signatures, new test attributes, recent AppSourceCop rules all read plausible. One stale recall corrupts the artifact (`architecture.md`, `Test Specification`, `Verification Plan`, refactor seam) and every downstream skill inherits the fiction.

When question is "does this signature exist in my dependency graph", workspace's compiled symbols are the truth, not the docs. System Application, Base Application, shipped libraries publish many overloads per release; doc shows one signature, symbol shows five, binding to wrong one fails the build.

Single source is a draft, two families is verification. BC ships across release cadences and "old and stable" is your guess, not a fact; agent's confidence about which areas have drifted is itself drift. Cross against a second source from a different family before returning a finding: Microsoft Learn, BaseApp via `/bc-standard-reference`, workspace symbols via `al-symbols-mcp`, curated BC topics via `bc-code-intelligence`. Agreement across families is the verification; pick which two by question shape. Single-source finding ships training-data fiction with citation-shaped wrapper.

## Quote, do not paraphrase

Every behavioural claim returns with verbatim symbol, signature, attribute value, or text plus one-line citation (source path, symbol name, topic id, URL). "Sales posting validates blocked customers" is useless; `Cust.TestField(Blocked, Cust.Blocked::" ")` inside `Codeunit 80 "Sales-Post".OnRun → CheckCustomerBlockage` is actionable, falsifiable, copy-pasteable into a test.

Hedges (`might`, `I think`, `probably`, `usually`) are tells that claim is unverified. Either verify and quote, or drop. Hedged finding looks like research but ships training-data fiction with citation-shaped wrapper.

## Topic recommender, not Q&A

Curated BC knowledge tools pattern-match constructs in code against a topic store and return a relevance-ranked list. Topic list is the research value; generic issue lists and optimisation-opportunity lists around it are scaffolding. Call shape that returns useful topics passes a BC-specific query (or an absolute file path to `analyze_al_code`); response carries a ranked `suggested_topics` / topic block. Fetch each on-domain topic above the caller's relevance bar and apply its anti-pattern indicators yourself.

Relevance score is not topicality. Off-domain topics (AI-collaboration methodology, tool-recommendation knowledge, generic workflow advice) pattern-match on common AL constructs (`SetRange`, `FindFirst`, `repeat`, `Insert`) and surface high regardless. Score is real; subject-mismatch against caller's question is the cue to drop before reaching `get_bc_topic`.

Call pattern: `${CLAUDE_SKILL_DIR}/../../references/bc-code-intelligence-dispatch.md`. Read before invoking `find_bc_knowledge` or `analyze_al_code`; `set_workspace_info` must run once first or every call errors.

## Stop at actionable, surface conflicts

The moment the caller has what they need to act → stop. Pass that returns ten findings when one was needed buries the actionable line. Scope is one question per pass; parallel passes for independent questions when host supports subagents.

When using parallel subagent passes, close each completed subagent thread after its finding is collected and before returning the consolidated answer.

When two authoritative sources disagree (Microsoft Learn says one signature, workspace symbols show another), surface both with citations and name the conflict. Silently picking hides it from caller, who has the architectural context to choose.

## Sources

What each source family is for, reach for whichever answers the specific question.

- **Microsoft Learn** via Learn search and fetch tools: canonical Microsoft documentation for AL platform constructs (attributes, properties, methods, triggers, page types, APIs, AppSourceCop rules, version-tagged behaviour).
- **bc-code-intelligence MCP**: curated BC pattern topic store. Topic recommender; cold on platform spec, pair with Microsoft Learn for anything spec-shaped. Governed by topic-recommender discipline above.
- **`/bc-standard-reference`**: BaseApp / System Application / APIV2 verbatim source. Reach when question is "what does Microsoft's shipped AL code actually do".
- **AL symbols** via `al-symbols-mcp` and AL Language Server: workspace's compiled dependency graph (actual signatures, table relations, field types, extension graphs).
- **LSP** over AL: your code's procedure callsites, definitions, hover info inside a single project.
- **Workspace grep**: comments, TODO markers, string literals (including handler name strings the compiler doesn't rename).
- **Context7** or equivalent: external non-AL library / framework / SDK docs. Rare for AL.
- **Web search**: last resort. AL/BC web content rots fast; cross-check against authoritative source before quoting.

## Output

Findings note to the caller. Verbatim quotes, one-line citations, no editorialising. Citations live in return note, never inline into durable artifacts (caller decides what survives into `architecture.md`, `CONTEXT.md`, ADRs, or task scaffolding). When two sources agree, name both: `Microsoft Learn <page> + al-symbols-mcp <object>.<procedure> agree on <signature>`. When two disagree, return both quotes with citations and name the conflict; caller resolves.

## Composition

| | |
|---|---|
| **Invoked from**     | `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-implement`, `/al-refactor`, `/al-refine` |
| **Returns to caller** | citation list (chat-bound) |
