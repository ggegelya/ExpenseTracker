//
//  TransactionDetailSheet.swift
//  ExpenseTracker
//
//  Unified transaction detail sheet component
//  Used by both QuickEntryView and TransactionListView
//

import SwiftUI

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: TransactionViewModel

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showSplitView = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Amount Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сума")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(alignment: .center, spacing: 8) {
                            Text(transaction.type.symbol)
                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                .foregroundColor(transaction.type == .expense ? .red : .green)
                            Text(Formatters.currencyString(
                                amount: transaction.amount,
                                currency: (transaction.fromAccount ?? transaction.toAccount)?.currency ?? .uah
                            ))
                            .font(.system(size: 32, weight: .light, design: .rounded))
                        }
                    }

                    Divider()

                    // Date Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Дата")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(transaction.transactionDate, style: .date)
                            .font(.body)
                    }

                    Divider()

                    // Account Section
                    if let fromAccount = transaction.fromAccount {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(transaction.toAccount != nil ? "З рахунку" : "Рахунок")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fromAccount.name)
                                        .font(.body)
                                    if !fromAccount.tag.isEmpty {
                                        Text(fromAccount.tag)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }

                        if transaction.toAccount != nil {
                            Divider()
                        }
                    }

                    if let toAccount = transaction.toAccount, transaction.fromAccount != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("На рахунок")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(toAccount.name)
                                        .font(.body)
                                    if !toAccount.tag.isEmpty {
                                        Text(toAccount.tag)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }

                        Divider()
                    }

                    // Category Section
                    if let category = transaction.category {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категорія")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.colorHex))
                                Text(category.name)
                                    .font(.body)
                            }
                        }

                        Divider()
                    }

                    // Description Section
                    if !transaction.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Опис")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(transaction.description)
                                .font(.body)
                        }

                        Divider()
                    }

                    // Split Transaction Info
                    if transaction.isSplitParent, let splits = transaction.splitTransactions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Розподіл")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            VStack(spacing: 8) {
                                ForEach(splits) { split in
                                    HStack {
                                        if let category = split.category {
                                            Image(systemName: category.icon)
                                                .foregroundColor(Color(hex: category.colorHex))
                                                .font(.caption)
                                            Text(category.name)
                                                .font(.subheadline)
                                        } else {
                                            Text(split.description)
                                                .font(.subheadline)
                                        }

                                        Spacer()

                                        Text(split.formattedAmount)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Деталі транзакції")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрити") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            isEditing = true
                        } label: {
                            Label("Редагувати", systemImage: "pencil")
                        }

                        if transaction.isSplitParent {
                            Button {
                                showSplitView = true
                            } label: {
                                Label("Редагувати розподіл", systemImage: "chart.pie")
                            }
                        } else {
                            Button {
                                showSplitView = true
                            } label: {
                                Label("Розділити транзакцію", systemImage: "chart.pie")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Видалити", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog(
                transaction.isSplitParent ? "Видалити сумарну транзакцію?" : "Видалити транзакцію?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                if transaction.isSplitParent {
                    Button("Видалити сумарну та всі розділи", role: .destructive) {
                        Task {
                            await viewModel.deleteSplitTransaction(transaction, cascade: true)
                            dismiss()
                        }
                    }

                    Button("Видалити лише сумарну", role: .destructive) {
                        Task {
                            await viewModel.deleteSplitTransaction(transaction, cascade: false)
                            dismiss()
                        }
                    }

                    Button("Скасувати", role: .cancel) { }
                } else {
                    Button("Скасувати", role: .cancel) { }
                    Button("Видалити", role: .destructive) {
                        Task {
                            await viewModel.deleteTransaction(transaction)
                            dismiss()
                        }
                    }
                }
            } message: {
                if transaction.isSplitParent {
                    Text("Видалення сумарної транзакції вплине на пов'язані розділи. Оберіть дію.")
                } else {
                    Text("Ви впевнені, що хочете видалити цю транзакцію? Цю дію не можна скасувати.")
                }
            }
            .sheet(isPresented: $isEditing) {
                TransactionEditView(transaction: transaction)
            }
            .sheet(isPresented: $showSplitView) {
                SplitTransactionView(
                    originalTransaction: transaction,
                    onSave: { splits, retainParent in
                        Task {
                            if transaction.isSplitParent {
                                await viewModel.updateSplitTransaction(transaction, splits: splits, retainParent: retainParent)
                            } else {
                                await viewModel.createSplitTransaction(from: transaction, splits: splits, retainParent: retainParent)
                            }
                            dismiss()
                        }
                    }
                )
                .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Transaction Edit View (placeholder for future)

struct TransactionEditView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Text("Редагування транзакції")
                Text("Ця функція буде додана пізніше")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Редагування")
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
