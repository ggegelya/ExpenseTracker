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
    @State private var accountToDelete: Account?
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Accounts list
                        if viewModel.accounts.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Spacer()
                                    .frame(height: 60)

                                Image(systemName: "creditcard")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)

                                Text("Немає рахунків")
                                    .font(.headline)
                                    .foregroundColor(.secondary)

                                Text("Створіть свій перший рахунок")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button {
                                    showAddAccount = true
                                } label: {
                                    Text("Створити рахунок")
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
                                        accountToDelete = account
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Видалити", systemImage: "trash")
                                    }
                                }
                            }

                            // Delete error
                            if let error = deleteError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Помилка видалення")
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
                                .frame(height: 80)
                        }
                    }
                    .padding(16)
                }

                // Total balance footer (subtle)
                if !viewModel.accounts.isEmpty {
                    VStack(spacing: 0) {
                        Divider()

                        VStack(spacing: 8) {
                            HStack {
                                Text("Загальний баланс")
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                    }
                }
            }
            .navigationTitle("Рахунки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddAccount.toggle()
                    } label: {
                        Label("Додати рахунок", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddAccount) {
                AddAccountView()
            }
            .alert("Видалити рахунок?", isPresented: $showDeleteConfirmation) {
                Button("Скасувати", role: .cancel) {
                    accountToDelete = nil
                    deleteError = nil
                }
                Button("Видалити", role: .destructive) {
                    if let account = accountToDelete {
                        deleteAccount(account)
                    }
                }
            } message: {
                if let account = accountToDelete {
                    Text("Ви впевнені, що хочете видалити рахунок \"\(account.name)\"?\n\nЦю дію не можна скасувати.")
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
        // TODO: Implement edit sheet
    }

    private func deleteAccount(_ account: Account) {
        Task {
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




