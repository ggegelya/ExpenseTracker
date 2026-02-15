//
//  SpendingTrendsCard.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI
import Charts

enum TrendPeriod: String, CaseIterable, Identifiable {
    case week7 = "7days"
    case days30 = "30days"
    case days90 = "90days"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .week7: return String(localized: "trend.7days")
        case .days30: return String(localized: "trend.30days")
        case .days90: return String(localized: "trend.90days")
        }
    }

    var days: Int {
        switch self {
        case .week7: return 7
        case .days30: return 30
        case .days90: return 90
        }
    }
}

struct SpendingTrendsCard: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @State private var selectedPeriod: TrendPeriod = .days30
    @State private var selectedDay: DailySpending?

    var body: some View {
        VStack(spacing: 16) {
            // Header with period selector
            VStack(spacing: 12) {
                HStack {
                    Text(String(localized: "analytics.spendingTrend"))
                        .font(.headline)
                    Spacer()
                }

                Picker(String(localized: "filter.period"), selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.localizedName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }

            if filteredDailySpending.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(String(localized: "analytics.noDataForPeriod"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else {
                // Line chart
                Chart {
                    // Daily spending line
                    ForEach(filteredDailySpending) { item in
                        LineMark(
                            x: .value(String(localized: "chart.day"), item.date, unit: .day),
                            y: .value(String(localized: "chart.expenses"), Double(truncating: NSDecimalNumber(decimal: item.amount)))
                        )
                        .foregroundStyle(Color.red.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value(String(localized: "chart.day"), item.date, unit: .day),
                            y: .value(String(localized: "chart.expenses"), Double(truncating: NSDecimalNumber(decimal: item.amount)))
                        )
                        .foregroundStyle(Color.red.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }

                    // Average line
                    if let average = averageSpending, average > 0 {
                        RuleMark(y: .value(String(localized: "chart.average"), Double(truncating: NSDecimalNumber(decimal: average))))
                            .foregroundStyle(Color.orange.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("\(String(localized: "analytics.average")): \(viewModel.formatAmount(average))")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                    }

                    // Selection
                    if let selectedDay = selectedDay {
                        RuleMark(x: .value(String(localized: "chart.day"), selectedDay.date, unit: .day))
                            .foregroundStyle(Color.accentColor.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .annotation(position: .top) {
                                VStack(spacing: 2) {
                                    Text(selectedDay.date, format: .dateTime.day().month())
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                    Text(viewModel.formatAmount(selectedDay.amount))
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground))
                                .cornerRadius(6)
                                .shadow(radius: 2)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: xAxisStride)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.day().month(.abbreviated))
                                    .font(.caption2)
                            }
                            AxisGridLine()
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(viewModel.formatAmount(Decimal(amount)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)

                // Stats
                HStack(spacing: 16) {
                    StatBox(
                        title: String(localized: "analytics.highest"),
                        value: viewModel.formatAmount(maxSpending),
                        date: maxSpendingDate,
                        color: .red
                    )

                    StatBox(
                        title: String(localized: "analytics.lowest"),
                        value: viewModel.formatAmount(minSpending),
                        date: minSpendingDate,
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Computed Properties

    private var filteredDailySpending: [DailySpending] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) else {
            return []
        }

        return viewModel.dailySpending.filter { spending in
            spending.date >= startDate && spending.date <= endDate
        }
    }

    private var averageSpending: Decimal? {
        guard !filteredDailySpending.isEmpty else { return nil }
        let total = filteredDailySpending.reduce(Decimal(0)) { $0 + $1.amount }
        return total / Decimal(filteredDailySpending.count)
    }

    private var maxSpending: Decimal {
        filteredDailySpending.map { $0.amount }.max() ?? 0
    }

    private var maxSpendingDate: Date? {
        filteredDailySpending.max { $0.amount < $1.amount }?.date
    }

    private var minSpending: Decimal {
        filteredDailySpending.map { $0.amount }.min() ?? 0
    }

    private var minSpendingDate: Date? {
        filteredDailySpending.min { $0.amount < $1.amount }?.date
    }

    private var xAxisStride: Calendar.Component {
        switch selectedPeriod {
        case .week7:
            return .day
        case .days30:
            return .weekOfYear
        case .days90:
            return .month
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let date: Date?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)

            if let date = date {
                Text(date, format: .dateTime.day().month())
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
