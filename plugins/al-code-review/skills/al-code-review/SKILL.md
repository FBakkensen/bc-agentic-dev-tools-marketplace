---
name: al-code-review
description: "Multi-model AL/Business Central code review. Spawns parallel code-review subagents across models and review types (Performance, Bug Hunter, Code Reuse). Use when asked to review a PR, review code, or run a code review."
---

# AL Code Review Skill

Orchestrates targeted, multi-model code reviews for AL/Business Central pull requests. Each review runs as an independent subagent with a focused lens.

## Invocation

| Command | Action |
|---------|--------|
| `/al-code-review` | Review current branch diff with current model |
| `/al-code-review using opus 4.6, gemini 3 pro` | Review current branch diff with multiple models |

## Step 1: Parse the User's Request

Extract from the user's prompt:

1. **Model list** — models specified after "using" keyword, comma-separated
2. **Review type filter** — if the user asks for only specific types, respect that; otherwise run all 3

### Model Name Resolution

The user may refer to models by short/friendly names (e.g., "opus 4.6", "gemini 3 pro", "codex 5.3"). Match these to the actual model IDs available in your environment. Be flexible with partial matches — resolve to the closest available model.

**If no models are specified**, do NOT default to any specific model list. Use only the user's currently selected model (no model override parameter — omit it from the subagent call).

Get the current branch name for display: `git branch --show-current`

## Step 1b: Detect Linked Issues (optional)

Check if the current branch has an associated PR with linked issues. Issues may be linked in the PR body text **or** via GitHub's Development sidebar.

1. **Get PR info**: Run `gh pr view --json number,body,url` — if no PR exists, skip this step entirely
2. **Extract body references**: Parse the PR body for issue references: `#N`, `Closes #N`, `Fixes #N`, `Resolves #N`, or full GitHub issue URLs
3. **Query Development sidebar links**: Extract owner/repo from the PR URL, then run:
   ```
   gh api graphql -f query='{
     repository(owner: "{owner}", name: "{repo}") {
       pullRequest(number: {N}) {
         closingIssuesReferences(first: 10) {
           nodes { number }
         }
       }
     }
   }'
   ```
4. **Deduplicate**: Merge issue numbers from both sources into a unique set
5. **Pass issue numbers to subagents** — do NOT fetch issue content here; the subagents will fetch it themselves

If no PR exists or no issues are linked, proceed without issue context — the review works fine without it.

## Step 2: Spawn Subagents

### Review Types

There are exactly 3 review types. For each, there is a reference guide in `<skill-folder>/references/`:

| Review Type | Reference File | Focus |
|---|---|---|
| **Performance** | `performance-review-guide.md` | Efficiency, data access patterns, loop optimization, memory |
| **Bug Hunter** | `bug-hunter-guide.md` | Runtime errors, data integrity, null refs, control flow bugs |
| **Code Reuse** | `code-reuse-guide.md` | DRY, naming, extensibility, formatting, refactoring opportunities |

### Spawning Strategy

For each **model** × **review type** combination, launch a `code-review` subagent using the `task` tool:

- **agent_type**: `code-review`
- **model**: the model ID (omit if using current model)
- **mode**: `background` (so all agents run in parallel)
- **prompt**: constructed per the template below

**Launch ALL subagents in a single response** to maximize parallelism. For N models × 3 review types = 3N subagents.

### Subagent Prompt Template

For each subagent, construct the prompt as follows:

```
You are reviewing AL/Business Central code changes on the current branch.

## Your Review Focus: {REVIEW_TYPE}

Read the reference guide below, then get the diff and analyze it. Report ONLY issues matching your review focus.

{IF LINKED ISSUES WERE FOUND IN STEP 1b, INSERT THIS SECTION — OTHERWISE OMIT ENTIRELY}
## Linked Issues

This PR is linked to the following issue(s): {comma-separated list, e.g., #42, #87}

Fetch each issue using `gh issue view {N} --json title,body` to understand the intent of the changes. After your review, also verify whether the diff addresses the requirements described in the linked issue(s). Flag any requirements that appear unaddressed or only partially implemented as a finding with severity 🟡 and short-id prefix `coverage-`.
{END IF}

## Step 1: Get the diff

Run these commands to get the diff locally:
1. Determine the merge base: `git merge-base HEAD main` (if that fails, try `master`)
2. Get the AL diff: `git diff $(git merge-base HEAD main) -- '*.al'`
3. Get the changed file list: `git diff --name-status $(git merge-base HEAD main) -- '*.al'`

If no AL files changed, output: `NO FINDINGS`

---
## Reference Guide

{CONTENTS OF THE CORRESPONDING REFERENCE GUIDE FILE}

---
## Instructions

1. Analyze every changed file in the diff through the lens of your review focus.
2. For each finding, output a structured block in EXACTLY this format:

### FINDING: {short-id}
- **Severity**: 🔴 Critical | 🟡 Warning | 🔵 Suggestion
- **File**: {filename}
- **Procedure/Trigger**: {procedure name or trigger name, or "N/A"}
- **Issue**: {one-line description}
- **Why it matters**: {1-2 sentence explanation of the risk or impact}
- **Fix**: {concrete description of what to change}
- **Code suggestion**:
```al
// Before
{the problematic code from the diff}

// After
{the corrected code}
```

3. Rules:
   - If you find NO issues, output exactly: `NO FINDINGS`
   - Do NOT invent findings — only flag real issues visible in the diff.
   - Be specific — reference actual code from the diff.
   - Focus ONLY on changed lines — do not review unchanged context.
   - Use short IDs like `perf-1`, `bug-1`, `reuse-1` etc.
   - Include code suggestions for every 🔴 and 🟡 finding. Optional for 🔵.
```

**IMPORTANT**: Read each reference guide file content using `view` on `<skill-folder>/references/{filename}` and inject the full content into the prompt. Do NOT just reference the file path — the subagent cannot access skill files.

## Step 3: Collect and Merge Results

Wait for all subagents to complete using `read_agent` with `wait: true`.

Then perform deduplication:
1. Parse each subagent's structured findings (the `FINDING` blocks)
2. Group findings that describe the **same issue** across models — match by file + procedure + similar issue description
3. For each unique finding, track:
   - Which models flagged it (and under which review type)
   - The highest severity any model assigned
   - The best code suggestion from any model
4. Flag **disagreements** — where one model explicitly says something is correct that another flags as a bug

## Step 4: Present Consolidated Review

### Multi-Model Output (2+ models)

```markdown
# Code Review — {branch_name}

**Models**: {list} | **Files**: {count} AL files changed

---

## Findings

Grouped by file. Within each file, sorted by: consensus findings first, then by severity.

### 📄 {FileName1.al}

#### 🔴 {Issue title} — `{ProcedureName}`
**Confidence**: 🟢 Consensus ({Model A}, {Model B}, {Model C})
**Category**: {Performance | Bug | Code Reuse}

{Why it matters — 1-2 sentences}

```al
// Before
{problematic code}

// After  
{fixed code}
```

---

#### 🟡 {Issue title} — `{ProcedureName}`
**Confidence**: 🟡 Majority ({Model A}, {Model B})
**Category**: {category}

{explanation}

```al
// Before → After
{code fix}
```

---

#### 🔵 {Issue title} — `{ProcedureName}`
**Confidence**: ⚪ Single model ({Model A})
**Category**: {category}

{explanation and suggestion}

---

### 📄 {FileName2.al}
(... repeat for each file with findings)

---

## ⚖️ Disagreements

List cases where models contradict each other. For each:
- **What {Model A} says**: {their finding}
- **What {Model B} says**: {their counter-analysis}
- **Recommendation**: {which analysis is more likely correct and why, or "investigate manually"}

---

## 🔧 Action Plan

Ordered fix tasks. Group related findings into logical work units. Critical consensus items first.

| # | Priority | Task | Files | Findings |
|---|----------|------|-------|----------|
| 1 | 🔴 Critical | {task description, e.g., "Add else clause with Error() to case statement in ProcessLine"} | {file(s)} | {finding refs} |
| 2 | 🔴 Critical | {task} | {files} | {refs} |
| 3 | 🟡 Important | {task, e.g., "Centralize Lock() into utility codeunit — affects 6 tables"} | {files} | {refs} |
| 4 | 🟡 Important | {task} | {files} | {refs} |
| 5 | 🔵 Nice-to-have | {task} | {files} | {refs} |

### Priority Rules:
- 🔴 **Critical**: consensus + critical severity, OR any critical bug
- 🟡 **Important**: consensus findings of any severity, OR single-model warnings
- 🔵 **Nice-to-have**: single-model suggestions
```

### Confidence Levels

| Icon | Level | Meaning |
|---|---|---|
| 🟢 | Consensus | All models agree (highest confidence) |
| 🟡 | Majority | 2 out of 3 models agree |
| ⚪ | Single | Only 1 model flagged this (investigate before acting) |

### Single-Model Output (1 model)

When only one model is used, simplify — no confidence levels or disagreements:

```markdown
# Code Review — {branch_name}

**Model**: {model} | **Files**: {count} AL files changed

---

## Findings

### 📄 {FileName.al}

#### 🔴 {Issue title} — `{ProcedureName}`
**Category**: {Performance | Bug | Code Reuse}

{explanation}

```al
// Before → After
{code fix}
```

(... grouped by file, sorted by severity)

---

## 🔧 Action Plan

| # | Priority | Task | Files |
|---|----------|------|-------|
| 1 | 🔴 | {task} | {files} |
| 2 | 🟡 | {task} | {files} |
```

## Error Handling

- If a subagent fails, report which model × review type failed and present results from successful agents
- If the diff is too large for a single subagent prompt, split by file groups and note which files each agent reviewed
- If no AL files are changed on the current branch, tell the user and stop

## Guidelines

- **Do NOT post results as PR comments** — conversation output only
- **Do NOT modify any files** — this is a read-only review skill
- **Respect the user's model choices** — only use specified models
- **Be honest about coverage** — if no issues found, say so; don't pad the review
- **Deduplicate aggressively** — same issue from 3 models = 1 finding with 🟢 consensus, not 3 separate findings
- **Code suggestions are mandatory** for 🔴 and 🟡 findings — show before/after
- **Action plan must be actionable** — each task should be a single, concrete code change a developer can make
- **Group related work** — "centralize Lock() across 6 tables" is one action plan task, not six
