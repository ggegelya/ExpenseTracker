//
//  AccountDetailView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct AccountDetailView: View {
    let account: Account
    @EnvironmentObject var viewModel: AccountsViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        List {
            // Account header
            Section {
                VStack(spacing: 16) {
                    // Account type icon
                    ZStack {
                        Circle()
                            .fill(accountTypeColor.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: account.accountType.icon)
                            .font(.system(size: 36))
                            .foregroundColor(accountTypeColor)
                    }

                    // Account name
                    Text(account.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    // Balance
                    VStack(spacing: 4) {
                        Text("Поточний баланс")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(account.formattedBalance())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(balanceColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .listRowBackground(Color.clear)

            // Account details
            Section {
                DetailRow(label: "Тип", value: account.accountType.localizedName)
                DetailRow(label: "Тег", value: account.tag)
                DetailRow(label: "Валюта", value: account.currency.localizedName)

                if let lastDate = account.lastTransactionDate {
                    DetailRow(
                        label: "Остання транзакція",
                        value: formatDate(lastDate)
                    )
                }

                HStack {
                    Text("За замовчуванням")
                    Spacer()
                    if account.isDefault {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Деталі")
            }

            // Quick actions
            Section {
                NavigationLink {
                    // TODO: Add income to this account
                    EmptyView()
                } label: {
                    Label("Додати дохід", systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                }

                NavigationLink {
                    // TODO: Add expense from this account
                    EmptyView()
                } label: {
                    Label("Додати витрату", systemImage: "arrow.up.circle.fill")
                        .foregroundColor(.red)
                }
            } header: {
                Text("Швидкі дії")
            }

            // Transaction history
            Section {
                if accountTransactions.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Немає транзакцій")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        Spacer()
                    }
                } else {
                    ForEach(accountTransactions.prefix(5)) { transaction in
                        TransactionRow(transaction: transaction)
                    }

                    if accountTransactions.count > 5 {
                        NavigationLink {
                            // TODO: Show all transactions for this account
                            EmptyView()
                        } label: {
                            Text("Показати всі (\(accountTransactions.count))")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            } header: {
                Text("Останні транзакції")
            }

            // Delete error
            if let error = deleteError {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle("Деталі рахунку")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Редагувати", systemImage: "pencil")
                    }

                    if !account.isDefault {
                        Button {
                            Task {
                                await viewModel.setAsDefault(account)
                            }
                        } label: {
                            Label("Встановити за замовчуванням", systemImage: "star")
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
        .sheet(isPresented: $showEditSheet) {
            AddAccountView(accountToEdit: account)
        }
        .alert("Видалити рахунок?", isPresented: $showDeleteConfirmation) {
            Button("Скасувати", role: .cancel) {
                deleteError = nil
            }
            Button("Видалити", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Ви впевнені, що хочете видалити рахунок \"\(account.name)\"? Цю дію не можна скасувати.")
        }
    }

    // MARK: - Computed Properties

    private var accountTypeColor: Color {
        switch account.accountType {
        case .cash: return .green
        case .card: return .blue
        case .savings: return .orange
        case .investment: return .purple
        }
    }

    private var balanceColor: Color {
        if account.balance > 0 {
            return .green
        } else if account.balance < 0 {
            return .red
        } else {
            return .primary
        }
    }

    private var accountTransactions: [Transaction] {
        transactionViewModel.transactions.filter { transaction in
            transaction.fromAccount?.id == account.id ||
            transaction.toAccount?.id == account.id
        }.sorted { $0.transactionDate > $1.transactionDate }
    }

    // MARK: - Methods

    private func deleteAccount() {
        Task {
            do {
                try await viewModel.deleteAccount(account)
                dismiss()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
