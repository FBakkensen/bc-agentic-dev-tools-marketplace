codeunit 50024 "Test Template"
{
    // ------------------------------------------------------------------------------------------------
    // TEST TEMPLATE INSTRUCTIONS
    // ------------------------------------------------------------------------------------------------
    // 1. COPY this file to the appropriate folder in test/src/ (e.g., Workflows/<Feature>/ or Components/<Component>/).
    // 2. RENAME the file to <Feature>Test.Codeunit.al.
    // 3. RENAME the codeunit object to "<Feature> Test" and assign a new ID (see al-object-id-allocator).
    // 4. IMPLEMENT tests using the Gherkin pattern (Scenario, Given, When, Then).
    // 5. USE "Library Assert" for verifications. NEVER use Error() or Message().
    //
    // TRANSACTION MODEL GUIDANCE (based on Microsoft BC standard test patterns):
    // - DEFAULT: Do NOT specify [TransactionModel] — let the TestRunner handle isolation.
    //   Microsoft's 40,000+ standard tests use this approach (~97% have no TransactionModel).
    // - EXCEPTION: Add [TransactionModel(AutoRollback)] only for pure logic tests that MUST NOT call Commit().
    // - EXCEPTION: Add [TransactionModel(AutoCommit)] only when testing code that calls Commit() (posting, job queue).
    // ------------------------------------------------------------------------------------------------

    Subtype = Test;
    Access = Internal;

    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
        IsInitialized: Boolean;

    // -------------------------------------------------------------------------
    // STANDARD TEST PATTERN (Default - follows Microsoft BC conventions)
    // Use for: Most tests — codeunits, tables, calculations, business logic
    // No TransactionModel specified — TestRunner's TestIsolation handles rollback
    // -------------------------------------------------------------------------

    [Test]
    procedure GivenPrecondition_WhenAction_ThenExpectedResult()
    begin
        // [SCENARIO] <Description of the scenario>
        FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', 'GivenPrecondition_WhenAction_ThenExpectedResult');
        Initialize();

        // [GIVEN] <Preconditions>
        // Create setup data, mock dependencies

        // [WHEN] <Action is performed>
        // Execute the code under test

        // [THEN] <Expected outcome is verified>
        // Assert.AreEqual(Expected, Actual, 'Message');
    end;

    // -------------------------------------------------------------------------
    // AUTOROLLBACK TEST PATTERN (Exception - use sparingly)
    // Use ONLY for: Pure logic tests where code MUST NOT call Commit()
    // Will ERROR if code under test calls Commit() — this is intentional
    // -------------------------------------------------------------------------

    /*
    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    procedure GivenPureLogic_WhenCalculated_ThenNoCommitAllowed()
    begin
        // [SCENARIO] Testing pure calculation logic that must not touch committed data
        FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', 'GivenPureLogic_WhenCalculated_ThenNoCommitAllowed');
        Initialize();

        // [GIVEN] <Preconditions>
        // [WHEN] <Action is performed>
        // [THEN] <Expected outcome is verified>
    end;
    */

    // -------------------------------------------------------------------------
    // AUTOCOMMIT TEST PATTERN (Exception - for posting/background scenarios)
    // Use ONLY for: Code that calls Commit() (posting routines, job queue, background sessions)
    // REQUIRES explicit cleanup — data persists after test
    // -------------------------------------------------------------------------

    /*
    [Test]
    [TransactionModel(TransactionModel::AutoCommit)]
    // [HandlerFunctions('ConfirmHandler,MessageHandler')] // Add handlers if needed
    procedure GivenDocument_WhenPosted_ThenLedgerEntriesCreated()
    var
        // SalesHeader: Record "Sales Header";
    begin
        // [SCENARIO] Testing posting routine that calls Commit()
        FeatureTelemetry.LogUsage('DEBUG-TEST-START', 'Testing', 'GivenDocument_WhenPosted_ThenLedgerEntriesCreated');
        Initialize(); // Must include DeleteKnownTestRecords() and Commit()

        // [GIVEN] <Preconditions>
        // Create setup data

        // [WHEN] <Posting action is performed>
        // LibrarySales.PostSalesDocument(SalesHeader, true, true);

        // [THEN] <Ledger entries exist>
        // Verify posted entries

        // Cleanup (REQUIRED for AutoCommit - data persists!)
        // DeleteKnownTestRecords();
    end;
    */

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;

        // [AUTOCOMMIT TESTS ONLY]
        // If using [TransactionModel(AutoCommit)], you MUST:
        // 1. Call DeleteKnownTestRecords() here to clean up from previous runs
        // 2. Call Commit() after setup
        //
        // DeleteKnownTestRecords();
        // Commit();

        // Common setup for all tests in this codeunit

        IsInitialized := true;
    end;

    // [AUTOCOMMIT TESTS ONLY]
    // local procedure DeleteKnownTestRecords()
    // begin
    //     // Delete records created by tests to ensure a clean state
    //     // Example:
    //     // SalesHeader.SetRange("Sell-to Customer No.", TestCustomerNo);
    //     // SalesHeader.DeleteAll(true);
    // end;
}
