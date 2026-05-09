# Probing standard BC and production flows via event subscribers

Reference for `/al-debug-logging` when the code under observation lives in BaseApp, the System Application, a third-party app, or any extension you cannot edit. The in-place `DEBUG-*` probe pattern needs source access. Subscribe to the events the inaccessible code already publishes; emit `DEBUG-*` `FeatureTelemetry.LogUsage` calls from your subscriber. The subscriber is itself a probe — attached to a real published extension point.

Pattern is general. Any BC subsystem that publishes events — sales/purchase posting, item journal posting, warehouse, manufacturing, document handling, dimensions, jobs, intercompany — can be observed this way.

## When to use

- A standard BC flow produces the wrong result and you cannot tell which BaseApp branch ran.
- A subscriber elsewhere (yours or a third party's) is suspected of firing or not firing.
- Posting / validation / installation appears correct in source but goes wrong at runtime.
- Inaccessible code does *something* between two of your own probes and you need a probe in the middle.

When you do control the source, use an in-place probe. Closer to the decision, easier to remove.

## Find the event

Use `/bc-standard-reference` to locate published events near the suspected behaviour. Look for events on either side of the suspected branch (`OnBefore*` and `OnAfter*` of the same operation) so the order in `telemetry.jsonl` reveals which path ran.

## Pattern

Place the subscriber codeunit in a non-shipping extension of your project (so it does not reach production). Prefix every emitted event ID with `DEBUG-BC-` so cleanup is one `rg`:

```al
codeunit 50XXX "Debug [Subsystem] Subsc"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"[BC Codeunit]", '[EventName]', '', false, false)]
    local procedure OnAfter[Event](var [Params])
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage(
            'DEBUG-BC-[SUBSYSTEM]-[EVENT]',
            '[Investigation]',
            StrSubstNo('[Shape, not contents]: %1', [RelevantValue]));
    end;
}
```

Run whatever harness exercises the BaseApp flow (posting a document, running a workflow, opening a page action), then read `.output/TestResults/*/telemetry.jsonl`:

```text
rg "DEBUG-BC-" .output/TestResults/*/telemetry.jsonl
```

```powershell
Select-String -Path .output/TestResults/*/telemetry.jsonl -Pattern "DEBUG-BC-"
```

When the investigation is done, delete the subscriber codeunit. Scaffolding, not production code.

## Example: BC pricing engine

Subscribe to `Price Calculation - V16` to find out whether the V16 calculator was selected and what amount it returned. Same shape works for any BC subsystem.

```al
codeunit 50105 "Debug Price Subsc"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Price Calculation - V16", 'OnAfterFindLines', '', false, false)]
    local procedure OnAfterFindLines(var PriceListLine: Record "Price List Line"; AmountType: Enum "Price Amount Type"; var IsHandled: Boolean)
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage('DEBUG-BC-PRICING-FINDLINES', 'PricingDiag',
            StrSubstNo('Found %1 lines, IsHandled=%2', PriceListLine.Count(), IsHandled));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Price Calculation - V16", 'OnAfterCalcBestAmount', '', false, false)]
    local procedure OnAfterCalcBestAmount(var PriceListLine: Record "Price List Line")
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage('DEBUG-BC-PRICING-BESTAMOUNT', 'PricingDiag',
            StrSubstNo('BestAmount: UnitPrice=%1, Status=%2', PriceListLine."Unit Price", PriceListLine.Status));
    end;
}
```

`telemetry.jsonl` after the run showed neither subscriber fired. The silence was the diagnosis: the V16 calculator was not enabled. The fix lived elsewhere:

```al
LibraryPriceCalculation.EnableExtendedPriceCalculation();
LibraryPriceCalculation.SetupDefaultHandler("Price Calculation Handler"::"Business Central (Version 16.0)");
```

A negative result is a result. The probe does not need to *catch* something to answer the question.

## Subsystem starting points

| Subsystem | Example events to subscribe |
|---|---|
| Sales Posting | `OnAfterPostSalesDoc`, `OnBeforePostSalesDoc` in `Sales-Post` |
| Purchase Posting | `OnAfterPostPurchaseDoc`, `OnBeforePostPurchaseDoc` in `Purch.-Post` |
| Inventory | `OnAfterPostItemJnlLine` in `Item Jnl.-Post Line` |
| Warehouse | `OnAfterCreateWhseJnlLine` in `Whse. Jnl.-Register Line` |
| Manufacturing | `OnAfterPostProdOrder` in `Production Order-Post` |
| Document approvals | Workflow event publishers in `Workflow Mgt.` |

Use both pre- and post-event variants when you want to see which side of an operation a behaviour lives on.

## Hygiene

- Subscriber probes are temporary scaffolding. Delete the codeunit when done.
- `DEBUG-BC-*` prefix distinguishes these from in-place `DEBUG-*` probes and from production telemetry.
- Subscriber lives in a non-shipping extension. Never reaches production.
- Drop list: full record bodies, customer data, secrets, tokens, credentials. Counts, IDs, enum values, booleans only — shape, not contents.
- Same-publisher constraint applies. Subscriber's extension publisher must match the Telemetry Logger's publisher. See [telemetry-workflow.md](telemetry-workflow.md).
- A `DEBUG-ENTRY` probe in your harness, paired with `DEBUG-BC-*` probes in the subscriber, gives per-scenario timelines in `telemetry.jsonl`.
