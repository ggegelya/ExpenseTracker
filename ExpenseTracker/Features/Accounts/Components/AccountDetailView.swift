//
//  AccountDetailView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct AccountDetailView: View {
    @State private var account: Account
    @EnvironmentObject var viewModel: AccountsViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    init(account: Account) {
        _account = State(initialValue: account)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                // Hero Balance Section
                VStack(alignment: .center, spacing: Spacing.xs) {
                    Text(account.formattedBalance())
                        .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                        .foregroundColor(balanceColor)
                        .frame(maxWidth: .infinity)

                    // Metadata pills
                    HStack(spacing: Spacing.betweenPills) {
                        // Account type pill
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: account.accountType.icon)
                                .font(.system(size: 10))
                            Text(account.accountType.localizedName)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(accountTypeColor)
                        .padding(.horizontal, Spacing.pillHorizontal)
                        .padding(.vertical, Spacing.pillVertical)
                        .background(accountTypeColor.opacity(0.1))
                        .cornerRadius(12)

                        // Account name pill
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "building.columns")
                                .font(.system(size: 10))
                            Text(account.name)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, Spacing.pillHorizontal)
                        .padding(.vertical, Spacing.pillVertical)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)

                        // Tag pill
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "tag")
                                .font(.system(size: 10))
                            Text(account.tag)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, Spacing.pillHorizontal)
                        .padding(.vertical, Spacing.pillVertical)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                    }
                }

                Divider()

                // Account Details Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(String(localized: "common.details"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: Spacing.md) {
                        DetailRow(label: String(localized: "account.currency"), value: account.currency.localizedName)

                        if let lastDate = account.lastTransactionDate {
                            DetailRow(
                                label: String(localized: "account.lastTransaction"),
                                value: formatDate(lastDate)
                            )
                        }

                        HStack {
                            Text(String(localized: "account.default"))
                                .foregroundColor(.secondary)
                            Spacer()
                            if account.isDefault {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(String(localized: "common.yes"))
                                        .fontWeight(.medium)
                                }
                            } else {
                                Text(String(localized: "common.no"))
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                Divider()

                // Transaction History Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(String(localized: "account.recentTransactions"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if accountTransactions.isEmpty {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text(String(localized: "transaction.empty.title"))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(accountTransactions.prefix(5)) { transaction in
                                SimplifiedTransactionRow(transaction: transaction)
                            }

                            if accountTransactions.count > 5 {
                                NavigationLink {
                                    AccountTransactionsView(account: account)
                                } label: {
                                    HStack {
                                        Text(String(localized: "common.showAll \(accountTransactions.count)"))
                                            .foregroundColor(.accentColor)
                                            .font(.subheadline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                    }
                                    .padding(12)
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Delete error
                if let error = deleteError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(Spacing.paddingBase)
        }
        .navigationTitle(String(localized: "account.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label(String(localized: "common.edit"), systemImage: "pencil")
                    }

                    if !account.isDefault {
                        Button {
                            Task { @MainActor in
                                await viewModel.setAsDefault(account)
                                refreshAccount()
                            }
                        } label: {
                            Label(String(localized: "account.setDefault"), systemImage: "star")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            refreshAccount()
        }) {
            AddAccountView(accountToEdit: account)
        }
        .alert(String(localized: "account.deleteConfirm.title"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "common.cancel"), role: .cancel) {
                deleteError = nil
            }
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text(String(localized: "account.deleteConfirm.message \(account.name)"))
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
            (transaction.fromAccount?.id == account.id ||
            transaction.toAccount?.id == account.id) &&
            transaction.parentTransactionId == nil
        }.sorted { $0.transactionDate > $1.transactionDate }
    }

    // MARK: - Methods

    private func deleteAccount() {
        Task { @MainActor in
            do {
                try await viewModel.deleteAccount(account)
                dismiss()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private func refreshAccount() {
        if let updated = viewModel.accounts.first(where: { $0.id == account.id }) {
            account = updated
        }
    }

    private func formatDate(_ date: Date) -> String {
        Formatters.dateString(date,
                              dateStyle: .medium,
                              timeStyle: .short)
    }
}

// MARK: - Supporting Components

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

struct SimplifiedTransactionRow: View {
    let transaction: Transaction

    var displayCategory: Category? {
        transaction.primaryCategory
    }

    var body: some View {
        HStack(spacing: 12) {
            // Transaction info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 15))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let category = displayCategory {
                        Image(systemName: category.icon)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: category.colorHex))

                        Text(category.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Text(transaction.transactionDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            Spacer()

            // Amount with color coding
            Text(transaction.formattedAmount)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AccountTransactionsView: View {
    let account: Account
    @EnvironmentObject var transactionViewModel: TransactionViewModel

    var body: some View {
        List {
            ForEach(accountTransactions) { transaction in
                NavigationLink {
                    TransactionDetailView(transaction: transaction)
                } label: {
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .navigationTitle(String(localized: "tab.transactions"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accountTransactions: [Transaction] {
        transactionViewModel.transactions.filter { transaction in
            (transaction.fromAccount?.id == account.id ||
            transaction.toAccount?.id == account.id) &&
            transaction.parentTransactionId == nil
        }.sorted { $0.transactionDate > $1.transactionDate }
    }
}
