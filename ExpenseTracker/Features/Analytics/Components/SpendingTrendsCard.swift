//
//  SpendingTrendsCard.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI
import Charts

enum TrendPeriod: String, CaseIterable, Identifiable {
    case week7 = "7 днів"
    case days30 = "30 днів"
    case days90 = "90 днів"

    var id: String { rawValue }

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
                    Text("Тренд витрат")
                        .font(.headline)
                    Spacer()
                }

                Picker("Період", selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
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
                    Text("Немає даних за цей період")
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
                            x: .value("День", item.date, unit: .day),
                            y: .value("Витрати", Double(truncating: NSDecimalNumber(decimal: item.amount)))
                        )
                        .foregroundStyle(Color.red.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("День", item.date, unit: .day),
                            y: .value("Витрати", Double(truncating: NSDecimalNumber(decimal: item.amount)))
                        )
                        .foregroundStyle(Color.red.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }

                    // Average line
                    if let average = averageSpending, average > 0 {
                        RuleMark(y: .value("Середнє", Double(truncating: NSDecimalNumber(decimal: average))))
                            .foregroundStyle(Color.orange.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Середнє: \(viewModel.formatAmount(average))")
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
                        RuleMark(x: .value("День", selectedDay.date, unit: .day))
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
                        title: "Найвищі",
                        value: viewModel.formatAmount(maxSpending),
                        date: maxSpendingDate,
                        color: .red
                    )

                    StatBox(
                        title: "Найнижчі",
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
