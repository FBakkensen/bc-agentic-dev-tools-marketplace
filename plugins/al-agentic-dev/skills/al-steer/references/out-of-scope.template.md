# {Concept name}

This project does not support {concept}.

## Why this is out of scope

{One or two paragraphs of substantive reasoning. Reference project scope or philosophy ("This extension focuses on rental contract posting; multi-currency rounding is a downstream G/L concern"), technical constraints ("Supporting this would require a second posting routine that bypasses `Gen. Jnl.-Post Line`, which conflicts with our R → P → W boundary"), strategic decisions ("We chose to model intervals as a separate table per ADR-007 instead of date ranges on the contract line"), or a referenced ADR.

Avoid temporary circumstances ("we're too busy right now", "wait for the next release"), those aren't real rejections, they're deferrals.}

```al
// Optional: a code shape that illustrates why the request doesn't fit.
codeunit 50100 "Rental Post"
{
    // The current posting routine assumes a single-currency contract;
    // it resolves amounts against the contract header LCY before
    // dispatching to Gen. Jnl.-Post Line.
    procedure Post(RentalHeader: Record "Rental Header")
    begin
        // ...
    end;
}
```

## Prior requests

- {issue / branch / conversation reference}, "{short title}"
- {issue / branch / conversation reference}, "{short title}"
