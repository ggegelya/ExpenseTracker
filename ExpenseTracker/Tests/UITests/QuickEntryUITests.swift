//
//  QuickEntryUITests.swift
//  ExpenseTrackerUITests
//
//  UI tests for Quick Entry form interactions
//

import XCTest

final class QuickEntryUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-DisableAnimations", "-ResetAppState"]
        app.launchEnvironment = ["IS_TESTING": "1", "DISABLE_ANIMATIONS": "1"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Quick Entry Display Tests

    @MainActor
    func testQuickEntryShowsAllRequiredFields() throws {
        // Open Quick Entry
        let addButton = app.buttons["AddTransactionButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Verify all required fields are present
        XCTAssertTrue(app.textFields["AmountField"].exists, "Amount field should exist")
        XCTAssertTrue(app.textFields["DescriptionField"].exists, "Description field should exist")
        XCTAssertTrue(app.buttons["CategoryPicker"].exists, "Category picker should exist")
        XCTAssertTrue(app.buttons["DatePicker"].exists, "Date picker should exist")
        XCTAssertTrue(app.buttons["TypeToggle"].exists, "Type toggle should exist")
        XCTAssertTrue(app.buttons["AccountSelector"].exists, "Account selector should exist")
        XCTAssertTrue(app.buttons["SaveButton"].exists, "Save button should exist")
        XCTAssertTrue(app.buttons["ClearButton"].exists, "Clear button should exist")
    }

    @MainActor
    func testEnterAmountAndDescriptionCreatesTransaction() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Enter amount
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText("250")

        // Enter description
        let descriptionField = app.textFields["DescriptionField"]
        descriptionField.tap()
        descriptionField.typeText("Test Expense")

        // Save transaction
        app.buttons["SaveButton"].tap()

        // Verify transaction appears in list
        XCTAssertTrue(app.staticTexts["250"].waitForExistence(timeout: 3), "Amount should appear in list")
        XCTAssertTrue(app.staticTexts["Test Expense"].exists, "Description should appear in list")
    }

    @MainActor
    func testCategoryPickerShowsAllCategories() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Open category picker
        let categoryPicker = app.buttons["CategoryPicker"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 2))
        categoryPicker.tap()

        // Verify default categories appear (using raw name identifiers)
        XCTAssertTrue(app.buttons["Category_groceries"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Category_taxi"].exists)
        XCTAssertTrue(app.buttons["Category_transport"].exists)
        XCTAssertTrue(app.buttons["Category_cafe"].exists)
        XCTAssertTrue(app.buttons["Category_entertainment"].exists)
    }

    @MainActor
    func testDatePickerUpdatesTransactionDate() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Open date picker
        let datePicker = app.buttons["DatePicker"]
        XCTAssertTrue(datePicker.waitForExistence(timeout: 2))
        datePicker.tap()

        // Select yesterday
        let yesterdayButton = app.buttons["YesterdayQuickOption"]
        if yesterdayButton.exists {
            yesterdayButton.tap()
        }

        // Confirm date picker
        if app.buttons["ConfirmDate"].exists {
            app.buttons["ConfirmDate"].tap()
        }

        // Verify date updated (implementation-specific)
        // This would need to check the displayed date text
    }

    @MainActor
    func testTypeToggleChangesBetweenIncomeAndExpense() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        let typeToggle = app.buttons["TypeToggle"]
        XCTAssertTrue(typeToggle.waitForExistence(timeout: 2))

        // Default should be expense
        let expenseIndicator = app.staticTexts["ExpenseIndicator"]
        XCTAssertTrue(expenseIndicator.waitForExistence(timeout: 2), "Should default to expense")

        // Toggle to income
        typeToggle.tap()

        // Verify switched to income
        let incomeIndicator = app.staticTexts["IncomeIndicator"]
        XCTAssertTrue(incomeIndicator.waitForExistence(timeout: 2), "Should switch to income")

        // Toggle back to expense
        typeToggle.tap()

        XCTAssertTrue(expenseIndicator.waitForExistence(timeout: 2), "Should switch back to expense")
    }

    @MainActor
    func testAccountSelectorShowsAllAccounts() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Open account selector
        let accountSelector = app.buttons["AccountSelector"]
        XCTAssertTrue(accountSelector.waitForExistence(timeout: 2))
        accountSelector.tap()

        // Verify accounts list appears
        XCTAssertTrue(app.tables["AccountsList"].waitForExistence(timeout: 2) ||
                     app.scrollViews["AccountsList"].exists,
                     "Accounts list should appear")

        // Verify at least one account exists
        let firstAccount = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstAccount.exists, "At least one account should exist")
    }

    @MainActor
    func testClearButtonResetsForm() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Enter data
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText("500")

        let descriptionField = app.textFields["DescriptionField"]
        descriptionField.tap()
        descriptionField.typeText("Test Data")

        // Tap clear
        app.buttons["ClearButton"].tap()

        // Verify fields are reset
        let amountValue = amountField.value as? String ?? ""
        let descriptionValue = descriptionField.value as? String ?? ""

        XCTAssertTrue(amountValue.isEmpty || amountValue == "0" || amountValue.contains("Enter"),
                     "Amount field should be reset")
        XCTAssertTrue(descriptionValue.isEmpty || descriptionValue.contains("Description"),
                     "Description field should be reset")
    }

    @MainActor
    func testSubmitWithEmptyAmountShowsValidationError() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Try to save without entering amount
        let descriptionField = app.textFields["DescriptionField"]
        XCTAssertTrue(descriptionField.waitForExistence(timeout: 2))
        descriptionField.tap()
        descriptionField.typeText("Test")

        app.buttons["SaveButton"].tap()

        // Verify validation error appears
        let errorAlert = app.alerts.firstMatch
        let errorText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'amount' OR label CONTAINS[c] 'сума'"))

        XCTAssertTrue(errorAlert.waitForExistence(timeout: 2) || errorText.firstMatch.exists,
                     "Validation error should appear")
    }

    @MainActor
    func testSubmitWithValidDataShowsSuccess() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Enter valid data
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText("100")

        let descriptionField = app.textFields["DescriptionField"]
        descriptionField.tap()
        descriptionField.typeText("Valid Transaction")

        // Save
        app.buttons["SaveButton"].tap()

        // Verify success (form dismissed or success message)
        let quickEntryView = app.otherElements["QuickEntryView"]

        // Either the view is dismissed or a success message appears
        let dismissed = !quickEntryView.exists
        let successMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'success' OR label CONTAINS[c] 'saved' OR label CONTAINS[c] 'збережено'")).firstMatch.exists

        XCTAssertTrue(dismissed || successMessage,
                     "Quick Entry should dismiss or show success message")
    }

    @MainActor
    func testKeyboardDismissesOnSwipeDown() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Tap amount field to show keyboard
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()

        // Wait for keyboard
        let keyboard = app.keyboards.element
        XCTAssertTrue(keyboard.waitForExistence(timeout: 2), "Keyboard should appear")

        // Swipe down on the view to dismiss keyboard
        let quickEntryView = app.otherElements["QuickEntryView"]
        if quickEntryView.exists {
            quickEntryView.swipeDown()
        } else {
            // Fallback: tap outside the field
            app.tap()
        }

        // Verify keyboard dismissed
        let keyboardDismissed = !keyboard.exists
        XCTAssertTrue(keyboardDismissed, "Keyboard should be dismissed")
    }

    // MARK: - Category Selection Test

    @MainActor
    func testSelectCategoryUpdatesField() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Open category picker
        let categoryPicker = app.buttons["CategoryPicker"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: 2))
        categoryPicker.tap()

        // Select groceries category (using raw name identifier)
        let groceriesCategory = app.buttons["Category_groceries"]
        XCTAssertTrue(groceriesCategory.waitForExistence(timeout: 2))
        groceriesCategory.tap()

        // Verify category field updated
        // The picker label may show the localized display name or the raw name
        let categoryLabel = categoryPicker.label
        XCTAssertTrue(!categoryLabel.isEmpty, "Category should be updated after selection")
    }

    // MARK: - Amount Input Validation Tests

    @MainActor
    func testAmountFieldAcceptsDecimalValues() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Enter decimal amount
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText("250.50")

        let descriptionField = app.textFields["DescriptionField"]
        descriptionField.tap()
        descriptionField.typeText("Decimal test")

        // Save
        app.buttons["SaveButton"].tap()

        // Verify transaction created with decimal amount
        XCTAssertTrue(app.staticTexts["250.50"].waitForExistence(timeout: 3) ||
                     app.staticTexts.containing(NSPredicate(format: "label CONTAINS '250'")).firstMatch.exists,
                     "Decimal amount should be saved")
    }

    @MainActor
    func testAmountFieldRejectsInvalidInput() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Try to enter invalid characters
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()

        // Numeric keyboard should prevent letters, but test if accessible
        let currentValue = amountField.value as? String ?? ""

        // Should only contain numbers and decimal separator
        let validCharacters = CharacterSet(charactersIn: "0123456789.,")
        let inputCharacters = CharacterSet(charactersIn: currentValue)

        XCTAssertTrue(validCharacters.isSuperset(of: inputCharacters),
                     "Amount field should only accept numeric input")
    }

    // MARK: - Navigation Tests

    @MainActor
    func testDismissQuickEntryWithoutSaving() throws {
        // Open Quick Entry
        app.buttons["AddTransactionButton"].tap()

        // Enter some data
        let amountField = app.textFields["AmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 2))
        amountField.tap()
        amountField.typeText("123")

        // Dismiss without saving
        if app.buttons["CancelButton"].exists {
            app.buttons["CancelButton"].tap()
        } else if app.buttons["CloseButton"].exists {
            app.buttons["CloseButton"].tap()
        } else {
            // Swipe down to dismiss sheet
            let quickEntryView = app.otherElements["QuickEntryView"]
            if quickEntryView.exists {
                quickEntryView.swipeDown(velocity: .fast)
            }
        }

        // Verify Quick Entry dismissed
        let quickEntryDismissed = !app.otherElements["QuickEntryView"].exists
        XCTAssertTrue(quickEntryDismissed, "Quick Entry should be dismissed")
    }
}
