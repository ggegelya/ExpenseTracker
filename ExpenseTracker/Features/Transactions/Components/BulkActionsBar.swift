//
//  BulkActionsBar.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct BulkActionsBar: View {
    @EnvironmentObject var viewModel: TransactionViewModel
    @State private var showCategoryPicker = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                // Selection info
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.selectedTransactionCount) обрано")
                        .font(.headline)
                    Text("з \(viewModel.filteredTransactions.count) транзакцій")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Select All/None buttons
                if viewModel.selectedTransactionCount == 0 {
                    Button {
                        viewModel.selectAllTransactions()
                    } label: {
                        Label("Обрати всі", systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                } else {
                    Button {
                        viewModel.deselectAllTransactions()
                    } label: {
                        Label("Зняти виділення", systemImage: "xmark.circle")
                            .font(.subheadline)
                    }
                }

                // Categorize button
                Button {
                    showCategoryPicker = true
                } label: {
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .disabled(viewModel.selectedTransactionCount == 0)

                // Delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .disabled(viewModel.selectedTransactionCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet()
        }
        .alert("Видалити транзакції?", isPresented: $showDeleteConfirmation) {
            Button("Скасувати", role: .cancel) {}
            Button("Видалити", role: .destructive) {
                Task { @MainActor in
                    await viewModel.bulkDeleteSelectedTransactions()
                }
            }
        } message: {
            Text("Ви впевнені, що хочете видалити \(viewModel.selectedTransactionCount) транзакцій? Цю дію не можна скасувати.")
        }
    }
}

// MARK: - Category Picker Sheet

struct CategoryPickerSheet: View {
    @EnvironmentObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.categories.isEmpty {
                    Text("Немає категорій")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.categories) { category in
                        Button {
                            Task { @MainActor in
                                await viewModel.bulkCategorizeSelectedTransactions(to: category)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.colorHex))
                                    .frame(width: 30)

                                Text(category.name)
                                    .foregroundColor(.primary)

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Оберіть категорію")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }
            }
        }
    }
}
