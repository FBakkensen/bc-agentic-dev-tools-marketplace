---
name: bc-standard-reference
description: "Locate canonical Business Central Standard behavior (BaseApp, System Application, APIV2, etc.) to identify events, event publishers, codeunits, tables/fields, tests, pages, APIs, etc. Use when you need standard behavior, event signatures, or reference implementation patterns."
---

**Voice:** caveman. Drop articles, filler, hedging. Fragments OK. Arrows for causality. Technical terms exact, code unchanged, errors quoted exact.

**Carve-outs:** drop caveman for confirm-before-destroy, user dialog turns (questions / grill rounds), numbered user-action steps, Stop block reason line.

# /bc-standard-reference — Canonical BaseApp lookup

Go to canonical mirror. Quote, don't paraphrase. Return file path, object name + ID, event signature, hook point — never vague summary.

Mirror is `fbakkensen/bc-w1` — BaseApp, System Application, APIV2, ExternalEvents, test framework. Source #2 in `/al-research`'s priority table.

## When to use

| Question | What you want back |
|---|---|
| What events fire when posting a sales order? | Event publisher list with signatures + file paths in `Sales/Posting`. |
| How does BC calculate line discounts? | Codeunit name + ID, procedure that holds the logic, events around it. |
| How do standard tests set up sales documents? | Library codeunit name + helper procedure signature. |
| How does APIV2 expose customers? | API page name + ID + exposed fields. |
| Where are field X's triggers / validations? | Table name + ID + field declaration with trigger code. |
| Which codeunit holds release logic for sales documents? | Codeunit name + ID + `OnBefore`/`OnAfter` events it publishes. |

Workspace itself answers → read it directly. Stop. This skill is for behaviour the workspace doesn't own.

## Procedure

Tool-agnostic. Use whatever symbol-discovery, repo-search, or browse method you have — MCP server, dependency metadata, raw grep, web UI. _Avoid_: prescribing one tool as the only path.

1. **Identify** — name codeunit, table, page, or event you're after. Use known object/event names where possible. Symbol metadata, dependency packages, or quick `/al-research` hit at source #1 narrows target before you search the mirror.
2. **Search the mirror** — query `fbakkensen/bc-w1` by object/event name, narrow by domain path (`Sales/Posting`, `Pricing`, `Inventory`). Goal: exact file that declares the object or publishes the event.
3. **Inspect** — open the file. Confirm declaration (name + ID), event signature, surrounding flow. Don't trust a name match without reading declaration.
4. **Cross-check** — official Microsoft Learn docs for AL syntax, BC concepts, version-current behaviour. _Avoid_: trusting training data on BC version specifics → verify against mirror or Learn.

**Anti-pattern: prescribe specific MCP server.** Procedure is tool-agnostic. Cite tools by name only as examples; describe search heuristic.

## Findings cadence

Per finding, return:

- **File path** in the mirror.
- **Object name + ID** (e.g., `codeunit 80 "Sales-Post"`).
- **Event signature** verbatim (parameters, modifiers, attribute).
- **Hook point or reference pattern** — event/seam to use, or procedure to mirror.
- **One-line citation** — repo path or symbol address.

_Avoid_: paraphrasing docs, vague summaries, or naming a source without quoting its content.

**Anti-pattern: paraphrase finding without quoting.** Behavioural claims carry verbatim signature. Can't quote it → didn't read it.

**Anti-pattern: source name, not source content.** *"It's in `Sales-Post`"* is not a finding. Quote the line. Cite the declaration.

**No:** *"Found pricing logic in `Sales/Pricing`."*
**Yes:** *"`codeunit 7002 \"Sales Line - Price\"` at `BaseApp/Source/Base Application/Sales/Pricing/SalesLinePrice.Codeunit.al` publishes the `OnAfter…` events used by V16 calculation; subscribe at the post-calc seam."*

## Subagent dispatch

For open-ended questions, spawn subagent with focused brief:

```
Search the standard mirror `fbakkensen/bc-w1` for [topic].
Return: file path, object name + ID, event signature, hook point.
Quote source content, don't paraphrase. Tool-agnostic — use whatever search you have.
```

## Composition

`/al-research` lists this skill as source #2 — reachable directly when question is purely BaseApp / System Application / APIV2 behaviour. For BC concepts and patterns rather than specific source location → route to available BC knowledge source. For AL syntax and version-current Microsoft docs → route to Microsoft Learn.

Detail in:

- `references/repo-structure.md` — folder layout and key paths.
- `references/search-patterns.md` — search heuristics by object kind.
- `references/scenarios.md` — walkthroughs for common questions.

## Out of scope

- No code edits, no test edits, no durable artifact writes.
- No design picks → which event to subscribe to, where to seam, what pattern to apply belongs to `/al-design` and `/al-implement`.
- No grilling on intent → `/al-grill-adr` and `/grill-me`.
