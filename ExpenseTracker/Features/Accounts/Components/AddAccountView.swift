//
//  AddAccountView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct AddAccountView: View {
    @EnvironmentObject var viewModel: AccountsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    // Form state
    @State private var name: String = ""
    @State private var tag: String = "#"
    @State private var initialBalance: String = "0"
    @State private var selectedType: AccountType = .card
    @State private var selectedCurrency: Currency = .uah
    @State private var setAsDefault: Bool = false

    // Account to edit (nil means create new)
    let accountToEdit: Account?

    // Validation
    @State private var validationError: String?
    @State private var isLoading = false

    enum Field: Hashable {
        case name, tag, balance
    }

    init(accountToEdit: Account? = nil) {
        self.accountToEdit = accountToEdit
    }

    var body: some View {
        NavigationStack {
            Form {
                // Account name
                Section {
                    TextField("Назва рахунку", text: $name)
                        .focused($focusedField, equals: .name)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 50 {
                                name = String(newValue.prefix(50))
                            }
                            validationError = nil
                        }

                    HStack {
                        Text("\(name.count)/50")
                            .font(.caption)
                            .foregroundColor(name.count > 45 ? .orange : .secondary)
                    }
                } header: {
                    Text("Основна інформація")
                } footer: {
                    Text("Наприклад: Монобанк, Готівка, Накопичувальний")
                        .font(.caption)
                }

                // Tag
                Section {
                    TextField("Тег", text: $tag)
                        .focused($focusedField, equals: .tag)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: tag) { _, newValue in
                            // Auto-format with #
                            if !newValue.hasPrefix("#") {
                                tag = "#" + newValue.replacingOccurrences(of: "#", with: "")
                            }
                            // Remove spaces
                            tag = tag.replacingOccurrences(of: " ", with: "")
                            validationError = nil
                        }
                } header: {
                    Text("Тег")
                } footer: {
                    Text("Унікальний ідентифікатор рахунку")
                        .font(.caption)
                }

                // Account type
                Section {
                    Picker("Тип рахунку", selection: $selectedType) {
                        ForEach(AccountType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.localizedName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Тип")
                }

                // Currency
                Section {
                    Picker("Валюта", selection: $selectedCurrency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.localizedName).tag(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Валюта")
                }

                // Initial balance
                Section {
                    HStack {
                        TextField("0", text: $initialBalance)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .balance)
                            .onChange(of: initialBalance) { _, _ in
                                validationError = nil
                            }

                        Text(selectedCurrency.symbol)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Початковий баланс")
                } footer: {
                    Text("Може бути від'ємним")
                        .font(.caption)
                }

                // Default account toggle
                if viewModel.accounts.isEmpty || accountToEdit == nil {
                    Section {
                        Toggle("Встановити як основний", isOn: $setAsDefault)
                    } footer: {
                        Text("Основний рахунок використовується за замовчуванням для нових транзакцій")
                            .font(.caption)
                    }
                }

                // Validation error
                if let error = validationError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle(accountToEdit == nil ? "Новий рахунок" : "Редагувати рахунок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(accountToEdit == nil ? "Створити" : "Зберегти") {
                        saveAccount()
                    }
                    .disabled(isLoading || !isFormValid)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                loadAccountData()
                if accountToEdit == nil {
                    focusedField = .name
                }
                // Set as default if first account
                if viewModel.accounts.isEmpty {
                    setAsDefault = true
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        tag.count > 1 &&
        tag.hasPrefix("#")
    }

    private var balanceDecimal: Decimal? {
        let normalized = initialBalance.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    // MARK: - Methods

    private func loadAccountData() {
        guard let account = accountToEdit else { return }

        name = account.name
        tag = account.tag
        initialBalance = String(describing: account.balance)
        selectedType = account.accountType
        selectedCurrency = account.currency
        setAsDefault = account.isDefault
    }

    private func saveAccount() {
        // Clear keyboard
        focusedField = nil

        // Validate
        let existingTags = viewModel.accounts
            .filter { $0.id != accountToEdit?.id }
            .map { $0.tag }

        do {
            try Account.validate(
                name: name,
                tag: tag,
                existingTags: existingTags,
                excludeAccountId: accountToEdit?.id
            )
        } catch {
            validationError = error.localizedDescription
            return
        }

        // Validate balance
        guard let balance = balanceDecimal else {
            validationError = "Невірний формат балансу"
            return
        }

        isLoading = true

        Task {
            if let existingAccount = accountToEdit {
                // Update existing account
                let updatedAccount = Account(
                    id: existingAccount.id,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    tag: tag,
                    balance: balance,
                    isDefault: setAsDefault,
                    accountType: selectedType,
                    currency: selectedCurrency,
                    lastTransactionDate: existingAccount.lastTransactionDate
                )
                await viewModel.updateAccount(updatedAccount)
            } else {
                // Create new account
                await viewModel.createAccount(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    tag: tag,
                    initialBalance: balance,
                    accountType: selectedType,
                    currency: selectedCurrency,
                    setAsDefault: setAsDefault
                )
            }

            isLoading = false
            dismiss()
        }
    }
}