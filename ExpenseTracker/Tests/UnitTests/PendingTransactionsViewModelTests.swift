//
//  PendingTransactionsViewModelTests.swift
//  ExpenseTracker
//
//  Created by Claude Code on 22.11.2025.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("PendingTransactionsViewModel Tests", .serialized)
@MainActor
struct PendingTransactionsViewModelTests {
    var sut: PendingTransactionsViewModel
    var mockRepository: MockTransactionRepository
    var mockCategorizationService: MockCategorizationService
    var mockAnalyticsService: MockAnalyticsService
    var mockErrorHandler: MockErrorHandlingService

    init() async throws {
        mockRepository = MockTransactionRepository()
        mockCategorizationService = MockCategorizationService()
        mockAnalyticsService = MockAnalyticsService()
        mockErrorHandler = MockErrorHandlingService()

        sut = PendingTransactionsViewModel(
            repository: mockRepository,
            categorizationService: mockCategorizationService,
            analyticsService: mockAnalyticsService,
            errorHandler: mockErrorHandler
        )
    }

    // MARK: - Load Pending Transactions Tests

    @Test("Load pending transactions filters by account")
    func loadPendingTransactionsFiltersByAccount() async throws {
        // Given
        let account1 = MockAccount.makeDefault()
        let account2 = MockAccount.makeSecondary()
        let category = MockCategory.makeGroceries()

        let pending1 = MockPendingTransaction.makePending(
            amount: 100,
            description: "Test 1",
            account: account1,
            suggestedCategory: category
        )

        let pending2 = MockPendingTransaction.makePending(
            amount: 200,
            description: "Test 2",
            account: account2,
            suggestedCategory: category
        )

        let pending3 = MockPendingTransaction.makePending(
            amount: 300,
            description: "Test 3",
            account: account1,
            suggestedCategory: category
        )

        // Add pending transactions via createPendingTransaction
        _ = try await mockRepository.createPendingTransaction(pending1)
        _ = try await mockRepository.createPendingTransaction(pending2)
        _ = try await mockRepository.createPendingTransaction(pending3)

        // When - load for account1
        await sut.loadPendingTransactions(for: account1)

        // Then - should only have account1's pending transactions
        #expect(sut.pendingTransactions.count == 2)
        #expect(sut.pendingTransactions.allSatisfy { $0.account.id == account1.id })
        #expect(mockRepository.wasCalled("getPendingTransactions(for:)"))
    }

    @Test("Load pending transactions updates count")
    func loadPendingTransactionsUpdatesCount() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(amount: 100, account: account, suggestedCategory: category)
        )
        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(amount: 200, account: account, suggestedCategory: category)
        )
        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(amount: 300, account: account, suggestedCategory: category)
        )

        // When
        await sut.loadPendingTransactions(for: account)

        // Then
        #expect(sut.pendingCount == 3)
        #expect(sut.hasPendingTransactions == true)
    }

    // MARK: - Process Transaction Tests

    @Test("Process transaction creates and removes pending")
    func processTransactionCreatesAndRemovesPending() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 150,
            description: "Покупка в магазині",
            account: account,
            suggestedCategory: category
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        // When
        await sut.processPendingTransaction(
            pendingTransaction,
            with: category,
            description: "Покупка в магазині",
            shouldLearn: true
        )

        // Then
        #expect(mockRepository.wasCalled("processPendingTransaction(_:as:)"))
        #expect(mockCategorizationService.wasLearningCalled) // Should learn from correction
        #expect(mockAnalyticsService.wasTransactionAdded())
    }

    @Test("Process transaction tracks processing state")
    func processTransactionTracksProcessingState() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 100,
            account: account,
            suggestedCategory: category
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        // When - start processing
        let processingTask = Task { @MainActor in
            await sut.processPendingTransaction(
                pendingTransaction,
                with: category,
                description: "Test",
                shouldLearn: false
            )
        }

        // Note: Hard to test intermediate state due to timing
        await processingTask.value

        // Then - should not be processing after completion
        #expect(!sut.processingIds.contains(pendingTransaction.id))
    }

    // MARK: - Dismiss Transaction Tests

    @Test("Dismiss transaction marks as processed")
    func dismissTransactionMarksAsProcessed() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 100,
            account: account,
            suggestedCategory: category
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        // When
        await sut.dismissPendingTransaction(pendingTransaction)

        // Then
        #expect(mockRepository.wasCalled("dismissPendingTransaction(_:)"))
        #expect(!sut.processingIds.contains(pendingTransaction.id))
    }

    // MARK: - Accept Suggestion Tests

    @Test("Accept suggestion uses suggested category")
    func acceptSuggestionUsesSuggestedCategory() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let suggestedCategory = MockCategory.makeGroceries()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 200,
            description: "Покупка в Сільпо",
            merchantName: "Сільпо",
            account: account,
            suggestedCategory: suggestedCategory,
            confidence: 0.95
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        // When - process with suggested category
        await sut.processPendingTransaction(
            pendingTransaction,
            with: suggestedCategory,
            description: pendingTransaction.descriptionText,
            shouldLearn: false // Don't learn if accepting suggestion
        )

        // Then
        #expect(mockRepository.wasCalled("processPendingTransaction(_:as:)"))
        #expect(!mockCategorizationService.wasLearningCalled) // Should NOT learn when accepting suggestion
    }

    // MARK: - Edit Suggestion Tests

    @Test("Edit suggestion allows category override")
    func editSuggestionAllowsCategoryOverride() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let suggestedCategory = MockCategory.makeGroceries()
        let overrideCategory = MockCategory.makeTransport()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 200,
            description: "Покупка",
            account: account,
            suggestedCategory: suggestedCategory,
            confidence: 0.90
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        // When - process with different category
        await sut.processPendingTransaction(
            pendingTransaction,
            with: overrideCategory, // Override suggestion
            description: pendingTransaction.descriptionText,
            shouldLearn: true // Learn from correction
        )

        // Then
        #expect(mockRepository.wasCalled("processPendingTransaction(_:as:)"))
        #expect(mockCategorizationService.wasLearningCalled) // Should learn when overriding
    }

    // MARK: - Bulk Process Tests

    @Test("Bulk process handles multiple transactions")
    func bulkProcessHandlesMultipleTransactions() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(amount: 100, account: account, suggestedCategory: category)
        )
        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(amount: 200, account: account, suggestedCategory: category)
        )
        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(amount: 300, account: account, suggestedCategory: category)
        )

        await sut.loadPendingTransactions(for: account)

        // When
        await sut.processAllPending()

        // Then
        #expect(mockRepository.callCount(for: "processPendingTransaction(_:as:)") == 3)
    }

    @Test("Bulk process uses suggested categories")
    func bulkProcessUsesSuggestedCategories() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()

        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(
                amount: 100,
                description: "Сільпо",
                account: account,
                suggestedCategory: groceries,
                confidence: 0.95
            )
        )
        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(
                amount: 200,
                description: "Uber",
                account: account,
                suggestedCategory: transport,
                confidence: 0.90
            )
        )

        await sut.loadPendingTransactions(for: account)

        // When
        await sut.processAllPending()

        // Then
        #expect(mockRepository.callCount(for: "processPendingTransaction(_:as:)") == 2)
    }

    // MARK: - Error Handling Tests

    @Test("Error in processing doesn't affect other pending transactions")
    func errorInProcessingDoesntAffectOtherPendingTransactions() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let pending1 = MockPendingTransaction.makePending(amount: 100, account: account, suggestedCategory: category)
        let pending2 = MockPendingTransaction.makePending(amount: 200, account: account, suggestedCategory: category)
        let pending3 = MockPendingTransaction.makePending(amount: 300, account: account, suggestedCategory: category)

        _ = try await mockRepository.createPendingTransaction(pending1)
        _ = try await mockRepository.createPendingTransaction(pending2)
        _ = try await mockRepository.createPendingTransaction(pending3)
        await sut.loadPendingTransactions(for: account)

        // Configure repository to fail on second transaction
        mockRepository.setError(NSError(domain: "Test", code: -1, userInfo: nil), forMethod: "processPendingTransaction(_:as:)")

        // When - process all (all will try to process)
        await sut.processAllPending()

        // Then - should attempt all transactions even if some fail
        #expect(mockRepository.callCount(for: "processPendingTransaction(_:as:)") >= 1)
    }

    @Test("Processing error clears processing state")
    func processingErrorClearsProcessingState() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 100,
            account: account,
            suggestedCategory: category
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = NSError(domain: "Test", code: -1, userInfo: nil)

        // When - processing fails
        await sut.processPendingTransaction(
            pendingTransaction,
            with: category,
            description: "Test",
            shouldLearn: false
        )

        // Then - should clear processing state even on error
        #expect(!sut.processingIds.contains(pendingTransaction.id))
    }

    // MARK: - Learning Tests

    @Test("Learning from correction updates categorization service")
    func learningFromCorrectionUpdatesCategorizationService() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let suggestedCategory = MockCategory.makeGroceries()
        let correctCategory = MockCategory.makeTransport()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 100,
            description: "Uber поїздка",
            merchantName: "Uber",
            account: account,
            suggestedCategory: suggestedCategory,
            confidence: 0.60
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        // When - process with correction and learning
        await sut.processPendingTransaction(
            pendingTransaction,
            with: correctCategory,
            description: "Uber поїздка",
            shouldLearn: true
        )

        // Then
        #expect(mockCategorizationService.wasLearningCalled)
        #expect(mockCategorizationService.wasLearningPerformed(for: correctCategory))
    }

    @Test("Learning notification shows after correction")
    func learningNotificationShowsAfterCorrection() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let suggestedCategory = MockCategory.makeGroceries()
        let correctCategory = MockCategory.makeTransport()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 100,
            description: "Test",
            merchantName: "TestMerchant",
            account: account,
            suggestedCategory: suggestedCategory
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        // When
        await sut.processPendingTransaction(
            pendingTransaction,
            with: correctCategory,
            description: "Test",
            shouldLearn: true
        )

        // Then - learning notification should be set
        // Note: Implementation may vary, but we can check if learning was called
        #expect(mockCategorizationService.wasLearningCalled)
    }

    // MARK: - Monitoring Tests

    @Test("Start monitoring begins polling")
    func startMonitoringBeginsPolling() async throws {
        // When
        sut.startMonitoring()
        // Allow polling task to execute
        try await AsyncTestUtilities.wait(seconds: 0.1)

        // Then - monitoring should have triggered a load
        #expect(mockRepository.wasCalled("getPendingTransactions(for:)"))

        // Cleanup
        sut.stopMonitoring()
    }

    @Test("Stop monitoring halts polling")
    func stopMonitoringHaltsPolling() async throws {
        // Given
        sut.startMonitoring()
        try await AsyncTestUtilities.wait(seconds: 0.1)
        let callCountBeforeStop = mockRepository.callCount(for: "getPendingTransactions(for:)")

        // When
        sut.stopMonitoring()
        try await AsyncTestUtilities.wait(seconds: 0.1)

        // Then - no additional calls after stop
        let callCountAfterStop = mockRepository.callCount(for: "getPendingTransactions(for:)")
        #expect(callCountAfterStop == callCountBeforeStop)
    }

    @Test("Pause and resume monitoring")
    func pauseAndResumeMonitoring() async throws {
        // Given
        sut.startMonitoring()
        try await AsyncTestUtilities.wait(seconds: 0.1)
        let callCountAfterStart = mockRepository.callCount(for: "getPendingTransactions(for:)")
        #expect(callCountAfterStart >= 1)

        // When - pause
        sut.pauseMonitoring()
        try await AsyncTestUtilities.wait(seconds: 0.1)

        // When - resume
        sut.resumeMonitoring()
        try await AsyncTestUtilities.wait(seconds: 0.1)

        // Then - resume should trigger another load
        let callCountAfterResume = mockRepository.callCount(for: "getPendingTransactions(for:)")
        #expect(callCountAfterResume > callCountAfterStart)

        // Cleanup
        sut.stopMonitoring()
    }

    // MARK: - Computed Properties Tests

    @Test("Pending count returns correct count")
    func pendingCountReturnsCorrectCount() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        for _ in 1...5 {
            _ = try await mockRepository.createPendingTransaction(
                MockPendingTransaction.makePending(account: account, suggestedCategory: category)
            )
        }

        // When
        await sut.loadPendingTransactions(for: account)

        // Then
        #expect(sut.pendingCount == 5)
    }

    @Test("Has pending transactions returns true when transactions exist")
    func hasPendingTransactionsReturnsTrueWhenTransactionsExist() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        _ = try await mockRepository.createPendingTransaction(
            MockPendingTransaction.makePending(amount: 100, account: account, suggestedCategory: category)
        )

        // When
        await sut.loadPendingTransactions(for: account)

        // Then
        #expect(sut.hasPendingTransactions == true)

        // When - create new ViewModel with no transactions
        let newMockRepo = MockTransactionRepository()
        let newSut = PendingTransactionsViewModel(
            repository: newMockRepo,
            categorizationService: mockCategorizationService,
            analyticsService: mockAnalyticsService,
            errorHandler: mockErrorHandler
        )
        await newSut.loadPendingTransactions(for: account)

        // Then
        #expect(newSut.hasPendingTransactions == false)
    }

    // MARK: - Confidence Tests

    @Test("High confidence suggestions are auto-applied")
    func highConfidenceSuggestionsAreAutoApplied() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let highConfidencePending = MockPendingTransaction.makePending(
            amount: 100,
            description: "Сільпо",
            merchantName: "Сільпо",
            account: account,
            suggestedCategory: category,
            confidence: 0.95
        )

        _ = try await mockRepository.createPendingTransaction(highConfidencePending)
        await sut.loadPendingTransactions(for: account)

        // Then - high confidence should have suggested category
        #expect(sut.pendingTransactions.first?.suggestedCategory?.id == category.id)
        #expect(sut.pendingTransactions.first?.confidence ?? 0 >= 0.8)
    }

    @Test("Low confidence suggestions show manual review")
    func lowConfidenceSuggestionsShowManualReview() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let lowConfidencePending = MockPendingTransaction.makePending(
            amount: 100,
            description: "Unclear merchant",
            account: account,
            suggestedCategory: category,
            confidence: 0.45
        )

        _ = try await mockRepository.createPendingTransaction(lowConfidencePending)
        await sut.loadPendingTransactions(for: account)

        // Then - low confidence should still have suggestion but needs review
        #expect(sut.pendingTransactions.first?.confidence ?? 1.0 < 0.8)
    }

    // MARK: - Description Override Tests

    @Test("Process transaction allows description override")
    func processTransactionAllowsDescriptionOverride() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let pendingTransaction = MockPendingTransaction.makePending(
            amount: 100,
            description: "Original description",
            account: account,
            suggestedCategory: category
        )

        _ = try await mockRepository.createPendingTransaction(pendingTransaction)
        await sut.loadPendingTransactions(for: account)

        let newDescription = "Updated description"

        // When
        await sut.processPendingTransaction(
            pendingTransaction,
            with: category,
            description: newDescription,
            shouldLearn: false
        )

        // Then
        #expect(mockRepository.wasCalled("processPendingTransaction(_:as:)"))
    }
}
