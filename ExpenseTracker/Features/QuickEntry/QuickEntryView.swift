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

    // Recent/frequent categories - using first 4-6 as placeholder
    // TODO: Replace with actual usage tracking
    private var recentCategories: [Category] {
        Array(viewModel.categories.prefix(6))
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring()) {
                                    pendingBadgeScale = 1.0
                                }
                            }
                            // Navigate to pending transactions tab
                        }
                        .padding(.bottom, 28)
                    }

                    Spacer(minLength: 40) // 1. Navigation title to amount: 40pt

                    // Amount Section with integrated metadata pills
                    // (metadata pills are 8pt below amount - handled inside AmountInputSection)
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

                    Spacer(minLength: 32) // 3. Metadata pills to description: 32pt

                    // Description Section with integrated category suggestion
                    // (category suggestion is 4pt below - handled inside DescriptionSection)
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

                            Text(selected.name)
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

                    Spacer(minLength: 40) // 5. Category to action button: 40pt

                    // Add Button
                    AddTransactionButton(
                        isValid: viewModel.isValidEntry,
                        isLoading: viewModel.isLoading,
                        scale: successScale
                    ) {
                        await addTransaction()
                    }

                    Spacer(minLength: 32) // 6. Action button to recent transactions: 32pt

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
            .navigationTitle("Додати транзакцію")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
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
            .alert("Помилка", isPresented: $showErrorAlert) {
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
        .onAppear {
            setupKeyboardHandling()
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
    }
    
    // MARK: - Actions

    private func handleKeyboardDone() {
        if isAmountFocused {
            // If amount is valid and focused, move to description field
            if !viewModel.entryAmount.isEmpty,
               let _ = Decimal(string: viewModel.entryAmount) {
                isAmountFocused = false
                // Delay slightly to ensure smooth transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
            // Success animation
            withAnimation(.spring(response: 0.3)) {
                successScale = 1.1
                showSuccessFeedback = true
            }

            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3)) {
                    successScale = 1.0
                }
            }

            // Hide success feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
            }
            .sink { height in
                withAnimation {
                    keyboardHeight = height - 100 // Account for tab bar
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { _ in
                withAnimation {
                    keyboardHeight = 0
                }
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Subviews

struct PendingTransactionsBadge: View {
    let count: Int
    let scale: CGFloat

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
            Text("\(count) транзакцій очікують обробки")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
        }
        .foregroundColor(.orange)
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(scale)
    }
}

struct AmountInputSection: View {
    @Binding var amount: String
    @Binding var transactionType: TransactionType
    @FocusState var isAmountFocused: Bool
    @Binding var selectedDate: Date
    let selectedAccount: Account?
    let showAccountSelector: Bool
    @Binding var toggleRotation: Double
    @Binding var datePillPressed: Bool
    @Binding var accountPillPressed: Bool
    let onMetadataTap: () -> Void

    @State private var toggleScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            // Amount input - Hero layout
            HStack(alignment: .center, spacing: 8) {
                // Tap-to-toggle -/+ sign only (no background)
                Button {
                    // Rotate 180° and pulse scale
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        toggleRotation += 180
                        transactionType = transactionType == .expense ? .income : .expense
                    }

                    // Scale pulse: 1.0 → 1.1 → 1.0
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        toggleScale = 1.1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            toggleScale = 1.0
                        }
                    }
                } label: {
                    Text(transactionType.symbol)
                        .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                        .foregroundColor(transactionType == .expense ? .red : .green)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees(toggleRotation))
                .scaleEffect(toggleScale)

                TextField("0", text: $amount)
                    .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
                    .tint(.blue)
                    .onChange(of: amount) { _, newValue in
                        // Format input to max 2 decimal places
                        if let dotIndex = newValue.lastIndex(of: ".") {
                            let decimals = newValue.distance(from: newValue.index(after: dotIndex), to: newValue.endIndex)
                            if decimals > 2 {
                                amount = String(newValue.prefix(newValue.count - (decimals - 2)))
                            }
                        }
                    }

                Text("₴")
                    .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                    .foregroundColor(.secondary)
            }

            // Metadata pills
            HStack(spacing: 8) {
                // Date pill
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        datePillPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            datePillPressed = false
                        }
                    }
                    onMetadataTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6).opacity(0.5))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .scaleEffect(datePillPressed ? 0.95 : 1.0)

                // Account pill (only if multiple accounts)
                if showAccountSelector, let account = selectedAccount {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            accountPillPressed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeOut(duration: 0.15)) {
                                accountPillPressed = false
                            }
                        }
                        onMetadataTap()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 10))
                            Text(account.name)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(accountPillPressed ? 0.95 : 1.0)
                }
            }
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Сьогодні"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Вчора"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale(identifier: "uk")
            return formatter.string(from: selectedDate)
        }
    }
}

struct CategoriesSection: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    let onShowAllCategories: () -> Void
    @EnvironmentObject private var viewModel: TransactionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Категорія")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    onShowAllCategories()
                } label: {
                    HStack(spacing: 4) {
                        Text("Всі категорії")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }

            // Compact chips wrapped in FlowLayout
            FlowLayout(spacing: 8) {
                ForEach(categories) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory?.id == category.id,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedCategory?.id == category.id {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = category
                                    // Mark as manually selected
                                    viewModel.categoryWasAutoDetected = false
                                }
                            }
                        }
                    )
                }
            }
        }
    }
}

struct DescriptionSection: View {
    @Binding var description: String
    @FocusState var isDescriptionFocused: Bool
    @Binding var selectedCategory: Category?
    let suggestedCategory: Category?
    let onShowCategoryPicker: () -> Void
    @EnvironmentObject private var viewModel: TransactionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Plain text field with bottom border
            VStack(spacing: 0) {
                TextField("Що купили?", text: $description)
                    .font(.system(size: 17))
                    .focused($isDescriptionFocused)
                    .submitLabel(.done)
                    .tint(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onSubmit {
                        isDescriptionFocused = false
                    }
                    .onChange(of: description) { oldValue, newValue in
                        // Auto-select category when strong suggestion appears
                        if newValue.count >= 3,
                           let suggested = suggestedCategory,
                           selectedCategory == nil {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = suggested
                                viewModel.categoryWasAutoDetected = true
                            }
                        }
                    }

                Divider()
            }

            // Always show category picker button when description is 3+ chars
            if description.count >= 3 {
                Button {
                    onShowCategoryPicker()
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCategory == nil ? "Обрати категорію" : "Змінити категорію")
                            .font(.system(size: 14))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
    }
}

struct AddTransactionButton: View {
    let isValid: Bool
    let isLoading: Bool
    let scale: CGFloat
    let action: () async -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text("Додати")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isValid
                    ? Color.blue.opacity(0.95)
                    : Color.gray.opacity(0.3)
            )
            .cornerRadius(16)
            .shadow(
                color: isValid ? Color.blue.opacity(0.2) : .clear,
                radius: 8,
                y: 2
            )
        }
        .disabled(!isValid || isLoading)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .scaleEffect(scale)
        .animation(.spring(response: 0.2), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isValid)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .padding(.horizontal, 20)
    }
}

struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    let totalCount: Int
    @EnvironmentObject private var viewModel: TransactionViewModel
    @State private var showAllTransactions = false
    @State private var selectedTransaction: Transaction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Останні")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()

                // Only show "Всі" link if there are more than 3 items
                if totalCount > 3 {
                    Button {
                        showAllTransactions = true
                    } label: {
                        Text("Всі")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Use List for swipe actions
            List {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                    VStack(spacing: 0) {
                        SimpleTransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                            }

                        // Add divider except for last item
                        if index < transactions.count - 1 {
                            Divider()
                                .background(Color(.systemGray4))
                                .padding(.leading, 20)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteTransaction(transaction)
                        } label: {
                            Label("Видалити", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            duplicateTransaction(transaction)
                        } label: {
                            Label("Дублювати", systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: CGFloat(transactions.count * 60))
            .scrollDisabled(true)
        }
        .sheet(isPresented: $showAllTransactions) {
            TransactionListView()
                .environmentObject(viewModel)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction)
                .environmentObject(viewModel)
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        Task {
            await viewModel.deleteTransaction(transaction)
        }
    }

    private func duplicateTransaction(_ transaction: Transaction) {
        // Pre-fill the form with transaction data
        viewModel.entryAmount = String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount).doubleValue)
        viewModel.transactionType = transaction.type
        viewModel.selectedCategory = transaction.category
        viewModel.entryDescription = transaction.description
        viewModel.selectedAccount = transaction.fromAccount ?? transaction.toAccount
        viewModel.selectedDate = transaction.transactionDate
    }
}

struct SimpleTransactionRow: View {
    let transaction: Transaction

    var displayCategory: Category? {
        transaction.primaryCategory
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon and info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 15))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let category = displayCategory {
                        Image(systemName: category.icon)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: category.colorHex))

                        Text(category.name)
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
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: TransactionViewModel

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
                    Button("Видалити") {
                        Task {
                            await viewModel.deleteTransaction(transaction)
                            dismiss()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

struct SuccessFeedbackView: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Транзакцію додано")
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }
}

struct MetadataEditorSheet: View {
    @Binding var selectedDate: Date
    @Binding var selectedAccount: Account?
    let accounts: [Account]
    let showAccountSelector: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Date Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Дата")
                            .font(.headline)

                        DatePicker(
                            "Оберіть дату",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }

                    // Account Selector (only if more than 1 account)
                    if showAccountSelector {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Рахунок")
                                .font(.headline)

                            ForEach(accounts) { account in
                                Button {
                                    selectedAccount = account
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(account.name)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            Text(formatAmount(account.balance, currency: account.currency))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if selectedAccount?.id == account.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedAccount?.id == account.id
                                            ? Color.blue.opacity(0.1)
                                            : Color(.systemGray6)
                                    )
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Деталі транзакції")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func formatAmount(_ amount: Decimal, currency: Currency) -> String {
        Formatters.currencyString(amount: amount,
                                  currency: currency,
                                  minFractionDigits: 0,
                                  maxFractionDigits: 2)
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Оберіть дату",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Дата транзакції")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct AccountPickerSheet: View {
    let accounts: [Account]
    @Binding var selectedAccount: Account?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(accounts) { account in
                Button {
                    selectedAccount = account
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(account.name)
                                .font(.headline)
                            Text(formatAmount(account.balance, currency: account.currency))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedAccount?.id == account.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Оберіть рахунок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func formatAmount(_ amount: Decimal, currency: Currency) -> String {
        Formatters.currencyString(amount: amount,
                                  currency: currency,
                                  minFractionDigits: 0,
                                  maxFractionDigits: 2)
    }
}

struct CategorySelectorSheet: View {
    @Binding var selectedCategory: Category?
    let categories: [Category]
    let recentCategories: [Category]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Пошук категорій", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Recent Categories Section
                    if !recentCategories.isEmpty && searchText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Останні використані")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(recentCategories) { category in
                                    CategoryGridItem(
                                        category: category,
                                        isSelected: selectedCategory?.id == category.id
                                    ) {
                                        selectedCategory = category
                                        dismiss()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // All Categories Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text(searchText.isEmpty ? "Всі категорії" : "Результати пошуку")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(filteredCategories) { category in
                                CategoryGridItem(
                                    category: category,
                                    isSelected: selectedCategory?.id == category.id
                                ) {
                                    selectedCategory = category
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Категорії")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredCategories: [Category] {
        if searchText.isEmpty {
            return categories
        } else {
            return categories.filter { category in
                category.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.body)
                    .foregroundColor(Color(hex: category.colorHex))

                Text(category.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.body)
                }
            }
            .foregroundColor(isSelected ? .blue : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? Color(hex: category.colorHex).opacity(0.1)
                    : Color(.systemGray6)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickEntryView()
        .environmentObject(DependencyContainer.makeForPreviews().makeTransactionViewModel())
        .environmentObject(DependencyContainer.makeForPreviews().makePendingTransactionsViewModel())
}
