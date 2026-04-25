# Probing Standard BC and Production Flows via Event Subscribers

The `DEBUG-*` probe pattern works well when you control the source. When the code you need to observe lives in BaseApp, the System Application, or any extension you cannot edit (a third-party app, a customer-side extension, a previous version of your own code in production), you cannot drop probes into it directly.

The workaround: subscribe to the events the inaccessible code already publishes, and emit `DEBUG-*` `FeatureTelemetry.LogUsage` calls from your subscriber. The subscriber is itself a probe — an *advanced* probe attached to a real, published extension point in the inaccessible code.

This pattern is general. Any BC subsystem that publishes events — sales/purchase posting, item journal posting, warehouse, manufacturing, document handling, dimensions, jobs, intercompany — can be observed this way.

## When to Use

Reach for an event-subscriber probe when:

- A standard BC flow is producing the wrong result and you cannot tell which BaseApp branch ran.
- A subscriber elsewhere (yours or a third party's) is suspected of firing or not firing.
- Posting / validation / installation appears correct in the source but goes wrong at runtime.
- The inaccessible code does *something* between two of your own probes and you need a probe in the middle.

When you *do* control the source, prefer an in-place probe — it is closer to the decision and easier to remove.

## Finding the Right Event

Use the `/bc-standard-reference` skill to locate published events near the behavior you are debugging. Look for events on either side of the suspected branch (`OnBefore*` and `OnAfter*` of the same operation) so the order of probes in `telemetry.jsonl` reveals which path ran.

## Pattern

Place the subscriber codeunit in a non-shipping extension of your project (so it does not reach production), and prefix every emitted event ID with `DEBUG-` so cleanup is trivial:

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

Run whatever harness exercises the BaseApp flow (posting a document, running a workflow, opening a page action), then read `.output/TestResults/telemetry.jsonl`:

```text
rg "DEBUG-BC-" .output/TestResults/telemetry.jsonl
```

```powershell
Select-String -Path .output/TestResults/telemetry.jsonl -Pattern "DEBUG-BC-"
```

When the investigation is done, delete the subscriber codeunit. It is scaffolding, not production code.

## Example: Diagnosing the BC Pricing Engine

The example below subscribes to `Price Calculation - V16` to find out whether the V16 calculator was actually selected and what amount it returned. The same shape works for any BC subsystem.

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

Inspecting `telemetry.jsonl` after a run revealed the V16 engine was never reached at all — the subscriber's events never fired. That negative result was the diagnosis: the V16 calculator was not enabled. The fix lived elsewhere:

```al
LibraryPriceCalculation.EnableExtendedPriceCalculation();
LibraryPriceCalculation.SetupDefaultHandler("Price Calculation Handler"::"Business Central (Version 16.0)");
```

The probe did not need to *catch* something — its silence was the answer.

## Other Subsystem Examples

The same shape applies to any BC area:

| Subsystem | Example Events to Subscribe |
|-----------|----------------------------|
| Sales Posting | `OnAfterPostSalesDoc`, `OnBeforePostSalesDoc` in `Sales-Post` |
| Purchase Posting | `OnAfterPostPurchaseDoc`, `OnBeforePostPurchaseDoc` in `Purch.-Post` |
| Inventory | `OnAfterPostItemJnlLine` in `Item Jnl.-Post Line` |
| Warehouse | `OnAfterCreateWhseJnlLine` in `Whse. Jnl.-Register Line` |
| Manufacturing | `OnAfterPostProdOrder` in `Production Order-Post` |
| Document approvals | Workflow event publishers in `Workflow Mgt.` |

Look for both pre- and post-event variants whenever you want to see *which side* of an operation a behavior lives on.

## Hygiene

- Subscriber probes are temporary scaffolding — delete the subscriber codeunit when done.
- Keep `DEBUG-BC-*` as the prefix for these probes. It distinguishes them from in-place `DEBUG-*` probes and from production telemetry.
- Place the subscriber in a non-shipping extension so it never reaches production.
- Log shape, not contents (counts, IDs, enum values, booleans). Do not log full record bodies, customer data, or anything sensitive.
- Same-publisher constraint applies: the subscriber must live in an extension whose publisher matches the publisher hosting the Telemetry Logger. See [telemetry-workflow.md](telemetry-workflow.md).
- A `DEBUG-ENTRY` probe in your harness, paired with the `DEBUG-BC-*` probes in the subscriber, gives you per-scenario timelines in `telemetry.jsonl`.
