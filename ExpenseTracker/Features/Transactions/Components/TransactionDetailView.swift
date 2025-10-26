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
            Form {
                // Transaction Type & Amount
                Section {
                    HStack {
                        Text("Тип")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(typeLocalizedName(transaction.type))
                            .foregroundColor(transaction.type.color == "red" ? .red : .green)
                    }

                    HStack {
                        Text("Сума")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(transaction.formattedAmount)
                            .font(.headline)
                            .foregroundColor(transaction.type.color == "red" ? .red : .green)
                    }
                } header: {
                    Text("Основна інформація")
                }

                // Description & Category
                Section {
                    HStack {
                        Text("Опис")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(transaction.description)
                            .multilineTextAlignment(.trailing)
                    }

                    if let category = transaction.category {
                        HStack {
                            Text("Категорія")
                                .foregroundColor(.secondary)
                            Spacer()
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.colorHex))
                                Text(category.name)
                            }
                        }
                    } else {
                        HStack {
                            Text("Категорія")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Без категорії")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Деталі")
                }

                // Accounts
                Section {
                    if let fromAccount = transaction.fromAccount {
                        HStack {
                            Text("З рахунку")
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(fromAccount.name)
                                Text(fromAccount.tag)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if let toAccount = transaction.toAccount {
                        HStack {
                            Text("На рахунок")
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(toAccount.name)
                                Text(toAccount.tag)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Show balance impact
                    if let account = transaction.fromAccount ?? transaction.toAccount {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Вплив на баланс")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text("Було:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatBalance(calculateBalanceBefore(for: account)))
                            }

                            HStack {
                                Text("Стало:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatBalance(calculateBalanceAfter(for: account)))
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Рахунки")
                }

                // Dates
                Section {
                    HStack {
                        Text("Дата транзакції")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(transaction.transactionDate, style: .date)
                        Text(transaction.transactionDate, style: .time)
                    }

                    HStack {
                        Text("Дата запису")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(transaction.timestamp, style: .date)
                        Text(transaction.timestamp, style: .time)
                    }
                } header: {
                    Text("Час")
                }
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

    // MARK: - Helper Methods

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

    private func calculateBalanceBefore(for account: Account) -> Decimal {
        // Current balance minus the impact of this transaction
        let impact = transactionImpact(for: account)
        return account.balance - impact
    }

    private func calculateBalanceAfter(for account: Account) -> Decimal {
        return account.balance
    }

    private func transactionImpact(for account: Account) -> Decimal {
        if transaction.fromAccount?.id == account.id {
            // Money went out
            return -transaction.amount
        } else if transaction.toAccount?.id == account.id {
            // Money came in
            return transaction.amount
        }
        return 0
    }

    private func formatBalance(_ amount: Decimal) -> String {
        Formatters.currencyStringUAH(amount: amount,
                                     minFractionDigits: 0,
                                     maxFractionDigits: 2)
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
