---
name: al-research
description: Verify AL/Business Central specifics from authoritative sources before acting. AL/BC training data is thin and stale — verify before trusting prior knowledge. Caller has already explored the workspace; /al-research handles what the codebase doesn't answer. Mandatory for non-trivial tasks. Sources in priority order: AL symbols → /bc-standard-reference → bc-knowledge MCP → Microsoft Learn → context7 → web.
---

# /al-research — Verify BC specifics

Research BC and AL specifics from authoritative sources before acting. Models are trained on limited, outdated AL/BC data — verify before trusting prior knowledge. **Mandatory for non-trivial tasks.**

## Precondition

The caller has already explored the current workspace. `/al-research` handles what the codebase doesn't answer. **If the workspace has the answer, do not invoke `/al-research`.**

## When to research

- Mandatory for non-trivial tasks.
- Before refining or implementing anything touching: events, posting routines, dimensions, ledger entries, posting setup, transaction isolation, permission sets, AppSource compliance, or any BaseApp object you haven't directly inspected.
- When `/grill-me` surfaces a domain term not grounded in current evidence.
- When prior knowledge feels uncertain — default to verifying.

## Source priority (top-down — stop at the first source that answers definitively)

1. **AL symbols** — `mcp__al-symbols-mcp`: `al_search_objects`, `al_get_object_definition`, `al_find_references`, `al_search_object_members`, `al_packages`. Definitions, references, package contents in dependencies you can't open directly.
2. **`/bc-standard-reference`** — BaseApp behaviour, standard events, reference patterns.
3. **bc-knowledge MCP** — `find_bc_knowledge`, `ask_bc_expert`, `get_bc_topic`. Internal BC knowledge graph and curated topics.
4. **Microsoft Learn** — `microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search`. Official, version-current documentation.
5. **context7** — external library / SDK documentation.
6. **Web search** — last resort. Treat with suspicion. AL/BC web content is often outdated.

## Discipline

- **Verify, do not paraphrase.** Quote or link the canonical source for any claim of behaviour.
- **Cite source path or URL** alongside each finding — the caller may need to re-check.
- **Stop when actionable.** Don't browse.
- If sources disagree, **surface the conflict** — don't pick silently.
- **Treat your own prior AL knowledge as untrusted** until corroborated.
- **Prefer parallel subagents for independent work.**

## Output

- Short findings note: question asked, what was found, where, one-line citations.
- **No edits to code or `tasks.md`.** The caller decides what to persist.

## Composition

- `/grill-me` when the research question itself is unclear and needs framing.
- `/bc-standard-reference` as source #2 in the priority chain.

## Out of scope

- No code edits.
- No `tasks.md` edits.
- No browsing for context — researches are scoped, return when actionable.
