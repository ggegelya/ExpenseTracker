//
//  AnalyticsViewModel.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI
import Combine

// MARK: - Date Range Options

enum AnalyticsDateRange: String, CaseIterable, Identifiable {
    case currentMonth = "currentMonth"
    case lastMonth = "lastMonth"
    case last3Months = "last3Months"
    case custom = "custom"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .currentMonth: return String(localized: "analytics.currentMonth")
        case .lastMonth: return String(localized: "analytics.lastMonth")
        case .last3Months: return String(localized: "analytics.last3Months")
        case .custom: return String(localized: "analytics.custom")
        }
    }

    func dateRange() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .currentMonth:
            guard let start = calendar.dateInterval(of: .month, for: now)?.start else {
                return nil
            }
            return start...now
        case .lastMonth:
            guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                  let interval = calendar.dateInterval(of: .month, for: lastMonth) else {
                return nil
            }
            // DateInterval.end is the first instant of the next month; use end - 1s
            let lastInstant = interval.end.addingTimeInterval(-1)
            return interval.start...lastInstant
        case .last3Months:
            guard let start = calendar.date(byAdding: .month, value: -3, to: now) else {
                return nil
            }
            return start...now
        case .custom:
            return nil
        }
    }
}

// MARK: - Data Models

struct CategorySpending: Identifiable {
    let id = UUID()
    let category: Category
    let amount: Decimal
    let percentage: Double
    let transactionCount: Int
}

struct MerchantSpending: Identifiable {
    let id = UUID()
    let merchantName: String
    let amount: Decimal
    let transactionCount: Int
}

struct DailySpending: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
}

struct MonthComparison {
    let currentExpenses: Decimal
    let currentIncome: Decimal
    let previousExpenses: Decimal
    let previousIncome: Decimal

    var expenseChange: Double {
        guard previousExpenses > 0 else { return 0 }
        let change = (currentExpenses - previousExpenses) / previousExpenses
        return Double(truncating: NSDecimalNumber(decimal: change)) * 100
    }

    var incomeChange: Double {
        guard previousIncome > 0 else { return 0 }
        let change = (currentIncome - previousIncome) / previousIncome
        return Double(truncating: NSDecimalNumber(decimal: change)) * 100
    }
}

// MARK: - Analytics ViewModel

@MainActor
final class AnalyticsViewModel: ObservableObject {
    // MARK: - Dependencies
    private let repository: TransactionRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let errorHandler: ErrorHandlingServiceProtocol

    // MARK: - Published Properties
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []

    @Published var selectedDateRange: AnalyticsDateRange = .currentMonth
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var customEndDate: Date = Date()

    @Published var isLoading = false
    @Published var error: AppError?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cached Filtered/Computed Results
    @Published private(set) var filteredTransactions: [Transaction] = []
    @Published private(set) var currentMonthExpenses: Decimal = 0
    @Published private(set) var currentMonthIncome: Decimal = 0
    @Published private(set) var monthComparison: MonthComparison = MonthComparison(currentExpenses: 0, currentIncome: 0, previousExpenses: 0, previousIncome: 0)
    @Published private(set) var categoryBreakdown: [CategorySpending] = []
    @Published private(set) var topMerchants: [MerchantSpending] = []
    @Published private(set) var dailySpending: [DailySpending] = []
    @Published private(set) var averageDailySpending: Decimal = 0

    // MARK: - Computed Properties

    var dateRange: ClosedRange<Date> {
        if selectedDateRange == .custom {
            return customStartDate...customEndDate
        }
        return selectedDateRange.dateRange() ?? (Date()...Date())
    }

    var flattenedFilteredTransactions: [Transaction] {
        filteredTransactions.flatMap { transaction -> [Transaction] in
            if transaction.isSplitParent {
                return transaction.effectiveSplits
            }
            return [transaction]
        }
    }

    // MARK: - Initialization

    init(repository: TransactionRepositoryProtocol,
         analyticsService: AnalyticsServiceProtocol,
         errorHandler: ErrorHandlingServiceProtocol) {
        self.repository = repository
        self.analyticsService = analyticsService
        self.errorHandler = errorHandler
        setupSubscriptions()
        Task { @MainActor in
            await loadData()
        }
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        repository.transactionsPublisher
            .sink { [weak self] transactions in
                self?.transactions = transactions
            }
            .store(in: &cancellables)

        repository.categoriesPublisher
            .sink { [weak self] categories in
                self?.categories = categories
            }
            .store(in: &cancellables)

        // Filter pipeline: recalculate filteredTransactions when inputs change
        Publishers.MergeMany([
            $transactions.map { _ in () }.eraseToAnyPublisher(),
            $selectedDateRange.map { _ in () }.eraseToAnyPublisher(),
            $customStartDate.map { _ in () }.eraseToAnyPublisher(),
            $customEndDate.map { _ in () }.eraseToAnyPublisher()
        ])
        .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.updateFilteredTransactions()
        }
        .store(in: &cancellables)
    }

    private func updateFilteredTransactions() {
        filteredTransactions = transactions.filter { dateRange.contains($0.transactionDate) }
        recomputeAnalytics()
    }

    private func recomputeAnalytics() {
        let flattened = flattenedFilteredTransactions
        let expenses = flattened.filter { $0.type == .expense }

        // Current/income totals
        currentMonthExpenses = expenses.reduce(0) { $0 + $1.effectiveAmount }
        currentMonthIncome = flattened.filter { $0.type == .income }.reduce(0) { $0 + $1.effectiveAmount }

        // Month comparison (always uses full transactions, not filtered)
        let comparison = analyticsService.monthlyComparison(transactions: transactions, referenceDate: Date())
        monthComparison = MonthComparison(
            currentExpenses: comparison.currentExpenses,
            currentIncome: comparison.currentIncome,
            previousExpenses: comparison.previousExpenses,
            previousIncome: comparison.previousIncome
        )

        // Category breakdown
        let categoryResults = analyticsService.spendingByCategory(
            transactions: filteredTransactions, dateRange: nil, types: [.expense]
        )
        categoryBreakdown = categoryResults.map {
            CategorySpending(category: $0.category, amount: $0.total, percentage: $0.percentage, transactionCount: $0.transactionCount)
        }

        // Top merchants
        let merchantResults = analyticsService.topMerchants(
            transactions: filteredTransactions, limit: .max, dateRange: nil
        )
        topMerchants = merchantResults.map {
            MerchantSpending(merchantName: $0.merchant, amount: $0.total, transactionCount: $0.transactionCount)
        }

        // Daily spending — use service trends + fill gaps for chart
        let trendResults = analyticsService.spendingTrends(
            transactions: filteredTransactions, dateRange: nil, types: [.expense]
        )
        let daily = fillDailyGaps(from: trendResults)
        dailySpending = daily
        averageDailySpending = daily.isEmpty ? 0 : daily.reduce(0) { $0 + $1.amount } / Decimal(daily.count)
    }

    /// Fills missing days with zero amounts for continuous chart display.
    private func fillDailyGaps(from trends: [AnalyticsService.DailySpendingSummary]) -> [DailySpending] {
        let calendar = Calendar.current
        var dailyTotals: [Date: Decimal] = [:]
        for entry in trends {
            dailyTotals[calendar.startOfDay(for: entry.date)] = entry.total
        }

        let start = calendar.startOfDay(for: dateRange.lowerBound)
        let end = calendar.startOfDay(for: dateRange.upperBound)
        guard start <= end else { return [] }
        var currentDate = start
        var iterations = 0

        while currentDate <= end, iterations < 366 {
            if dailyTotals[currentDate] == nil { dailyTotals[currentDate] = 0 }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
            iterations += 1
        }

        return dailyTotals.map { DailySpending(date: $0.key, amount: $0.value) }.sorted { $0.date < $1.date }
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedTransactions = try await repository.getAllTransactions()
            let loadedCategories = try await repository.getAllCategories()

            self.transactions = loadedTransactions
            self.categories = loadedCategories
        } catch {
            self.error = errorHandler.handleAny(error, context: "Loading analytics data")
        }
    }

    // MARK: - Helper Methods

    func formatAmount(_ amount: Decimal) -> String {
        let absAmount = abs(NSDecimalNumber(decimal: amount).doubleValue)

        if absAmount >= 1_000_000 {
            let millions = amount / 1_000_000
            let formatted = Formatters.decimalString(millions, minFractionDigits: 0, maxFractionDigits: 1)
            return "\(formatted) \(String(localized: "analytics.million")) ₴"
        } else if absAmount >= 1000 {
            let thousands = amount / 1000
            let formatted = Formatters.decimalString(thousands, minFractionDigits: 0, maxFractionDigits: 1)
            return "\(formatted) \(String(localized: "analytics.thousand")) ₴"
        } else {
            return Formatters.currencyStringUAH(amount: amount, minFractionDigits: 0, maxFractionDigits: 0)
        }
    }

    func formatPercentage(_ value: Double) -> String {
        let formatter = Formatters.percentFormatter(maxFractionDigits: 1)
        return formatter.string(from: NSNumber(value: value / 100)) ?? "0%"
    }

}
