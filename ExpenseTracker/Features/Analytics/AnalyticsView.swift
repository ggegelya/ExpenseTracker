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
    @State private var showCustomDatePicker = false

    init(container: DependencyContainer) {
        _analyticsViewModel = StateObject(wrappedValue: container.makeAnalyticsViewModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactionViewModel.transactions.count < AppConstants.analyticsMinTransactions {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "chart.pie")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(String(localized: "analytics.empty.title"))
                            .font(.headline)
                        Text("analytics.empty.subtitle \(transactionViewModel.transactions.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        ProgressView(value: Double(transactionViewModel.transactions.count), total: Double(AppConstants.analyticsMinTransactions))
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
