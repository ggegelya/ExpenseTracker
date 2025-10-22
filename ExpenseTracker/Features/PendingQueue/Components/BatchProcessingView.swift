//
//  BatchProcessingView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct BatchProcessingView: View {
    let pendingTransactions: [PendingTransaction]

    @EnvironmentObject var viewModel: PendingTransactionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var selectedCategories: [UUID: Category] = [:]
    @State private var editedDescriptions: [UUID: String] = [:]
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var showError = false
    @State private var errorMessage = ""

    private var currentPending: PendingTransaction? {
        guard currentIndex < pendingTransactions.count else { return nil }
        return pendingTransactions[currentIndex]
    }

    private var progress: Double {
        guard !pendingTransactions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(pendingTransactions.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Bar
                progressSection

                if let pending = currentPending {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Transaction Info
                            transactionCard(for: pending)

                            // Category Selection
                            CategorySuggestionCard(
                                suggestedCategory: selectedCategories[pending.id] ?? pending.suggestedCategory,
                                confidence: pending.confidence,
                                onCategorySelect: { category in
                                    selectedCategories[pending.id] = category
                                }
                            )
                            .padding(.horizontal)

                            // Description Editor
                            descriptionEditor(for: pending)

                            Spacer()
                        }
                        .padding(.vertical)
                    }

                    // Action Buttons
                    actionButtons(for: pending)
                } else {
                    // Completion View
                    completionView
                }
            }
            .navigationTitle("Переглянути всі (\(currentIndex + 1)/\(pendingTransactions.count))")
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
        }
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Прогрес")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(processedCount) з \(pendingTransactions.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Transaction Card
    private func transactionCard(for pending: PendingTransaction) -> some View {
        VStack(spacing: 16) {
            // Amount
            VStack(spacing: 8) {
                Text(formatAmount(pending.amount))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(pending.type == .expense ? .red : .green)

                Text(formatDate(pending.transactionDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Details
            VStack(spacing: 12) {
                if let merchant = pending.merchantName {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("Торгівець")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(merchant)
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Image(systemName: "creditcard")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Рахунок")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(pending.account.name)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Description Editor
    private func descriptionEditor(for pending: PendingTransaction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Опис")
                .font(.headline)

            TextField(
                "Введіть опис",
                text: Binding(
                    get: { editedDescriptions[pending.id] ?? pending.descriptionText },
                    set: { editedDescriptions[pending.id] = $0 }
                ),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .lineLimit(3...6)
        }
        .padding(.horizontal)
    }

    // MARK: - Action Buttons
    private func actionButtons(for pending: PendingTransaction) -> some View {
        VStack(spacing: 12) {
            // Accept Button
            Button {
                Task {
                    await acceptAndContinue(pending)
                }
            } label: {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text(currentIndex < pendingTransactions.count - 1 ? "Прийняти і продовжити" : "Прийняти і завершити")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedCategories[pending.id] != nil || pending.suggestedCategory != nil ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled((selectedCategories[pending.id] == nil && pending.suggestedCategory == nil) || isProcessing)

            HStack(spacing: 12) {
                // Skip Button
                Button {
                    skipToNext()
                } label: {
                    HStack {
                        Image(systemName: "forward")
                        Text("Пропустити")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isProcessing)

                // Dismiss Button
                Button {
                    Task {
                        await dismissAndContinue(pending)
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
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Completion View
    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Готово!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Оброблено \(processedCount) з \(pendingTransactions.count) транзакцій")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                dismiss()
            } label: {
                Text("Закрити")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions
    private func acceptAndContinue(_ pending: PendingTransaction) async {
        let category = selectedCategories[pending.id] ?? pending.suggestedCategory
        guard let category = category else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let description = editedDescriptions[pending.id]
            await viewModel.processPendingTransaction(
                pending,
                with: category,
                description: description
            )

            processedCount += 1
            moveToNext()
        } catch {
            errorMessage = "Не вдалося обробити транзакцію: \(error.localizedDescription)"
            showError = true
        }
    }

    private func dismissAndContinue(_ pending: PendingTransaction) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            await viewModel.dismissPendingTransaction(pending)
            moveToNext()
        } catch {
            errorMessage = "Не вдалося відхилити транзакцію: \(error.localizedDescription)"
            showError = true
        }
    }

    private func skipToNext() {
        withAnimation {
            currentIndex += 1
        }
    }

    private func moveToNext() {
        withAnimation {
            currentIndex += 1
        }
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
