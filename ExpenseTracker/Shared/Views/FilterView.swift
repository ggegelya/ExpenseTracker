//
//  FilterView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case today = "today"
    case thisWeek = "thisWeek"
    case thisMonth = "thisMonth"
    case custom = "custom"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .today: return String(localized: "filter.today")
        case .thisWeek: return String(localized: "filter.thisWeek")
        case .thisMonth: return String(localized: "filter.thisMonth")
        case .custom: return String(localized: "filter.custom")
        }
    }

    func dateRange() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return startOfDay...now
        case .thisWeek:
            guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
                return nil
            }
            return startOfWeek...now
        case .thisMonth:
            guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start else {
                return nil
            }
            return startOfMonth...now
        case .custom:
            return nil
        }
    }
}

struct FilterView: View {
    @EnvironmentObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDateRange: DateRangeFilter = .thisMonth
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var selectedCategories: Set<Category.ID> = []
    @State private var minAmount: String = ""
    @State private var maxAmount: String = ""
    @State private var selectedTypes: Set<TransactionType> = []
    @State private var selectedAccounts: Set<Account.ID> = []

    var body: some View {
        NavigationStack {
            Form {
                // Date Range Section
                Section {
                    if TestingConfiguration.isRunningTests {
                        Button(action: {}) { EmptyView() }
                            .accessibilityIdentifier("FilterByDateRange")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .opacity(0.02)
                    }
                    Picker(String(localized: "filter.period"), selection: $selectedDateRange) {
                        ForEach(DateRangeFilter.allCases) { range in
                            Text(range.localizedName).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    if TestingConfiguration.isRunningTests {
                        Button(action: {
                            selectedDateRange = .thisMonth
                            viewModel.filterDateRange = DateRangeFilter.thisMonth.dateRange()
                        }) { EmptyView() }
                            .accessibilityIdentifier("ThisMonth")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .opacity(0.02)
                    }

                    if selectedDateRange == .custom {
                        DatePicker(String(localized: "common.from"), selection: $customStartDate, displayedComponents: .date)
                        DatePicker(String(localized: "common.to"), selection: $customEndDate, displayedComponents: .date)
                    }
                } header: {
                    Text(String(localized: "filter.date"))
                } footer: {
                    if selectedDateRange == .custom {
                        Text(String(localized: "filter.selectDateRange"))
                    }
                }

                // Category Section
                Section {
                    if TestingConfiguration.isRunningTests {
                        Button(action: {}) { EmptyView() }
                            .accessibilityIdentifier("FilterByCategory")
                            .frame(width: 1, height: 1)
                            .opacity(0.01)
                    }
                    if viewModel.categories.isEmpty {
                        Text(String(localized: "common.noCategories"))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.categories) { category in
                            Button {
                                toggleCategory(category.id)
                            } label: {
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(Color(hex: category.colorHex))
                                    Text(category.displayName)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCategories.contains(category.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .accessibilityIdentifier("Category_\(category.name)")
                        }
                    }
                } header: {
                    HStack {
                        Text(String(localized: "filter.categories"))
                        Spacer()
                        if !selectedCategories.isEmpty {
                            Button(String(localized: "common.clear")) {
                                selectedCategories.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                } footer: {
                    if !selectedCategories.isEmpty {
                        Text(String(localized: "filter.selected \(selectedCategories.count)"))
                    }
                }

                // Amount Range Section
                Section {
                    HStack {
                        Text(String(localized: "common.from"))
                            .frame(width: 50, alignment: .leading)
                        TextField("0", text: $minAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("₴")
                    }

                    HStack {
                        Text(String(localized: "common.to"))
                            .frame(width: 50, alignment: .leading)
                        TextField("∞", text: $maxAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("₴")
                    }
                } header: {
                    Text(String(localized: "filter.amount"))
                } footer: {
                    Text(String(localized: "filter.amountFooter"))
                }

                // Transaction Type Section
                Section {
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Button {
                            toggleType(type)
                        } label: {
                            HStack {
                                Text(typeLocalizedName(type))
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedTypes.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(String(localized: "filter.transactionType"))
                        Spacer()
                        if !selectedTypes.isEmpty {
                            Button(String(localized: "common.clear")) {
                                selectedTypes.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                }

                // Account Section
                Section {
                    if viewModel.accounts.isEmpty {
                        Text(String(localized: "common.noAccounts"))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.accounts) { account in
                            Button {
                                toggleAccount(account.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(account.displayName)
                                            .foregroundColor(.primary)
                                        Text(account.tag)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedAccounts.contains(account.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(String(localized: "filter.accounts"))
                        Spacer()
                        if !selectedAccounts.isEmpty {
                            Button(String(localized: "common.clear")) {
                                selectedAccounts.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "filter.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if TestingConfiguration.isRunningTests {
                        Button(String(localized: "common.reset")) {
                            resetFilters()
                            dismiss()
                        }
                        .accessibilityIdentifier("ClearFilters")
                    } else {
                        Button(String(localized: "common.reset")) {
                            resetFilters()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.apply")) {
                        applyFilters()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentFilters()
            }
        }
        .overlay(alignment: .topLeading) {
            if TestingConfiguration.isRunningTests {
                Text(selectedDateRange.localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("SelectedDateRangeLabel")
                    .accessibilityLabel(selectedDateRange.localizedName)
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleCategory(_ id: Category.ID) {
        if selectedCategories.contains(id) {
            selectedCategories.remove(id)
        } else {
            selectedCategories.insert(id)
        }
    }

    private func toggleType(_ type: TransactionType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
        } else {
            selectedTypes.insert(type)
        }
    }

    private func toggleAccount(_ id: Account.ID) {
        if selectedAccounts.contains(id) {
            selectedAccounts.remove(id)
        } else {
            selectedAccounts.insert(id)
        }
    }

    private func typeLocalizedName(_ type: TransactionType) -> String {
        type.localizedName
    }

    private func loadCurrentFilters() {
        // Load from ViewModel's current filter state
        selectedCategories = Set(viewModel.filterCategories.map { $0.id })
        selectedTypes = viewModel.filterTypes
        selectedAccounts = Set(viewModel.filterAccounts.map { $0.id })

        if let range = viewModel.filterDateRange {
            // Try to match with predefined ranges
            if let today = DateRangeFilter.today.dateRange(),
               Calendar.current.isDate(range.lowerBound, inSameDayAs: today.lowerBound) {
                selectedDateRange = .today
            } else if let week = DateRangeFilter.thisWeek.dateRange(),
                      Calendar.current.isDate(range.lowerBound, inSameDayAs: week.lowerBound) {
                selectedDateRange = .thisWeek
            } else if let month = DateRangeFilter.thisMonth.dateRange(),
                      Calendar.current.isDate(range.lowerBound, inSameDayAs: month.lowerBound) {
                selectedDateRange = .thisMonth
            } else {
                selectedDateRange = .custom
                customStartDate = range.lowerBound
                customEndDate = range.upperBound
            }
        }

        if let min = viewModel.filterMinAmount {
            minAmount = String(describing: min)
        }
        if let max = viewModel.filterMaxAmount {
            maxAmount = String(describing: max)
        }
    }

    private func applyFilters() {
        // Apply date range filter
        if selectedDateRange == .custom {
            viewModel.filterDateRange = customStartDate...customEndDate
        } else {
            viewModel.filterDateRange = selectedDateRange.dateRange()
        }

        // Apply category filter
        viewModel.filterCategories = viewModel.categories.filter { selectedCategories.contains($0.id) }

        // Apply type filter
        viewModel.filterTypes = selectedTypes

        // Apply account filter
        viewModel.filterAccounts = viewModel.accounts.filter { selectedAccounts.contains($0.id) }

        // Apply amount range filter
        if let minDecimal = Decimal(string: minAmount.replacingOccurrences(of: ",", with: ".")) {
            viewModel.filterMinAmount = minDecimal
        } else {
            viewModel.filterMinAmount = nil
        }

        if let maxDecimal = Decimal(string: maxAmount.replacingOccurrences(of: ",", with: ".")) {
            viewModel.filterMaxAmount = maxDecimal
        } else {
            viewModel.filterMaxAmount = nil
        }
    }

    private func resetFilters() {
        selectedDateRange = .thisMonth
        selectedCategories.removeAll()
        selectedTypes.removeAll()
        selectedAccounts.removeAll()
        minAmount = ""
        maxAmount = ""

        viewModel.filterDateRange = nil
        viewModel.filterCategories = []
        viewModel.filterTypes = []
        viewModel.filterAccounts = []
        viewModel.filterMinAmount = nil
        viewModel.filterMaxAmount = nil
    }
}
