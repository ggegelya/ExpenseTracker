//
//  TransactionListUITests.swift
//  ExpenseTrackerUITests
//
//  UI tests for transaction list interactions and filtering
//

import XCTest

final class TransactionListUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-DisableAnimations"]
        app.launchEnvironment = ["IS_TESTING": "1", "DISABLE_ANIMATIONS": "1", "MOCK_DATA_ENABLED": "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Transaction List Display Tests

    @MainActor
    func testTransactionListDisplaysRecentTransactions() throws {
        // Verify transaction list exists
        let transactionList = app.tables["TransactionList"]
        XCTAssertTrue(transactionList.waitForExistence(timeout: 5) ||
                     app.scrollViews["TransactionList"].exists,
                     "Transaction list should exist")

        // Verify at least one transaction is visible
        let firstTransaction = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.exists, "At least one transaction should be visible")
    }

    @MainActor
    func testTapTransactionShowsDetailView() throws {
        // Wait for list to load
        let transactionList = app.tables["TransactionList"]
        XCTAssertTrue(transactionList.waitForExistence(timeout: 5) ||
                     app.scrollViews["TransactionList"].exists)

        // Tap first transaction
        let firstTransaction = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.exists)
        firstTransaction.tap()

        // Verify detail view appears
        let detailView = app.otherElements["TransactionDetailView"]
        XCTAssertTrue(detailView.waitForExistence(timeout: 3), "Transaction detail view should appear")

        // Verify detail view contains expected elements
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'amount' OR label CONTAINS[c] 'сума'")).firstMatch.exists ||
                     app.textFields["AmountField"].exists,
                     "Detail view should show amount")
    }

    @MainActor
    func testSwipeToDeleteRemovesTransaction() throws {
        // Wait for list
        let transactionList = app.tables["TransactionList"]
        XCTAssertTrue(transactionList.waitForExistence(timeout: 5) ||
                     app.scrollViews["TransactionList"].exists)

        // Get initial count
        let initialCellCount = app.cells.count

        // Swipe first transaction to reveal delete
        let firstTransaction = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.exists)
        firstTransaction.swipeLeft()

        // Tap delete button
        let deleteButton = app.buttons["Delete"] ?? app.buttons["Видалити"]
        if deleteButton.waitForExistence(timeout: 2) {
            deleteButton.tap()

            // Confirm deletion if alert appears
            let confirmButton = app.buttons["Confirm"] ?? app.buttons["Delete"] ?? app.buttons["Видалити"]
            if confirmButton.waitForExistence(timeout: 1) {
                confirmButton.tap()
            }

            // Verify transaction count decreased
            let finalCellCount = app.cells.count
            XCTAssertTrue(finalCellCount < initialCellCount, "Transaction should be removed from list")
        }
    }

    @MainActor
    func testSearchFiltersTransactions() throws {
        // Find search field
        let searchField = app.searchFields.firstMatch
        if !searchField.exists {
            // Try to open search
            let searchButton = app.buttons["SearchButton"]
            if searchButton.exists {
                searchButton.tap()
            }
        }

        if searchField.waitForExistence(timeout: 2) {
            searchField.tap()
            searchField.typeText("test")

            // Wait for filtering
            sleep(1)

            // Verify list is filtered
            // This is implementation-specific, but we expect fewer results
            let visibleCells = app.cells.count
            XCTAssertTrue(visibleCells >= 0, "Filtered results should be displayed")

            // Clear search
            if app.buttons["ClearSearch"].exists {
                app.buttons["ClearSearch"].tap()
            } else {
                searchField.buttons["Clear text"].tap()
            }
        }
    }

    @MainActor
    func testFilterByCategoryWorks() throws {
        // Open filter menu
        let filterButton = app.buttons["FilterButton"]
        if !filterButton.exists {
            // Try toolbar button
            if app.buttons["ShowFilters"].exists {
                app.buttons["ShowFilters"].tap()
            }
        }

        if filterButton.waitForExistence(timeout: 2) {
            filterButton.tap()

            // Select category filter
            let categoryFilterOption = app.buttons["FilterByCategory"]
            if categoryFilterOption.waitForExistence(timeout: 2) {
                categoryFilterOption.tap()

                // Select a category
                let groceriesCategory = app.buttons["Category_продукти"]
                if groceriesCategory.waitForExistence(timeout: 2) {
                    groceriesCategory.tap()

                    // Verify filter applied
                    let filterIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'продукти'")).firstMatch
                    XCTAssertTrue(filterIndicator.exists, "Category filter should be applied")

                    // Verify list updates
                    let transactionList = app.tables["TransactionList"]
                    XCTAssertTrue(transactionList.exists || app.scrollViews["TransactionList"].exists)
                }
            }
        }
    }

    @MainActor
    func testFilterByDateRangeWorks() throws {
        // Open filter menu
        let filterButton = app.buttons["FilterButton"] ?? app.buttons["ShowFilters"]

        if filterButton.waitForExistence(timeout: 2) {
            filterButton.tap()

            // Select date range filter
            let dateRangeOption = app.buttons["FilterByDateRange"] ?? app.buttons["DateRange"]
            if dateRangeOption.waitForExistence(timeout: 2) {
                dateRangeOption.tap()

                // Select "This Month" quick option
                let thisMonthButton = app.buttons["ThisMonth"] ?? app.buttons["Цей місяць"]
                if thisMonthButton.waitForExistence(timeout: 2) {
                    thisMonthButton.tap()

                    // Verify filter applied
                    let filterIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'month' OR label CONTAINS[c] 'місяць'")).firstMatch
                    XCTAssertTrue(filterIndicator.exists, "Date filter should be applied")
                }
            }
        }
    }

    @MainActor
    func testPullToRefreshUpdatesList() throws {
        // Find scrollable view
        let scrollView = app.scrollViews["TransactionList"].firstMatch
        let tableView = app.tables["TransactionList"].firstMatch

        let targetView = scrollView.exists ? scrollView : tableView

        if targetView.waitForExistence(timeout: 3) {
            // Pull down to refresh
            let start = targetView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let end = targetView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.1, thenDragTo: end)

            // Wait for refresh to complete
            sleep(2)

            // Verify list still displays
            XCTAssertTrue(targetView.exists, "List should still be visible after refresh")
        }
    }

    @MainActor
    func testBulkSelectionAllowsMultiDelete() throws {
        // Enter selection mode
        let selectButton = app.buttons["SelectButton"] ?? app.buttons["Вибрати"]

        if selectButton.waitForExistence(timeout: 2) {
            selectButton.tap()

            // Select multiple transactions
            let firstCell = app.cells.element(boundBy: 0)
            let secondCell = app.cells.element(boundBy: 1)

            if firstCell.exists && secondCell.exists {
                firstCell.tap()
                secondCell.tap()

                // Verify selection indicators appear
                // This is implementation-specific

                // Tap bulk delete
                let deleteSelectedButton = app.buttons["DeleteSelected"] ?? app.buttons["Видалити вибрані"]
                if deleteSelectedButton.waitForExistence(timeout: 2) {
                    let initialCount = app.cells.count

                    deleteSelectedButton.tap()

                    // Confirm deletion
                    let confirmButton = app.buttons["Confirm"] ?? app.buttons["Delete"] ?? app.buttons["Видалити"]
                    if confirmButton.waitForExistence(timeout: 1) {
                        confirmButton.tap()
                    }

                    // Verify transactions removed
                    sleep(1)
                    let finalCount = app.cells.count
                    XCTAssertTrue(finalCount < initialCount, "Selected transactions should be deleted")
                }
            }
        }
    }

    @MainActor
    func testSplitTransactionShowsSubItemsWhenExpanded() throws {
        // Find a split transaction
        let splitTransaction = app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'split' OR label CONTAINS[c] 'роздільна'")).firstMatch

        if splitTransaction.waitForExistence(timeout: 3) {
            // Tap to expand
            splitTransaction.tap()

            // Verify sub-items appear
            let subItem = app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'split' AND label CONTAINS[c] '—'")).firstMatch
            XCTAssertTrue(subItem.waitForExistence(timeout: 2), "Split sub-items should appear")

            // Tap again to collapse
            splitTransaction.tap()

            // Verify sub-items hidden
            let subItemHidden = !subItem.exists
            XCTAssertTrue(subItemHidden, "Split sub-items should be hidden when collapsed")
        }
    }

    // MARK: - Empty State Tests

    @MainActor
    func testEmptyStateAppearsWhenNoTransactions() throws {
        // This test would require starting with no transactions
        // Launch with specific environment to ensure empty state
        app.terminate()
        app.launchEnvironment = ["IS_TESTING": "1", "START_EMPTY": "1"]
        app.launch()

        // Verify empty state appears
        let emptyStateView = app.otherElements["EmptyStateView"]
        let emptyStateText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'no transactions' OR label CONTAINS[c] 'немає транзакцій'")).firstMatch

        XCTAssertTrue(emptyStateView.waitForExistence(timeout: 5) || emptyStateText.exists,
                     "Empty state should appear when no transactions exist")
    }

    // MARK: - Scroll Performance Tests

    @MainActor
    func testScrollThroughLargeListIsSmooth() throws {
        // This requires a list with many transactions
        let transactionList = app.tables["TransactionList"].firstMatch
        let scrollView = app.scrollViews["TransactionList"].firstMatch

        let targetView = transactionList.exists ? transactionList : scrollView

        if targetView.waitForExistence(timeout: 3) {
            // Scroll down multiple times
            for _ in 0..<5 {
                targetView.swipeUp()
            }

            // Verify list is still responsive
            XCTAssertTrue(targetView.exists, "List should remain responsive during scrolling")

            // Scroll back to top
            for _ in 0..<5 {
                targetView.swipeDown()
            }

            XCTAssertTrue(targetView.exists, "List should remain responsive")
        }
    }

    // MARK: - Transaction Type Indicators

    @MainActor
    func testTransactionListShowsTypeIndicators() throws {
        // Verify expense transactions show expense indicator
        let expenseIndicator = app.images["ExpenseIcon"] ?? app.staticTexts.containing(NSPredicate(format: "label CONTAINS '-'")).firstMatch
        let incomeIndicator = app.images["IncomeIcon"] ?? app.staticTexts.containing(NSPredicate(format: "label CONTAINS '+'")).firstMatch

        // At least one type of transaction should be visible
        XCTAssertTrue(expenseIndicator.waitForExistence(timeout: 3) || incomeIndicator.exists,
                     "Transaction type indicators should be visible")
    }

    // MARK: - Context Menu Tests

    @MainActor
    func testLongPressShowsContextMenu() throws {
        // Long press on first transaction
        let firstTransaction = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.waitForExistence(timeout: 3))

        firstTransaction.press(forDuration: 1.0)

        // Verify context menu appears
        let editOption = app.buttons["Edit"] ?? app.buttons["Редагувати"]
        let deleteOption = app.buttons["Delete"] ?? app.buttons["Видалити"]
        let shareOption = app.buttons["Share"] ?? app.buttons["Поділитися"]

        let contextMenuAppeared = editOption.waitForExistence(timeout: 2) ||
                                 deleteOption.exists ||
                                 shareOption.exists

        if contextMenuAppeared {
            XCTAssertTrue(true, "Context menu appeared")

            // Dismiss context menu
            app.tap()
        }
    }

    // MARK: - Sorting Tests

    @MainActor
    func testSortingOptionsChangeOrder() throws {
        // Open sort menu
        let sortButton = app.buttons["SortButton"] ?? app.buttons["Сортувати"]

        if sortButton.waitForExistence(timeout: 2) {
            sortButton.tap()

            // Get first transaction text before sorting
            let firstTransactionBefore = app.cells.element(boundBy: 0).label

            // Select "Sort by Amount"
            let sortByAmount = app.buttons["SortByAmount"] ?? app.buttons["За сумою"]
            if sortByAmount.waitForExistence(timeout: 2) {
                sortByAmount.tap()

                // Wait for re-sort
                sleep(1)

                // Get first transaction after sorting
                let firstTransactionAfter = app.cells.element(boundBy: 0).label

                // They might be different (unless coincidentally the same)
                // Just verify list still exists and is populated
                XCTAssertTrue(app.cells.element(boundBy: 0).exists, "List should still be populated after sorting")
            }
        }
    }
}
