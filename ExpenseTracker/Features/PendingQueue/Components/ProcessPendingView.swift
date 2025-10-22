//
//  ProcessPendingView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import SwiftUI

struct ProcessPendingView: View {
    let pending: PendingTransaction

    @EnvironmentObject var viewModel: PendingTransactionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: Category?
    @State private var editedDescription: String
    @State private var isProcessing = false
    @State private var showLearningPrompt = false
    @State private var similarTransactions: [Transaction] = []
    @State private var showError = false
    @State private var errorMessage = ""

    init(pending: PendingTransaction) {
        self.pending = pending
        _selectedCategory = State(initialValue: pending.suggestedCategory)
        _editedDescription = State(initialValue: pending.descriptionText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Transaction Amount Card
                    amountCard

                    // Transaction Details
                    detailsSection

                    // Category Suggestion
                    CategorySuggestionCard(
                        suggestedCategory: selectedCategory,
                        confidence: pending.confidence,
                        onCategorySelect: { category in
                            let wasChanged = selectedCategory?.id != pending.suggestedCategory?.id
                            selectedCategory = category
                            if wasChanged && category.id != pending.suggestedCategory?.id {
                                showLearningPrompt = true
                            }
                        }
                    )
                    .padding(.horizontal)

                    // Description Editor
                    descriptionSection

                    // Similar Transactions
                    if !similarTransactions.isEmpty {
                        similarTransactionsSection
                    }

                    // Action Buttons
                    actionButtons
                }
                .padding(.vertical)
            }
            .navigationTitle("Обробити транзакцію")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрити") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .alert("Помилка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Запам'ятати вибір?", isPresented: $showLearningPrompt) {
                Button("Так") {
                    // Learning will happen during processing
                }
                Button("Ні", role: .cancel) { }
            } message: {
                if let merchant = pending.merchantName {
                    Text("Запам'ятати, що '\(merchant)' належить до категорії '\(selectedCategory?.name.capitalized ?? "")'?")
                } else {
                    Text("Запам'ятати цей вибір для схожих транзакцій?")
                }
            }
            .task {
                await loadSimilarTransactions()
            }
        }
    }

    // MARK: - Amount Card
    private var amountCard: some View {
        VStack(spacing: 8) {
            Text(formatAmount(pending.amount))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(pending.type == .expense ? .red : .green)

            Text(formatDate(pending.transactionDate))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Деталі")
                .font(.headline)

            VStack(spacing: 12) {
                if let merchant = pending.merchantName {
                    PendingDetailRow(icon: "building.2", label: "Торгівець", value: merchant)
                }

                PendingDetailRow(
                    icon: "creditcard",
                    label: "Рахунок",
                    value: pending.account.name
                )

                PendingDetailRow(
                    icon: "arrow.left.arrow.right",
                    label: "Тип",
                    value: pending.type == .expense ? "Витрата" : "Надходження"
                )

                if let bankId = pending.bankTransactionId {
                    PendingDetailRow(icon: "number", label: "ID транзакції", value: bankId)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Опис")
                .font(.headline)

            TextField("Введіть опис", text: $editedDescription, axis: .vertical)
                .textFieldStyle(.plain)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .lineLimit(3...6)
        }
        .padding(.horizontal)
    }

    // MARK: - Similar Transactions Section
    private var similarTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text("Схожі транзакції")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                ForEach(similarTransactions.prefix(3)) { transaction in
                    SimilarTransactionRow(transaction: transaction)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await acceptTransaction()
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Прийняти")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCategory != nil ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedCategory == nil || isProcessing)

            Button {
                Task {
                    await dismissTransaction()
                }
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Відхилити")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isProcessing)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Actions
    private func acceptTransaction() async {
        guard let category = selectedCategory else {
            errorMessage = "Будь ласка, оберіть категорію"
            showError = true
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            // Check if transaction still exists (race condition check)
            let currentPending = viewModel.pendingTransactions.first { $0.id == pending.id }
            guard currentPending != nil else {
                throw ProcessingError.alreadyProcessed
            }

            await viewModel.processPendingTransaction(
                pending,
                with: category,
                description: editedDescription.isEmpty ? nil : editedDescription
            )

            // Show success and dismiss
            await MainActor.run {
                dismiss()
            }
        } catch let error as ProcessingError {
            switch error {
            case .alreadyProcessed:
                errorMessage = "Ця транзакція вже була оброблена"
            case .networkFailure:
                errorMessage = "Помилка мережі. Перевірте з'єднання та спробуйте знову"
            case .validationFailed(let reason):
                errorMessage = "Помилка валідації: \(reason)"
            }
            showError = true
        } catch {
            errorMessage = "Не вдалося обробити транзакцію: \(error.localizedDescription)"
            showError = true
        }
    }

    private func dismissTransaction() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Check if transaction still exists (race condition check)
            let currentPending = viewModel.pendingTransactions.first { $0.id == pending.id }
            guard currentPending != nil else {
                throw ProcessingError.alreadyProcessed
            }

            await viewModel.dismissPendingTransaction(pending)
            await MainActor.run {
                dismiss()
            }
        } catch let error as ProcessingError {
            switch error {
            case .alreadyProcessed:
                errorMessage = "Ця транзакція вже була оброблена"
            case .networkFailure:
                errorMessage = "Помилка мережі. Перевірте з'єднання та спробуйте знову"
            case .validationFailed(let reason):
                errorMessage = "Помилка валідації: \(reason)"
            }
            showError = true
        } catch {
            errorMessage = "Не вдалося відхилити транзакцію: \(error.localizedDescription)"
            showError = true
        }
    }

    private func loadSimilarTransactions() async {
        // In a real app, this would query the repository for similar transactions
        // based on merchant name, amount range, or description
        // For now, we'll leave it empty
        similarTransactions = []
    }

    // MARK: - Formatters
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴0"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views
private struct PendingDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

private struct SimilarTransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            if let category = transaction.category {
                Image(systemName: category.icon)
                    .foregroundColor(Color(hex: category.colorHex))
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(.subheadline)
                Text(formatDate(transaction.transactionDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formatAmount(transaction.amount))
                .font(.subheadline)
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴0"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "uk_UA")
        return formatter.string(from: date)
    }
}

// MARK: - Processing Errors
enum ProcessingError: LocalizedError {
    case alreadyProcessed
    case networkFailure
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyProcessed:
            return "Transaction has already been processed"
        case .networkFailure:
            return "Network connection failed"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        }
    }
}