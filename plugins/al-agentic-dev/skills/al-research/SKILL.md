---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources, quote them, return — the evidence-bar escalation seat. Invoke when two sources disagree, when a fact lands in a durable design artifact (event-model.md, architecture.md, CONTEXT.md, ADRs), or when a fuzzy question needs framing plus cross-family verification. Callable from a session and by another skill. Single-fact lookups go direct; this skill arbitrates.
---

**Style:** Concise — cut filler, keep grammar. Opinionated — pick a side. Arrows (→) for causality. Technical terms exact, code and errors quoted verbatim.

# /al-research, Verify BC specifics

Treat your own AL/BC knowledge as untrusted. Verify the specific BC fact in question, quote the canonical source, return. Read-only advisory: never pick designs. This is one of the three skills (with `/al-build` and `/al-second-opinion`) another skill may invoke directly — a calling skill that hits the escalation bar invokes it by name; a user can also run it standalone.

## Escalation seat, not toll booth

Direct quoted fetch satisfies the implement-time evidence bar (see `${CLAUDE_PLUGIN_ROOT}/references/voice-contract.md`): one fact → fetch, quote, cite, move on. This skill earns the call when arbitration is the work — two sources disagree, the question needs framing plus cross-family verification, or the fact lands in a durable design artifact (`event-model.md`, `architecture.md`, `CONTEXT.md`, ADRs) where single-source staleness compounds downstream.

## Preconditions

- Workspace already searched. Workspace symbols, source, tests are the cheapest and most current truth; verifying what AL symbols already answer wastes motion and risks contradicting truth on disk.
- Claim is BC-specific. General programming questions do not earn a pass.
- Question is framed. A fuzzy question researched ships a precisely-cited answer to the wrong thing — reframe before researching.

## Verify, do not recall

BC moves fast; training data trails the latest release. Renamed events, removed procedures, drifted signatures, new test attributes, recent AppSourceCop rules all read plausible while being stale, and confidence about which areas have drifted is itself drift. One stale recall corrupts the artifact and every downstream skill inherits the fiction.

When the question is "does this signature exist in my dependency graph", the workspace's compiled symbols are the truth, not the docs — shipped libraries publish many overloads per release, and binding to the wrong one fails the build.

Single source is a draft, two families is verification. Cross against a second source from a different family before returning a finding; agreement across families is the verification, picked by question shape.

## Quote, do not paraphrase

Every behavioural claim returns with a verbatim symbol, signature, attribute value, or text plus a one-line citation (source path, symbol name, topic id, URL). "Sales posting validates blocked customers" is useless; `Cust.TestField(Blocked, Cust.Blocked::" ")` inside `Codeunit 80 "Sales-Post".OnRun → CheckCustomerBlockage` is actionable, falsifiable, copy-pasteable into a test.

Hedges (`might`, `probably`, `usually`) tell that a claim is unverified. Either verify and quote, or drop.

## Topic recommender

Curated BC knowledge tools recommend relevance-ranked topics; they do not answer for you. Fetch each on-domain topic, apply its anti-pattern indicators yourself. Call pattern, noise drop-list, and the mandatory `set_workspace_info` init: `${CLAUDE_PLUGIN_ROOT}/references/bc-code-intelligence-dispatch.md`, read before invoking `find_bc_knowledge` or `analyze_al_code`.

## Sources

Reach for whichever answers the specific question.

- **Microsoft Learn** via web fetch and search (or the Microsoft Learn MCP): canonical Microsoft docs for AL platform constructs (attributes, properties, triggers, page types, APIs, AppSourceCop rules, version-tagged behaviour).
- **bc-code-intelligence MCP**: curated BC pattern topic recommender; cold on platform spec, pair with Microsoft Learn for anything spec-shaped. Governed by the topic-recommender discipline above.
- **bc-standard-reference**: reach for it when the question is "what does Microsoft's shipped AL code actually do" — it isolates the BaseApp / System Application / APIV2 mirror search off your thread.
- **AL symbols** via `al-symbols-mcp` and **LSP**: the workspace's compiled dependency graph — actual signatures, table relations, field types, extension graphs, callsites, definitions.
- **Workspace grep**: comments, TODO markers, string literals (including handler name strings the compiler doesn't rename).
- **Web search**: last resort for non-Learn content; rots fast, cross-check against an authoritative source before quoting.

**Graceful degradation.** MCP servers may be absent in a consumer session — those calls simply have no effect. Fall back to Microsoft Learn for constructs and bc-standard-reference for names. Never block on a missing server.

## Stop at actionable, surface conflicts

Stop the moment the caller has what they need to act; one question per pass.

When two authoritative sources disagree (Microsoft Learn says one signature, workspace symbols show another), surface both with citations and name the conflict. Silently picking hides it from the caller, who has the architectural context to choose.

## Output

A findings note: verbatim quotes, one-line citations, no editorialising. Citations live in the note, never inline into durable artifacts — the caller decides what survives and lands task-scoped citations as `Contract notes` bullets per the evidence bar. When two sources agree, name both (`Microsoft Learn <page> + al-symbols-mcp <object>.<procedure> agree on <signature>`); when they disagree, return both quotes and name the conflict.

## Next step

Hand the findings note back to whatever needed the fact. **Invoked by another skill** → return the note; the caller lands any `Contract notes` bullet. **Run standalone** → `Next:` the skill that owns the artifact the fact feeds — `/al-design` or `/al-event-model` for a design fact, `/al-refine` or `/al-implement` for an implementation fact, `/al-grill-adr` for a CONTEXT/ADR fact. If a conflict was surfaced and the choice is architectural, `Next: /al-steer`.
