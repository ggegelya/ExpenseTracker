//
//  CoachMarkManagerTests.swift
//  ExpenseTracker
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("CoachMarkManager Tests", .serialized)
@MainActor
struct CoachMarkManagerTests {

    // MARK: - Fresh Install

    @Test("Fresh install — no marks shown yet")
    func freshInstallNoMarksShown() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        for id in CoachMarkID.allCases {
            #expect(!sut.hasBeenShown(id))
        }
    }

    @Test("Activate shows mark when not previously shown")
    func activateShowsMark() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        sut.activate(.quickEntryAmountField)
        #expect(sut.shouldShow(.quickEntryAmountField))
        #expect(sut.activeMarks.contains(.quickEntryAmountField))
    }

    // MARK: - Persistence

    @Test("Deactivate persists shown state")
    func deactivatePersists() {
        let suiteName = "CoachMarkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)
        sut.activate(.quickEntryAmountField)
        sut.deactivate(.quickEntryAmountField)

        #expect(sut.hasBeenShown(.quickEntryAmountField))
        #expect(!sut.shouldShow(.quickEntryAmountField))

        // New manager with same defaults should see persisted state
        let sut2 = CoachMarkManager(defaults: defaults, suppressInTests: false)
        #expect(sut2.hasBeenShown(.quickEntryAmountField))
    }

    @Test("Activate is no-op when mark was already shown")
    func activateIdempotentWhenShown() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        sut.activate(.firstTransactionSaved)
        sut.deactivate(.firstTransactionSaved)

        // Try to activate again — should not show
        sut.activate(.firstTransactionSaved)
        #expect(!sut.shouldShow(.firstTransactionSaved))
        #expect(!sut.activeMarks.contains(.firstTransactionSaved))
    }

    // MARK: - Independence

    @Test("Marks are independent — deactivating one doesn't affect others")
    func marksAreIndependent() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        sut.activate(.quickEntryAmountField)
        sut.activate(.swipeActionsHint)

        sut.deactivate(.quickEntryAmountField)

        #expect(!sut.shouldShow(.quickEntryAmountField))
        #expect(sut.shouldShow(.swipeActionsHint))
    }

    @Test("shouldShow returns false when mark is not activated")
    func shouldShowFalseWhenNotActivated() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        #expect(!sut.shouldShow(.analyticsReady))
    }

    @Test("Deactivating non-active mark still persists shown state")
    func deactivateNonActiveMarkPersists() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        sut.deactivate(.autoCategoryDetected)
        #expect(sut.hasBeenShown(.autoCategoryDetected))
    }

    // MARK: - Suppress in Tests

    @Test("suppressInTests blocks activation in test environment")
    func suppressInTestsBlocksActivation() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        // Default: suppressInTests = true — since we ARE in a test environment,
        // activate should be a no-op
        let sut = CoachMarkManager(defaults: defaults)

        sut.activate(.quickEntryAmountField)
        #expect(!sut.shouldShow(.quickEntryAmountField))
        #expect(sut.activeMarks.isEmpty)
    }

    @Test("suppressInTests false allows activation in test environment")
    func suppressInTestsFalseAllowsActivation() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        sut.activate(.quickEntryAmountField)
        #expect(sut.shouldShow(.quickEntryAmountField))
    }

    // MARK: - Full Lifecycle

    @Test("All 5 marks activate, deactivate, and persist independently")
    func fullLifecycleAllMarks() {
        let defaults = UserDefaults(suiteName: "CoachMarkTests.\(UUID().uuidString)")!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        // Activate all
        for id in CoachMarkID.allCases {
            sut.activate(id)
        }
        #expect(sut.activeMarks.count == CoachMarkID.allCases.count)
        for id in CoachMarkID.allCases {
            #expect(sut.shouldShow(id))
        }

        // Deactivate one at a time
        for (index, id) in CoachMarkID.allCases.enumerated() {
            sut.deactivate(id)
            #expect(!sut.shouldShow(id))
            #expect(sut.hasBeenShown(id))
            // Remaining marks still active
            let remaining = CoachMarkID.allCases.count - index - 1
            #expect(sut.activeMarks.count == remaining)
        }

        // All persisted — new instance should see all as shown
        let sut2 = CoachMarkManager(defaults: defaults, suppressInTests: false)
        for id in CoachMarkID.allCases {
            #expect(sut2.hasBeenShown(id))
        }
        // None can be re-activated
        for id in CoachMarkID.allCases {
            sut2.activate(id)
        }
        #expect(sut2.activeMarks.isEmpty)
    }

    // MARK: - App State Reset

    @Test("Clearing UserDefaults domain resets all coach marks")
    func clearingDefaultsResetsAllMarks() {
        let suiteName = "CoachMarkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let sut = CoachMarkManager(defaults: defaults, suppressInTests: false)

        // Show all marks
        for id in CoachMarkID.allCases {
            sut.activate(id)
            sut.deactivate(id)
        }
        for id in CoachMarkID.allCases {
            #expect(sut.hasBeenShown(id))
        }

        // Simulate app state reset (same as ExpenseTrackerApp.resetAppState)
        defaults.removePersistentDomain(forName: suiteName)

        // New manager should see fresh state
        let sut2 = CoachMarkManager(defaults: defaults, suppressInTests: false)
        for id in CoachMarkID.allCases {
            #expect(!sut2.hasBeenShown(id))
        }
    }

    // MARK: - Key Format

    @Test("UserDefaults key factory produces expected format")
    func keyFactoryFormat() {
        let key = UserDefaultsKeys.coachMarkShown(.quickEntryAmountField)
        #expect(key == "coachMark.shown.quickEntryAmountField")

        let key2 = UserDefaultsKeys.coachMarkShown(.firstTransactionSaved)
        #expect(key2 == "coachMark.shown.firstTransactionSaved")
    }

    // MARK: - All Cases

    @Test("All coach mark IDs have unique raw values")
    func uniqueRawValues() {
        let rawValues = CoachMarkID.allCases.map(\.rawValue)
        #expect(Set(rawValues).count == rawValues.count)
    }

    @Test("All coach mark IDs produce unique UserDefaults keys")
    func uniqueUserDefaultsKeys() {
        let keys = CoachMarkID.allCases.map { UserDefaultsKeys.coachMarkShown($0) }
        #expect(Set(keys).count == keys.count)
    }

    @Test("CoachMarkID has exactly 5 cases")
    func exactlyFiveCases() {
        #expect(CoachMarkID.allCases.count == 5)
    }
}
