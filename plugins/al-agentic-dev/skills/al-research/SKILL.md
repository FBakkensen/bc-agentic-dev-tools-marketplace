---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources before acting in /al-design, /al-grill-adr, /al-implement, /al-refactor, /al-refine. Use when prior AL/BC knowledge is unverified and the workspace itself doesn't answer, training data is thin and stale; verify before trusting it.
---

# /al-research, Verify BC specifics

Treat your own AL/BC knowledge as untrusted. Verify the specific BC fact the caller is about to lean on, quote the canonical source, and return. `/al-research` answers what the codebase cannot.

This skill is a side-band, called from `/al-design`, `/al-grill-adr`, `/al-implement`, `/al-refactor`, `/al-refine`. Never standalone as a workflow.

## Preconditions

- The caller has already looked in the workspace. The workspace is the cheapest, most current source for anything that lives in this repo or its dependencies; verifying a fact `/al-research` could read from `AL symbols` is wasted motion and risks contradicting the truth on disk.
- The claim is BC-specific. AL syntax, BaseApp behaviour, event signatures, posting flows, install/upgrade contracts, AppSource gates, dimension propagation, permission inheritance, RDLC conventions. General programming questions don't earn a research pass.

## Disciplines

### Verify, don't recall

Treat training data as suspect for any BC version-specific behaviour, event signature, table field, posting routine, or AppSource rule. **Why**: BC moves fast and the training cutoff is always behind a recent release. Confidently wrong is the failure mode; renamed events, removed procedures, drifted signatures all read plausible. One stale recall corrupts the artifact (`architecture.html`, a Gherkin assertion, a refactor seam) and every downstream skill inherits the fiction.

### Workspace first, authoritative second

When the answer could live in the workspace (an AL symbol, a dependency `.app`, a referenced procedure), look there before reaching outward. **Why**: the workspace is the only source guaranteed to match the user's current BC version, dependency graph, and extension shape. Going to Microsoft Learn for a procedure that lives in the workspace's `AL packages` retrieves a generic answer when a specific one is on disk.

### Quote, don't paraphrase

Every behavioural claim returns with the verbatim symbol, signature, or text and a one-line citation (source path, symbol name, or URL). **Why**: paraphrase loses the load-bearing detail. "Sales posting validates blocked customers" is useless; `Cust.TestField(Blocked, Cust.Blocked::" ")` inside `Codeunit 80 "Sales-Post".OnRun → CheckCustomerBlockage` is actionable, falsifiable, and copy-pasteable into a test.

### Stop at actionable

The moment the caller has what they need to act, stop. Don't keep browsing for context, don't gather adjacent facts the caller didn't ask for. **Why**: a research pass that returns ten findings when the caller needed one buries the actionable line and invites the caller to skim. Scope is one question per pass; parallel passes for independent questions when the host supports subagents.

### Surface conflicts, don't pick

When two authoritative sources disagree (Learn says one signature, BaseApp source shows another), surface both with citations. **Why**: silently picking one hides the conflict from the caller, who is the one with the architectural context to choose. The research pass doesn't know which version of BC the user is targeting or which compatibility line the design draws.

### Hedging is not a finding

"Might", "I think", "probably", "usually" are tells that the claim is unverified. Either verify it and quote, or drop it. **Why**: a hedged finding looks like research but ships training-data fiction with a citation-shaped wrapper. The caller can't distinguish a hedged finding from a quoted one until it fails in `/al-implement`.

## Authoritative sources

Reach for whichever source answers the specific question. None is universally first; the question's shape decides.

- **AL symbols**, including the available AL symbol lookup, dependency metadata, and language-server-backed search. The workspace's own symbols, including dependency `.app` contents the caller cannot open directly.
- **`/bc-standard-reference`**. BaseApp, System Application, APIV2 canonical behaviour. The right reach when the question is "what does Microsoft's shipped code do."
- **BC knowledge**, via the available BC knowledge source or expert reference. Conceptual guidance, dimension propagation, install/upgrade contracts, AppSource gates, permission inheritance, RDLC convention.
- **Microsoft Learn**, via the available Learn search and fetch tools. Official, version-current MS docs. Right for external integration contracts and concept-level documentation.
- **Context7** or equivalent library docs. External non-AL library / framework / SDK docs. Rare for AL.
- **Web search.** Last resort. AL/BC web content rots fast; treat with suspicion and cross-check against an authoritative source before quoting.

## Output

A findings note to the caller. Verbatim quotes, one-line citations, no editorialising. No code edits, no `tasks.html` edits, no durable artifact writes; the caller decides what survives into `architecture.html`, `CONTEXT.md`, ADRs, or task scaffolding. Citations live in the return note, never inline into durable artifacts. Names are the citation.

## Composition

- Called from `/al-design`, `/al-grill-adr`, `/al-implement`, `/al-refactor`, `/al-refine`. Never standalone.
- `/bc-standard-reference` is reachable directly when the question is purely BaseApp behaviour.
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
