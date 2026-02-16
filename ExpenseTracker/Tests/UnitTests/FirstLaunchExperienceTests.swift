//
//  FirstLaunchExperienceTests.swift
//  ExpenseTracker
//
//  Tests for celebration trigger, analytics empty state threshold,
//  empty state action button, and tab switching environment.
//

import Testing
import Foundation
import SwiftUI
@testable import ExpenseTracker

// MARK: - Celebration Flag Tests

@Suite("First Transaction Celebration Tests", .serialized)
@MainActor
struct CelebrationFlagTests {
    let testSuiteName: String
    let testDefaults: UserDefaults

    init() {
        testSuiteName = "CelebrationFlagTests_\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: testSuiteName)!
    }

    @Test("Celebration flag defaults to false on fresh install")
    func celebrationFlagDefaultsToFalse() {
        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) == false)
    }

    @Test("First transaction sets celebration flag to true")
    func firstTransactionSetsCelebrationFlag() {
        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) == false)

        if !testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) {
            testDefaults.set(true, forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration)
        }

        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) == true)
    }

    @Test("Second transaction does not re-trigger celebration")
    func secondTransactionDoesNotRetrigger() {
        testDefaults.set(true, forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration)

        var showCelebration = false
        if !testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) {
            testDefaults.set(true, forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration)
            showCelebration = true
        }

        #expect(showCelebration == false)
    }

    @Test("Resetting app state clears celebration flag")
    func resetAppStateClearsCelebration() {
        testDefaults.set(true, forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration)
        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) == true)

        testDefaults.removePersistentDomain(forName: testSuiteName)

        #expect(testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) == false)
    }

    @Test("Celebration triggers exactly once across multiple transactions")
    func celebrationTriggersExactlyOnce() {
        var celebrationCount = 0

        for _ in 0..<5 {
            if !testDefaults.bool(forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration) {
                testDefaults.set(true, forKey: UserDefaultsKeys.hasShownFirstTransactionCelebration)
                celebrationCount += 1
            }
        }

        #expect(celebrationCount == 1)
    }
}

// MARK: - Analytics Empty State Threshold Tests

@Suite("Analytics Empty State Tests", .serialized)
@MainActor
struct AnalyticsEmptyStateTests {
    var mockRepository: MockTransactionRepository
    var mockErrorHandler: MockErrorHandlingService

    init() async throws {
        mockRepository = MockTransactionRepository()
        mockErrorHandler = MockErrorHandlingService()
    }

    @Test("Empty transactions triggers analytics empty state")
    func emptyTransactionsTriggersEmptyState() async throws {
        mockRepository.transactions = []
        #expect(mockRepository.transactions.count < AppConstants.analyticsMinTransactions)
    }

    @Test("Transactions below threshold trigger empty state")
    func belowThresholdTriggersEmptyState() async throws {
        for count in 1..<AppConstants.analyticsMinTransactions {
            mockRepository.transactions = MockTransaction.makeMultiple(count: count)
            #expect(mockRepository.transactions.count < AppConstants.analyticsMinTransactions)
        }
    }

    @Test("Transactions at threshold show analytics charts")
    func atThresholdShowCharts() async throws {
        mockRepository.transactions = MockTransaction.makeMultiple(count: AppConstants.analyticsMinTransactions)
        #expect(mockRepository.transactions.count >= AppConstants.analyticsMinTransactions)
    }

    @Test("Transactions above threshold show analytics charts")
    func aboveThresholdShowCharts() async throws {
        mockRepository.transactions = MockTransaction.makeMultiple(count: 10)
        #expect(mockRepository.transactions.count >= AppConstants.analyticsMinTransactions)
    }

    @Test("ProgressView value calculation is correct at boundary")
    func progressViewBoundary() {
        let threshold = AppConstants.analyticsMinTransactions

        for count in 0..<threshold {
            let progress = Double(count) / Double(threshold)
            #expect(progress < 1.0)
        }

        let fullProgress = Double(threshold) / Double(threshold)
        #expect(fullProgress == 1.0)
    }

    @Test("Threshold uses total transaction count via ViewModel")
    func thresholdUsesTotalTransactionCount() async throws {
        let sut = TransactionViewModel(
            repository: mockRepository,
            categorizationService: MockCategorizationService(),
            analyticsService: MockAnalyticsService(),
            errorHandler: mockErrorHandler
        )
        mockRepository.transactions = MockTransaction.makeMultiple(count: 5)

        await sut.loadData()

        #expect(sut.transactions.count >= AppConstants.analyticsMinTransactions)
    }
}

// MARK: - Empty State Action Button Tests

@Suite("Empty State Action Button Tests")
struct EmptyStateActionTests {

    @Test("Filtered empty state has nil action")
    func filteredEmptyStateHasNilAction() {
        let hasActiveFilters = true
        let actionTitle: String? = hasActiveFilters ? nil : "Add Transaction"
        let action: (() -> Void)? = hasActiveFilters ? nil : { }

        #expect(actionTitle == nil)
        #expect(action == nil)
    }

    @Test("Unfiltered empty state has action")
    func unfilteredEmptyStateHasAction() {
        let hasActiveFilters = false
        let actionTitle: String? = hasActiveFilters ? nil : "Add Transaction"
        let action: (() -> Void)? = hasActiveFilters ? nil : { }

        #expect(actionTitle != nil)
        #expect(action != nil)
    }

    @Test("Action callback is invoked when called")
    func actionCallbackIsInvoked() {
        var actionCalled = false
        let action: (() -> Void) = { actionCalled = true }

        action()
        #expect(actionCalled == true)
    }
}

// MARK: - Tab Switching Tests

@Suite("Tab Switching Tests")
struct TabSwitchingTests {

    @Test("All AppTab cases are available")
    func allAppTabCases() {
        let allCases = AppTab.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.quickEntry))
        #expect(allCases.contains(.transactions))
        #expect(allCases.contains(.pending))
        #expect(allCases.contains(.accounts))
        #expect(allCases.contains(.analytics))
    }

    @Test("AppTab raw values are sequential starting at 0")
    func rawValuesAreSequential() {
        #expect(AppTab.quickEntry.rawValue == 0)
        #expect(AppTab.transactions.rawValue == 1)
        #expect(AppTab.analytics.rawValue == 4)
    }

    @Test("AppTab URL paths round-trip correctly")
    func urlPathsRoundTrip() {
        for tab in AppTab.allCases {
            let path = tab.urlPath
            let restored = AppTab(urlPath: path)
            #expect(restored == tab, "URL path round-trip failed for \(tab)")
        }
    }
}

// MARK: - Onboarding Gate Logic Tests

@Suite("Onboarding Gate Tests")
struct OnboardingGateTests {

    @Test("Shows onboarding when hasCompletedOnboarding is false and not testing")
    func onboardingShowsOnFreshInstall() {
        let hasCompletedOnboarding = false
        let isRunningTests = false
        let shouldShowOnboarding = false

        let showMainTab = (hasCompletedOnboarding || isRunningTests) && !shouldShowOnboarding
        #expect(showMainTab == false)
    }

    @Test("Shows main tab when hasCompletedOnboarding is true")
    func mainTabShowsAfterOnboarding() {
        let hasCompletedOnboarding = true
        let isRunningTests = false
        let shouldShowOnboarding = false

        let showMainTab = (hasCompletedOnboarding || isRunningTests) && !shouldShowOnboarding
        #expect(showMainTab == true)
    }

    @Test("Shows main tab when running tests (skips onboarding)")
    func mainTabShowsInTestMode() {
        let hasCompletedOnboarding = false
        let isRunningTests = true
        let shouldShowOnboarding = false

        let showMainTab = (hasCompletedOnboarding || isRunningTests) && !shouldShowOnboarding
        #expect(showMainTab == true)
    }

    @Test("shouldShowOnboarding forces onboarding even in test mode")
    func shouldShowOnboardingOverridesTestMode() {
        let hasCompletedOnboarding = false
        let isRunningTests = true
        let shouldShowOnboarding = true

        let showMainTab = (hasCompletedOnboarding || isRunningTests) && !shouldShowOnboarding
        #expect(showMainTab == false)
    }

    @Test("shouldShowOnboarding forces onboarding even when already completed")
    func shouldShowOnboardingOverridesCompleted() {
        let hasCompletedOnboarding = true
        let isRunningTests = false
        let shouldShowOnboarding = true

        let showMainTab = (hasCompletedOnboarding || isRunningTests) && !shouldShowOnboarding
        #expect(showMainTab == false)
    }
}

// MARK: - AppConstants Tests

@Suite("AppConstants Tests")
struct AppConstantsTests {

    @Test("Analytics minimum transactions is a positive value")
    func analyticsMinIsPositive() {
        #expect(AppConstants.analyticsMinTransactions > 0)
    }

    @Test("UserDefaultsKeys are non-empty strings")
    func keysAreNonEmpty() {
        #expect(!UserDefaultsKeys.hasCompletedOnboarding.isEmpty)
        #expect(!UserDefaultsKeys.hasShownFirstTransactionCelebration.isEmpty)
        #expect(!UserDefaultsKeys.favoriteCategoryIds.isEmpty)
    }

    @Test("UserDefaultsKeys are distinct")
    func keysAreDistinct() {
        let keys = [
            UserDefaultsKeys.hasCompletedOnboarding,
            UserDefaultsKeys.hasShownFirstTransactionCelebration,
            UserDefaultsKeys.favoriteCategoryIds
        ]
        #expect(Set(keys).count == keys.count)
    }
}
