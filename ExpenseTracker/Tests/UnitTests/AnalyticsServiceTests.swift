//
//  AnalyticsServiceTests.swift
//  ExpenseTracker
//
//  Tests for AnalyticsService business logic
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("Analytics Service Tests")
struct AnalyticsServiceTests {
    // Use MockAnalyticsService for event/error tracking tests (tracks calls)
    var mockSut: MockAnalyticsService
    // Use real AnalyticsService for business analytics tests (pure computations)
    var realSut: AnalyticsService

    init() {
        mockSut = MockAnalyticsService()
        realSut = AnalyticsService()
    }

    // MARK: - Event Tracking Tests

    @Test("Track event logs correctly")
    func trackEventLogsCorrectly() throws {
        // Given
        let event = AnalyticsEvent.transactionAdded(amount: 100, category: "продукти")

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasTransactionAdded(amount: 100))
    }

    @Test("Track transaction added event")
    func trackTransactionAddedEvent() throws {
        // Given
        let event = AnalyticsEvent.transactionAdded(amount: 250.50, category: "кафе")

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasTransactionAdded(amount: 250.50))
        #expect(mockSut.wasTransactionAdded(category: "кафе"))
    }

    @Test("Track transaction deleted event")
    func trackTransactionDeletedEvent() throws {
        // Given
        let event = AnalyticsEvent.transactionDeleted

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasTransactionDeleted())
    }

    @Test("Track account connected event")
    func trackAccountConnectedEvent() throws {
        // Given
        let event = AnalyticsEvent.accountConnected(bankName: "Monobank")

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasAccountConnected(bankName: "Monobank"))
    }

    @Test("Track category created event")
    func trackCategoryCreatedEvent() throws {
        // Given
        let event = AnalyticsEvent.categoryCreated

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasCategoryCreated())
    }

    @Test("Track export completed event")
    func trackExportCompletedEvent() throws {
        // Given
        let event = AnalyticsEvent.exportCompleted(format: "CSV")

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasExportCompleted(format: "CSV"))
    }

    @Test("Track multiple events in sequence")
    func trackMultipleEventsInSequence() throws {
        // Given
        let events: [AnalyticsEvent] = [
            .transactionAdded(amount: 100, category: "продукти"),
            .transactionAdded(amount: 200, category: "таксі"),
            .categoryCreated,
            .exportCompleted(format: "CSV")
        ]

        // When
        for event in events {
            mockSut.trackEvent(event)
        }

        // Then
        #expect(mockSut.eventCount == 4)
        #expect(mockSut.eventCount(for: .transactionAdded) == 2)
        #expect(mockSut.wasCategoryCreated())
        #expect(mockSut.wasExportCompleted(format: "CSV"))
    }

    @Test("Track transaction with nil category")
    func trackTransactionWithNilCategory() throws {
        // Given
        let event = AnalyticsEvent.transactionAdded(amount: 100, category: nil)

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasTransactionAdded(amount: 100))
    }

    @Test("Track transaction with large amount")
    func trackTransactionWithLargeAmount() throws {
        // Given
        let event = AnalyticsEvent.transactionAdded(amount: 999999.99, category: "зарплата")

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasTransactionAdded(amount: 999999.99))
    }

    @Test("Track transaction with zero amount")
    func trackTransactionWithZeroAmount() throws {
        // Given
        let event = AnalyticsEvent.transactionAdded(amount: 0, category: "інше")

        // When
        mockSut.trackEvent(event)

        // Then
        #expect(mockSut.eventCount == 1)
        #expect(mockSut.wasTransactionAdded(amount: 0))
    }

    // MARK: - Error Tracking Tests

    @Test("Track error captures error details")
    func trackErrorCapturesDetails() throws {
        // Given
        let error = NSError(domain: "TestDomain", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Test error"
        ])
        let context = "Transaction creation"

        // When
        mockSut.trackError(error, context: context)

        // Then
        #expect(mockSut.errorCount == 1)
        #expect(mockSut.wasErrorTracked(withContext: "Transaction creation"))
    }

    @Test("Track error with nil context")
    func trackErrorWithNilContext() throws {
        // Given
        let error = NSError(domain: "TestDomain", code: 456)

        // When
        mockSut.trackError(error, context: nil)

        // Then
        #expect(mockSut.errorCount == 1)
        #expect(mockSut.lastErrorContext == nil)
    }

    @Test("Track error with empty context")
    func trackErrorWithEmptyContext() throws {
        // Given
        let error = NSError(domain: "TestDomain", code: 789)

        // When
        mockSut.trackError(error, context: "")

        // Then
        #expect(mockSut.errorCount == 1)
        #expect(mockSut.wasErrorTracked(withContext: ""))
    }

    @Test("Track multiple errors")
    func trackMultipleErrors() throws {
        // Given
        let errors = [
            NSError(domain: "Domain1", code: 1),
            NSError(domain: "Domain2", code: 2),
            NSError(domain: "Domain3", code: 3)
        ]

        // When
        for (index, error) in errors.enumerated() {
            mockSut.trackError(error, context: "Error \(index + 1)")
        }

        // Then
        #expect(mockSut.errorCount == 3)
        #expect(mockSut.wasErrorTracked(withContext: "Error 1"))
        #expect(mockSut.wasErrorTracked(withContext: "Error 2"))
        #expect(mockSut.wasErrorTracked(withContext: "Error 3"))
    }

    @Test("Track repository error")
    func trackRepositoryError() throws {
        // Given
        let repositoryError = RepositoryError.saveFailed(underlying: NSError(domain: "CoreData", code: 1))

        // When
        mockSut.trackError(repositoryError, context: "Saving transaction")

        // Then
        #expect(mockSut.errorCount == 1)
        #expect(mockSut.wasErrorTracked(withContext: "Saving transaction"))
    }

    @Test("Track custom error types")
    func trackCustomErrorTypes() throws {
        // Given
        enum CustomError: Error {
            case invalidInput
            case networkFailure
            case authenticationFailed
        }

        // When
        mockSut.trackError(CustomError.invalidInput, context: "Validation")
        mockSut.trackError(CustomError.networkFailure, context: "API call")
        mockSut.trackError(CustomError.authenticationFailed, context: "Login")

        // Then
        #expect(mockSut.errorCount == 3)
        #expect(mockSut.wasErrorTracked(withContext: "Validation"))
        #expect(mockSut.wasErrorTracked(withContext: "API call"))
        #expect(mockSut.wasErrorTracked(withContext: "Login"))
    }

    // MARK: - Integration Tests

    @Test("Track events and errors together")
    func trackEventsAndErrorsTogether() throws {
        // Given
        let event = AnalyticsEvent.transactionAdded(amount: 100, category: "продукти")
        let error = NSError(domain: "TestDomain", code: 1)

        // When
        mockSut.trackEvent(event)
        mockSut.trackError(error, context: "After event")
        mockSut.trackEvent(.categoryCreated)

        // Then
        #expect(mockSut.eventCount == 2)
        #expect(mockSut.errorCount == 1)
        #expect(mockSut.wasTransactionAdded())
        #expect(mockSut.wasCategoryCreated())
        #expect(mockSut.wasErrorTracked(withContext: "After event"))
    }

    @Test("Analytics events are Equatable")
    func analyticsEventsAreEquatable() throws {
        // Given
        let event1 = AnalyticsEvent.transactionAdded(amount: 100, category: "продукти")
        let event2 = AnalyticsEvent.transactionAdded(amount: 100, category: "продукти")
        let event3 = AnalyticsEvent.transactionAdded(amount: 200, category: "продукти")

        // Then
        #expect(event1 == event2)
        #expect(event1 != event3)
    }

    @Test("Analytics events with different types are not equal")
    func analyticsEventsDifferentTypesNotEqual() throws {
        // Given
        let event1 = AnalyticsEvent.transactionAdded(amount: 100, category: nil)
        let event2 = AnalyticsEvent.transactionDeleted
        let event3 = AnalyticsEvent.categoryCreated

        // Then
        #expect(event1 != event2)
        #expect(event2 != event3)
        #expect(event1 != event3)
    }

    // MARK: - Business Analytics Tests

    @Test("Calculate spending by category returns correct totals")
    func calculateSpendingByCategory() async throws {
        // Given
        let groceries = MockCategory.makeGroceries()
        let taxi = MockCategory.makeTaxi()
        let account = MockAccount.makeDefault()
        let transactions = [
            MockTransaction.makeExpense(amount: 100, category: groceries, account: account),
            MockTransaction.makeExpense(amount: 50, category: groceries, account: account),
            MockTransaction.makeExpense(amount: 30, category: taxi, account: account),
            MockTransaction.makeIncome(amount: 200, account: account)
        ]

        // When
        let results = realSut.spendingByCategory(transactions: transactions)

        // Then
        let groceriesResult = results.first { $0.category.id == groceries.id }
        let taxiResult = results.first { $0.category.id == taxi.id }

        #expect(results.count == 2)
        #expect(DecimalComparison.areEqual(groceriesResult?.total ?? 0, 150))
        #expect(groceriesResult?.transactionCount == 2)
        #expect(DecimalComparison.areEqual(taxiResult?.total ?? 0, 30))
        #expect(taxiResult?.transactionCount == 1)
        #expect(abs((groceriesResult?.percentage ?? 0) - 83.333) < 0.5)
    }

    @Test("Calculate spending trends handles empty data")
    func calculateSpendingTrendsEmptyData() async throws {
        // When
        let results = realSut.spendingTrends(transactions: [])

        // Then
        #expect(results.isEmpty)
    }

    @Test("Calculate monthly comparison works across year boundaries")
    func calculateMonthlyComparison() async throws {
        // Given
        let decExpense = MockTransaction.makeExpense(
            amount: 100,
            date: DateGenerator.date(year: 2024, month: 12, day: 15)
        )
        let decIncome = MockTransaction.makeIncome(
            amount: 300,
            date: DateGenerator.date(year: 2024, month: 12, day: 20)
        )
        let janExpense = MockTransaction.makeExpense(
            amount: 200,
            date: DateGenerator.date(year: 2025, month: 1, day: 10)
        )
        let janIncome = MockTransaction.makeIncome(
            amount: 500,
            date: DateGenerator.date(year: 2025, month: 1, day: 12)
        )

        let transactions = [decExpense, decIncome, janExpense, janIncome]

        // When
        let comparison = realSut.monthlyComparison(
            transactions: transactions,
            referenceDate: DateGenerator.date(year: 2025, month: 1, day: 20)
        )

        // Then
        #expect(DecimalComparison.areEqual(comparison.currentExpenses, 200))
        #expect(DecimalComparison.areEqual(comparison.currentIncome, 500))
        #expect(DecimalComparison.areEqual(comparison.previousExpenses, 100))
        #expect(DecimalComparison.areEqual(comparison.previousIncome, 300))
    }

    @Test("Top merchants calculation returns correct order")
    func topMerchantsCalculation() async throws {
        // Given
        let transactions = [
            MockTransaction.makeExpense(amount: 100, merchantName: "Silpo"),
            MockTransaction.makeExpense(amount: 50, merchantName: "Silpo"),
            MockTransaction.makeExpense(amount: 80, merchantName: "Uber"),
            MockTransaction.makeExpense(amount: 20, merchantName: "АТБ")
        ]

        // When
        let results = realSut.topMerchants(transactions: transactions, limit: 2)

        // Then
        #expect(results.count == 2)
        #expect(results[0].merchant == "Silpo")
        #expect(DecimalComparison.areEqual(results[0].total, 150))
        #expect(results[1].merchant == "Uber")
        #expect(DecimalComparison.areEqual(results[1].total, 80))
    }

    @Test("Analytics respects date range filters")
    func analyticsRespectsDateRangeFilters() async throws {
        // Given
        let janDate = DateGenerator.date(year: 2025, month: 1, day: 5)
        let febDate = DateGenerator.date(year: 2025, month: 2, day: 5)
        let groceries = MockCategory.makeGroceries()

        let transactions = [
            MockTransaction.makeExpense(amount: 100, category: groceries, date: janDate),
            MockTransaction.makeExpense(amount: 200, category: groceries, date: febDate)
        ]

        let januaryRange = janDate...DateGenerator.date(year: 2025, month: 1, day: 31)

        // When
        let results = realSut.spendingByCategory(transactions: transactions, dateRange: januaryRange)

        // Then
        #expect(results.count == 1)
        #expect(DecimalComparison.areEqual(results[0].total, 100))
    }

    @Test("Calculate category breakdown with percentages")
    func calculateCategoryBreakdown() async throws {
        // Given
        let groceries = MockCategory.makeGroceries()
        let taxi = MockCategory.makeTaxi()
        let transactions = [
            MockTransaction.makeExpense(amount: 75, category: groceries),
            MockTransaction.makeExpense(amount: 25, category: taxi)
        ]

        // When
        let results = realSut.spendingByCategory(transactions: transactions)

        // Then
        let groceriesResult = results.first { $0.category.id == groceries.id }
        let taxiResult = results.first { $0.category.id == taxi.id }
        #expect(abs((groceriesResult?.percentage ?? 0) - 75) < 0.1)
        #expect(abs((taxiResult?.percentage ?? 0) - 25) < 0.1)
    }

    @Test("Calculate average transaction amount")
    func calculateAverageTransactionAmount() async throws {
        // Given
        let transactions = [
            MockTransaction.makeExpense(amount: 100),
            MockTransaction.makeExpense(amount: 200),
            MockTransaction.makeIncome(amount: 300)
        ]

        // When
        let average = realSut.averageTransactionAmount(transactions: transactions)

        // Then
        #expect(DecimalComparison.areEqual(average, 200))
    }

    @Test("Identify spending anomalies")
    func identifySpendingAnomalies() async throws {
        // Given
        let transactions = [
            MockTransaction.makeExpense(amount: 10),
            MockTransaction.makeExpense(amount: 12),
            MockTransaction.makeExpense(amount: 11),
            MockTransaction.makeExpense(amount: 60)
        ]

        // When
        let anomalies = realSut.identifySpendingAnomalies(transactions: transactions, sigmaThreshold: 1.0)

        // Then
        #expect(anomalies.count == 1)
        #expect(DecimalComparison.areEqual(anomalies[0].amount, 60))
    }

    @Test("Generate spending forecast")
    func generateSpendingForecast() async throws {
        // Given
        let day1 = DateGenerator.daysAgo(2)
        let day2 = DateGenerator.daysAgo(1)
        let day3 = DateGenerator.today()
        let transactions = [
            MockTransaction.makeExpense(amount: 10, date: day1),
            MockTransaction.makeExpense(amount: 20, date: day2),
            MockTransaction.makeExpense(amount: 30, date: day3)
        ]
        let range = day1...day3

        // When
        let forecast = realSut.generateSpendingForecast(transactions: transactions, days: 5, dateRange: range)

        // Then
        #expect(forecast.count == 5)
        for entry in forecast {
            #expect(DecimalComparison.areEqual(entry.total, 20))
        }
    }

    @Test("Calculate savings rate")
    func calculateSavingsRate() async throws {
        // Given
        let transactions = [
            MockTransaction.makeIncome(amount: 1000),
            MockTransaction.makeExpense(amount: 400)
        ]

        // When
        let rate = realSut.savingsRate(transactions: transactions)

        // Then
        #expect(abs(rate - 0.6) < 0.01)
    }

    @Test("Track budget performance")
    func trackBudgetPerformance() async throws {
        // Given
        let groceries = MockCategory.makeGroceries()
        let taxi = MockCategory.makeTaxi()
        let transactions = [
            MockTransaction.makeExpense(amount: 150, category: groceries),
            MockTransaction.makeExpense(amount: 120, category: taxi)
        ]
        let budgets: [UUID: Decimal] = [
            groceries.id: 200,
            taxi.id: 100
        ]

        // When
        let results = realSut.budgetPerformance(transactions: transactions, budgets: budgets)

        // Then
        let groceriesResult = results.first { $0.categoryId == groceries.id }
        let taxiResult = results.first { $0.categoryId == taxi.id }
        #expect(DecimalComparison.areEqual(groceriesResult?.spent ?? 0, 150))
        #expect(abs((groceriesResult?.percentage ?? 0) - 75) < 0.1)
        #expect(DecimalComparison.areEqual(taxiResult?.spent ?? 0, 120))
        #expect(abs((taxiResult?.percentage ?? 0) - 120) < 0.1)
    }

    @Test("Calculate expense velocity")
    func calculateExpenseVelocity() async throws {
        // Given
        let day1 = DateGenerator.date(year: 2025, month: 1, day: 1)
        let day2 = DateGenerator.date(year: 2025, month: 1, day: 2)
        let day3 = DateGenerator.date(year: 2025, month: 1, day: 3)
        let transactions = [
            MockTransaction.makeExpense(amount: 100, date: day1),
            MockTransaction.makeExpense(amount: 100, date: day2),
            MockTransaction.makeExpense(amount: 100, date: day3)
        ]

        // When
        let velocity = realSut.expenseVelocity(transactions: transactions)

        // Then
        #expect(DecimalComparison.areEqual(velocity, 100))
    }

    // MARK: - Performance Tests

    @Test("Track large number of events performs efficiently")
    func trackLargeNumberOfEvents() throws {
        // Given
        let eventCount = 1000

        // When
        for i in 0..<eventCount {
            let event = AnalyticsEvent.transactionAdded(
                amount: Decimal(i),
                category: "category_\(i % 10)"
            )
            mockSut.trackEvent(event)
        }

        // Then
        #expect(mockSut.eventCount == 1000)
    }

    @Test("Track large number of errors performs efficiently")
    func trackLargeNumberOfErrors() throws {
        // Given
        let errorCount = 100

        // When
        for i in 0..<errorCount {
            let error = NSError(domain: "Domain\(i)", code: i)
            mockSut.trackError(error, context: "Context \(i)")
        }

        // Then
        #expect(mockSut.errorCount == 100)
    }
}
