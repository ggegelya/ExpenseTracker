//
//  FilterView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

enum DateRangeFilter: String, CaseIterable, Identifiable {
    case today = "Сьогодні"
    case thisWeek = "Цей тиждень"
    case thisMonth = "Цей місяць"
    case custom = "Власний період"

    var id: String { rawValue }

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
                    Picker("Період", selection: $selectedDateRange) {
                        ForEach(DateRangeFilter.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    if selectedDateRange == .custom {
                        DatePicker("Від", selection: $customStartDate, displayedComponents: .date)
                        DatePicker("До", selection: $customEndDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Дата")
                } footer: {
                    if selectedDateRange == .custom {
                        Text("Оберіть початкову та кінцеву дату")
                    }
                }

                // Category Section
                Section {
                    if viewModel.categories.isEmpty {
                        Text("Немає категорій")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.categories) { category in
                            Button {
                                toggleCategory(category.id)
                            } label: {
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(Color(hex: category.colorHex))
                                    Text(category.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedCategories.contains(category.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Категорії")
                        Spacer()
                        if !selectedCategories.isEmpty {
                            Button("Очистити") {
                                selectedCategories.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                } footer: {
                    if !selectedCategories.isEmpty {
                        Text("Обрано: \(selectedCategories.count)")
                    }
                }

                // Amount Range Section
                Section {
                    HStack {
                        Text("Від")
                            .frame(width: 50, alignment: .leading)
                        TextField("0", text: $minAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("₴")
                    }

                    HStack {
                        Text("До")
                            .frame(width: 50, alignment: .leading)
                        TextField("∞", text: $maxAmount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        Text("₴")
                    }
                } header: {
                    Text("Сума")
                } footer: {
                    Text("Залиште порожнім для необмеженого діапазону")
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
                        Text("Тип транзакції")
                        Spacer()
                        if !selectedTypes.isEmpty {
                            Button("Очистити") {
                                selectedTypes.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                }

                // Account Section
                Section {
                    if viewModel.accounts.isEmpty {
                        Text("Немає рахунків")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.accounts) { account in
                            Button {
                                toggleAccount(account.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(account.name)
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
                        Text("Рахунки")
                        Spacer()
                        if !selectedAccounts.isEmpty {
                            Button("Очистити") {
                                selectedAccounts.removeAll()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Фільтри")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скинути") {
                        resetFilters()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Застосувати") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentFilters()
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
        switch type {
        case .expense:
            return "Витрата"
        case .income:
            return "Дохід"
        case .transferOut:
            return "Переказ (списання)"
        case .transferIn:
            return "Переказ (зарахування)"
        }
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

// MARK: - Color Extension for Hex Colors

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
