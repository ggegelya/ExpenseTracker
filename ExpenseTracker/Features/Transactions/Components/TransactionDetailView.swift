//
//  TransactionDetailView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct TransactionDetailView: View {
    let transaction: Transaction
    @EnvironmentObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var editedTransaction: Transaction
    @State private var showDeleteConfirmation = false
    @State private var showSplitView = false

    init(transaction: Transaction) {
        self.transaction = transaction
        _editedTransaction = State(initialValue: transaction)
    }

    var body: some View {
        NavigationStack {
            TransactionDetailContentView(transaction: transaction)
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
            .confirmationDialog(transaction.isSplitParent ? "Видалити сумарну транзакцію?" : "Видалити транзакцію?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
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
