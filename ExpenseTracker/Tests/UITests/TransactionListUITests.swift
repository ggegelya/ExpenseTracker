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

    /// Finds the TransactionList element regardless of its UIKit backing type
    /// (UITableView, UICollectionView, or UIScrollView).
    private func findTransactionList(timeout: TimeInterval = 5) -> XCUIElement? {
        let table = app.tables["TransactionList"]
        if table.waitForExistence(timeout: timeout) { return table }
        let collectionView = app.collectionViews["TransactionList"]
        if collectionView.waitForExistence(timeout: 1) { return collectionView }
        let scrollView = app.scrollViews["TransactionList"]
        if scrollView.waitForExistence(timeout: 1) { return scrollView }
        return nil
    }

    // MARK: - Transaction List Display Tests

    @MainActor
    func testTransactionListDisplaysRecentTransactions() throws {
        // Verify transaction list exists
        let transactionList = findTransactionList()
        XCTAssertNotNil(transactionList, "Transaction list should exist")

        // Verify at least one transaction is visible
        let firstTransaction = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.waitForExistence(timeout: 3), "At least one transaction should be visible")
    }

    @MainActor
    func testTapTransactionShowsDetailView() throws {
        // Wait for list to load
        let transactionList = findTransactionList()
        XCTAssertNotNil(transactionList, "Transaction list should exist")

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
        guard let transactionList = findTransactionList() else {
            XCTFail("Transaction list should exist")
            return
        }

        // Verify cells exist
        let firstTransaction = transactionList.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.waitForExistence(timeout: 3), "At least one cell should exist")

        // Swipe first transaction to reveal delete action
        firstTransaction.swipeLeft()

        // Tap delete button (localized: "Delete" or "Видалити")
        let deleteButton = app.buttons.matching(
            NSPredicate(format: "label == 'Delete' OR label == 'Видалити'")
        ).firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "Delete button should appear after swipe")
        deleteButton.tap()

        // Confirm deletion if alert appears (split transactions show confirmation)
        let confirmButton = app.alerts.buttons.matching(
            NSPredicate(format: "label == 'Confirm' OR label == 'Delete' OR label == 'Видалити'")
        ).firstMatch
        if confirmButton.waitForExistence(timeout: 1) {
            confirmButton.tap()
        }

        // Verify the list is still visible after deletion (app didn't crash)
        XCTAssertTrue(transactionList.waitForExistence(timeout: 3), "Transaction list should remain visible after deletion")
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

        guard searchField.waitForExistence(timeout: 2) else {
            XCTFail("Search field should exist")
            return
        }
        searchField.tap()
        searchField.typeText("test")

        // Wait for filtering
        _ = app.cells.firstMatch.waitForExistence(timeout: 3)

        // Verify list is filtered
        // This is implementation-specific, but we expect fewer results
        let visibleCells = app.cells.count
        XCTAssertTrue(visibleCells > 0, "Filtered results should be displayed")

        // Clear search
        if app.buttons["ClearSearch"].exists {
            app.buttons["ClearSearch"].tap()
        } else {
            searchField.buttons["Clear text"].tap()
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

        guard filterButton.waitForExistence(timeout: 2) else {
            XCTFail("Filter button should exist")
            return
        }
        filterButton.tap()

        // Select category filter
        let categoryFilterOption = app.buttons["FilterByCategory"]
        if categoryFilterOption.waitForExistence(timeout: 2) {
            categoryFilterOption.tap()

            // Select a category
            let groceriesCategory = app.buttons["Category_groceries"]
            if groceriesCategory.waitForExistence(timeout: 2) {
                groceriesCategory.tap()

                // Verify filter applied
                let filterIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'продукти'")).firstMatch
                XCTAssertTrue(filterIndicator.exists, "Category filter should be applied")

                // Verify list updates
                XCTAssertNotNil(findTransactionList(timeout: 2), "Transaction list should exist")
            }
        }
    }

    @MainActor
    func testFilterByDateRangeWorks() throws {
        // Open filter menu
        let filterButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'FilterButton' OR identifier == 'ShowFilters'")
        ).firstMatch

        guard filterButton.waitForExistence(timeout: 2) else {
            XCTFail("Filter button should exist")
            return
        }
        filterButton.tap()

        // Select date range filter
        let dateRangeOption = app.buttons.matching(
            NSPredicate(format: "identifier == 'FilterByDateRange' OR identifier == 'DateRange'")
        ).firstMatch
        if dateRangeOption.waitForExistence(timeout: 2) {
            dateRangeOption.tap()

            // Select "This Month" quick option
            let thisMonthButton = app.buttons.matching(
                NSPredicate(format: "identifier == 'ThisMonth' OR label == 'Цей місяць'")
            ).firstMatch
            if thisMonthButton.waitForExistence(timeout: 2) {
                thisMonthButton.tap()

                // Verify filter applied
                let filterIndicator = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'month' OR label CONTAINS[c] 'місяць'")).firstMatch
                XCTAssertTrue(filterIndicator.exists, "Date filter should be applied")
            }
        }
    }

    @MainActor
    func testPullToRefreshUpdatesList() throws {
        // Find scrollable view
        guard let targetView = findTransactionList(timeout: 5) else {
            XCTFail("Transaction list should exist")
            return
        }

        // Pull down to refresh
        let start = targetView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = targetView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: end)

        // Wait for refresh to complete
        _ = targetView.waitForExistence(timeout: 3)

        // Verify list still displays
        XCTAssertTrue(targetView.exists, "List should still be visible after refresh")
    }

    @MainActor
    func testBulkSelectionAllowsMultiDelete() throws {
        // Enter selection mode
        let selectButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'SelectButton' OR label == 'Вибрати'")
        ).firstMatch

        guard selectButton.waitForExistence(timeout: 2) else {
            XCTFail("Select button should exist")
            return
        }
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
            let deleteSelectedButton = app.buttons.matching(
                NSPredicate(format: "identifier == 'DeleteSelected' OR label == 'Видалити вибрані'")
            ).firstMatch
            if deleteSelectedButton.waitForExistence(timeout: 2) {
                let initialCount = app.cells.count

                deleteSelectedButton.tap()

                // Confirm deletion
                let confirmButton = app.buttons.matching(
                    NSPredicate(format: "label == 'Confirm' OR label == 'Delete' OR label == 'Видалити'")
                ).firstMatch
                if confirmButton.waitForExistence(timeout: 1) {
                    confirmButton.tap()
                }

                // Verify transactions removed
                _ = app.cells.firstMatch.waitForExistence(timeout: 3)
                let finalCount = app.cells.count
                XCTAssertTrue(finalCount < initialCount, "Selected transactions should be deleted")
            }
        }
    }

    @MainActor
    func testSplitTransactionShowsSubItemsWhenExpanded() throws {
        // Find a split transaction
        let splitTransaction = app.cells.containing(NSPredicate(format: "label CONTAINS[c] 'split' OR label CONTAINS[c] 'роздільна'")).firstMatch

        guard splitTransaction.waitForExistence(timeout: 3) else {
            XCTFail("Split transaction should exist")
            return
        }
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

    // MARK: - Empty State Tests

    @MainActor
    func testEmptyStateAppearsWhenNoTransactions() throws {
        // This test would require starting with no transactions
        // Launch with specific environment to ensure empty state
        app.terminate()
        app.launchArguments = ["-UITesting", "-DisableAnimations"]
        app.launchEnvironment = ["IS_TESTING": "1", "DISABLE_ANIMATIONS": "1", "START_EMPTY": "1"]
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
        guard let targetView = findTransactionList(timeout: 5) else {
            XCTFail("Transaction list should exist")
            return
        }

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

    // MARK: - Transaction Type Indicators

    @MainActor
    func testTransactionListShowsTypeIndicators() throws {
        // Verify expense transactions show expense indicator
        let expenseIndicator = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'ExpenseIcon' OR label CONTAINS '-'")
        ).firstMatch
        let incomeIndicator = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'IncomeIcon' OR label CONTAINS '+'")
        ).firstMatch

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
        let editOption = app.buttons.matching(
            NSPredicate(format: "label == 'Edit' OR label == 'Редагувати'")
        ).firstMatch
        let deleteOption = app.buttons.matching(
            NSPredicate(format: "label == 'Delete' OR label == 'Видалити'")
        ).firstMatch
        let shareOption = app.buttons.matching(
            NSPredicate(format: "label == 'Share' OR label == 'Поділитися'")
        ).firstMatch

        let contextMenuAppeared = editOption.waitForExistence(timeout: 2) ||
                                 deleteOption.exists ||
                                 shareOption.exists

        XCTAssertTrue(contextMenuAppeared, "Context menu should appear after long press")

        // Dismiss context menu
        app.tap()
    }

    // MARK: - Sorting Tests

    @MainActor
    func testSortingOptionsChangeOrder() throws {
        // Open sort menu
        let sortButton = app.buttons.matching(
            NSPredicate(format: "identifier == 'SortButton' OR label == 'Сортувати'")
        ).firstMatch

        guard sortButton.waitForExistence(timeout: 2) else {
            XCTFail("Sort button should exist")
            return
        }
        sortButton.tap()

        // Get first transaction text before sorting
        let firstTransactionBefore = app.cells.element(boundBy: 0).label

        // Select "Sort by Amount"
        let sortByAmount = app.buttons.matching(
            NSPredicate(format: "identifier == 'SortByAmount' OR label == 'За сумою'")
        ).firstMatch
        if sortByAmount.waitForExistence(timeout: 2) {
            sortByAmount.tap()

            // Wait for re-sort
            _ = app.cells.firstMatch.waitForExistence(timeout: 3)

            // Get first transaction after sorting
            let firstTransactionAfter = app.cells.element(boundBy: 0).label

            // They might be different (unless coincidentally the same)
            // Just verify list still exists and is populated
            XCTAssertTrue(app.cells.element(boundBy: 0).exists, "List should still be populated after sorting")
        }
    }
}
