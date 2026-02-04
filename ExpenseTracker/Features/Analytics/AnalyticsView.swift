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
    @State private var showDateRangePicker = false
    @State private var showCustomDatePicker = false
    @State private var selectedCategoryFilter: ((Category) -> Void)? = nil

    init(container: DependencyContainer) {
        _analyticsViewModel = StateObject(wrappedValue: container.makeAnalyticsViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date range selector
                    DateRangeSelectorView(viewModel: analyticsViewModel, showCustomDatePicker: $showCustomDatePicker)

                    // Month overview
                    MonthOverviewCard(viewModel: analyticsViewModel)

                    // Category breakdown
                    CategoryBreakdownCard(
                        viewModel: analyticsViewModel,
                        onCategoryTap: .constant({ category in
                            // Navigate to transactions filtered by category
                            transactionViewModel.filterCategories = [category]
                        })
                    )

                    // Spending trends
                    SpendingTrendsCard(viewModel: analyticsViewModel)

                    // Top merchants
                    TopMerchantsCard(viewModel: analyticsViewModel)
                }
                .padding()
            }
            .accessibilityIdentifier("AnalyticsView")
            .navigationTitle("Аналітика")
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
                Text("Період")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AnalyticsDateRange.allCases) { range in
                        DateRangeChip(
                            title: range.rawValue,
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
                    DatePicker("Від", selection: $startDate, displayedComponents: .date)
                    DatePicker("До", selection: $endDate, displayedComponents: .date)
                } header: {
                    Text("Оберіть період")
                } footer: {
                    if startDate > endDate {
                        Text("Початкова дата має бути раніше кінцевої")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Власний період")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Застосувати") {
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
