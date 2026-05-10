# AL Environment Interface Patterns

Three default decoupling seams every BC app has. When the three-phase decoupling refactor (see `decoupling.md`) declares an interface, it is almost always one of these three categories — reach for the named pattern first.

## Three Seams

| Seam | Interface | Production impl | Stub impl |
|---|---|---|---|
| System environment | `"IEnvironment"` | `"App Environment"` | `"Stub Environment"` |
| External APIs | `"IApiRequest"` | `"App Api Request"` | `"Stub Api Request"` |
| Standard Application | `"IFinance"` (example) | `"App Finance"` | `"Stub Finance"` |

## Naming Convention

- **Interface**: `"I<Concept>"` — e.g., `"IEnvironment"`, `"IApiRequest"`
- **Production impl**: `"App <Concept>"` — ships in the production app
- **Stub impl**: `"Stub <Concept>"` — ships in the unit test app, **never in the production app**
- Multiple stub variants: `"Stub <Variant> <Concept>"` — e.g., `"Stub Production Environment"`, `"Stub Test Environment"`

Apply your AppSource prefix to every object name when shipping; examples here drop it for clarity.

## Stub Location Rule (mechanical)

Find the interface's `.Interface.al` file and read its location:

- Interface in the production app → stub in the unit test app's `Stubs/<InterfaceName>/` folder
- Interface in the unit test app → stub co-located with the test codeunit

No judgment call. The file's location decides.

## IEnvironment

```al
interface "IEnvironment"
{
    procedure SystemEnvironment(): Enum "System Environment"
    procedure ThisCompanyName(): Text[30]
    procedure IsEvaluationCompany(): Boolean
}
```

Stubs return fixed values — no real `EnvironmentInformation` codeunit or `Company` table access.

ApplicationState derivation: Production requires all three (`SystemEnvironment = Production` AND `not IsEvaluationCompany` AND `Licensee = ThisCompanyName`). Test requires only `Licensee = ThisCompanyName`. This enables a company-copy safety subscriber that clears `Licensee` on copied companies, preventing them from running in Production state.

## IApiRequest — Setup-Then-Return Pattern

```al
interface "IApiRequest"
{
    procedure Send(RequestMethod: Enum "Api Method"; RequestUrl: Text; Payload: Text;
        SecretKey: SecretText; var ResponseStatusCode: Integer; var ResponseContent: Text)
}

codeunit 50100 "Stub Api Request" implements "IApiRequest"
{
    var
        StatusCode: Integer;
        Content: Text;

    internal procedure SetupResponse(Code: Integer; Body: Text)
    begin
        StatusCode := Code;
        Content := Body;
    end;

    procedure Send(RequestMethod: Enum "Api Method"; RequestUrl: Text; Payload: Text;
        SecretKey: SecretText; var ResponseStatusCode: Integer; var ResponseContent: Text)
    begin
        ResponseStatusCode := StatusCode;
        ResponseContent := Content;
    end;
}
```

Two-step test pattern: call `SetupResponse(200, jsonBody)` before the SUT; `Send()` returns the pre-configured values. Test how your code reacts to the response — not whether the API works.

## IFinance (Standard Application Seam)

Hides BaseApp G/L calls: `Gen. Journal Line` `Validate()` and `Insert(true)`, number-series allocation, posting-setup reads. All parameters are `var` — the stub returns data by overwriting the caller's variables (same store/restore pattern as `IApiRequest` but for record parameters).

Enables: unit tests that assert finance logic without G/L accounts, bank accounts, or posting setup in the database.

## Temporary Tables as a Cheaper Alternative

For logic that only depends on a record's own fields (not external calls): pass `var TempRecord: Record X temporary` instead of declaring an interface. Cheaper than a full interface extraction when the coupling is to a table, not an external system.

```al
// test setup — no database needed
TempSetup."Application State" := Enum::"Application State"::Production;
Encoders.EncodePhoneNumber(TempSetup, 'FieldKey', PhoneNumber, JsonObj);
```

## Decision Tree

```
Does the seam involve...
  ├─ BC runtime / OS environment?   → IEnvironment
  ├─ an external HTTP API?          → IApiRequest
  ├─ standard BC G/L / finance ops? → IFinance (or IPosting, ISales per seam)
  └─ a record's own data fields?    → var TempRecord (no interface needed)
```
