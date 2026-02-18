//
//  AnalyticsView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct AnalyticsView: View {
    @StateObject private var analyticsViewModel: AnalyticsViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @Environment(\.selectedTab) private var selectedTabBinding
    @State private var showCustomDatePicker = false

    init(container: DependencyContainer) {
        _analyticsViewModel = StateObject(wrappedValue: container.makeAnalyticsViewModel())
    }

    private var transactionCount: Int {
        transactionViewModel.transactions.count
    }

    private var remaining: Int {
        max(0, AppConstants.analyticsMinTransactions - transactionCount)
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactionCount < AppConstants.analyticsMinTransactions {
                    analyticsEmptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Date range selector
                            DateRangeSelectorView(viewModel: analyticsViewModel, showCustomDatePicker: $showCustomDatePicker)

                            // Month overview
                            MonthOverviewCard(viewModel: analyticsViewModel)

                            // Category breakdown
                            CategoryBreakdownCard(
                                viewModel: analyticsViewModel,
                                onCategoryTap: { category in
                                    transactionViewModel.filterCategories = [category]
                                }
                            )

                            // Spending trends
                            SpendingTrendsCard(viewModel: analyticsViewModel)

                            // Top merchants
                            TopMerchantsCard(viewModel: analyticsViewModel)
                        }
                        .padding()
                    }
                }
            }
            .accessibilityIdentifier("AnalyticsView")
            .navigationTitle(String(localized: "tab.analytics"))
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await analyticsViewModel.loadData()
            }
            .sheet(isPresented: $showCustomDatePicker) {
                CustomDateRangePicker(viewModel: analyticsViewModel)
            }
        }
    }

    // MARK: - Empty State

    private var analyticsEmptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: Spacing.sm) {
                Text(transactionCount == 0
                    ? String(localized: "analytics.empty.zeroTitle")
                    : String(localized: "analytics.empty.unlockTitle \(remaining)"))
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(String(localized: "analytics.empty.explanation"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.sm) {
                ProgressView(
                    value: Double(transactionCount),
                    total: Double(AppConstants.analyticsMinTransactions)
                )
                Text(String(localized: "analytics.empty.progress \(transactionCount) \(AppConstants.analyticsMinTransactions)"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, Spacing.hero)

            VStack(spacing: Spacing.sm) {
                Button {
                    selectedTabBinding.wrappedValue = .quickEntry
                } label: {
                    Text(String(localized: "analytics.empty.addTransaction"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(20)
                }

                Button {
                    selectedTabBinding.wrappedValue = .transactions
                } label: {
                    Text(String(localized: "analytics.empty.goToTransactions"))
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.top, Spacing.sm)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Date Range Selector

struct DateRangeSelectorView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @Binding var showCustomDatePicker: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(String(localized: "filter.period"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalyticsDateRange.allCases) { range in
                        DateRangeChip(
                            title: range.localizedName,
                            isSelected: viewModel.selectedDateRange == range,
                            action: {
                                if range == .custom {
                                    showCustomDatePicker = true
                                } else {
                                    viewModel.selectedDateRange = range
                                }
                            }
                        )
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

struct DateRangeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

// MARK: - Custom Date Range Picker

struct CustomDateRangePicker: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate: Date

    init(viewModel: AnalyticsViewModel) {
        self.viewModel = viewModel
        _startDate = State(initialValue: viewModel.customStartDate)
        _endDate = State(initialValue: viewModel.customEndDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(String(localized: "common.from"), selection: $startDate, displayedComponents: .date)
                    DatePicker(String(localized: "common.to"), selection: $endDate, displayedComponents: .date)
                } header: {
                    Text(String(localized: "analytics.selectPeriod"))
                } footer: {
                    if startDate > endDate {
                        Text(String(localized: "analytics.invalidDateRange"))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "analytics.custom"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.apply")) {
                        viewModel.customStartDate = startDate
                        viewModel.customEndDate = endDate
                        viewModel.selectedDateRange = .custom
                        dismiss()
                    }
                    .disabled(startDate > endDate)
                }
            }
        }
    }
}
