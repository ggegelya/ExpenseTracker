//
//  AnalyticsUITests.swift
//  ExpenseTrackerUITests
//
//  UI tests for Analytics tab navigation and interactions
//

import XCTest

final class AnalyticsUITests: XCTestCase {
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

    // MARK: - Navigation Tests

    @MainActor
    func testAnalyticsTabNavigatesToAnalyticsView() throws {
        // Navigate to analytics tab
        let analyticsTab = app.buttons.matching(
            NSPredicate(format: "identifier == 'AnalyticsTab'")
        ).firstMatch.exists
            ? app.buttons["AnalyticsTab"]
            : app.tabBars.buttons.element(boundBy: 2)

        guard analyticsTab.waitForExistence(timeout: 3) else {
            XCTFail("Analytics tab should exist")
            return
        }
        analyticsTab.tap()

        // Verify analytics view loads
        let analyticsView = app.otherElements["AnalyticsView"]
        let analyticsContent = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'analytics' OR label CONTAINS[c] 'аналітика'")
        ).firstMatch

        XCTAssertTrue(
            analyticsView.waitForExistence(timeout: 3) || analyticsContent.exists,
            "Analytics view should load after tapping analytics tab"
        )
    }

    // MARK: - Date Range Tests

    @MainActor
    func testDateRangeSelectorShowsAllOptions() throws {
        // Navigate to analytics
        let analyticsTab = app.buttons.matching(
            NSPredicate(format: "identifier == 'AnalyticsTab'")
        ).firstMatch.exists
            ? app.buttons["AnalyticsTab"]
            : app.tabBars.buttons.element(boundBy: 2)
        guard analyticsTab.waitForExistence(timeout: 3) else {
            XCTFail("Analytics tab should exist")
            return
        }
        analyticsTab.tap()

        // Find and tap date range selector
        let dateRangeSelector = app.buttons.matching(
            NSPredicate(format: "identifier == 'DateRangeSelector'")
        ).firstMatch.exists
            ? app.buttons["DateRangeSelector"]
            : app.segmentedControls.firstMatch

        guard dateRangeSelector.waitForExistence(timeout: 3) else {
            XCTFail("Date range selector should exist")
            return
        }
        dateRangeSelector.tap()

        // Verify date range options exist
        let options = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'month' OR label CONTAINS[c] 'місяць' OR label CONTAINS[c] 'custom' OR label CONTAINS[c] 'довільний'")
        )

        XCTAssertTrue(options.count > 0, "Date range selector should show options")
    }

    @MainActor
    func testSwitchingDateRangeUpdatesDisplayedData() throws {
        // Navigate to analytics
        let analyticsTab = app.buttons.matching(
            NSPredicate(format: "identifier == 'AnalyticsTab'")
        ).firstMatch.exists
            ? app.buttons["AnalyticsTab"]
            : app.tabBars.buttons.element(boundBy: 2)
        guard analyticsTab.waitForExistence(timeout: 3) else {
            XCTFail("Analytics tab should exist")
            return
        }
        analyticsTab.tap()

        // Wait for analytics content to load
        let _ = app.staticTexts.firstMatch.waitForExistence(timeout: 2)

        // Find date range selector
        let dateRangeSelector = app.segmentedControls.firstMatch

        guard dateRangeSelector.waitForExistence(timeout: 3) else {
            XCTFail("Date range selector should exist")
            return
        }

        // Switch to a different date range
        let segments = dateRangeSelector.buttons
        guard segments.count > 1 else {
            XCTFail("Date range selector should have more than one segment")
            return
        }
        segments.element(boundBy: 1).tap()

        // Wait for data refresh
        let analyticsView = app.otherElements["AnalyticsView"]
        let _ = analyticsView.waitForExistence(timeout: 3)

        // Analytics view should still be showing data
        XCTAssertTrue(
            analyticsView.exists || app.scrollViews.firstMatch.exists,
            "Analytics should display updated data after switching date range"
        )
    }

    // MARK: - Category Breakdown Tests

    @MainActor
    func testCategoryBreakdownCardDisplaysCategories() throws {
        // Navigate to analytics
        let analyticsTab = app.buttons.matching(
            NSPredicate(format: "identifier == 'AnalyticsTab'")
        ).firstMatch.exists
            ? app.buttons["AnalyticsTab"]
            : app.tabBars.buttons.element(boundBy: 2)
        guard analyticsTab.waitForExistence(timeout: 3) else {
            XCTFail("Analytics tab should exist")
            return
        }
        analyticsTab.tap()

        // Wait for content to load
        let _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Scroll down to find category breakdown section
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }

        // Look for category breakdown card
        let breakdownCard = app.otherElements["CategoryBreakdownCard"]
        let categoryContent = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'category' OR label CONTAINS[c] 'категор'")
        ).firstMatch

        XCTAssertTrue(
            breakdownCard.waitForExistence(timeout: 3) || categoryContent.exists,
            "Category breakdown should be displayed in analytics"
        )
    }

    @MainActor
    func testTappingCategoryInBreakdownNavigatesToTransactions() throws {
        // Navigate to analytics
        let analyticsTab = app.buttons.matching(
            NSPredicate(format: "identifier == 'AnalyticsTab'")
        ).firstMatch.exists
            ? app.buttons["AnalyticsTab"]
            : app.tabBars.buttons.element(boundBy: 2)
        guard analyticsTab.waitForExistence(timeout: 3) else {
            XCTFail("Analytics tab should exist")
            return
        }
        analyticsTab.tap()

        // Wait for content to load
        let _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        // Scroll to find breakdown section
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
        }

        // Find and tap first category in breakdown
        let categoryRow = app.cells.element(boundBy: 0)
        guard categoryRow.waitForExistence(timeout: 3) else {
            XCTFail("Category row should exist in breakdown")
            return
        }
        categoryRow.tap()

        // Verify navigation occurs (either detail view or filtered transaction list)
        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(
            backButton.waitForExistence(timeout: 3),
            "Tapping category should trigger navigation to a detail view"
        )
    }
}
