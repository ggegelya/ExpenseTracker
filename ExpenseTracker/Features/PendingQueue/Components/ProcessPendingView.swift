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
            .navigationTitle(String(localized: "pending.processTransaction"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .alert(String(localized: "error.title"), isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert(String(localized: "pending.rememberChoice"), isPresented: $showLearningPrompt) {
                Button(String(localized: "common.yes")) {
                    // Learning will happen during processing
                }
                Button(String(localized: "common.no"), role: .cancel) { }
            } message: {
                if let merchant = pending.merchantName {
                    Text(String(localized: "pending.rememberMerchantCategory \(merchant) \(selectedCategory?.displayName ?? "")"))
                } else {
                    Text(String(localized: "pending.rememberSimilar"))
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
            Text(String(localized: "common.details"))
                .font(.headline)

            VStack(spacing: 12) {
                if let merchant = pending.merchantName {
                    PendingDetailRow(icon: "building.2", label: String(localized: "pending.merchant"), value: merchant)
                }

                PendingDetailRow(
                    icon: "creditcard",
                    label: String(localized: "common.account"),
                    value: pending.account.displayName
                )

                PendingDetailRow(
                    icon: "arrow.left.arrow.right",
                    label: String(localized: "edit.type"),
                    value: pending.type == .expense ? String(localized: "transactionType.expense") : String(localized: "transactionType.income")
                )

                if let bankId = pending.bankTransactionId {
                    PendingDetailRow(icon: "number", label: String(localized: "pending.transactionId"), value: bankId)
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
            Text(String(localized: "common.description"))
                .font(.headline)

            TextField(String(localized: "edit.enterDescription"), text: $editedDescription, axis: .vertical)
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
                Text(String(localized: "pending.similarTransactions"))
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
                Task { @MainActor in
                    await acceptTransaction()
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text(String(localized: "pending.accept"))
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
            .accessibilityIdentifier("ConfirmButton")

            Button {
                Task { @MainActor in
                    await dismissTransaction()
                }
            } label: {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text(String(localized: "pending.dismiss"))
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
            errorMessage = String(localized: "validation.selectCategory")
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
                errorMessage = String(localized: "error.alreadyProcessed")
            case .networkFailure:
                errorMessage = String(localized: "error.networkRetry")
            case .validationFailed(let reason):
                errorMessage = "\(String(localized: "error.validation")): \(reason)"
            }
            showError = true
        } catch {
            errorMessage = "\(String(localized: "error.processFailed")): \(error.localizedDescription)"
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
                errorMessage = String(localized: "error.alreadyProcessed")
            case .networkFailure:
                errorMessage = String(localized: "error.networkRetry")
            case .validationFailed(let reason):
                errorMessage = "\(String(localized: "error.validation")): \(reason)"
            }
            showError = true
        } catch {
            errorMessage = "\(String(localized: "error.dismissFailed")): \(error.localizedDescription)"
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
        Formatters.currencyStringUAH(amount: amount)
    }

    private func formatDate(_ date: Date) -> String {
        Formatters.dateString(date,
                              dateStyle: .long,
                              timeStyle: .short)
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
        Formatters.currencyStringUAH(amount: amount,
                                     minFractionDigits: 0,
                                     maxFractionDigits: 0)
    }

    private func formatDate(_ date: Date) -> String {
        Formatters.dateString(date,
                              dateStyle: .short)
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
            return String(localized: "error.alreadyProcessed")
        case .networkFailure:
            return String(localized: "error.networkRetry")
        case .validationFailed(let reason):
            return "\(String(localized: "error.validation")): \(reason)"
        }
    }
}
