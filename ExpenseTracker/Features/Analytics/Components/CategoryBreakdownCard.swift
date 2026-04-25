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
    var onCategoryTap: ((Category) -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(String(localized: "analytics.categoryBreakdown"))
                    .font(.headline)
                Spacer()
                if !viewModel.categoryBreakdown.isEmpty {
                    Text(String(localized: "analytics.categoryCount \(viewModel.categoryBreakdown.count)"))
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
                    Text(String(localized: "analytics.noData"))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(String(localized: "analytics.addTransactionsWithCategories"))
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

                    Text(viewModel.categoryBreakdown[0].category.displayName)
                        .font(.headline)
                    Text(viewModel.formatAmount(viewModel.categoryBreakdown[0].amount))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
                .accessibilityIdentifier("ExpenseChart")
            } else {
                // Apple-Fitness-style nested rings — top 4 categories as
                // concentric stroked circles. Center shows total + period.
                NestedCategoryRings(
                    items: Array(viewModel.categoryBreakdown.prefix(4)),
                    centerLabel: String(localized: "analytics.totalExpenses"),
                    centerValue: viewModel.formatAmount(
                        viewModel.categoryBreakdown.reduce(Decimal(0)) { $0 + $1.amount }
                    )
                )
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
                                    Text(item.category.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text(String(localized: "analytics.transactionCount \(item.transactionCount)"))
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
                        Text(String(localized: "analytics.moreCategories \(viewModel.categoryBreakdown.count - 5)"))
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

/// Apple Fitness-style nested category rings.
///
/// Each item gets one concentric stroked ring sized so the total reads
/// 0–100% of that category's share of the period total. Background is
/// the same color at 15% opacity so under-spent rings still register.
private struct NestedCategoryRings: View {
    let items: [CategorySpending]
    let centerLabel: String
    let centerValue: String

    private let stroke: CGFloat = 10
    private let gap: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let outerRadius = (size - stroke) / 2
            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.category.id) { index, item in
                    let radius = outerRadius - CGFloat(index) * (stroke + gap)
                    let color = Color(hex: item.category.colorHex)
                    let progress = min(max(item.percentage / 100.0, 0), 1)

                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.15), lineWidth: stroke)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                color,
                                style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: radius * 2, height: radius * 2)
                }

                VStack(spacing: 2) {
                    Text(centerLabel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.3)
                    Text(centerValue)
                        .font(.system(.title3, design: .rounded).weight(.regular))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 12)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
    }
}
