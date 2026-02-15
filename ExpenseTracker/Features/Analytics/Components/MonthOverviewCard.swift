//
//  MonthOverviewCard.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct MonthOverviewCard: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @State private var showMonthlyBreakdown = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "analytics.monthOverview"))
                        .font(.headline)
                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    showMonthlyBreakdown = true
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.accentColor)
                }
            }

            // Main stats
            HStack(spacing: 12) {
                // Expenses
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "analytics.expenses"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(viewModel.formatAmount(viewModel.currentMonthExpenses))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if viewModel.selectedDateRange == .currentMonth {
                        ComparisonBadge(
                            change: viewModel.monthComparison.expenseChange,
                            type: .expense
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Income
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "analytics.income"))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(viewModel.formatAmount(viewModel.currentMonthIncome))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if viewModel.selectedDateRange == .currentMonth {
                        ComparisonBadge(
                            change: viewModel.monthComparison.incomeChange,
                            type: .income
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Balance
            VStack(spacing: 8) {
                HStack {
                    Text(String(localized: "analytics.balance"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    let balance = viewModel.currentMonthIncome - viewModel.currentMonthExpenses
                    Text(viewModel.formatAmount(balance))
                        .font(.headline)
                        .foregroundColor(balance >= 0 ? .green : .red)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        // Income bar (full width if income > 0)
                        if viewModel.currentMonthIncome > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green.opacity(0.3))
                                .frame(width: geometry.size.width, height: 8)
                        }

                        // Expense bar (proportional to expenses/income)
                        if viewModel.currentMonthIncome > 0 {
                            let ratio = min(1.0, Double(truncating: NSDecimalNumber(decimal: viewModel.currentMonthExpenses / viewModel.currentMonthIncome)))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: geometry.size.width * ratio, height: 8)
                        }
                    }
                }
                .frame(height: 8)

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 8, height: 8)
                        Text(String(localized: "analytics.expenses"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(String(localized: "analytics.income"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showMonthlyBreakdown) {
            MonthlyBreakdownSheet(viewModel: viewModel)
        }
    }

    private var dateRangeText: String {
        let start = viewModel.dateRange.lowerBound
        let end = viewModel.dateRange.upperBound

        return "\(Self.dayMonthFormatter.string(from: start)) - \(Self.dayMonthFormatter.string(from: end))"
    }

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter
    }()
}

// MARK: - Comparison Badge

struct ComparisonBadge: View {
    let change: Double
    let type: TransactionType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "minus")
                .font(.caption2)

            Text(abs(change).formatted(.percent.precision(.fractionLength(1))))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(4)
    }

    private var badgeColor: Color {
        if type == .expense {
            // For expenses, increase is bad (red), decrease is good (green)
            return change > 0 ? .red : change < 0 ? .green : .gray
        } else {
            // For income, increase is good (green), decrease is bad (red)
            return change > 0 ? .green : change < 0 ? .red : .gray
        }
    }
}

// MARK: - Monthly Breakdown Sheet

struct MonthlyBreakdownSheet: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatRow(
                        title: String(localized: "analytics.totalExpenses"),
                        value: viewModel.formatAmount(viewModel.currentMonthExpenses),
                        color: .red
                    )
                    StatRow(
                        title: String(localized: "analytics.totalIncome"),
                        value: viewModel.formatAmount(viewModel.currentMonthIncome),
                        color: .green
                    )
                    StatRow(
                        title: String(localized: "analytics.balance"),
                        value: viewModel.formatAmount(viewModel.currentMonthIncome - viewModel.currentMonthExpenses),
                        color: (viewModel.currentMonthIncome - viewModel.currentMonthExpenses) >= 0 ? .green : .red
                    )
                } header: {
                    Text(String(localized: "analytics.summary"))
                }

                if viewModel.selectedDateRange == .currentMonth {
                    Section {
                        StatRow(
                            title: String(localized: "analytics.previousExpenses"),
                            value: viewModel.formatAmount(viewModel.monthComparison.previousExpenses),
                            color: .secondary
                        )
                        StatRow(
                            title: String(localized: "analytics.previousIncome"),
                            value: viewModel.formatAmount(viewModel.monthComparison.previousIncome),
                            color: .secondary
                        )
                    } header: {
                        Text(String(localized: "analytics.comparison"))
                    }
                }

                Section {
                    StatRow(
                        title: String(localized: "analytics.averageDailySpending"),
                        value: viewModel.formatAmount(viewModel.averageDailySpending),
                        color: .orange
                    )
                } header: {
                    Text(String(localized: "analytics.statistics"))
                }
            }
            .navigationTitle(String(localized: "analytics.detailedOverview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}
