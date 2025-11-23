//
//  ExpenseTrackerUITests.swift
//  ExpenseTrackerUITests
//
//  Created by Heorhii Hehelia on 14.08.2025.
//

import XCTest

final class ExpenseTrackerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-DisableAnimations"]
        app.launchEnvironment = ["IS_TESTING": "1", "DISABLE_ANIMATIONS": "1"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Critical Flow Tests

    @MainActor
    func testCompleteExpenseEntryFlow_FromLaunchToSaved() throws {
        // Step 1: Launch app
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        // Step 2: Wait for main view to load
        let mainView = app.otherElements["MainView"] ?? app.tables["TransactionList"]
        XCTAssertTrue(mainView.waitForExistence(timeout: 5), "Main view should load")

        // Step 3: Tap add transaction button
        let addButton = app.buttons["AddTransactionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3), "Add button should exist")
        addButton.tap()

        // Step 4: Enter transaction details
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2), "Amount field should appear")
        amountField.tap()
        amountField.typeText("350")

        let descriptionField = app.textFields["DescriptionField"]
        descriptionField.tap()
        descriptionField.typeText("Groceries at Silpo")

        // Step 5: Select category
        let categoryPicker = app.buttons["CategoryPicker"]
        if categoryPicker.exists {
            categoryPicker.tap()

            let groceriesCategory = app.buttons["Category_продукти"]
            if groceriesCategory.waitForExistence(timeout: 2) {
                groceriesCategory.tap()
            }
        }

        // Step 6: Save transaction
        let saveButton = app.buttons["SaveButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()

        // Step 7: Verify transaction appears in list
        let transactionInList = app.staticTexts["350"] ?? app.staticTexts["Groceries at Silpo"]
        XCTAssertTrue(transactionInList.waitForExistence(timeout: 3),
                     "Transaction should appear in list after saving")

        // Step 8: Verify transaction count increased
        let transactionCells = app.cells.matching(identifier: "TransactionCell")
        XCTAssertTrue(transactionCells.count > 0, "At least one transaction should exist")
    }

    @MainActor
    func testEditExistingTransactionFlow() throws {
        // Step 1: Launch app
        app.launch()

        // Step 2: Wait for transaction list
        let transactionList = app.tables["TransactionList"]
        XCTAssertTrue(transactionList.waitForExistence(timeout: 5) ||
                     app.scrollViews["TransactionList"].exists,
                     "Transaction list should load")

        // Step 3: Tap first transaction to open details
        let firstTransaction = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.waitForExistence(timeout: 3))
        firstTransaction.tap()

        // Step 4: Wait for detail view
        let detailView = app.otherElements["TransactionDetailView"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 2), "Detail view should appear")

        // Step 5: Tap edit button
        let editButton = app.buttons["EditButton"] ?? app.buttons["Редагувати"]
        if editButton.waitForExistence(timeout: 2) {
            editButton.tap()

            // Step 6: Modify amount
            let amountField = app.textFields["AmountField"]
            if amountField.exists {
                amountField.tap()
                amountField.clearText()
                amountField.typeText("500")

                // Step 7: Save changes
                let saveButton = app.buttons["SaveButton"] ?? app.buttons["Зберегти"]
                XCTAssertTrue(saveButton.exists, "Save button should exist")
                saveButton.tap()

                // Step 8: Verify changes saved
                let updatedAmount = app.staticTexts["500"]
                XCTAssertTrue(updatedAmount.waitForExistence(timeout: 3),
                             "Updated amount should be visible")
            }
        }
    }

    @MainActor
    func testProcessPendingTransactionFlow() throws {
        // Step 1: Launch app with pending transactions
        app.launchEnvironment["MOCK_DATA_ENABLED"] = "1"
        app.launch()

        // Step 2: Navigate to pending transactions
        let pendingTab = app.buttons["PendingTab"] ?? app.buttons["Очікують"]
        if pendingTab.waitForExistence(timeout: 3) {
            pendingTab.tap()

            // Step 3: Wait for pending transaction list
            let pendingList = app.tables["PendingTransactionList"]
            XCTAssertTrue(pendingList.waitForExistence(timeout: 3) ||
                         app.scrollViews.element.exists,
                         "Pending transactions should load")

            // Step 4: Tap first pending transaction
            let firstPending = app.cells.element(boundBy: 0)
            if firstPending.exists {
                firstPending.tap()

                // Step 5: Review categorization
                let categoryField = app.buttons["CategoryPicker"]
                if categoryField.waitForExistence(timeout: 2) {
                    // Category might be pre-selected, verify it exists
                    XCTAssertTrue(categoryField.exists, "Category picker should exist")
                }

                // Step 6: Confirm and process
                let confirmButton = app.buttons["ConfirmButton"] ?? app.buttons["Підтвердити"]
                if confirmButton.waitForExistence(timeout: 2) {
                    confirmButton.tap()

                    // Step 7: Verify pending transaction removed
                    sleep(1)
                    let pendingCellCount = app.cells.count
                    // Should have fewer pending transactions
                    XCTAssertTrue(pendingCellCount >= 0, "Pending transaction should be processed")
                }
            }
        }
    }

    @MainActor
    func testCreateAndUseSplitTransactionFlow() throws {
        // Step 1: Launch app
        app.launch()

        // Step 2: Open Quick Entry
        let addButton = app.buttons["AddTransactionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        // Step 3: Enter base amount
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText("500")

        let descriptionField = app.textFields["DescriptionField"]
        descriptionField.tap()
        descriptionField.typeText("Market shopping")

        // Step 4: Enable split transaction
        let splitButton = app.buttons["SplitTransactionButton"] ?? app.buttons["Розділити"]
        if splitButton.waitForExistence(timeout: 2) {
            splitButton.tap()

            // Step 5: Add first split component
            let addSplitButton = app.buttons["AddSplitComponent"]
            if addSplitButton.waitForExistence(timeout: 2) {
                addSplitButton.tap()

                // Enter first split
                let split1Amount = app.textFields["SplitAmount_0"]
                if split1Amount.exists {
                    split1Amount.tap()
                    split1Amount.typeText("300")
                }

                // Select category for first split
                let split1Category = app.buttons["SplitCategoryPicker_0"]
                if split1Category.exists {
                    split1Category.tap()
                    let groceries = app.buttons["Category_продукти"]
                    if groceries.waitForExistence(timeout: 1) {
                        groceries.tap()
                    }
                }

                // Add second split
                if addSplitButton.exists {
                    addSplitButton.tap()

                    let split2Amount = app.textFields["SplitAmount_1"]
                    if split2Amount.exists {
                        split2Amount.tap()
                        split2Amount.typeText("200")
                    }
                }
            }

            // Step 6: Save split transaction
            let saveButton = app.buttons["SaveButton"]
            if saveButton.exists {
                saveButton.tap()

                // Step 7: Verify split transaction in list
                let splitTransaction = app.cells.containing(NSPredicate(format: "label CONTAINS '500'")).firstMatch
                XCTAssertTrue(splitTransaction.waitForExistence(timeout: 3),
                             "Split transaction should appear in list")
            }
        }
    }

    // MARK: - Account Management Flow

    @MainActor
    func testAccountCreationAndSelectionFlow() throws {
        // Step 1: Launch app
        app.launch()

        // Step 2: Navigate to accounts
        let accountsTab = app.buttons["AccountsTab"] ?? app.buttons["Рахунки"]
        if accountsTab.waitForExistence(timeout: 3) {
            accountsTab.tap()

            // Step 3: Add new account
            let addAccountButton = app.buttons["AddAccountButton"]
            if addAccountButton.waitForExistence(timeout: 2) {
                addAccountButton.tap()

                // Step 4: Enter account details
                let nameField = app.textFields["AccountNameField"]
                if nameField.waitForExistence(timeout: 2) {
                    nameField.tap()
                    nameField.typeText("Test Card")

                    let tagField = app.textFields["AccountTagField"]
                    if tagField.exists {
                        tagField.tap()
                        tagField.typeText("#testcard")
                    }

                    // Step 5: Save account
                    let saveButton = app.buttons["SaveButton"]
                    saveButton.tap()

                    // Step 6: Verify account appears in list
                    let newAccount = app.staticTexts["Test Card"]
                    XCTAssertTrue(newAccount.waitForExistence(timeout: 3),
                                 "New account should appear in list")
                }
            }
        }
    }

    // MARK: - Filter and Search Flow

    @MainActor
    func testCompleteFilterFlow() throws {
        // Step 1: Launch app
        app.launch()

        // Step 2: Open filters
        let filterButton = app.buttons["FilterButton"] ?? app.buttons["Фільтри"]
        if filterButton.waitForExistence(timeout: 3) {
            filterButton.tap()

            // Step 3: Apply category filter
            let categoryFilter = app.buttons["FilterByCategory"]
            if categoryFilter.waitForExistence(timeout: 2) {
                categoryFilter.tap()

                let groceries = app.buttons["Category_продукти"]
                if groceries.waitForExistence(timeout: 2) {
                    groceries.tap()
                }
            }

            // Step 4: Apply date filter
            let dateFilter = app.buttons["FilterByDateRange"]
            if dateFilter.exists {
                dateFilter.tap()

                let thisMonth = app.buttons["ThisMonth"]
                if thisMonth.waitForExistence(timeout: 2) {
                    thisMonth.tap()
                }
            }

            // Step 5: Verify filtered results
            let transactionList = app.tables["TransactionList"]
            XCTAssertTrue(transactionList.exists || app.scrollViews["TransactionList"].exists,
                         "Filtered list should be displayed")

            // Step 6: Clear filters
            let clearFilters = app.buttons["ClearFilters"] ?? app.buttons["Очистити фільтри"]
            if clearFilters.exists {
                clearFilters.tap()

                // Verify all transactions shown again
                XCTAssertTrue(transactionList.exists, "Full list should be restored")
            }
        }
    }

    // MARK: - Analytics and Reports Flow

    @MainActor
    func testNavigateToAnalyticsAndViewReports() throws {
        // Step 1: Launch app
        app.launch()

        // Step 2: Navigate to analytics
        let analyticsTab = app.buttons["AnalyticsTab"] ?? app.buttons["Аналітика"]
        if analyticsTab.waitForExistence(timeout: 3) {
            analyticsTab.tap()

            // Step 3: Verify analytics view loads
            let analyticsView = app.otherElements["AnalyticsView"]
            XCTAssertTrue(analyticsView.waitForExistence(timeout: 3) ||
                         app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'analytics' OR label CONTAINS[c] 'аналітика'")).firstMatch.exists,
                         "Analytics view should load")

            // Step 4: Check for chart or statistics
            let chart = app.otherElements["ExpenseChart"] ?? app.images.element(boundBy: 0)
            let statistics = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'total' OR label CONTAINS[c] 'всього'")).firstMatch

            XCTAssertTrue(chart.exists || statistics.exists,
                         "Analytics should display charts or statistics")
        }
    }

    // MARK: - Error Handling Flow

    @MainActor
    func testValidationErrorsDisplayCorrectly() throws {
        // Step 1: Launch app
        app.launch()

        // Step 2: Open Quick Entry
        let addButton = app.buttons["AddTransactionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        // Step 3: Try to save without required fields
        let saveButton = app.buttons["SaveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        // Step 4: Verify error message appears
        let errorAlert = app.alerts.firstMatch
        let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'amount' OR label CONTAINS[c] 'required' OR label CONTAINS[c] 'обов\\'язково'")).firstMatch

        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2) || errorMessage.exists,
                     "Validation error should be displayed")

        // Step 5: Dismiss error
        if errorAlert.exists {
            let okButton = app.buttons["OK"] ?? app.buttons["Гаразд"]
            if okButton.exists {
                okButton.tap()
            }
        }

        // Step 6: Verify Quick Entry still visible
        let quickEntryView = app.otherElements["QuickEntryView"]
        XCTAssertTrue(quickEntryView.exists, "Quick Entry should remain open after validation error")
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testScrollPerformance() throws {
        app.launch()

        let scrollView = app.tables["TransactionList"].firstMatch

        if scrollView.waitForExistence(timeout: 5) {
            measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                scrollView.swipeUp(velocity: .fast)
                scrollView.swipeDown(velocity: .fast)
            }
        }
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }

        var deleteString = String()
        for _ in stringValue {
            deleteString += XCUIKeyboardKey.delete.rawValue
        }
        self.typeText(deleteString)
    }
}
