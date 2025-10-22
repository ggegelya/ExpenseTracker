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
            List {
                ForEach(viewModel.accounts) { account in
                    NavigationLink {
                        AccountDetailView(account: account)
                    } label: {
                        AccountRow(account: account)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            accountToDelete = account
                            showDeleteConfirmation = true
                        } label: {
                            Label("Видалити", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            showEditSheet(for: account)
                        } label: {
                            Label("Редагувати", systemImage: "pencil")
                        }
                        .tint(.blue)

                        if !account.isDefault {
                            Button {
                                Task {
                                    await viewModel.setAsDefault(account)
                                }
                            } label: {
                                Label("За замовчуванням", systemImage: "star")
                            }
                            .tint(.orange)
                        }
                    }
                }

                // Total balance
                if !viewModel.accounts.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Загальний баланс")
                                    .font(.headline)
                                Spacer()
                                Text(formatAmount(totalBalance))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(totalBalance >= 0 ? .green : .red)
                            }

                            // Balance breakdown by currency
                            if hasMultipleCurrencies {
                                Divider()

                                VStack(spacing: 8) {
                                    ForEach(Currency.allCases) { currency in
                                        if let balance = balanceByCurrency[currency] {
                                            HStack {
                                                Text(currency.localizedName)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text(formatAmount(balance, currency: currency))
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Empty state
                if viewModel.accounts.isEmpty {
                    Section {
                        VStack(spacing: 16) {
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
                        .padding(.vertical, 40)
                    }
                    .listRowBackground(Color.clear)
                }

                // Delete error
                if let error = deleteError {
                    Section {
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
                    }
                }
            }
            .navigationTitle("Рахунки")
            .navigationBarTitleDisplayMode(.large)
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
            .refreshable {
                await viewModel.loadAccounts()
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.currencySymbol = currency.symbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0

        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(currency.symbol)0"
    }
}





