//
//  QuickEntryView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import SwiftUI
import Combine

struct QuickEntryView: View {
    @EnvironmentObject private var viewModel: TransactionViewModel
    @EnvironmentObject private var pendingViewModel: PendingTransactionsViewModel
    @Environment(\.dismiss) private var dismiss

    @FocusState private var isAmountFocused: Bool
    @FocusState private var isDescriptionFocused: Bool

    @State private var showMetadataEditor = false
    @State private var showCategoryPicker = false
    @State private var showSuccessFeedback = false
    @State private var showErrorAlert = false
    @State private var keyboardHeight: CGFloat = 0

    // Animation states
    @State private var successScale: CGFloat = 1.0
    @State private var pendingBadgeScale: CGFloat = 1.0
    @State private var toggleRotation: Double = 0
    @State private var datePillPressed = false
    @State private var accountPillPressed = false
    @State private var showCategorySuggestion = false

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // Best suggested category based on description (single match)
    private var bestSuggestedCategory: Category? {
        let description = viewModel.entryDescription.trimmingCharacters(in: .whitespaces).lowercased()

        // Only suggest if description has 3+ characters
        guard description.count >= 3 else {
            return nil
        }

        // Find best match using fuzzy matching
        let matches = viewModel.categories.filter { category in
            let categoryName = category.name.lowercased()
            // Match if description contains category name OR category name starts with description
            return description.contains(categoryName) || categoryName.hasPrefix(description)
        }

        // Return first strong match
        return matches.first
    }

    private var recentCategories: [Category] {
        if !viewModel.recentCategories.isEmpty {
            return viewModel.recentCategories
        }
        return Array(viewModel.categories.prefix(6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Pending transactions badge
                    if !pendingViewModel.pendingTransactions.isEmpty {
                        PendingTransactionsBadge(
                            count: pendingViewModel.pendingTransactions.count,
                            scale: pendingBadgeScale
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                pendingBadgeScale = 0.95
                            }
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(100))
                                withAnimation(.spring()) {
                                    pendingBadgeScale = 1.0
                                }
                            }
                            // Navigate to pending transactions tab
                        }
                        .padding(.bottom, 28)
                    }

                    Spacer(minLength: 40)

                    // Amount Section with integrated metadata pills
                    AmountInputSection(
                        amount: $viewModel.entryAmount,
                        transactionType: $viewModel.transactionType,
                        isAmountFocused: _isAmountFocused,
                        selectedDate: $viewModel.selectedDate,
                        selectedAccount: viewModel.selectedAccount,
                        showAccountSelector: viewModel.accounts.count > 1,
                        toggleRotation: $toggleRotation,
                        datePillPressed: $datePillPressed,
                        accountPillPressed: $accountPillPressed,
                        onMetadataTap: { showMetadataEditor = true }
                    )

                    Spacer(minLength: 32)

                    // Description Section with integrated category suggestion
                    DescriptionSection(
                        description: $viewModel.entryDescription,
                        isDescriptionFocused: _isDescriptionFocused,
                        selectedCategory: $viewModel.selectedCategory,
                        suggestedCategory: bestSuggestedCategory,
                        onShowCategoryPicker: { showCategoryPicker = true }
                    )

                    // Show selected category chip if one is selected
                    if let selected = viewModel.selectedCategory {
                        HStack(spacing: 6) {
                            Image(systemName: selected.icon)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: selected.colorHex))

                            Text(selected.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.selectedCategory = nil
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(height: 28)
                        .background(Color(hex: selected.colorHex).opacity(0.15))
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 40)

                    // Add Button
                    AddTransactionButton(
                        isValid: viewModel.isValidEntry,
                        isLoading: viewModel.isLoading,
                        scale: successScale
                    ) {
                        await addTransaction()
                    }

                    Spacer(minLength: 32)

                    // Recent Transactions
                    if !viewModel.transactions.isEmpty {
                        RecentTransactionsSection(
                            transactions: Array(viewModel.transactions.prefix(3)),
                            totalCount: viewModel.transactions.count
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, keyboardHeight)
            }
            .navigationTitle(String(localized: "quickEntry.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if TestingConfiguration.isRunningTests {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) {
                            dismiss()
                        }
                        .accessibilityIdentifier("CancelButton")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.clearEntry()
                    } label: {
                        Text(String(localized: "common.clear"))
                    }
                    .accessibilityIdentifier("ClearButton")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.done")) {
                        handleKeyboardDone()
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
            .sheet(isPresented: $showMetadataEditor) {
                MetadataEditorSheet(
                    selectedDate: $viewModel.selectedDate,
                    selectedAccount: $viewModel.selectedAccount,
                    accounts: viewModel.accounts,
                    showAccountSelector: viewModel.accounts.count > 1
                )
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategorySelectorSheet(
                    selectedCategory: $viewModel.selectedCategory,
                    categories: viewModel.categories,
                    recentCategories: recentCategories
                )
            }
            .alert(String(localized: "error.title"), isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .overlay(alignment: .top) {
                if showSuccessFeedback {
                    SuccessFeedbackView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                withAnimation {
                    keyboardHeight = frame.cgRectValue.height - 100
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation {
                keyboardHeight = 0
            }
        }
        .onChange(of: bestSuggestedCategory) { _, newValue in
            if newValue != nil && !showCategorySuggestion {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCategorySuggestion = true
                }
            } else if newValue == nil && showCategorySuggestion {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCategorySuggestion = false
                }
            }
        }
        .accessibilityIdentifier("QuickEntryView")
        .simultaneousGesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 10 {
                        isAmountFocused = false
                        isDescriptionFocused = false
                    }
                }
        )
    }

    // MARK: - Actions

    private func handleKeyboardDone() {
        if isAmountFocused {
            // If amount is valid and focused, move to description field
            if !viewModel.entryAmount.isEmpty,
               let _ = Decimal(string: viewModel.entryAmount) {
                isAmountFocused = false
                // Delay slightly to ensure smooth transition
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    isDescriptionFocused = true
                }
            } else {
                // If amount is invalid, just dismiss keyboard
                isAmountFocused = false
            }
        } else if isDescriptionFocused {
            // If description is focused, just dismiss keyboard
            isDescriptionFocused = false
        }
    }

    private func addTransaction() async {
        // Haptic feedback
        hapticFeedback.prepare()
        hapticFeedback.impactOccurred()

        // Animate button
        withAnimation(.spring(response: 0.3)) {
            successScale = 0.95
        }

        // Add transaction
        await viewModel.addTransaction()

        // Handle result
        if viewModel.error == nil {
            if TestingConfiguration.isRunningTests {
                dismiss()
                return
            }
            // Success animation
            withAnimation(.spring(response: 0.3)) {
                successScale = 1.1
                showSuccessFeedback = true
            }

            // Reset after delay
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.spring(response: 0.3)) {
                    successScale = 1.0
                }
            }

            // Hide success feedback
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                withAnimation {
                    showSuccessFeedback = false
                }
            }

            // Dismiss keyboard
            isAmountFocused = false
            isDescriptionFocused = false
        } else {
            // Error handling
            showErrorAlert = true
            withAnimation(.spring(response: 0.3)) {
                successScale = 1.0
            }
        }
    }

}

#Preview {
    QuickEntryView()
        .environmentObject(DependencyContainer.makeForPreviews().makeTransactionViewModel())
        .environmentObject(DependencyContainer.makeForPreviews().makePendingTransactionsViewModel())
}
