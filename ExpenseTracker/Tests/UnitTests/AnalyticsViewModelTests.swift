//
//  AnalyticsViewModelTests.swift
//  ExpenseTracker
//
//  Tests for AnalyticsViewModel covering data loading, date range filtering,
//  expense/income sums, month comparison, category breakdown, top merchants,
//  daily spending, and formatting methods.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("AnalyticsViewModel Tests", .serialized)
@MainActor
struct AnalyticsViewModelTests {
    var sut: AnalyticsViewModel
    var mockRepository: MockTransactionRepository
    var mockErrorHandler: MockErrorHandlingService

    init() async throws {
        mockRepository = MockTransactionRepository()
        mockErrorHandler = MockErrorHandlingService()

        sut = AnalyticsViewModel(
            repository: mockRepository,
            analyticsService: MockAnalyticsService(),
            errorHandler: mockErrorHandler
        )
    }

    // MARK: - Load Data Tests

    @Test("loadData populates transactions and categories")
    func loadDataPopulatesTransactionsAndCategories() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let categories = MockCategory.makeDefaultCategories()
        let transactions = MockTransaction.makeMultiple(count: 5, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = categories
        mockRepository.transactions = transactions

        // When
        await sut.loadData()

        // Then
        #expect(sut.transactions.count == 5)
        #expect(sut.categories.count == categories.count)
        #expect(!sut.isLoading)
        #expect(mockRepository.wasCalled("getAllTransactions()"))
        #expect(mockRepository.wasCalled("getAllCategories()"))
    }

    @Test("loadData handles repository errors gracefully")
    func loadDataHandlesRepositoryErrors() async throws {
        // Given
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = NSError(domain: "Test", code: -1, userInfo: nil)

        // When
        await sut.loadData()

        // Then
        #expect(sut.error != nil)
        #expect(!sut.isLoading)
        #expect(mockErrorHandler.handledErrors.count == 1)
    }

    // MARK: - Date Range Filtering Tests

    @Test("selectedDateRange currentMonth filters to current month")
    func selectedDateRangeCurrentMonthFilters() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.today()),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.daysAgo(60))
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.filteredTransactions.count == 1)
        #expect(sut.filteredTransactions.first?.amount == Decimal(100))
    }

    @Test("selectedDateRange last3Months includes transactions from 3 months")
    func selectedDateRangeLast3MonthsFilters() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.today()),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.daysAgo(60)),
            MockTransaction.makeExpense(amount: 300, category: category, account: account, date: DateGenerator.daysAgo(120))
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .last3Months
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then - should include transactions within last 3 months
        #expect(sut.filteredTransactions.count == 2)
    }

    @Test("custom date range uses customStartDate and customEndDate")
    func customDateRangeUsesCustomDates() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let targetDate = DateGenerator.daysAgo(15)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.today()),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: targetDate),
            MockTransaction.makeExpense(amount: 300, category: category, account: account, date: DateGenerator.daysAgo(60))
        ]

        // When
        await sut.loadData()
        sut.customStartDate = DateGenerator.daysAgo(20)
        sut.customEndDate = DateGenerator.daysAgo(10)
        sut.selectedDateRange = .custom
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.filteredTransactions.count == 1)
        #expect(sut.filteredTransactions.first?.amount == Decimal(200))
    }

    // MARK: - Expense/Income Totals Tests

    @Test("currentMonthExpenses correctly sums expense transactions")
    func currentMonthExpensesCorrectlySums() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.today()),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.today()),
            MockTransaction.makeIncome(amount: 5000, category: category, account: account, date: DateGenerator.today())
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.currentMonthExpenses == Decimal(300))
    }

    @Test("currentMonthIncome correctly sums income transactions")
    func currentMonthIncomeCorrectlySums() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeSalary()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, account: account, date: DateGenerator.today()),
            MockTransaction.makeIncome(amount: 5000, category: category, account: account, date: DateGenerator.today()),
            MockTransaction.makeIncome(amount: 3000, category: category, account: account, date: DateGenerator.today())
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.currentMonthIncome == Decimal(8000))
    }

    // MARK: - Month Comparison Tests

    @Test("monthComparison calculates current and previous month")
    func monthComparisonCalculatesCorrectly() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let currentMonthDate = DateGenerator.today()
        let lastMonthDate = DateGenerator.startOfLastMonth()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: currentMonthDate),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: currentMonthDate),
            MockTransaction.makeExpense(amount: 500, category: category, account: account, date: lastMonthDate)
        ]

        // When
        await sut.loadData()
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.monthComparison.currentExpenses == Decimal(300))
        #expect(sut.monthComparison.previousExpenses == Decimal(500))
    }

    @Test("monthComparison handles zero previous month without division by zero")
    func monthComparisonHandlesZeroPreviousMonth() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.today())
        ]

        // When
        await sut.loadData()
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then - should not crash, should return 0 for change
        #expect(sut.monthComparison.previousExpenses == Decimal(0))
        #expect(sut.monthComparison.expenseChange == 0)
    }

    @Test("MonthComparison expenseChange calculates percentage correctly")
    func monthComparisonExpenseChangeCalculatesPercentage() async throws {
        // Given
        let comparison = MonthComparison(
            currentExpenses: 150,
            currentIncome: 0,
            previousExpenses: 100,
            previousIncome: 0
        )

        // Then
        #expect(comparison.expenseChange == 50.0) // 50% increase
    }

    @Test("MonthComparison incomeChange calculates percentage correctly")
    func monthComparisonIncomeChangeCalculatesPercentage() async throws {
        // Given
        let comparison = MonthComparison(
            currentExpenses: 0,
            currentIncome: 200,
            previousExpenses: 0,
            previousIncome: 100
        )

        // Then
        #expect(comparison.incomeChange == 100.0) // 100% increase
    }

    // MARK: - Category Breakdown Tests

    @Test("categoryBreakdown groups expenses by category with correct percentages")
    func categoryBreakdownGroupsByCategory() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()

        mockRepository.accounts = [account]
        mockRepository.categories = [groceries, transport]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 300, category: groceries, account: account, date: DateGenerator.today()),
            MockTransaction.makeExpense(amount: 200, category: transport, account: account, date: DateGenerator.today()),
            MockTransaction.makeExpense(amount: 100, category: groceries, account: account, date: DateGenerator.today())
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.categoryBreakdown.count == 2)
        // Sorted by amount descending
        let first = sut.categoryBreakdown.first
        #expect(first?.category.id == groceries.id)
        #expect(first?.amount == Decimal(400))
        #expect(first?.transactionCount == 2)
        // Percentage: 400/600 ≈ 66.67%
        #expect(abs(first!.percentage - 66.67) < 1.0)
    }

    @Test("categoryBreakdown handles uncategorized transactions")
    func categoryBreakdownHandlesUncategorized() async throws {
        // Given
        let account = MockAccount.makeDefault()

        // Create a transaction with nil category directly (not via MockTransaction which defaults to groceries)
        let uncategorizedTransaction = Transaction(
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 100,
            category: nil,
            description: "Uncategorized purchase",
            fromAccount: account
        )

        mockRepository.accounts = [account]
        mockRepository.categories = []
        mockRepository.transactions = [uncategorizedTransaction]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then - should handle nil category with "uncategorized"
        #expect(sut.categoryBreakdown.count == 1)
        #expect(sut.categoryBreakdown.first?.category.name == "uncategorized")
    }

    @Test("categoryBreakdown returns empty for no expenses")
    func categoryBreakdownEmptyForNoExpenses() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeSalary()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeIncome(amount: 5000, category: category, account: account, date: DateGenerator.today())
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.categoryBreakdown.isEmpty)
    }

    // MARK: - Top Merchants Tests

    @Test("topMerchants aggregates by merchant name")
    func topMerchantsAggregatesByMerchant() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.today(), merchantName: "Сільпо"),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.today(), merchantName: "Сільпо"),
            MockTransaction.makeExpense(amount: 150, category: category, account: account, date: DateGenerator.today(), merchantName: "АТБ")
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.topMerchants.count == 2)
        let silpo = sut.topMerchants.first { $0.merchantName == "Сільпо" }
        #expect(silpo?.amount == Decimal(300))
        #expect(silpo?.transactionCount == 2)
    }

    @Test("topMerchants excludes empty merchant names")
    func topMerchantsExcludesEmpty() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, description: "", date: DateGenerator.today(), merchantName: ""),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.today(), merchantName: "Сільпо")
        ]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then - empty merchant should be excluded
        let emptyMerchant = sut.topMerchants.first { $0.merchantName.isEmpty }
        #expect(emptyMerchant == nil)
    }

    // MARK: - Daily Spending Tests

    @Test("dailySpending generates correct per-day amounts")
    func dailySpendingGeneratesCorrectAmounts() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let day1 = DateGenerator.daysAgo(2)
        let day2 = DateGenerator.daysAgo(1)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: day1),
            MockTransaction.makeExpense(amount: 50, category: category, account: account, date: day1),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: day2)
        ]

        // When
        await sut.loadData()
        sut.customStartDate = DateGenerator.daysAgo(3)
        sut.customEndDate = DateGenerator.today()
        sut.selectedDateRange = .custom
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        let dayAmounts = Dictionary(uniqueKeysWithValues: sut.dailySpending.map {
            (Calendar.current.startOfDay(for: $0.date), $0.amount)
        })
        #expect(dayAmounts[Calendar.current.startOfDay(for: day1)] == Decimal(150))
        #expect(dayAmounts[Calendar.current.startOfDay(for: day2)] == Decimal(200))
    }

    @Test("dailySpending fills zero for days without transactions")
    func dailySpendingFillsZeroForEmptyDays() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.daysAgo(2))
        ]

        // When
        await sut.loadData()
        sut.customStartDate = DateGenerator.daysAgo(3)
        sut.customEndDate = DateGenerator.today()
        sut.selectedDateRange = .custom
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then - should have entries for all days in range including zero-spending days
        let zeroDays = sut.dailySpending.filter { $0.amount == 0 }
        #expect(!zeroDays.isEmpty)
    }

    @Test("averageDailySpending calculates correct mean")
    func averageDailySpendingCalculatesCorrectMean() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.daysAgo(1)),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.today())
        ]

        // When
        await sut.loadData()
        sut.customStartDate = DateGenerator.daysAgo(1)
        sut.customEndDate = DateGenerator.today()
        sut.selectedDateRange = .custom
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then - total 300 across 2 days = average 150
        #expect(DecimalComparison.areEqual(sut.averageDailySpending, 150))
    }

    // MARK: - Format Tests

    @Test("formatAmount uses K suffix for thousands")
    func formatAmountUsesKForThousands() async throws {
        // When
        let result = sut.formatAmount(Decimal(5000))

        // Then - should contain thousands indicator
        #expect(result.contains("₴"))
        #expect(result.contains("5"))
    }

    @Test("formatAmount uses M suffix for millions")
    func formatAmountUsesMForMillions() async throws {
        // When
        let result = sut.formatAmount(Decimal(2_500_000))

        // Then - should contain millions indicator
        #expect(result.contains("₴"))
        #expect(result.contains("2"))
    }

    @Test("formatAmount formats small amounts directly")
    func formatAmountFormatsSmallAmounts() async throws {
        // When
        let result = sut.formatAmount(Decimal(500))

        // Then - should be formatted as regular currency
        #expect(result.contains("500"))
        #expect(result.contains("₴"))
    }

    @Test("formatPercentage formats correctly")
    func formatPercentageFormatsCorrectly() async throws {
        // When
        let result = sut.formatPercentage(75.5)

        // Then
        #expect(result.contains("75"))
        #expect(result.contains("%"))
    }

    // MARK: - Flattened Transactions Tests

    @Test("flattenedFilteredTransactions includes split children")
    func flattenedFilteredTransactionsIncludesSplitChildren() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()

        let splitParent = Transaction(
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 500,
            description: "Split Purchase",
            fromAccount: account,
            splitTransactions: [
                Transaction(
                    transactionDate: DateGenerator.today(),
                    type: .expense,
                    amount: 300,
                    category: groceries,
                    description: "Groceries part",
                    fromAccount: account,
                    parentTransactionId: UUID()
                ),
                Transaction(
                    transactionDate: DateGenerator.today(),
                    type: .expense,
                    amount: 200,
                    category: transport,
                    description: "Transport part",
                    fromAccount: account,
                    parentTransactionId: UUID()
                )
            ]
        )

        mockRepository.accounts = [account]
        mockRepository.categories = [groceries, transport]
        mockRepository.transactions = [splitParent]

        // When
        await sut.loadData()
        sut.selectedDateRange = .currentMonth
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then - flattened should contain the split children
        #expect(sut.flattenedFilteredTransactions.count == 2)
    }

    // MARK: - AnalyticsDateRange Tests

    @Test("AnalyticsDateRange currentMonth returns valid date range")
    func analyticsDateRangeCurrentMonth() async throws {
        let range = AnalyticsDateRange.currentMonth.dateRange()
        #expect(range != nil)
    }

    @Test("AnalyticsDateRange lastMonth returns valid date range")
    func analyticsDateRangeLastMonth() async throws {
        let range = AnalyticsDateRange.lastMonth.dateRange()
        #expect(range != nil)
    }

    @Test("AnalyticsDateRange last3Months returns valid date range")
    func analyticsDateRangeLast3Months() async throws {
        let range = AnalyticsDateRange.last3Months.dateRange()
        #expect(range != nil)
    }

    @Test("AnalyticsDateRange custom returns nil")
    func analyticsDateRangeCustomReturnsNil() async throws {
        let range = AnalyticsDateRange.custom.dateRange()
        #expect(range == nil)
    }

    @Test("AnalyticsDateRange localizedName returns non-empty for all cases")
    func analyticsDateRangeLocalizedNames() async throws {
        for range in AnalyticsDateRange.allCases {
            #expect(!range.localizedName.isEmpty, "localizedName should not be empty for \(range)")
        }
    }
}
