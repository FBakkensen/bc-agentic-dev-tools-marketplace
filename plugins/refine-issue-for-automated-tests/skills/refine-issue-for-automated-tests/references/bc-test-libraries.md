# BC Test Libraries Reference

Use relevant library codeunits available in your BC/AL test environment. Library names and helper methods may vary by version or localization; prefer the local equivalents in your repo.

| Library | Purpose | Common Methods |
|---------|---------|----------------|
| Library - Sales | Sales documents | CreateCustomer, CreateSalesHeader, CreateSalesLine |
| Library - Purchase | Purchase documents | CreateVendor, CreatePurchaseHeader, CreatePurchaseLine |
| Library - Inventory | Items, inventory | CreateItem, CreateItemJournalLine, PostItemJournalLine |
| Library - ERM | Finance, posting setup | FindVATPostingSetup, CreateGLAccount |
| Library - Manufacturing | Production | CreateProductionOrder, CreateProductionBOMHeader |
| Library - Warehouse | Warehouse | CreateLocation, CreateWarehouseReceipt |
| Library - Utility | General utilities | GenerateGUID, GetGlobalNoSeriesCode |
| Library - Random | Random data | RandInt, RandDec, RandDate |
| Library - Variable Storage | State between handlers | Enqueue, Dequeue, AssertEmpty |
| Library Assert | Assertions | AreEqual, IsTrue, ExpectedError |
