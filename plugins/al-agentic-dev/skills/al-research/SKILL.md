---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources before acting in /al-design, /al-grill-adr, /al-implement, /al-refactor, /al-refine. Use when prior AL/BC knowledge is unverified and the workspace itself doesn't answer; training data is thin and stale; verify before trusting it.
---

# /al-research, Verify BC specifics

Treat your own AL/BC knowledge as untrusted. Verify the specific BC fact the caller is about to lean on, quote the canonical source, and return. `/al-research` answers what the codebase cannot.

Read-only. Never writes AL, never edits artifacts, never picks designs. The caller writes; this skill ensures what the caller writes is grounded.

This skill is side-band, called from `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-implement`, `/al-refactor`, `/al-refine`. Never standalone as a workflow.

## Preconditions

- The caller has already looked in the workspace. The workspace is the cheapest, most current source for anything that lives in this repo or its dependencies. Verifying a fact `/al-research` could read from AL symbols is wasted motion and risks contradicting the truth on disk.
- The claim is BC-specific. AL syntax, BaseApp behaviour, event signatures, table fields, posting flows, install/upgrade contracts, AppSource gates, AI/Copilot capabilities, dimension propagation, permission inheritance, RDLC conventions. General programming questions don't earn a research pass.

## Disciplines

### Verify, don't recall

Treat training data as suspect for any BC version-specific behaviour, event signature, table field, posting routine, attribute default, Copilot capability, or AppSource rule. **Why**: BC moves fast and the training cutoff is always behind a recent release. Confidently wrong is the failure mode; renamed events, removed procedures, drifted signatures, new test attributes, recent AppSourceCop rules all read plausible. One stale recall corrupts the artifact (`architecture.html`, a Gherkin assertion, a refactor seam) and every downstream skill inherits the fiction.

### Workspace symbols are the version anchor

When the question is "does this signature exist in my dependency graph", the workspace's compiled symbols are the truth, not the docs. **Why**: System Application, Base Application, and shipped libraries publish many overloads per release. Microsoft Learn describes the platform shape; your `.alpackages` carry whichever overloads compile against your project today. The doc shows one signature, the symbol shows five; binding to the wrong one fails the build.

### Cross-source on versioned or recent claims

Recent runtime features, new platform attributes, AI/Copilot APIs, AppSourceCop rule additions, last-two-release behaviour: single-source is not enough. Verify against at least two of (Microsoft Learn / BaseApp source / workspace symbols / curated BC topic). **Why**: training data shapes confidently-wrong claims; the second source from a different family catches drift before it lands in a durable artifact. Agreement across sources is the verification.

### Quote, don't paraphrase

Every behavioural claim returns with the verbatim symbol, signature, attribute value, or text plus a one-line citation (source path, symbol name, topic id, or URL). **Why**: paraphrase loses the load-bearing detail. "Sales posting validates blocked customers" is useless; `Cust.TestField(Blocked, Cust.Blocked::" ")` inside `Codeunit 80 "Sales-Post".OnRun → CheckCustomerBlockage` is actionable, falsifiable, copy-pasteable into a test.

### Topic recommender, not Q&A

Curated BC knowledge tools are topic recommenders, not question-answer engines. They pattern-match constructs in code against a curated topic store and return a relevance-ranked list. The topic list is the research value; the persona body, generic issue list, and optimisation-opportunity list around it are scaffolding and noise. **Why**: treating a topic recommender as a Q&A oracle reads the wrong layer and dismisses the right one. The call shape that returns useful topics passes the file content (or its absolute path) and a mapped specialist; the response carries a `RECOMMENDED TOPICS` / `suggested_topics` block. Fetch each topic above the caller's relevance bar and apply its anti-pattern indicators against the code yourself. Persona text, low-severity "continue following this pattern" issues, and generic optimisation suggestions get dropped.

**Relevance score is not topicality.** The topic's subject must match the question being verified. Off-domain topics (AI-collaboration methodology, tool-recommendation knowledge, generic developer-workflow advice) pattern-match on common AL constructs (`SetRange`, `FindFirst`, `repeat`, `Insert`) and surface high regardless. Their score is real; their subject mismatching the caller's question is the cue to drop them before reaching `get_bc_topic`. **Why**: relevance-as-pattern-match catches "this code uses these constructs"; it doesn't catch "this topic answers the question I'm verifying". The caller is the only one who can judge subject-match against intent.

The call pattern is defined in `${CLAUDE_SKILL_DIR}/../../references/bc-knowledge-dispatch.md`. Read it before calling.

### Stop at actionable

The moment the caller has what they need to act, stop. Don't keep browsing for context, don't gather adjacent facts the caller didn't ask for. **Why**: a research pass that returns ten findings when the caller needed one buries the actionable line and invites the caller to skim. Scope is one question per pass; parallel passes for independent questions when the host supports subagents.

### Surface conflicts, don't pick

When two authoritative sources disagree (Microsoft Learn says one signature, workspace symbols show another), surface both with citations. **Why**: silently picking one hides the conflict from the caller, who has the architectural context to choose. The research pass doesn't know which version of BC the user targets or which compatibility line the design draws.

### Hedging is not a finding

"Might", "I think", "probably", "usually" are tells that the claim is unverified. Either verify and quote, or drop. **Why**: a hedged finding looks like research but ships training-data fiction with a citation-shaped wrapper. The caller cannot distinguish a hedged finding from a quoted one until it fails in `/al-implement`.

## Source purposes

What each source family IS for, stable across release cycles. Reach for whichever answers the specific question; none is universally first. Specific topic IDs, current query patterns, and present-day failure modes belong in the bootstrap hook (refreshable cache), not here.

- **Microsoft Learn**, via the available Learn search and fetch tools. Canonical Microsoft documentation for AL platform constructs: attributes, properties, methods, triggers, page types, APIs, AppSourceCop rules, version-tagged behaviour. Reach when the question is "what does Microsoft's platform document".
- **bc-knowledge MCP**, the curated BC pattern topic store. Returns relevance-ranked topic recommendations from code constructs; each topic carries attributed AL samples, anti-pattern indicators, and finding templates. Reach when the question is "what's a well-known pattern for X in BC". The topic-recommender discipline above governs how to read its output. Cold on platform spec; pair with Microsoft Learn for anything spec-shaped.
- **`/bc-standard-reference`**, the BaseApp / System Application / APIV2 verbatim source skill. Reach when the question is "what does Microsoft's shipped AL code actually do" and a quote of the canonical implementation is wanted.
- **AL symbols** (the available `al-symbols-mcp` tools and AL Language Server). The workspace's compiled dependency graph: actual signatures, table relations, field types, extension graphs. Reach when the question is "what does my project currently compile against" (signatures, overloads, members of a System Application codeunit your dependencies pull in).
- **LSP** (the available LSP tool over AL). Your code's procedure callsites, definitions, hover info. Reach when the question is "where in *my* code is this used" inside a single AL project.
- **Workspace grep**, comments, TODO/SCENARIO markers, string literals (including handler name strings that the compiler doesn't rename). Reach when the question is "is this text anywhere in my project".
- **Context7** or equivalent library docs. External non-AL library / framework / SDK docs. Rare for AL.
- **Web search.** Last resort. AL/BC web content rots fast; treat with suspicion and cross-check against an authoritative source before quoting.

## Output

A findings note to the caller. Verbatim quotes, one-line citations, no editorialising. No code edits, no `tasks.html` edits, no durable artifact writes; the caller decides what survives into `architecture.html`, `CONTEXT.md`, ADRs, or task scaffolding. Citations live in the return note, never inline into durable artifacts. Names are the citation.

When the answer rests on two sources agreeing, name both in the citation: `Microsoft Learn <page> + al-symbols-mcp <object>.<procedure> agree on <signature>`. When two authoritative sources disagree, return both quotes with their citations and name the conflict; the caller resolves.

## Composition

- Called from `/al-design`, `/al-grill-adr`, `/al-event-model`, `/al-implement`, `/al-refactor`, `/al-refine`. Never standalone.
- `/bc-standard-reference` is reachable directly when the question is purely BaseApp verbatim.
- `${CLAUDE_SKILL_DIR}/../../references/bc-knowledge-dispatch.md` defines the bc-knowledge MCP call pattern, specialist mapping, relevance thresholds per calling skill. Read before invoking `ask_bc_expert` or `analyze_al_code`.
- `/grill-me` when the research question itself is unclear and needs framing before any source is worth consulting.

## Naming and BC vocabulary

- **BC verbs.** Insert / Modify / Delete (records). Post (not Submit). Validate (not Check). Get / Find (not Fetch). Ledger Entry (not Transaction). No. (not ID). Procedure (not Method).
- **Objects.** `"Prefix Feature Suffix"`, suffixes `Impl`, `Card`, `List`, `Ext`, `Test`.
- **Events.** `OnBefore{Action}{Object}`, `OnAfter{Action}{Object}`.

Use BC vocabulary in findings; a citation that renames `Insert` to `Create` corrupts every artifact downstream.

## Out of scope

- No code edits, no test edits, no `tasks.html` edits, no ADR writes, no `CONTEXT.md` edits.
- No design picks (`/al-design`), no grilling (`/al-grill-adr`, `/grill-me`), no scope decisions (`/al-scope`).
- No browsing for context. Research is scoped, returns when actionable.
- No empirical probes, no AL code generation. `/al-research` reads sources; it does not write probe codeunits or run tests. If a claim cannot be verified from sources, surface the gap; the caller decides whether to write a probe themselves under their own skill.
