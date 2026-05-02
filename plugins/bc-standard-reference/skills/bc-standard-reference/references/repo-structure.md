# Repository Structure

The `fbakkensen/bc-w1` repo mirrors the official Microsoft Business Central Standard (Worldwide) source. Navigate by domain path, not by guessing filenames.

```
bc-w1/
├── BaseApp/
│   ├── Source/Base Application/      # Core BC application source
│   │   ├── Sales/                    # Sales orders, invoices, quotes, returns
│   │   ├── Purchases/                # Purchase orders, invoices, vendors
│   │   ├── Inventory/                # Items, locations, tracking, adjustments
│   │   ├── Finance/                  # G/L, journals, VAT, currencies
│   │   ├── Bank/                     # Bank accounts, reconciliation
│   │   ├── Manufacturing/            # Production orders, BOMs, routing
│   │   ├── Warehouse/                # Picks, puts, bin contents
│   │   ├── Service/                  # Service management
│   │   ├── CRM/                      # Contacts, opportunities, campaigns
│   │   ├── Assembly/                 # Assembly orders
│   │   ├── CostAccounting/           # Cost centers, cost types
│   │   ├── CashFlow/                 # Cash flow forecasting
│   │   ├── RoleCenters/              # Role center pages
│   │   └── Integration/              # External integrations
│   └── Test/                         # BaseApp tests
│       ├── Tests-ERM/                # Enterprise Resource Management tests
│       ├── Tests-Bank/               # Banking tests
│       ├── Tests-Job/                # Jobs/Projects tests
│       ├── Tests-Marketing/          # CRM tests
│       ├── Tests-Fixed Asset/        # Fixed asset tests
│       └── Tests-TestLibraries/      # Helper libraries (Library - *)
│
├── System Application/
│   └── Source/System Application/    # Platform services
│       ├── Azure AD User/
│       ├── Barcode/
│       ├── Camera and Media/
│       ├── Cryptography Management/
│       ├── Email/
│       └── Retention Policy/
│
├── APIV1/ & APIV2/                   # REST API implementations
│   └── Source/_Exclude_APIV2_/src/
│       ├── pages/                    # API pages (customers, items, orders, ...)
│       └── codeunits/                # API helper codeunits
│
├── ExternalEvents/                   # Business events for external subscribers
│   └── Source/_Exclude_Business_Events_/src/
│       ├── ARExternalEvents.Codeunit.al    # Accounts Receivable events
│       └── APExternalEvents.Codeunit.al    # Accounts Payable events
│
├── testframework/
│   ├── testlibraries/                # Core test libraries (Any, Assert, ...)
│   ├── TestRunner/                   # Test execution framework
│   ├── performancetoolkit/           # Performance testing
│   └── aitesttoolkit/                # AI test utilities
│
├── Manufacturing/                    # Manufacturing module (separate app)
├── ServiceManagement/                # Service Management (separate app)
├── Shopify/                          # Shopify connector
├── SubscriptionBilling/              # Subscription management
└── Sustainability/                   # Sustainability tracking
```

Plus separate apps for email connectors, payment integrations, Intrastat, VAT Group, Data Exchange — search by app name when the domain isn't in BaseApp.

## Lookup table

| Looking for | Path |
|---|---|
| **Events in a domain** | `BaseApp/Source/Base Application/<Domain>/`, plus `ExternalEvents/` for partner-facing events |
| **Table definitions** | `BaseApp/Source/Base Application/<Domain>/*.Table.al` |
| **Standard tests** | `BaseApp/Test/Tests-<Domain>/` |
| **Test libraries** | `BaseApp/Test/Tests-TestLibraries/`, `testframework/testlibraries/` |
| **API implementations** | `APIV2/Source/_Exclude_APIV2_/src/pages/` |
| **System utilities** | `System Application/Source/System Application/` |

_Avoid_: searching the whole repo when the domain is known. Narrow first.
