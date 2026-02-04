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
    @State private var showDeleteConfirmation = false
    @State private var showSplitView = false

    init(transaction: Transaction) {
        self.transaction = transaction
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
                        .accessibilityIdentifier("EditButton")

                        if transaction.isSplitParent {
                            Button {
                                showSplitView = true
                            } label: {
                                Label("Редагувати розподіл", systemImage: "chart.pie")
                            }
                            .accessibilityIdentifier("SplitTransactionButton")
                        } else {
                            Button {
                                showSplitView = true
                            } label: {
                                Label("Розділити транзакцію", systemImage: "chart.pie")
                            }
                            .accessibilityIdentifier("SplitTransactionButton")
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
                        Task { @MainActor in
                            await viewModel.deleteSplitTransaction(transaction, cascade: true)
                            dismiss()
                        }
                    }

                    Button("Видалити лише сумарну", role: .destructive) {
                        Task { @MainActor in
                            await viewModel.deleteSplitTransaction(transaction, cascade: false)
                            dismiss()
                        }
                    }

                    Button("Скасувати", role: .cancel) { }
                } else {
                    Button("Скасувати", role: .cancel) { }
                    Button("Видалити", role: .destructive) {
                        Task { @MainActor in
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
                        Task { @MainActor in
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
        .accessibilityIdentifier("TransactionDetailView")
        .overlay {
            if TestingConfiguration.isRunningTests {
                Text("TransactionDetailView")
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("TransactionDetailView")
                    .accessibilityIdentifier("TransactionDetailView")
            }
        }
    }

}

// MARK: - Transaction Edit View

struct TransactionEditView: View {
    let transaction: Transaction
    @EnvironmentObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var amountText: String
    @State private var descriptionText: String
    @State private var merchantText: String
    @State private var selectedType: TransactionType
    @State private var selectedCategory: Category?
    @State private var selectedDate: Date
    @State private var selectedFromAccount: Account?
    @State private var selectedToAccount: Account?

    @State private var showCategoryPicker = false
    @State private var showFromAccountPicker = false
    @State private var showToAccountPicker = false
    @State private var validationError: String?
    @State private var isSaving = false

    enum Field: Hashable {
        case amount
        case description
        case merchant
    }

    init(transaction: Transaction) {
        self.transaction = transaction
        _amountText = State(initialValue: Formatters.decimalString(transaction.amount, minFractionDigits: 0, maxFractionDigits: 2))
        _descriptionText = State(initialValue: transaction.description)
        _merchantText = State(initialValue: transaction.merchantName ?? "")
        _selectedType = State(initialValue: transaction.type)
        _selectedCategory = State(initialValue: transaction.category)
        _selectedDate = State(initialValue: transaction.transactionDate)
        _selectedFromAccount = State(initialValue: transaction.fromAccount)
        _selectedToAccount = State(initialValue: transaction.toAccount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Сума та тип") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .disabled(transaction.isSplitParent)

                    Picker("Тип", selection: $selectedType) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    .disabled(transaction.isSplitParent)
                }

                Section("Дата") {
                    DatePicker("Дата транзакції", selection: $selectedDate, displayedComponents: .date)
                }

                if !isTransferType && !transaction.isSplitParent {
                    Section("Категорія") {
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack {
                                if let category = selectedCategory {
                                    Image(systemName: category.icon)
                                        .foregroundColor(Color(hex: category.colorHex))
                                    Text(category.name)
                                } else {
                                    Text("Обрати категорію")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Опис") {
                    TextField("Опис", text: $descriptionText)
                        .focused($focusedField, equals: .description)
                    TextField("Мерчант (опційно)", text: $merchantText)
                        .focused($focusedField, equals: .merchant)
                }

                if showTransferAccounts {
                    Section("Рахунки") {
                        accountRow(
                            title: "З рахунку",
                            selected: $selectedFromAccount,
                            showPicker: $showFromAccountPicker
                        )

                        accountRow(
                            title: "На рахунок",
                            selected: $selectedToAccount,
                            showPicker: $showToAccountPicker
                        )
                    }
                } else {
                    Section("Рахунок") {
                        if requiresFromAccount {
                            accountRow(
                                title: "З рахунку",
                                selected: $selectedFromAccount,
                                showPicker: $showFromAccountPicker
                            )
                        } else if requiresToAccount {
                            accountRow(
                                title: "На рахунок",
                                selected: $selectedToAccount,
                                showPicker: $showToAccountPicker
                            )
                        }
                    }
                }

                if let validationError {
                    Section {
                        Text(validationError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Редагування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        save()
                    }
                    .disabled(isSaving || !isFormValid)
                    .accessibilityIdentifier("SaveButton")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        focusedField = nil
                    }
                }
            }
            .onChange(of: selectedType) { _, newValue in
                handleTypeChange(newValue)
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategorySelectorSheet(
                    selectedCategory: $selectedCategory,
                    categories: viewModel.categories,
                    recentCategories: viewModel.recentCategories
                )
            }
            .sheet(isPresented: $showFromAccountPicker) {
                AccountPickerSheet(accounts: viewModel.accounts, selectedAccount: $selectedFromAccount)
            }
            .sheet(isPresented: $showToAccountPicker) {
                AccountPickerSheet(accounts: viewModel.accounts, selectedAccount: $selectedToAccount)
            }
        }
        .onAppear {
            if selectedFromAccount == nil {
                selectedFromAccount = viewModel.accounts.first
            }
            if selectedToAccount == nil {
                selectedToAccount = viewModel.accounts.first
            }
        }
    }

    // MARK: - Computed Properties

    private var amountDecimal: Decimal? {
        Formatters.decimalValue(from: amountText)
    }

    private var isTransferType: Bool {
        selectedType == .transferIn || selectedType == .transferOut
    }

    private var showTransferAccounts: Bool {
        selectedType == .transferIn || selectedType == .transferOut
    }

    private var requiresFromAccount: Bool {
        selectedType == .expense || selectedType == .transferOut
    }

    private var requiresToAccount: Bool {
        selectedType == .income || selectedType == .transferIn
    }

    private var isFormValid: Bool {
        guard let amount = amountDecimal, amount > 0 else { return false }
        if requiresFromAccount && selectedFromAccount == nil { return false }
        if requiresToAccount && selectedToAccount == nil { return false }
        if showTransferAccounts && (selectedFromAccount == nil || selectedToAccount == nil) { return false }
        return true
    }

    // MARK: - Actions

    private func save() {
        guard let amount = amountDecimal, amount > 0 else {
            validationError = "Вкажіть коректну суму"
            return
        }

        if requiresFromAccount && selectedFromAccount == nil {
            validationError = "Оберіть рахунок списання"
            return
        }

        if requiresToAccount && selectedToAccount == nil {
            validationError = "Оберіть рахунок надходження"
            return
        }

        if showTransferAccounts && (selectedFromAccount == nil || selectedToAccount == nil) {
            validationError = "Оберіть рахунки для переказу"
            return
        }

        validationError = nil
        isSaving = true

        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMerchant = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)

        let updated = Transaction(
            id: transaction.id,
            timestamp: transaction.timestamp,
            transactionDate: selectedDate,
            type: selectedType,
            amount: amount,
            category: isTransferType ? nil : selectedCategory,
            description: trimmedDescription,
            merchantName: trimmedMerchant.isEmpty ? nil : trimmedMerchant,
            fromAccount: requiresFromAccount || showTransferAccounts ? selectedFromAccount : nil,
            toAccount: requiresToAccount || showTransferAccounts ? selectedToAccount : nil,
            parentTransactionId: transaction.parentTransactionId,
            splitTransactions: transaction.splitTransactions
        )

        Task { @MainActor in
            await viewModel.updateTransaction(updated)
            isSaving = false
            dismiss()
        }
    }

    private func handleTypeChange(_ newValue: TransactionType) {
        if isTransferType {
            selectedCategory = nil
        }

        if requiresFromAccount && selectedFromAccount == nil {
            selectedFromAccount = viewModel.accounts.first
        }

        if requiresToAccount && selectedToAccount == nil {
            selectedToAccount = viewModel.accounts.first
        }

        if showTransferAccounts {
            if selectedFromAccount == nil {
                selectedFromAccount = viewModel.accounts.first
            }
            if selectedToAccount == nil {
                selectedToAccount = viewModel.accounts.first { $0.id != selectedFromAccount?.id } ?? selectedFromAccount
            }
        }
    }

    @ViewBuilder
    private func accountRow(
        title: String,
        selected: Binding<Account?>,
        showPicker: Binding<Bool>
    ) -> some View {
        Button {
            showPicker.wrappedValue = true
        } label: {
            HStack {
                Text(title)
                Spacer()
                if let account = selected.wrappedValue {
                    Text(account.name)
                        .foregroundColor(.primary)
                } else {
                    Text("Оберіть")
                        .foregroundColor(.secondary)
                }
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
