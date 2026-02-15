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
         errorHandler: ErrorHandlingServiceProtocol) {
        self.repository = repository
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
        monthComparison = computeMonthComparison()

        // Category breakdown
        categoryBreakdown = computeCategoryBreakdown(expenses: expenses)

        // Top merchants
        topMerchants = computeTopMerchants(expenses: expenses)

        // Daily spending
        let daily = computeDailySpending(expenses: expenses)
        dailySpending = daily
        averageDailySpending = daily.isEmpty ? 0 : daily.reduce(0) { $0 + $1.amount } / Decimal(daily.count)
    }

    private func computeMonthComparison() -> MonthComparison {
        let calendar = Calendar.current
        let now = Date()

        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return MonthComparison(currentExpenses: 0, currentIncome: 0, previousExpenses: 0, previousIncome: 0)
        }

        let currentMonthTransactions = transactions.filter { $0.transactionDate >= currentMonthStart }
        let flattenedCurrent: [Transaction] = currentMonthTransactions.flatMap { $0.isSplitParent ? $0.effectiveSplits : [$0] }

        let currentExpenses = flattenedCurrent.filter { $0.type == .expense }.reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        let currentIncome = flattenedCurrent.filter { $0.type == .income }.reduce(0 as Decimal) { $0 + $1.effectiveAmount }

        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now),
              let previousMonthInterval = calendar.dateInterval(of: .month, for: previousMonthDate) else {
            return MonthComparison(currentExpenses: currentExpenses, currentIncome: currentIncome, previousExpenses: 0, previousIncome: 0)
        }

        let previousMonthTransactions = transactions.filter {
            $0.transactionDate >= previousMonthInterval.start && $0.transactionDate < currentMonthStart
        }
        let flattenedPrevious: [Transaction] = previousMonthTransactions.flatMap { $0.isSplitParent ? $0.effectiveSplits : [$0] }

        let previousExpenses = flattenedPrevious.filter { $0.type == .expense }.reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        let previousIncome = flattenedPrevious.filter { $0.type == .income }.reduce(0 as Decimal) { $0 + $1.effectiveAmount }

        return MonthComparison(currentExpenses: currentExpenses, currentIncome: currentIncome, previousExpenses: previousExpenses, previousIncome: previousIncome)
    }

    private func computeCategoryBreakdown(expenses: [Transaction]) -> [CategorySpending] {
        let totalExpenses = expenses.reduce(0) { $0 + $1.effectiveAmount }
        guard totalExpenses > 0 else { return [] }

        let uncategorizedId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let uncategorizedCategory = Category(id: uncategorizedId, name: "uncategorized", icon: "questionmark.circle", colorHex: "#9E9E9E")
        var categoryTotals: [UUID: (category: Category, amount: Decimal, count: Int)] = [:]

        for transaction in expenses {
            let category = transaction.category ?? uncategorizedCategory
            if let existing = categoryTotals[category.id] {
                categoryTotals[category.id] = (category: category, amount: existing.amount + transaction.effectiveAmount, count: existing.count + 1)
            } else {
                categoryTotals[category.id] = (category: category, amount: transaction.effectiveAmount, count: 1)
            }
        }

        return categoryTotals.values.map { item in
            CategorySpending(
                category: item.category,
                amount: item.amount,
                percentage: Double(truncating: NSDecimalNumber(decimal: item.amount / totalExpenses)) * 100,
                transactionCount: item.count
            )
        }.sorted { $0.amount > $1.amount }
    }

    private func computeTopMerchants(expenses: [Transaction]) -> [MerchantSpending] {
        var merchantTotals: [String: (amount: Decimal, count: Int)] = [:]

        for transaction in expenses {
            let merchant = (transaction.merchantName ?? transaction.description).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !merchant.isEmpty else { continue }
            if let existing = merchantTotals[merchant] {
                merchantTotals[merchant] = (amount: existing.amount + transaction.effectiveAmount, count: existing.count + 1)
            } else {
                merchantTotals[merchant] = (amount: transaction.effectiveAmount, count: 1)
            }
        }

        return merchantTotals.map { merchant, data in
            MerchantSpending(merchantName: merchant, amount: data.amount, transactionCount: data.count)
        }.sorted { $0.amount > $1.amount }
    }

    private func computeDailySpending(expenses: [Transaction]) -> [DailySpending] {
        let calendar = Calendar.current
        var dailyTotals: [Date: Decimal] = [:]

        for transaction in expenses {
            let day = calendar.startOfDay(for: transaction.transactionDate)
            dailyTotals[day, default: 0] += transaction.effectiveAmount
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
