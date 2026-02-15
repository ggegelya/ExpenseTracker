//
//  AccountsView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct AccountsView: View {
    @EnvironmentObject var viewModel: AccountsViewModel
    @EnvironmentObject var transactionViewModel: TransactionViewModel
    @State private var showAddAccount = false
    @State private var accountToEdit: Account?
    @State private var accountToDelete: Account?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: Spacing.listRowSpacing) {
                        // Accounts list
                        if viewModel.accounts.isEmpty {
                            // Empty state
                            VStack(spacing: Spacing.lg) {
                                Spacer()
                                    .frame(height: 60)

                                Image(systemName: "creditcard")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)

                                Text(String(localized: "account.empty.title"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text(String(localized: "account.empty.subtitle"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button {
                                    showAddAccount = true
                                } label: {
                                    Text(String(localized: "account.create"))
                                        .fontWeight(.semibold)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(viewModel.accounts) { account in
                                NavigationLink {
                                    AccountDetailView(account: account)
                                } label: {
                                    AccountRow(account: account)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        showEditSheet(for: account)
                                    } label: {
                                        Label(String(localized: "common.edit"), systemImage: "pencil")
                                    }

                                    if !account.isDefault {
                                        Button {
                                            Task { @MainActor in
                                                await viewModel.setAsDefault(account)
                                            }
                                        } label: {
                                            Label(String(localized: "account.setDefault"), systemImage: "star")
                                        }
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        accountToDelete = account
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label(String(localized: "common.delete"), systemImage: "trash")
                                    }
                                }
                            }

                            // Delete error
                            if let error = deleteError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(String(localized: "error.deleteError"))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.red)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(12)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }

                            // Spacer for footer
                            Spacer()
                                .frame(height: Spacing.footer)
                        }
                    }
                    .padding(Spacing.paddingBase)
                }

                // Total balance footer (subtle)
                if !viewModel.accounts.isEmpty {
                    VStack(spacing: 0) {
                        Divider()

                        VStack(spacing: Spacing.sm) {
                            HStack {
                                Text(String(localized: "account.totalBalance"))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatAmount(totalBalance))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(totalBalance >= 0 ? .green : .red)
                            }

                            // Balance breakdown by currency (if multiple)
                            if hasMultipleCurrencies {
                                ForEach(Currency.allCases) { currency in
                                    if let balance = balanceByCurrency[currency], balance != 0 {
                                        HStack {
                                            Text(currency.localizedName)
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(formatAmount(balance, currency: currency))
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.paddingBase)
                        .padding(.vertical, Spacing.base)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle(String(localized: "tab.accounts"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddAccount.toggle()
                    } label: {
                        Label(String(localized: "account.add"), systemImage: "plus")
                    }
                    .accessibilityIdentifier("AddAccountButton")
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView()
            }
            .sheet(item: $accountToEdit) { account in
                AddAccountView(accountToEdit: account)
            }
            .alert(String(localized: "account.deleteConfirm.title"), isPresented: $showDeleteConfirmation) {
                Button(String(localized: "common.cancel"), role: .cancel) {
                    accountToDelete = nil
                    deleteError = nil
                }
                Button(String(localized: "common.delete"), role: .destructive) {
                    if let account = accountToDelete {
                        deleteAccount(account)
                    }
                }
            } message: {
                if let account = accountToDelete {
                    Text(String(localized: "account.deleteConfirm.message \(account.name)"))
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var totalBalance: Decimal {
        viewModel.accounts
            .filter { $0.currency == .uah }
            .reduce(0) { $0 + $1.balance }
    }

    private var hasMultipleCurrencies: Bool {
        Set(viewModel.accounts.map { $0.currency }).count > 1
    }

    private var balanceByCurrency: [Currency: Decimal] {
        var result: [Currency: Decimal] = [:]

        for account in viewModel.accounts {
            result[account.currency, default: 0] += account.balance
        }

        return result
    }

    // MARK: - Methods

    private func showEditSheet(for account: Account) {
        accountToEdit = account
    }

    private func deleteAccount(_ account: Account) {
        Task { @MainActor in
            do {
                try await viewModel.deleteAccount(account)
                accountToDelete = nil
                deleteError = nil
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private func formatAmount(_ amount: Decimal, currency: Currency = .uah) -> String {
        Formatters.currencyString(amount: amount,
                                  currency: currency,
                                  minFractionDigits: 0,
                                  maxFractionDigits: 2)
    }
}

