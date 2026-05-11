# ZOMBIES Scenario Ordering

Use ZOMBIES to build a scenario list bottom-up. This order surfaces edge cases that happy-path-first planning misses. Cited by `/al-refine` before writing any test.

## The Acronym

| Letter | Category | AL example |
|---|---|---|
| **Z** | Zero / empty | Empty configuration, zero attribute lines, no matching rule, empty rule set |
| **O** | One | Single attribute line, one rule entry, first sub-configuration, single mapping |
| **M** | Many | Full rule set, batch of headers, multiple simultaneous attribute updates |
| **B** | Boundary | Period cutoff date, max/min field values, exact threshold match, last day of posting period |
| **I** | Interface | Implementer substitution, different stub injected per scenario (unit layer) |
| **E** | Exceptional | Error paths: blocked record, missing setup, permission denied, duplicate key, invalid state |
| **S** | Simple | The happy path, named last because it is never the most revealing |

## Application

Write **Zero first**. If the system can't handle empty input, everything else is irrelevant. Then One, Many, Boundary, Interface, Exceptional. Simple scenarios (S) are a hygiene check, write them last.

A scenario list that only covers S is a demo script, not a test plan.

## Anti-pattern

Writing scenarios top-down from the feature description: "User creates a configuration, edits it, copies it, deletes it." This covers only S and misses the entire ZOMBIES spectrum. Start from Zero and work forward.

## Scenario naming

Each ZOMBIES scenario becomes one short PascalCase test name (BaseApp style, see `/al-refine`):
- Z: `RuleSetWithNoEntriesReturnsDefault`
- O: `RuleSetWithSingleEntryMatchesExactly`
- B: `RuleSetBoundaryValueMatchesUpperLimit`
- E: `RuleSetWithBlockedRecordThrowsError`
- S: `RuleSetCopyPreservesIntervals`
