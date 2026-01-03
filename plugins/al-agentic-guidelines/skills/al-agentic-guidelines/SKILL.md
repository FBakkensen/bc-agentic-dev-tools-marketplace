---
name: al-agentic-guidelines
description: Local mirror of Microsoft AL Guidelines (alguidelines.dev) for searching agentic coding rules, vibe-coding standards, AL best practices, and community resources. Use when: (1) Writing or reviewing AL code and need naming conventions, code style, or formatting rules, (2) Implementing event subscribers, error handling, or performance patterns, (3) Setting up AI-assisted development with Claude/Copilot/Cursor agent configurations, (4) Looking for MCP server integrations (AL-ObjID, BC-Code-Intel, NAB), (5) Understanding classic NAV/BC patterns like Document, Journal, Hooks, or Master Data. Content includes: vibe-coding-rules/ (7 AL-specific rule files), BestPractices/ (~27 topics), patterns/ (facade, template-method, event-bridge), NAVPatterns/ (~50+ classic patterns), and CommunityResources/ (agent configs, MCP tools).
---
# AL Guidelines Reference

## Overview
Set up and use a local mirror of the Microsoft AL Guidelines (alguidelines.dev) so you can search for agentic coding rules, vibe-coding standards, best practices, and community resources without remote browsing. The default mirror location is a sibling `_aldoc/al-guidelines` folder (outside the repo root) to avoid noise in search tools.

**Recommended approach:** For open-ended exploration of guidelines, use the Task tool with `subagent_type=Explore` to search the mirror. This handles multi-step searches and returns synthesized findings.

## Quick Start
Important: Do not run the setup/update scripts automatically. Ask the user to confirm before running them; in most cases, you should not run them at all unless the user explicitly requests it.

1) Ensure the local mirror exists (clones if missing):

```powershell
<skill-folder>/skills/al-agentic-guidelines/scripts/setup-al-guidelines-mirror.ps1
```

2) Update the mirror (fast-forward only):

```powershell
<skill-folder>/skills/al-agentic-guidelines/scripts/update-al-guidelines.ps1
```

3) Search locally with ripgrep (examples, from repo root):

```powershell
rg -n "vibe coding" "..\_aldoc\al-guidelines\content\docs\agentic-coding" -i
rg -n "naming convention" "..\_aldoc\al-guidelines\content\docs" -i
rg -n "EventSubscriber" "..\_aldoc\al-guidelines\content\docs" -i
```

## Tasks

### 1) Ensure local mirror
Use when the mirror does not exist yet.

```powershell
<skill-folder>/skills/al-agentic-guidelines/scripts/setup-al-guidelines-mirror.ps1
```

### 2) Update mirror
Use when you want the latest changes.

```powershell
<skill-folder>/skills/al-agentic-guidelines/scripts/update-al-guidelines.ps1
```

Options:
- `-TargetPath <path>`: override the folder (default `_aldoc\al-guidelines`)
- `-RepoRoot <path>`: repo root if you are not running from it

### 3) Explore with a subagent (recommended)
For open-ended questions or when you need to find relevant guidelines, use the Task tool with `subagent_type=Explore` to search the mirror:

```
Task tool:
  subagent_type: Explore
  prompt: "Search the AL guidelines mirror at C:\Users\FlemmingBK\repo\_aldoc\al-guidelines\content\docs for [topic]. Look for best practices, patterns, and examples related to [specific question]."
```

This is preferred for:
- Finding guidance on a topic (e.g., "How should I handle errors in AL?")
- Discovering relevant patterns (e.g., "What patterns exist for document posting?")
- Comparing approaches (e.g., "Event subscribers vs direct calls")

### 4) Search patterns (manual)
Use `rg` (ripgrep) for fast local search (start narrow, then widen):

```powershell
# Search agentic-coding section
rg -n "vibe coding" "..\_aldoc\al-guidelines\content\docs\agentic-coding" -i
rg -n "procedure naming" "..\_aldoc\al-guidelines\content\docs\agentic-coding\vibe-coding-rules" -i

# Search across all guidelines
rg -n "best practice" "..\_aldoc\al-guidelines\content\docs" -i
rg -l "EventSubscriber" ..\_aldoc\al-guidelines\content\docs -g "*.md" | Select-Object -First 5
```

## Resources

### scripts/
- `setup-al-guidelines-mirror.ps1`: Clone the repo locally (if missing).
- `update-al-guidelines.ps1`: Fast-forward update of the local mirror.

Note: These are PowerShell scripts. Run them from PowerShell or prefix with your preferred PowerShell invocation if needed.

## Content Structure

The `microsoft/alguidelines` repo (https://alguidelines.dev) contains:

```
content/docs/
├── agentic-coding/              # AI-assisted AL development
│   ├── GettingStarted/          # Setup, prompting, limitations, glossary
│   ├── GettingMore/             # Code review, documentation, telemetry
│   ├── vibe-coding-rules/       # AL-specific rules for AI readability
│   │   ├── al-code-style.md
│   │   ├── al-naming-conventions.md
│   │   ├── al-error-handling.md
│   │   ├── al-events.md
│   │   ├── al-performance.md
│   │   ├── al-testing.md
│   │   └── al-upgrade.md
│   └── CommunityResources/
│       ├── Agents/              # Claude, Cursor, GitHub Copilot configs
│       └── Tools/               # MCP servers (AL-ObjID, BC-Code-Intel, NAB, etc.)
│
├── BestPractices/               # General AL coding standards (~27 topics)
│   ├── variable-naming          # Naming conventions
│   ├── SubscriberCodeunits      # Event subscriber patterns
│   ├── SetLoadFields            # Performance: partial loading
│   ├── CustomTelemetry          # Telemetry implementation
│   ├── api-page                 # API page design
│   └── ...                      # Formatting, indentation, if/else patterns
│
├── patterns/                    # Modern AL design patterns (~9 patterns)
│   ├── facade-pattern
│   ├── template-method-pattern
│   ├── event-bridge-pattern
│   ├── error-handling
│   ├── no-series
│   └── ...
│
└── NAVPatterns/                 # Classic NAV/BC patterns (~50+ patterns)
    ├── patterns/                # Document, Master Data, Journal, Hooks, etc.
    ├── 2-anti-patterns/         # What NOT to do
    └── 3-cal-coding-guidelines/ # Legacy C/AL guidance (still relevant)
```

## Command Cheatsheet

Use these when searching the local AL guidelines mirror.

```powershell
# List all markdown files
rg --files -g "*.md" ..\_aldoc\al-guidelines\content\docs | Select-Object -First 20

# Search agentic coding topics
rg -n "vibe coding" ..\_aldoc\al-guidelines\content\docs\agentic-coding -i
rg -n "AI assistant" ..\_aldoc\al-guidelines\content\docs\agentic-coding -i

# Search vibe-coding rules specifically
rg -n "procedure" ..\_aldoc\al-guidelines\content\docs\agentic-coding\vibe-coding-rules -i
rg -n "naming" ..\_aldoc\al-guidelines\content\docs\agentic-coding\vibe-coding-rules -i

# Search best practices
rg -n "best practice" ..\_aldoc\al-guidelines\content\docs -i
rg -n "error handling" ..\_aldoc\al-guidelines\content\docs -i

# Check mirror status
git -C ..\_aldoc\al-guidelines log -1
```

Optional helpers (if installed):

```powershell
fd -e md . ..\_aldoc\al-guidelines\content\docs | Select-Object -First 20
```
