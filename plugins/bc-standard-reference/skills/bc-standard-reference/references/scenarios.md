# Scenario Walkthroughs

## Force a Specific Customer Price in V16 Price Calculation

### Step 1: Identify Standard Objects and Events

Focus on standard pricing codeunits and events:
- `Price Calculation - V16`
- `Sales Line - Price`
- `Price Calculation Mgt.`

### Step 2: Narrow Scope (Optional)

If you have extension code, search it for existing pricing event subscribers (e.g., `OnAfterCalcBestAmount`) to align with current behavior and signatures.

### Step 3: Confirm in the Standard Source

Search the standard mirror for `Price Calculation - V16` within the Pricing domain. Open the file and inspect:
- How price sources are selected
- Which events are published during calculation
- The best hook point to enforce a customer-specific price

---

## Block Partial Posting of Sales Orders

### Step 1: Identify Posting Codeunits

Focus on standard posting codeunits:
- `Sales-Post`
- `Sales-Post (Yes/No)`

### Step 2: Locate the Posting Event

Search the standard mirror for the posting events (e.g., `OnBeforePostSalesDoc`) within `Sales/Posting`. Open the file and confirm where validation happens before posting.

### Step 3: Validate the Event Choice

Confirm the event signature and check whether your extension already subscribes to a related posting event to avoid duplicate logic.

---

## Find Events That Fire During Sales Order Release

### Step 1: Find the Release Codeunit

Identify the standard codeunit `Release Sales Document`.

### Step 2: List Events in the Codeunit

Search within the codeunit for event publishers and `OnBefore`/`OnAfter` procedures to find release-related events.

### Step 3: Inspect the Implementation

Open the file in the standard mirror and trace the release flow to see exactly when each event fires.

---

## Understand Standard Test Setup for Sales Documents

### Step 1: Find the Test Library

Locate the test library `Library - Sales`.

### Step 2: Find Helper Methods

Look for helper procedures such as `CreateSalesOrder` and other setup utilities.

### Step 3: View Implementation

Open the library in the standard mirror to see how standard tests set up sales documents and related data.
