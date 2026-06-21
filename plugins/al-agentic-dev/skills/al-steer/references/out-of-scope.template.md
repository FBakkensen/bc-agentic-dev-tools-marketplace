# {Concept name}

This project does not support {concept}.

## Why this is out of scope

{Substantive reasoning: project scope, technical constraint, strategic decision, or a referenced ADR. Not a deferral.}

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
