---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources before acting in /al-design, /al-grill-adr, /al-implement, /al-refactor, /al-refine. Use when prior AL/BC knowledge is unverified and the workspace itself doesn't answer — training data is thin and stale; verify before trusting it.
---

# /al-research — Verify BC specifics

Verify AL/Business Central facts from authoritative sources before acting. Treat your own AL knowledge as untrusted until corroborated. The caller has already searched the workspace — `/al-research` answers what the codebase cannot. Stop at the first source that answers definitively. Return findings to the caller; persist nothing.

## Precondition

Workspace already explored. If the answer lives in the current repo, the caller reads it directly — do not invoke `/al-research`.

## Source priority

Top-down. Stop at the first source that answers definitively. Don't browse past a hit.

| # | Source | Tools | Use for |
|---|---|---|---|
| 1 | **AL symbols** | `mcp__al-symbols-mcp__al_search_objects`, `al_get_object_definition`, `al_get_object_summary`, `al_search_object_members`, `al_find_references`, `al_packages` | Definitions, signatures, references, members in dependencies you can't open. |
| 2 | **`/bc-standard-reference`** | skill | BaseApp behaviour, standard publishers, reference patterns. |
| 3 | **bc-knowledge MCP** | `mcp__bc-knowledge__find_bc_knowledge`, `ask_bc_expert`, `get_bc_topic` | Curated BC knowledge graph and topics. |
| 4 | **Microsoft Learn** | `mcp__plugin_microsoft-docs_microsoft-learn__microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search` | Official, version-current docs. |
| 5 | **context7** | `mcp__context7__resolve-library-id`, `query-docs` | External libraries / SDKs. |
| 6 | **Web** | search | Last resort. AL/BC web content rots fast — treat with suspicion. |

If sources disagree, surface the conflict — don't pick silently.

## When the caller must run it

Mandatory before non-trivial actions in the callers below. The caller spawns `/al-research` per claim, often in parallel.

| Caller | Research what |
|---|---|
| **`/al-design`** | One pattern per module against current BaseApp examples; every R→P→W signature on the boundary; every brownfield procedure / event / table-field name and signature before listing it as a touchpoint. Also inside each design-twice sub-agent for any AL/BC behavioural claim. |
| **`/al-grill-adr`** | Any domain term whose canonical BC meaning the user invokes; any standard event or posting routine cited as load-bearing for a domain rule. |
| **`/al-implement`** | The exact event signature, posting-routine entry, or table-field type before red; any BaseApp procedure called from new code. |
| **`/al-refactor`** | Any seam target — published event, interface boundary, replaceable adapter — before extracting; any BaseApp procedure renamed, moved, or wrapped. |
| **`/al-refine`** | Any BC vocabulary term used in a Gherkin scenario whose meaning the workspace doesn't pin down; any standard error message string asserted on. |

If prior knowledge feels uncertain, default to verifying.

## Discipline

- **Verify, don't paraphrase.** Quote the canonical source for any behavioural claim.
- **One-line citation per finding** — source path, symbol, or URL — in the return note. Never inline citations into durable artifacts; the caller decides what (if anything) to persist, and durable docs cite by name only.
- **Stop when actionable.** Don't browse past a definitive answer.
- **Parallel sub-agents** for independent claims — one research call per claim, dispatched together.
- **Treat your own AL knowledge as untrusted** until corroborated.

## Output

Short findings note to the caller — question, answer, source, one-line citation each. No code edits. No `tasks.md` edits. No durable artifact writes.

## Composition

`/grill-me` when the research question itself is unclear and needs framing. `/bc-standard-reference` is source #2 in the priority chain — reachable directly when the question is purely BaseApp behaviour. Caller decides whether a finding earns a line in `architecture.md`, `CONTEXT.md`, or an ADR.

## Out of scope

- No code edits, no test edits, no `tasks.md` edits, no ADR writes, no `CONTEXT.md` edits.
- No browsing for context — research is scoped, returns when actionable.
- No design picks (`/al-design`), no grilling (`/al-grill-adr`, `/grill-me`).
