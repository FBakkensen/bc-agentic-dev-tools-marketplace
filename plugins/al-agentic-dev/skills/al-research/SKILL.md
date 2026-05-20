---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources before acting in /al-design, /al-grill-adr, /al-implement, /al-refactor, /al-refine. Use when prior AL/BC knowledge is unverified and the workspace itself doesn't answer, training data is thin and stale; verify before trusting it.
---

# /al-research, Verify BC specifics

Treat your own AL/BC knowledge as untrusted. Quote the canonical source, return one finding per question, persist nothing. The caller has already searched the workspace, `/al-research` answers what the codebase cannot.

## Precondition

Workspace already explored. If the answer lives in the current repo, the caller reads it directly. Stop.

## Source priority

Top-down. Stop at the first source that answers definitively. Don't browse past a hit. If sources disagree, surface the conflict, do not pick silently.

| # | Source | Access | Use for |
|---|---|---|---|
| 1 | **AL symbols** | available AL symbol lookup, dependency metadata, or language-server-backed search | The workspace's own symbols and dependencies. |
| 2 | **`/bc-standard-reference`** | skill | BaseApp, System Application, APIV2 canonical behaviour. |
| 3 | **BC knowledge** | available BC knowledge source or expert reference | BC concepts and patterns. |
| 4 | **Microsoft Learn** | available Microsoft Learn search and fetch tools | Official, version-current MS docs. |
| 5 | **Context7** | available library documentation lookup | External library / framework / SDK docs. Rare for AL. |
| 6 | **Web** | search | Last resort. AL/BC web content rots fast, treat with suspicion. |

## Situation → action

| Question | Source |
|---|---|
| Need an event publisher in BaseApp. | `/bc-standard-reference` |
| Need a posting flow's exact entry codeunit and signature. | `/bc-standard-reference` |
| Need to know whether table T exists in 25.0. | AL package metadata + object search |
| Need the field type / length of an existing extension table. | AL object definition lookup |
| Need every caller of a procedure in the workspace. | AL reference search |
| Need an event signature inside a dependency `.app` you can't open. | AL object summary + member search |
| Need conceptual guidance, dimension propagation, install/upgrade contract, AppSource gate, permission inheritance, RDLC convention. | BC knowledge source |
| Need API contract for an external integration. | Microsoft Learn |
| Need a non-AL library / SDK signature. | Context7 or equivalent library docs |
| Nothing above answers and the question is BC-specific. | Stop. Report unanswerable. |

## Verify before trusting training data

Training data is thin and stale on BC version-specific behaviour, event signatures, install/upgrade contracts, AppSource gates, etc. Verify, do not recall. The Situation → action table above maps concrete questions to the right source.

## When the caller must run it

Mandatory before non-trivial actions in the callers below. Caller spawns `/al-research` per claim, often in parallel.

| Caller | Research what |
|---|---|
| **`/al-design`** | One pattern per module against current BaseApp examples; every R→P→W signature on the boundary; every brownfield procedure / event / table-field name and signature before listing it as a touchpoint. Also inside each design-twice delegated pass for any AL/BC behavioural claim. |
| **`/al-grill-adr`** | Any domain term whose canonical BC meaning the user invokes; any standard event or posting routine cited as load-bearing for a domain rule. |
| **`/al-implement`** | The exact event signature, posting-routine entry, or table-field type before red; any BaseApp procedure called from new code. |
| **`/al-refactor`** | Any seam target, published event, interface boundary, replaceable adapter, before extracting; any BaseApp procedure renamed, moved, or wrapped. |
| **`/al-refine`** | Any BC vocabulary term used in a Gherkin scenario whose meaning the workspace doesn't pin down; any standard error message string asserted on. |

If prior knowledge feels uncertain, default to verifying.

## Discipline

**Quote, don't paraphrase.** Every behavioural claim ships verbatim with a one-line citation, source path, symbol, or URL.

| | Finding |
|---|---|
| _Avoid_: | Sales posting validates blocked customers before inserting ledger entries. |
| Use: | `Cust.TestField(Blocked, Cust.Blocked::" ")`, `Codeunit 80 "Sales-Post"`, `OnRun → CheckCustomerBlockage`. |

Citations live in the return note only, never inline into durable artifacts. The caller decides what to persist; `architecture.html`, `tasks.html`, `CONTEXT.md`, ADRs cite by name. Stop browsing the moment an answer is actionable. Dispatch independent claims as parallel delegated research passes when the host supports subagents, one claim per pass.

_Avoid_:

- Trusting training data on BC version specifics.
- Web-searching before checking BaseApp via source #1 or #2.
- Hedging, "might", "I think", "probably". A claim without a source is not a finding; drop it or verify it.

## Output

Findings note to the caller. Per finding: question, answer, source, one-line citation. No code edits. No `tasks.html` edits. No durable artifact writes.

## Composition

`/grill-me` when the research question itself is unclear and needs framing. `/bc-standard-reference` is source #2, reachable directly when the question is purely BaseApp behaviour. Caller decides whether a finding earns a line in `architecture.html`, `CONTEXT.md`, or an ADR.

## Out of scope

- No code edits, no test edits, no `tasks.html` edits, no ADR writes, no `CONTEXT.md` edits.
- No browsing for context, research is scoped, returns when actionable.
- No design picks (`/al-design`), no grilling (`/al-grill-adr`, `/grill-me`).
