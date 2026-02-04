//
//  CategoryBreakdownCard.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI
import Charts

struct CategoryBreakdownCard: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @Binding var onCategoryTap: ((Category) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Розподіл за категоріями")
                    .font(.headline)
                Spacer()
                if !viewModel.categoryBreakdown.isEmpty {
                    Text("\(viewModel.categoryBreakdown.count) категорій")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.categoryBreakdown.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Немає даних")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Додайте транзакції з категоріями")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else if viewModel.categoryBreakdown.count == 1 {
                // Single category - show as full circle
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: viewModel.categoryBreakdown[0].category.colorHex))
                            .frame(width: 120, height: 120)

                        VStack(spacing: 4) {
                            Image(systemName: viewModel.categoryBreakdown[0].category.icon)
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                            Text("100%")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }

                    Text(viewModel.categoryBreakdown[0].category.name)
                        .font(.headline)
                    Text(viewModel.formatAmount(viewModel.categoryBreakdown[0].amount))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .accessibilityIdentifier("ExpenseChart")
            } else {
                // Pie chart
                Chart(viewModel.categoryBreakdown.prefix(8)) { item in
                    SectorMark(
                        angle: .value("Amount", Double(truncating: NSDecimalNumber(decimal: item.amount))),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color(hex: item.category.colorHex))
                }
                .frame(height: 200)
                .accessibilityIdentifier("ExpenseChart")

                // Top 5 list
                VStack(spacing: 12) {
                    ForEach(viewModel.categoryBreakdown.prefix(5)) { item in
                        Button {
                            onCategoryTap?(item.category)
                        } label: {
                            HStack(spacing: 12) {
                                // Color indicator & icon
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: item.category.colorHex))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: item.category.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }

                                // Category name & count
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.category.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text("\(item.transactionCount) транзакцій")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Amount & percentage
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(viewModel.formatAmount(item.amount))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)

                                    Text(viewModel.formatPercentage(item.percentage))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.categoryBreakdown.count > 5 {
                        Text("+ ще \(viewModel.categoryBreakdown.count - 5) категорій")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}
