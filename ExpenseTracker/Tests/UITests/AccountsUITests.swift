//
//  AccountsUITests.swift
//  ExpenseTrackerUITests
//
//  UI tests for Accounts tab interactions
//

import XCTest

final class AccountsUITests: XCTestCase {
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

    // MARK: - Accounts List Tests

    @MainActor
    func testAccountsTabShowsAccountList() throws {
        // Navigate to accounts tab
        let accountsTab = app.buttons["AccountsTab"] ?? app.tabBars.buttons.element(boundBy: 1)

        if accountsTab.waitForExistence(timeout: 3) {
            accountsTab.tap()

            // Verify accounts list is displayed
            let accountsList = app.tables.firstMatch
            let scrollView = app.scrollViews.firstMatch

            XCTAssertTrue(
                accountsList.waitForExistence(timeout: 3) || scrollView.exists,
                "Accounts list should be displayed"
            )

            // Verify at least one account is visible
            let firstAccount = app.cells.element(boundBy: 0)
            XCTAssertTrue(
                firstAccount.waitForExistence(timeout: 2),
                "At least one account should be visible"
            )
        }
    }

    // MARK: - Add Account Tests

    @MainActor
    func testAddAccountFormValidatesInput() throws {
        // Navigate to accounts tab
        let accountsTab = app.buttons["AccountsTab"] ?? app.tabBars.buttons.element(boundBy: 1)
        guard accountsTab.waitForExistence(timeout: 3) else { return }
        accountsTab.tap()

        // Open add account form
        let addButton = app.buttons["AddAccountButton"]
        guard addButton.waitForExistence(timeout: 3) else { return }
        addButton.tap()

        // Try to save without filling required fields
        let saveButton = app.buttons["SaveButton"] ?? app.buttons["Зберегти"]
        if saveButton.waitForExistence(timeout: 2) {
            saveButton.tap()

            // Verify validation error appears
            let errorAlert = app.alerts.firstMatch
            let errorText = app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS[c] 'name' OR label CONTAINS[c] 'tag' OR label CONTAINS[c] 'назва' OR label CONTAINS[c] 'тег'")
            ).firstMatch

            XCTAssertTrue(
                errorAlert.waitForExistence(timeout: 2) || errorText.exists,
                "Validation error should appear for empty form"
            )

            // Dismiss error if alert
            if errorAlert.exists {
                let okButton = app.buttons["OK"] ?? app.buttons["Гаразд"]
                if okButton.exists {
                    okButton.tap()
                }
            }
        }

        // Now fill valid data and save
        let nameField = app.textFields["AccountNameField"]
        if nameField.waitForExistence(timeout: 2) {
            nameField.tap()
            nameField.typeText("UI Test Account")

            let tagField = app.textFields["AccountTagField"]
            if tagField.exists {
                tagField.tap()
                tagField.typeText("#uitest")
            }

            if saveButton.exists {
                saveButton.tap()

                // Verify account was created
                let newAccount = app.staticTexts["UI Test Account"]
                XCTAssertTrue(
                    newAccount.waitForExistence(timeout: 3),
                    "New account should appear in list after saving"
                )
            }
        }
    }
}
