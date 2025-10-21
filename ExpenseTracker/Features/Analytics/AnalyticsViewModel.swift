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
    case currentMonth = "Поточний місяць"
    case lastMonth = "Минулий місяць"
    case last3Months = "Останні 3 місяці"
    case custom = "Власний період"

    var id: String { rawValue }

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
            return interval.start...interval.end
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

    // MARK: - Published Properties
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []

    @Published var selectedDateRange: AnalyticsDateRange = .currentMonth
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var customEndDate: Date = Date()

    @Published var isLoading = false
    @Published var error: Error?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var dateRange: ClosedRange<Date> {
        if selectedDateRange == .custom {
            return customStartDate...customEndDate
        }
        return selectedDateRange.dateRange() ?? (Date()...Date())
    }

    var filteredTransactions: [Transaction] {
        transactions.filter { dateRange.contains($0.transactionDate) }
    }

    var currentMonthExpenses: Decimal {
        filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    var currentMonthIncome: Decimal {
        filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var monthComparison: MonthComparison {
        let calendar = Calendar.current
        let now = Date()

        // Current month
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return MonthComparison(
                currentExpenses: 0,
                currentIncome: 0,
                previousExpenses: 0,
                previousIncome: 0
            )
        }

        let currentMonthTransactions = transactions.filter {
            $0.transactionDate >= currentMonthStart
        }

        let currentExpenses = currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }

        let currentIncome = currentMonthTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }

        // Previous month
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now),
              let previousMonthInterval = calendar.dateInterval(of: .month, for: previousMonthDate) else {
            return MonthComparison(
                currentExpenses: currentExpenses,
                currentIncome: currentIncome,
                previousExpenses: 0,
                previousIncome: 0
            )
        }

        let previousMonthTransactions = transactions.filter {
            previousMonthInterval.contains($0.transactionDate)
        }

        let previousExpenses = previousMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }

        let previousIncome = previousMonthTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }

        return MonthComparison(
            currentExpenses: currentExpenses,
            currentIncome: currentIncome,
            previousExpenses: previousExpenses,
            previousIncome: previousIncome
        )
    }

    var categoryBreakdown: [CategorySpending] {
        let expenses = filteredTransactions.filter { $0.type == .expense }
        let totalExpenses = expenses.reduce(0) { $0 + $1.amount }

        guard totalExpenses > 0 else { return [] }

        var categoryTotals: [UUID: (category: Category, amount: Decimal, count: Int)] = [:]

        for transaction in expenses {
            guard let category = transaction.category else { continue }

            if let existing = categoryTotals[category.id] {
                categoryTotals[category.id] = (
                    category: category,
                    amount: existing.amount + transaction.amount,
                    count: existing.count + 1
                )
            } else {
                categoryTotals[category.id] = (
                    category: category,
                    amount: transaction.amount,
                    count: 1
                )
            }
        }

        return categoryTotals.values.map { item in
            let percentage = Double(truncating: NSDecimalNumber(decimal: item.amount / totalExpenses)) * 100
            return CategorySpending(
                category: item.category,
                amount: item.amount,
                percentage: percentage,
                transactionCount: item.count
            )
        }.sorted { $0.amount > $1.amount }
    }

    var topMerchants: [MerchantSpending] {
        let expenses = filteredTransactions.filter { $0.type == .expense }

        var merchantTotals: [String: (amount: Decimal, count: Int)] = [:]

        for transaction in expenses {
            let merchant = transaction.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !merchant.isEmpty else { continue }

            if let existing = merchantTotals[merchant] {
                merchantTotals[merchant] = (
                    amount: existing.amount + transaction.amount,
                    count: existing.count + 1
                )
            } else {
                merchantTotals[merchant] = (
                    amount: transaction.amount,
                    count: 1
                )
            }
        }

        return merchantTotals.map { merchant, data in
            MerchantSpending(
                merchantName: merchant,
                amount: data.amount,
                transactionCount: data.count
            )
        }.sorted { $0.amount > $1.amount }
    }

    var dailySpending: [DailySpending] {
        let expenses = filteredTransactions.filter { $0.type == .expense }
        let calendar = Calendar.current

        var dailyTotals: [Date: Decimal] = [:]

        for transaction in expenses {
            let day = calendar.startOfDay(for: transaction.transactionDate)

            if let existing = dailyTotals[day] {
                dailyTotals[day] = existing + transaction.amount
            } else {
                dailyTotals[day] = transaction.amount
            }
        }

        // Fill in missing days with zero
        let start = calendar.startOfDay(for: dateRange.lowerBound)
        let end = calendar.startOfDay(for: dateRange.upperBound)
        var currentDate = start

        while currentDate <= end {
            if dailyTotals[currentDate] == nil {
                dailyTotals[currentDate] = 0
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? end
        }

        return dailyTotals.map { date, amount in
            DailySpending(date: date, amount: amount)
        }.sorted { $0.date < $1.date }
    }

    var averageDailySpending: Decimal {
        guard !dailySpending.isEmpty else { return 0 }
        let total = dailySpending.reduce(0) { $0 + $1.amount }
        return total / Decimal(dailySpending.count)
    }

    // MARK: - Initialization

    init(repository: TransactionRepositoryProtocol) {
        self.repository = repository
        setupSubscriptions()
        Task {
            await loadData()
        }
    }

    // MARK: - Setup

    private func setupSubscriptions() {
        repository.transactionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.transactions = transactions
            }
            .store(in: &cancellables)

        repository.categoriesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] categories in
                self?.categories = categories
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let transactions = repository.getAllTransactions()
            async let categories = repository.getAllCategories()

            let (loadedTransactions, loadedCategories) = try await (transactions, categories)

            self.transactions = loadedTransactions
            self.categories = loadedCategories
        } catch {
            self.error = error
#if DEBUG
            print("Error loading analytics data: \(error)")
#endif
        }
    }

    // MARK: - Helper Methods

    func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0

        let absAmount = abs(NSDecimalNumber(decimal: amount).doubleValue)

        if absAmount >= 1_000_000 {
            let millions = amount / 1_000_000
            formatter.maximumFractionDigits = 1
            return formatter.string(from: NSDecimalNumber(decimal: millions))?.replacingOccurrences(of: "₴", with: "") ?? "0" + " млн ₴"
        } else if absAmount >= 1000 {
            let thousands = amount / 1000
            formatter.maximumFractionDigits = 1
            return formatter.string(from: NSDecimalNumber(decimal: thousands))?.replacingOccurrences(of: "₴", with: "") ?? "0" + " тис ₴"
        } else {
            return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴0"
        }
    }

    func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value / 100)) ?? "0%"
    }
}
