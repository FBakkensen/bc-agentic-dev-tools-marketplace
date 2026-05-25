---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources, quote them, return. Use when prior AL/BC knowledge is unverified, the workspace itself does not answer, and a downstream skill (`/al-design`, `/al-grill-adr`, `/al-implement`, `/al-refactor`, `/al-refine`) is about to lean on the fact.
---

# /al-research, Verify BC specifics

Treat your own AL/BC knowledge as untrusted. Verify the specific BC fact the caller leans on, quote the canonical source, return. Read-only: never writes AL, never edits artifacts, never picks designs. Side-band only, never standalone.

## Preconditions

- The caller has already looked in the workspace. Workspace symbols, source, and tests are the cheapest and most current truth for anything in the repo or its dependencies; verifying what AL symbols already answer wastes motion and risks contradicting the truth on disk.
- The claim is BC-specific: AL syntax, BaseApp behaviour, event signatures, table fields, posting flows, install/upgrade contracts, AppSource gates, AI/Copilot capabilities, dimension propagation, permission inheritance, RDLC conventions. General programming questions do not earn a pass.
- The question is framed. If the question itself is fuzzy, frame it with `/grill-me` first; research a fuzzy question and you ship a precisely-cited answer to the wrong thing.

## Verify, do not recall

BC moves fast and training data is always behind a recent release: renamed events, removed procedures, drifted signatures, new test attributes, recent AppSourceCop rules all read plausible. One stale recall corrupts the artifact (`architecture.html`, a Gherkin assertion, a refactor seam) and every downstream skill inherits the fiction.

When the question is "does this signature exist in my dependency graph", the workspace's compiled symbols are the truth, not the docs. System Application, Base Application, and shipped libraries publish many overloads per release; the doc shows one signature, the symbol shows five, binding to the wrong one fails the build.

Single source is a draft, two families is verification. BC ships across release cadences and "old and stable" is your guess, not a fact; the agent's confidence about which areas have drifted is itself drift. Cross against a second source from a different family before returning a finding: Microsoft Learn, BaseApp via `/bc-standard-reference`, workspace symbols via `al-symbols-mcp`, curated BC topics via `bc-knowledge`. Agreement across families is the verification; pick which two by question shape. A single-source finding ships training-data fiction with a citation-shaped wrapper.

## Quote, do not paraphrase

Every behavioural claim returns with the verbatim symbol, signature, attribute value, or text plus a one-line citation (source path, symbol name, topic id, URL). "Sales posting validates blocked customers" is useless; `Cust.TestField(Blocked, Cust.Blocked::" ")` inside `Codeunit 80 "Sales-Post".OnRun → CheckCustomerBlockage` is actionable, falsifiable, copy-pasteable into a test.

Hedges (`might`, `I think`, `probably`, `usually`) are tells that the claim is unverified. Either verify and quote, or drop. A hedged finding looks like research but ships training-data fiction with a citation-shaped wrapper.

## Topic recommender, not Q&A

Curated BC knowledge tools pattern-match constructs in code against a topic store and return a relevance-ranked list. The topic list is the research value; persona body, generic issue lists, optimisation-opportunity lists around it are scaffolding. The call shape that returns useful topics passes file content (or absolute path) and a mapped specialist; the response carries a `RECOMMENDED TOPICS` / `suggested_topics` block. Fetch each topic above the caller's relevance bar and apply its anti-pattern indicators yourself.

Relevance score is not topicality. Off-domain topics (AI-collaboration methodology, tool-recommendation knowledge, generic workflow advice) pattern-match on common AL constructs (`SetRange`, `FindFirst`, `repeat`, `Insert`) and surface high regardless. The score is real; subject-mismatch against the caller's question is the cue to drop before reaching `get_bc_topic`.

Call pattern: `${CLAUDE_SKILL_DIR}/../../references/bc-knowledge-dispatch.md`. Read before invoking `ask_bc_expert` or `analyze_al_code`.

## Stop at actionable, surface conflicts

The moment the caller has what they need to act, stop. A pass that returns ten findings when one was needed buries the actionable line. Scope is one question per pass; parallel passes for independent questions when the host supports subagents.

When two authoritative sources disagree (Microsoft Learn says one signature, workspace symbols show another), surface both with citations and name the conflict. Silently picking hides it from the caller, who has the architectural context to choose.

## Sources

What each source family is for, reach for whichever answers the specific question.

- **Microsoft Learn** via the Learn search and fetch tools: canonical Microsoft documentation for AL platform constructs (attributes, properties, methods, triggers, page types, APIs, AppSourceCop rules, version-tagged behaviour).
- **bc-knowledge MCP**: curated BC pattern topic store. Topic recommender; cold on platform spec, pair with Microsoft Learn for anything spec-shaped. Governed by the topic-recommender discipline above.
- **`/bc-standard-reference`**: BaseApp / System Application / APIV2 verbatim source. Reach when the question is "what does Microsoft's shipped AL code actually do".
- **AL symbols** via `al-symbols-mcp` and AL Language Server: workspace's compiled dependency graph (actual signatures, table relations, field types, extension graphs).
- **LSP** over AL: your code's procedure callsites, definitions, hover info inside a single project.
- **Workspace grep**: comments, TODO markers, string literals (including handler name strings the compiler doesn't rename).
- **Context7** or equivalent: external non-AL library / framework / SDK docs. Rare for AL.
- **Web search**: last resort. AL/BC web content rots fast; cross-check against an authoritative source before quoting.

## Output

A findings note to the caller. Verbatim quotes, one-line citations, no editorialising. Citations live in the return note, never inline into durable artifacts (the caller decides what survives into `architecture.html`, `CONTEXT.md`, ADRs, or task scaffolding). When two sources agree, name both: `Microsoft Learn <page> + al-symbols-mcp <object>.<procedure> agree on <signature>`. When two disagree, return both quotes with citations and name the conflict; the caller resolves.

## Composition

| | |
|---|---|
| **Invoked from**     | `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-implement`, `/al-refactor`, `/al-refine` |
| **Returns to caller** | citation list (chat-bound) |
