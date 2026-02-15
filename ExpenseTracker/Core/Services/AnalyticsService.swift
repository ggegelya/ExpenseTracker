//
//  AnalyticsService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import os

private let analyticsLogger = Logger(subsystem: "com.expensetracker", category: "Analytics")

protocol AnalyticsServiceProtocol {
    func trackEvent(_ event: AnalyticsEvent)
    func trackError(_ error: Error, context: String?)
}

enum AnalyticsEvent {
    case transactionAdded(amount: Decimal, category: String?)
    case transactionDeleted
    case accountConnected(bankName: String)
    case categoryCreated
    case exportCompleted(format: String)
}

final class AnalyticsService: AnalyticsServiceProtocol {
    func trackEvent(_ event: AnalyticsEvent) {
        // In production, send to analytics service
        #if DEBUG
        analyticsLogger.debug("Event: \(String(describing: event))")
        #endif
    }

    func trackError(_ error: Error, context: String?) {
        // In production, send to error tracking service
        analyticsLogger.error("Error: \(error.localizedDescription) — Context: \(context ?? "none")")
    }

    // MARK: - Business Analytics

    struct CategorySpendingSummary: Equatable {
        let category: Category
        let total: Decimal
        let transactionCount: Int
        let percentage: Double
    }

    struct MerchantSpendingSummary: Equatable {
        let merchant: String
        let total: Decimal
        let transactionCount: Int
    }

    struct DailySpendingSummary: Equatable {
        let date: Date
        let total: Decimal
    }

    struct MonthlyComparisonSummary: Equatable {
        let currentExpenses: Decimal
        let currentIncome: Decimal
        let previousExpenses: Decimal
        let previousIncome: Decimal
    }

    struct BudgetPerformanceSummary: Equatable {
        let categoryId: UUID
        let spent: Decimal
        let budget: Decimal
        let percentage: Double
    }

    func spendingByCategory(
        transactions: [Transaction],
        dateRange: ClosedRange<Date>? = nil,
        types: Set<TransactionType> = [.expense]
    ) -> [CategorySpendingSummary] {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: types)
        let flattened = flatten(transactions: filtered)

        let uncategorizedId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let uncategorizedCategory = Category(id: uncategorizedId, name: "uncategorized", icon: "questionmark.circle", colorHex: "#9E9E9E")

        var totals: [UUID: (category: Category, total: Decimal, count: Int)] = [:]
        for transaction in flattened {
            let category = transaction.category ?? uncategorizedCategory
            let entry = totals[category.id] ?? (category, 0, 0)
            totals[category.id] = (category, entry.total + transaction.effectiveAmount, entry.count + 1)
        }

        let totalAmount = totals.values.reduce(0 as Decimal) { $0 + $1.total }
        return totals.values.map { entry in
            let percentage = totalAmount > 0
                ? Double(truncating: NSDecimalNumber(decimal: entry.total / totalAmount)) * 100
                : 0
            return CategorySpendingSummary(
                category: entry.category,
                total: entry.total,
                transactionCount: entry.count,
                percentage: percentage
            )
        }
        .sorted { $0.total > $1.total }
    }

    func spendingTrends(
        transactions: [Transaction],
        dateRange: ClosedRange<Date>? = nil,
        types: Set<TransactionType> = [.expense]
    ) -> [DailySpendingSummary] {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: types)
        let flattened = flatten(transactions: filtered)

        var totals: [Date: Decimal] = [:]
        let calendar = Calendar.current

        for transaction in flattened {
            let day = calendar.startOfDay(for: transaction.transactionDate)
            totals[day, default: 0] += transaction.effectiveAmount
        }

        return totals
            .map { DailySpendingSummary(date: $0.key, total: $0.value) }
            .sorted { $0.date < $1.date }
    }

    func monthlyComparison(
        transactions: [Transaction],
        referenceDate: Date = Date()
    ) -> MonthlyComparisonSummary {
        let calendar = Calendar.current
        let currentInterval = calendar.dateInterval(of: .month, for: referenceDate)
        let previousDate = calendar.date(byAdding: .month, value: -1, to: referenceDate)
        let previousInterval = previousDate.flatMap { calendar.dateInterval(of: .month, for: $0) }

        let currentRange = currentInterval.map { $0.start...$0.end }
        let previousRange = previousInterval.map { $0.start...$0.end }

        let current = filter(transactions: transactions, dateRange: currentRange, types: [.expense, .income])
        let previous = filter(transactions: transactions, dateRange: previousRange, types: [.expense, .income])

        let currentFlattened = flatten(transactions: current)
        let previousFlattened = flatten(transactions: previous)

        let currentExpenses = currentFlattened
            .filter { $0.type == .expense }
            .reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        let currentIncome = currentFlattened
            .filter { $0.type == .income }
            .reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        let previousExpenses = previousFlattened
            .filter { $0.type == .expense }
            .reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        let previousIncome = previousFlattened
            .filter { $0.type == .income }
            .reduce(0 as Decimal) { $0 + $1.effectiveAmount }

        return MonthlyComparisonSummary(
            currentExpenses: currentExpenses,
            currentIncome: currentIncome,
            previousExpenses: previousExpenses,
            previousIncome: previousIncome
        )
    }

    func topMerchants(
        transactions: [Transaction],
        limit: Int = 5,
        dateRange: ClosedRange<Date>? = nil
    ) -> [MerchantSpendingSummary] {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: [.expense])
        let flattened = flatten(transactions: filtered)

        var totals: [String: (total: Decimal, count: Int)] = [:]

        for transaction in flattened {
            let merchant = (transaction.merchantName ?? transaction.description)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !merchant.isEmpty else { continue }
            let entry = totals[merchant] ?? (0, 0)
            totals[merchant] = (entry.total + transaction.effectiveAmount, entry.count + 1)
        }

        return totals
            .map { MerchantSpendingSummary(merchant: $0.key, total: $0.value.total, transactionCount: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    func averageTransactionAmount(
        transactions: [Transaction],
        dateRange: ClosedRange<Date>? = nil,
        types: Set<TransactionType> = [.expense, .income]
    ) -> Decimal {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: types)
        let flattened = flatten(transactions: filtered)
        guard !flattened.isEmpty else { return 0 }
        let total = flattened.reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        return total / Decimal(flattened.count)
    }

    func identifySpendingAnomalies(
        transactions: [Transaction],
        dateRange: ClosedRange<Date>? = nil,
        sigmaThreshold: Double = 2.0
    ) -> [Transaction] {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: [.expense])
        let flattened = flatten(transactions: filtered)
        guard flattened.count >= 2 else { return [] }

        let amounts = flattened.map { NSDecimalNumber(decimal: $0.effectiveAmount).doubleValue }
        let mean = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.reduce(0) { $0 + pow($1 - mean, 2) } / Double(amounts.count)
        let stdDev = sqrt(variance)
        guard stdDev > 0 else { return [] }

        return flattened.filter { transaction in
            let value = NSDecimalNumber(decimal: transaction.effectiveAmount).doubleValue
            return value > mean + (sigmaThreshold * stdDev)
        }
    }

    func generateSpendingForecast(
        transactions: [Transaction],
        days: Int = 30,
        dateRange: ClosedRange<Date>? = nil
    ) -> [DailySpendingSummary] {
        guard days > 0 else { return [] }
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: [.expense])
        let flattened = flatten(transactions: filtered)
        guard !flattened.isEmpty else { return [] }

        let calendar = Calendar.current
        let totals = spendingTrends(transactions: flattened, dateRange: dateRange, types: [.expense])
        let average = totals.isEmpty
            ? Decimal(0)
            : totals.reduce(0 as Decimal) { $0 + $1.total } / Decimal(totals.count)

        let lastDate = (totals.last?.date ?? calendar.startOfDay(for: Date()))
        return (1...days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: lastDate) else { return nil }
            return DailySpendingSummary(date: date, total: average)
        }
    }

    func savingsRate(
        transactions: [Transaction],
        dateRange: ClosedRange<Date>? = nil
    ) -> Double {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: [.expense, .income])
        let flattened = flatten(transactions: filtered)

        let income = flattened
            .filter { $0.type == .income }
            .reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        let expenses = flattened
            .filter { $0.type == .expense }
            .reduce(0 as Decimal) { $0 + $1.effectiveAmount }

        guard income > 0 else { return 0 }
        let rate = (income - expenses) / income
        return Double(truncating: NSDecimalNumber(decimal: rate))
    }

    func budgetPerformance(
        transactions: [Transaction],
        budgets: [UUID: Decimal],
        dateRange: ClosedRange<Date>? = nil
    ) -> [BudgetPerformanceSummary] {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: [.expense])
        let flattened = flatten(transactions: filtered)

        var totals: [UUID: Decimal] = [:]
        for transaction in flattened {
            guard let categoryId = transaction.category?.id else { continue }
            totals[categoryId, default: 0] += transaction.effectiveAmount
        }

        return budgets.map { key, budget in
            let spent = totals[key] ?? 0
            let percentage = budget > 0
                ? Double(truncating: NSDecimalNumber(decimal: spent / budget)) * 100
                : 0
            return BudgetPerformanceSummary(
                categoryId: key,
                spent: spent,
                budget: budget,
                percentage: percentage
            )
        }
    }

    func expenseVelocity(
        transactions: [Transaction],
        dateRange: ClosedRange<Date>? = nil
    ) -> Decimal {
        let filtered = filter(transactions: transactions, dateRange: dateRange, types: [.expense])
        let flattened = flatten(transactions: filtered)
        guard !flattened.isEmpty else { return 0 }

        let calendar = Calendar.current
        let dates = flattened.map { calendar.startOfDay(for: $0.transactionDate) }
        guard let minDate = dates.min(), let maxDate = dates.max() else { return 0 }

        let dayCount = max(1, calendar.dateComponents([.day], from: minDate, to: maxDate).day ?? 0) + 1
        let total = flattened.reduce(0 as Decimal) { $0 + $1.effectiveAmount }
        return total / Decimal(dayCount)
    }

    // MARK: - Helpers

    private func filter(
        transactions: [Transaction],
        dateRange: ClosedRange<Date>?,
        types: Set<TransactionType>
    ) -> [Transaction] {
        transactions.filter { transaction in
            guard types.contains(transaction.type) else { return false }
            if let range = dateRange {
                return range.contains(transaction.transactionDate)
            }
            return true
        }
    }

    private func flatten(transactions: [Transaction]) -> [Transaction] {
        transactions.flatMap { transaction in
            if transaction.isSplitParent {
                return transaction.effectiveSplits
            }
            return [transaction]
        }
    }
}
