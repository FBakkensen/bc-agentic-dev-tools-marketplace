---
name: bc-w1-reference
description: Local mirror of standard Business Central W1 source code (fbakkensen/bc-w1) for searching events, APIs, tables, fields, tests, and implementation patterns. Use when: (1) Finding events to subscribe to (e.g., posting events, validation triggers), (2) Understanding how standard BC implements features (discounts, pricing, document posting), (3) Looking up table/field definitions and relationships, (4) Finding test patterns and test library usage (Library - Sales, Library - Inventory), (5) Checking APIV2 implementations for external integrations, (6) Referencing System Application utilities (Email, Azure AD, Barcode). Content includes: BaseApp/ (~165 modules: Sales, Purchases, Inventory, Finance, Manufacturing, Warehouse), BaseApp/Test/ (~30 test apps), System Application/ (~80+ platform modules), APIV2/ (REST API pages), ExternalEvents/ (business events), testframework/ (Assert, Any, TestRunner).
---
# BC W1 Reference

## Overview
Set up and use a local mirror of the standard Business Central (W1) source so you can search for events, APIs, tables, fields, and tests without remote browsing. The default mirror location is a sibling `_aldoc/bc-w1` folder (outside the repo root) to avoid noise in search tools.

**Recommended approach:** For open-ended exploration (finding events, understanding patterns, locating test examples), use the Task tool with `subagent_type=Explore` to search the mirror. This handles multi-step searches and returns synthesized findings.

## Quick Start
Important: Do not run the setup/update scripts automatically. Ask the user to confirm before running them; in most cases, you should not run them at all unless the user explicitly requests it.

1) Ensure the local mirror exists (clones if missing, adds local ignore):

```powershell
<skill-folder>/skills/bc-w1-reference/scripts/setup-bc-w1-mirror.ps1
```

2) Update the mirror (fast-forward only):

```powershell
<skill-folder>/skills/bc-w1-reference/scripts/update-bc-w1.ps1
```

3) Search locally with ripgrep (examples, from repo root; single-file):

```powershell
rg -n "EventSubscriber" "..\_aldoc\bc-w1\Email - SMTP Connector\Test\Email - SMTP Connector Tests\src\SMTPAccountAuthTests.Codeunit.al"
rg -n "OnAfterValidateEvent" "..\_aldoc\bc-w1\ExternalEvents\Source\_Exclude_Business_Events_\src\ARExternalEvents.Codeunit.al"
rg -n "table 27" "..\_aldoc\bc-w1\BaseApp\Source\Base Application\Inventory\Item\Item.Table.al"
```

4) Search structurally with ast-grep (single file to keep output small):

```powershell
ast-grep run -l al -p 'codeunit 130300 "Library - Demo Data"' -C 0 "..\_aldoc\bc-w1\BaseApp\Test\Tests-TestLibraries\LibraryDemoData.Codeunit.al"
```

## Tasks

### 1) Ensure local mirror
Use when the mirror does not exist yet or when you want to re-apply local ignore.

```powershell
<skill-folder>/skills/bc-w1-reference/scripts/setup-bc-w1-mirror.ps1
```

### 2) Update mirror
Use when you want the latest changes (monthly cadence).

```powershell
<skill-folder>/skills/bc-w1-reference/scripts/update-bc-w1.ps1
```

Options:
- `-TargetPath <path>`: override the folder (default `_aldoc\bc-w1`)
- `-RepoRoot <path>`: repo root if you are not running from it

### 3) Explore with a subagent (recommended)
For open-ended questions or when you need to find standard BC implementations, use the Task tool with `subagent_type=Explore` to search the mirror:

```
Task tool:
  subagent_type: Explore
  prompt: "Search the BC W1 source mirror at C:\Users\FlemmingBK\repo\_aldoc\bc-w1 for [topic]. Look for events, implementation patterns, and examples related to [specific question]."
```

This is preferred for:
- Finding events to subscribe to (e.g., "What events fire when posting a sales order?")
- Understanding standard implementations (e.g., "How does BC calculate line discounts?")
- Locating test patterns (e.g., "How do standard tests set up sales documents?")
- Finding API implementations (e.g., "How does the APIV2 handle customer creation?")

### 4) Search patterns (manual)
Use `rg` (ripgrep) for fast local search (start narrow, then widen):

```powershell
rg -n "\[EventSubscriber" "..\_aldoc\bc-w1\Email - SMTP Connector\Test\Email - SMTP Connector Tests\src\SMTPAccountAuthTests.Codeunit.al"
rg -n "procedure .*\(" "..\_aldoc\bc-w1\BaseApp\Source\Base Application\Sales\History\SalesCrMemoHeader.Table.al" -m 5
rg -l "OnAfterValidateEvent" ..\_aldoc\bc-w1 -g "*.al" | Select-Object -First 5
```

## Resources

### scripts/
- `setup-bc-w1-mirror.ps1`: Clone the repo locally (if missing) and add a local ignore entry in `.git/info/exclude`.
- `update-bc-w1.ps1`: Fast-forward update of the local mirror.

Note: These are PowerShell scripts. Run them from PowerShell or prefix with your preferred PowerShell invocation if needed.

## Content Structure

The `fbakkensen/bc-w1` repo mirrors official Microsoft Business Central W1 source:

```
bc-w1/
├── BaseApp/                          # Core Business Central application
│   ├── Source/Base Application/      # Main source (~165 modules)
│   │   ├── Sales/                    # Sales orders, invoices, quotes, returns
│   │   ├── Purchases/                # Purchase orders, invoices, vendors
│   │   ├── Inventory/                # Items, locations, tracking, adjustments
│   │   ├── Finance/                  # G/L, journals, VAT, currencies
│   │   ├── Bank/                     # Bank accounts, reconciliation
│   │   ├── Manufacturing/            # Production orders, BOMs, routing
│   │   ├── Warehouse/                # Warehouse management, picks, puts
│   │   ├── Service/                  # Service management
│   │   ├── CRM/                      # Contacts, opportunities, campaigns
│   │   ├── Assembly/                 # Assembly orders
│   │   ├── CostAccounting/           # Cost centers, cost types
│   │   ├── CashFlow/                 # Cash flow forecasting
│   │   ├── RoleCenters/              # Role center pages
│   │   ├── Integration/              # External integrations
│   │   └── ...                       # ~150 more modules
│   └── Test/                         # BaseApp tests (~30 test apps)
│       ├── Tests-ERM/                # Enterprise Resource Management tests
│       ├── Tests-Bank/               # Banking tests
│       ├── Tests-Job/                # Jobs/Projects tests
│       ├── Tests-Marketing/          # CRM tests
│       ├── Tests-Fixed Asset/        # Fixed asset tests
│       └── Tests-TestLibraries/      # Test helper libraries (Library - *)
│
├── System Application/               # Platform services
│   └── Source/System Application/    # Core system modules
│       ├── Azure AD User/            # Azure AD integration
│       ├── Barcode/                  # Barcode generation
│       ├── Camera and Media/         # Device integration
│       ├── Cryptography Management/  # Encryption utilities
│       ├── Email/                    # Email framework
│       ├── Retention Policy/         # Data retention
│       └── ...                       # ~80+ system modules
│
├── APIV1/ & APIV2/                   # REST API implementations
│   └── Source/_Exclude_APIV2_/src/
│       ├── pages/                    # API pages (customers, items, orders, etc.)
│       └── codeunits/                # API helper codeunits
│
├── ExternalEvents/                   # Business events for external subscribers
│   └── Source/_Exclude_Business_Events_/src/
│       ├── ARExternalEvents.Codeunit.al    # Accounts Receivable events
│       ├── APExternalEvents.Codeunit.al    # Accounts Payable events
│       └── ...                             # Domain-specific event publishers
│
├── testframework/                    # Test infrastructure
│   ├── testlibraries/                # Core test libraries (Any, Assert, etc.)
│   ├── TestRunner/                   # Test execution framework
│   ├── performancetoolkit/           # Performance testing
│   └── aitesttoolkit/                # AI test utilities
│
├── Manufacturing/                    # Manufacturing module (separate app)
├── ServiceManagement/                # Service Management (separate app)
├── Shopify/                          # Shopify connector
├── SubscriptionBilling/              # Subscription management
├── Sustainability/                   # Sustainability tracking
│
└── [60+ more apps]                   # Email connectors, Payment integrations,
                                      # Intrastat, VAT Group, Data Exchange, etc.
```

### Key Folders for Common Tasks

| Task | Look In |
|------|---------|
| **Find events** | `BaseApp/Source/Base Application/[Domain]/`, `ExternalEvents/` |
| **Table definitions** | `BaseApp/Source/Base Application/[Domain]/*.Table.al` |
| **Standard tests** | `BaseApp/Test/Tests-[Domain]/` |
| **Test libraries** | `BaseApp/Test/Tests-TestLibraries/`, `testframework/testlibraries/` |
| **API implementations** | `APIV2/Source/_Exclude_APIV2_/src/pages/` |
| **System utilities** | `System Application/Source/System Application/` |

## Command Cheatsheet

Use these when searching the local W1 mirror.

```powershell
rg --files -g "*.al" ..\_aldoc\bc-w1 | Select-Object -First 20
rg -l "OnAfterValidateEvent" ..\_aldoc\bc-w1 -g "*.al" | Select-Object -First 5
rg -n "\[EventSubscriber" "..\_aldoc\bc-w1\Email - SMTP Connector\Test\Email - SMTP Connector Tests\src\SMTPAccountAuthTests.Codeunit.al"
git -C ..\_aldoc\bc-w1 log -1
git -C ..\_aldoc\bc-w1 grep -n "EventSubscriber" -- "Email - SMTP Connector/Test/Email - SMTP Connector Tests/src/SMTPAccountAuthTests.Codeunit.al"
```

Optional helpers (if installed):

```powershell
fd -e al . ..\_aldoc\bc-w1 | Select-Object -First 20
```
