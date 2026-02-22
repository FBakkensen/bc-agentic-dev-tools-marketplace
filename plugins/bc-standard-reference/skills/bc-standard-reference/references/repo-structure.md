# BC Standard Repository Structure

The `fbakkensen/bc-w1` repo mirrors the official Microsoft Business Central Standard (Worldwide) source:

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

## Key Folders for Common Tasks

| Task | Look In |
|------|---------|
| **Find events** | `BaseApp/Source/Base Application/[Domain]/`, `ExternalEvents/` |
| **Table definitions** | `BaseApp/Source/Base Application/[Domain]/*.Table.al` |
| **Standard tests** | `BaseApp/Test/Tests-[Domain]/` |
| **Test libraries** | `BaseApp/Test/Tests-TestLibraries/`, `testframework/testlibraries/` |
| **API implementations** | `APIV2/Source/_Exclude_APIV2_/src/pages/` |
| **System utilities** | `System Application/Source/System Application/` |
