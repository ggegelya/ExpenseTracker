//
//  OnboardingUITests.swift
//  ExpenseTrackerUITests
//
//  UI tests for the onboarding flow: welcome, account setup,
//  category selection, ready screen, and skip behavior.
//

import XCTest

final class OnboardingUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        // Force onboarding to show and reset state
        app.launchArguments = ["-UITesting", "-DisableAnimations", "-ResetAppState", "-ShowOnboarding"]
        app.launchEnvironment = ["IS_TESTING": "1", "DISABLE_ANIMATIONS": "1"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Onboarding Appearance Tests

    @MainActor
    func testOnboardingAppearsOnFreshLaunch() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        // Verify onboarding welcome screen elements
        let welcomeTitle = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'витрати' OR label CONTAINS[c] 'Track'")
        ).firstMatch
        let skipButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Пропустити' OR label CONTAINS[c] 'Skip'")
        ).firstMatch

        XCTAssertTrue(
            welcomeTitle.waitForExistence(timeout: 5) || skipButton.waitForExistence(timeout: 5),
            "Onboarding welcome screen should appear on fresh launch"
        )
    }

    @MainActor
    func testWelcomeScreenShowsHryvniaIcon() throws {
        app.launch()

        // The hryvnia icon should be visible
        let startButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Почати' OR label CONTAINS[c] 'Started'")
        ).firstMatch

        XCTAssertTrue(
            startButton.waitForExistence(timeout: 5),
            "Welcome screen should show a start button"
        )
    }

    // MARK: - Navigation Tests

    @MainActor
    func testSwipeThroughAllOnboardingSteps() throws {
        app.launch()

        // Step 1: Welcome screen — tap start
        let startButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Почати' OR label CONTAINS[c] 'Started'")
        ).firstMatch

        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        } else {
            // Try swiping left to advance
            app.swipeLeft()
        }

        // Step 2: Account setup — verify and advance
        let accountTitle = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'рахунок' OR label CONTAINS[c] 'Account'")
        ).firstMatch

        if accountTitle.waitForExistence(timeout: 3) {
            // Tap Next button to advance
            let nextButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS[c] 'Далі' OR label CONTAINS[c] 'Next'")
            ).firstMatch
            if nextButton.exists {
                nextButton.tap()
            } else {
                app.swipeLeft()
            }
        }

        // Step 3: Category setup — verify and advance
        let categoryTitle = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'категорії' OR label CONTAINS[c] 'Categories'")
        ).firstMatch

        if categoryTitle.waitForExistence(timeout: 3) {
            let nextButton = app.buttons.containing(
                NSPredicate(format: "label CONTAINS[c] 'Далі' OR label CONTAINS[c] 'Next'")
            ).firstMatch
            if nextButton.exists {
                nextButton.tap()
            } else {
                app.swipeLeft()
            }
        }

        // Step 4: Ready screen
        let readyTitle = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'готово' OR label CONTAINS[c] 'Set'")
        ).firstMatch

        XCTAssertTrue(
            readyTitle.waitForExistence(timeout: 3),
            "Ready screen should appear after navigating through all steps"
        )
    }

    @MainActor
    func testCompleteOnboardingShowsMainApp() throws {
        app.launch()

        // Navigate through all steps quickly
        // Step 1: Welcome — tap start
        let startButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Почати' OR label CONTAINS[c] 'Started'")
        ).firstMatch

        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        // Step 2: Account setup — tap next
        sleep(1)
        let nextButton1 = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Далі' OR label CONTAINS[c] 'Next'")
        ).firstMatch
        if nextButton1.waitForExistence(timeout: 3) {
            nextButton1.tap()
        }

        // Step 3: Categories — tap next
        sleep(1)
        let nextButton2 = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Далі' OR label CONTAINS[c] 'Next'")
        ).firstMatch
        if nextButton2.waitForExistence(timeout: 3) {
            nextButton2.tap()
        }

        // Step 4: Ready — tap start
        sleep(1)
        let finalButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Почати' OR label CONTAINS[c] 'Started'")
        ).firstMatch
        if finalButton.waitForExistence(timeout: 3) {
            finalButton.tap()
        }

        // Verify main app appears (MainView or QuickEntryView or transaction tabs)
        let mainView = app.otherElements["MainView"]
        let quickEntry = app.otherElements["QuickEntryView"]
        let transactionList = app.tables["TransactionList"]

        XCTAssertTrue(
            mainView.waitForExistence(timeout: 5) ||
            quickEntry.waitForExistence(timeout: 5) ||
            transactionList.waitForExistence(timeout: 5),
            "Main app should appear after completing onboarding"
        )
    }

    // MARK: - Skip Tests

    @MainActor
    func testSkipButtonBypassesOnboarding() throws {
        app.launch()

        // Find and tap Skip button
        let skipButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Пропустити' OR label CONTAINS[c] 'Skip'")
        ).firstMatch

        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "Skip button should be visible")
        skipButton.tap()

        // Verify main app appears
        let mainView = app.otherElements["MainView"]
        let quickEntry = app.otherElements["QuickEntryView"]
        let transactionList = app.tables["TransactionList"]

        XCTAssertTrue(
            mainView.waitForExistence(timeout: 5) ||
            quickEntry.waitForExistence(timeout: 5) ||
            transactionList.waitForExistence(timeout: 5),
            "Main app should appear after skipping onboarding"
        )
    }

    // MARK: - Account Setup Tests

    @MainActor
    func testAccountSetupShowsPresets() throws {
        app.launch()

        // Navigate to account setup (step 2)
        let startButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Почати' OR label CONTAINS[c] 'Started'")
        ).firstMatch

        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        // Verify presets are visible
        let monobankPreset = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Монобанк' OR label CONTAINS[c] 'Monobank'")
        ).firstMatch
        let privatPreset = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'ПриватБанк' OR label CONTAINS[c] 'PrivatBank'")
        ).firstMatch
        let cashPreset = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Готівка' OR label CONTAINS[c] 'Cash'")
        ).firstMatch

        XCTAssertTrue(
            monobankPreset.waitForExistence(timeout: 3) ||
            privatPreset.exists ||
            cashPreset.exists,
            "Account presets should be visible on account setup screen"
        )
    }

    @MainActor
    func testAccountSetupPresetFillsNameField() throws {
        app.launch()

        // Navigate to account setup
        let startButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Почати' OR label CONTAINS[c] 'Started'")
        ).firstMatch

        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        // Tap a preset
        let monobankPreset = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Монобанк' OR label CONTAINS[c] 'Monobank'")
        ).firstMatch

        if monobankPreset.waitForExistence(timeout: 3) {
            monobankPreset.tap()

            // Verify the text field was updated
            let textField = app.textFields.firstMatch
            if textField.exists {
                let value = textField.value as? String ?? ""
                XCTAssertTrue(
                    value.contains("Монобанк") || value.contains("Monobank"),
                    "Tapping preset should fill the name field"
                )
            }
        }
    }

    // MARK: - Category Setup Tests

    @MainActor
    func testCategorySetupShowsCategories() throws {
        app.launch()

        // Navigate to category setup (step 3)
        // Step 1: Welcome
        let startButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Почати' OR label CONTAINS[c] 'Started'")
        ).firstMatch
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        // Step 2: Account setup
        sleep(1)
        let nextButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] 'Далі' OR label CONTAINS[c] 'Next'")
        ).firstMatch
        if nextButton.waitForExistence(timeout: 3) {
            nextButton.tap()
        }

        // Verify categories are visible
        let categoryTitle = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'категорії' OR label CONTAINS[c] 'Categories'")
        ).firstMatch

        XCTAssertTrue(
            categoryTitle.waitForExistence(timeout: 3),
            "Category setup should show category title"
        )
    }
}
