---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources before acting in /al-design, /al-grill-adr, /al-implement, /al-refactor, /al-refine. Use when prior AL/BC knowledge is unverified and the workspace itself doesn't answer — training data is thin and stale; verify before trusting it.
---

# /al-research — Verify BC specifics

Treat your own AL/BC knowledge as untrusted. Quote the canonical source, return one finding per question, persist nothing. The caller has already searched the workspace — `/al-research` answers what the codebase cannot.

## Precondition

Workspace already explored. If the answer lives in the current repo, the caller reads it directly. Stop.

## Source priority

Top-down. Stop at the first source that answers definitively. Don't browse past a hit. If sources disagree, surface the conflict — do not pick silently.

| # | Source | Tools | Use for |
|---|---|---|---|
| 1 | **AL symbols** | `mcp__al-symbols-mcp__al_search_objects`, `al_get_object_definition`, `al_get_object_summary`, `al_search_object_members`, `al_find_references`, `al_packages` | The workspace's own symbols and dependencies. |
| 2 | **`/bc-standard-reference`** | skill | BaseApp, System Application, APIV2 canonical behaviour. |
| 3 | **bc-knowledge** | `mcp__bc-knowledge__find_bc_knowledge`, `ask_bc_expert`, `get_bc_topic`, `analyze_al_code` | BC concepts and patterns. |
| 4 | **Microsoft Learn** | `mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search` | Official, version-current MS docs. |
| 5 | **context7** | `mcp__context7__resolve-library-id`, `query-docs` | External library / framework / SDK docs. Rare for AL. |
| 6 | **Web** | search | Last resort. AL/BC web content rots fast — treat with suspicion. |

## Situation → action

| Question | Source |
|---|---|
| Need an event publisher in BaseApp. | `/bc-standard-reference` |
| Need a posting flow's exact entry codeunit and signature. | `/bc-standard-reference` |
| Need to know whether table T exists in 25.0. | `mcp__al-symbols-mcp__al_packages` + `al_search_objects` |
| Need the field type / length of an existing extension table. | `mcp__al-symbols-mcp__al_get_object_definition` |
| Need every caller of a procedure in the workspace. | `mcp__al-symbols-mcp__al_find_references` |
| Need an event signature inside a dependency `.app` you can't open. | `mcp__al-symbols-mcp__al_get_object_summary` + `al_search_object_members` |
| Need conceptual guidance — dimension propagation, install/upgrade contract, AppSource gate, permission inheritance, RDLC convention. | `mcp__bc-knowledge__*` |
| Need API contract for an external integration. | `mcp__plugin_microsoft-docs__*` |
| Need a non-AL library / SDK signature. | `mcp__context7__*` |
| Nothing above answers and the question is BC-specific. | Stop. Report unanswerable. |

## Verify before trusting training data

Training data is thin and stale on BC version-specific behaviour — event signatures, install/upgrade contracts, AppSource gates, etc. Verify, do not recall. The Situation → action table above maps concrete questions to the right source.

## When the caller must run it

Mandatory before non-trivial actions in the callers below. Caller spawns `/al-research` per claim, often in parallel.

| Caller | Research what |
|---|---|
| **`/al-design`** | One pattern per module against current BaseApp examples; every R→P→W signature on the boundary; every brownfield procedure / event / table-field name and signature before listing it as a touchpoint. Also inside each design-twice sub-agent for any AL/BC behavioural claim. |
| **`/al-grill-adr`** | Any domain term whose canonical BC meaning the user invokes; any standard event or posting routine cited as load-bearing for a domain rule. |
| **`/al-implement`** | The exact event signature, posting-routine entry, or table-field type before red; any BaseApp procedure called from new code. |
| **`/al-refactor`** | Any seam target — published event, interface boundary, replaceable adapter — before extracting; any BaseApp procedure renamed, moved, or wrapped. |
| **`/al-refine`** | Any BC vocabulary term used in a Gherkin scenario whose meaning the workspace doesn't pin down; any standard error message string asserted on. |

If prior knowledge feels uncertain, default to verifying.

## Discipline

**Quote, don't paraphrase.** Every behavioural claim ships verbatim with a one-line citation — source path, symbol, or URL.

| | Finding |
|---|---|
| _Avoid_: | Sales posting validates blocked customers before inserting ledger entries. |
| Use: | `Cust.TestField(Blocked, Cust.Blocked::" ")` — `Codeunit 80 "Sales-Post"`, `OnRun → CheckCustomerBlockage`. |

Citations live in the return note only — never inline into durable artifacts. The caller decides what to persist; `architecture.md`, `tasks.md`, `CONTEXT.md`, ADRs cite by name. Stop browsing the moment an answer is actionable. Dispatch independent claims as parallel sub-agents — one call per claim.

_Avoid_:

- Trusting training data on BC version specifics.
- Web-searching before checking BaseApp via source #1 or #2.
- Hedging — "might", "I think", "probably". A claim without a source is not a finding; drop it or verify it.

## Output

Findings note to the caller. Per finding: question, answer, source, one-line citation. No code edits. No `tasks.md` edits. No durable artifact writes.

## Composition

`/grill-me` when the research question itself is unclear and needs framing. `/bc-standard-reference` is source #2 — reachable directly when the question is purely BaseApp behaviour. Caller decides whether a finding earns a line in `architecture.md`, `CONTEXT.md`, or an ADR.

## Out of scope

- No code edits, no test edits, no `tasks.md` edits, no ADR writes, no `CONTEXT.md` edits.
- No browsing for context — research is scoped, returns when actionable.
- No design picks (`/al-design`), no grilling (`/al-grill-adr`, `/grill-me`).
