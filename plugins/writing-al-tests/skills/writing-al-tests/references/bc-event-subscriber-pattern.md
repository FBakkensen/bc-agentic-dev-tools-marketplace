# BC Event Subscriber Telemetry Pattern

When tests fail because standard BC code isn't behaving as expected, we can't add DEBUG telemetry directly to BC code. Instead, we create temporary event subscribers that emit telemetry from BC's published events.

This pattern applies to **any BC subsystem**—pricing, posting, warehouse, manufacturing, etc. The pricing engine example below is just one application of a universal debugging technique.

## When to Use

- BC subsystem returns unexpected values (pricing engine, posting routines, document handling, etc.)
- Need to understand which BC code paths are executing
- Standard BC behavior is opaque and assertions alone can't diagnose the issue
- Any situation where you need visibility into what standard BC is doing internally

## Finding Relevant BC Events

Use the [bc-standard-reference skill](../../bc-standard-reference/SKILL.md) to locate events in the subsystem you are debugging.

## Implementation Steps

1. **Find relevant BC events**

2. **Create temporary debug subscriber codeunit** in test folder:

```al
codeunit 50XXX "Debug [Subsystem] Subsc"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"[BC Codeunit]", '[EventName]', '', false, false)]
    local procedure OnAfter[Event](var [Params])
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage('DEBUG-BC-[SUBSYSTEM]-[EVENT]', '[Area]',
            StrSubstNo('[Description]: %1', [RelevantValue]));
    end;
}
```

3. **Run tests and analyze telemetry.jsonl** — Correlate BC events with test execution:

```text
# Example (rg)
rg "DEBUG-BC-" .output/TestResults/telemetry.jsonl
```

```powershell
# Example (PowerShell)
Select-String -Path .output/TestResults/telemetry.jsonl -Pattern "DEBUG-BC-"
```

4. **Delete the subscriber codeunit after debugging** — It's temporary scaffolding, not production code.

## Example: BC Pricing Engine

This example shows debugging the Price Calculation - V16 codeunit, but the same approach works for any BC subsystem (posting codeunits, document management, inventory, etc.):

```al
codeunit 50105 "Debug Price Subsc"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Price Calculation - V16", 'OnAfterFindLines', '', false, false)]
    local procedure OnAfterFindLines(var PriceListLine: Record "Price List Line"; AmountType: Enum "Price Amount Type"; var IsHandled: Boolean)
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage('DEBUG-BC-PRICING-FINDLINES', 'Pricing',
            StrSubstNo('Found %1 lines, IsHandled=%2', PriceListLine.Count(), IsHandled));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Price Calculation - V16", 'OnAfterCalcBestAmount', '', false, false)]
    local procedure OnAfterCalcBestAmount(var PriceListLine: Record "Price List Line")
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
    begin
        FeatureTelemetry.LogUsage('DEBUG-BC-PRICING-BESTAMOUNT', 'Pricing',
            StrSubstNo('BestAmount: UnitPrice=%1, Status=%2', PriceListLine."Unit Price", PriceListLine.Status));
    end;
}
```

This revealed the V16 pricing engine wasn't enabled—leading to the fix:

```al
LibraryPriceCalculation.EnableExtendedPriceCalculation();
LibraryPriceCalculation.SetupDefaultHandler("Price Calculation Handler"::"Business Central (Version 16.0)");
```

## Other Subsystem Examples

The same pattern applies to any BC area:

| Subsystem | Example Events to Subscribe |
|-----------|----------------------------|
| Sales Posting | `OnAfterPostSalesDoc`, `OnBeforePostSalesDoc` in "Sales-Post" |
| Purchase Posting | `OnAfterPostPurchaseDoc`, `OnBeforePostPurchaseDoc` in "Purch.-Post" |
| Inventory | `OnAfterPostItemJnlLine` in "Item Jnl.-Post Line" |
| Warehouse | `OnAfterCreateWhseJnlLine` in "Whse. Jnl.-Register Line" |
| Manufacturing | `OnAfterPostProdOrder` in "Production Order-Post" |

## Key Points

- Subscriber codeunits are **temporary**—delete after debugging
- Use `DEBUG-BC-*` prefix to distinguish from app telemetry
- Place in test folder (not app folder) to avoid shipping debug code
- Combine with test-start telemetry to correlate BC events to specific tests
- Find relevant events before creating subscribers
- This pattern works for **any BC subsystem**, not just pricing
