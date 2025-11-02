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
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    // Auto-suggest categories based on description, only show when 3+ characters
    private var suggestedCategories: [Category] {
        let description = viewModel.entryDescription.trimmingCharacters(in: .whitespaces)

        // Only show suggestions if description has 3+ characters
        guard description.count >= 3 else {
            return []
        }

        // Filter categories based on description match
        let filtered = viewModel.categories.filter { category in
            category.name.localizedCaseInsensitiveContains(description)
        }

        // Return matches (max 5), or top 5 categories if no matches
        if !filtered.isEmpty {
            return Array(filtered.prefix(5))
        } else {
            return Array(viewModel.categories.prefix(5))
        }
    }

    // Recent/frequent categories - using first 4-6 as placeholder
    // TODO: Replace with actual usage tracking
    private var recentCategories: [Category] {
        Array(viewModel.categories.prefix(6))
    }

    // Categories to display - always include selected category
    private var displayedCategories: [Category] {
        var categories = suggestedCategories

        // If there's a selected category and it's not in the suggestions, add it
        if let selected = viewModel.selectedCategory,
           !categories.contains(where: { $0.id == selected.id }) {
            categories.insert(selected, at: 0)
        }

        return categories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
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
                    }
                    
                    // Amount Section
                    AmountInputSection(
                        amount: $viewModel.entryAmount,
                        transactionType: $viewModel.transactionType,
                        isAmountFocused: _isAmountFocused
                    )

                    // Metadata Row (Date + Account)
                    MetadataRow(
                        selectedDate: $viewModel.selectedDate,
                        selectedAccount: viewModel.selectedAccount,
                        showAccountSelector: viewModel.accounts.count > 1,
                        onTap: { showMetadataEditor = true }
                    )

                    // Description Section
                    DescriptionSection(
                        description: $viewModel.entryDescription,
                        isDescriptionFocused: _isDescriptionFocused,
                        suggestedCategory: viewModel.selectedCategory
                    )

                    // Categories Section (moved after description, show max 5)
                    if !suggestedCategories.isEmpty || viewModel.selectedCategory != nil {
                        CategoriesSection(
                            categories: displayedCategories,
                            selectedCategory: $viewModel.selectedCategory,
                            onShowAllCategories: { showCategoryPicker = true }
                        )
                    } else {
                        // Show "Всі категорії" button when no suggestions and no selection
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                    .font(.subheadline)
                                Text("Обрати категорію")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Add Button
                    AddTransactionButton(
                        isValid: viewModel.isValidEntry,
                        isLoading: viewModel.isLoading,
                        scale: successScale
                    ) {
                        await addTransaction()
                    }
                    
                    // Recent Transactions
                    if !viewModel.transactions.isEmpty {
                        RecentTransactionsSection(
                            transactions: Array(viewModel.transactions.prefix(3)),
                            totalCount: viewModel.transactions.count
                        )
                    }
                }
                .padding()
                .padding(.bottom, keyboardHeight)
            }
            .navigationTitle("Додати транзакцію")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isAmountFocused = false
                        isDescriptionFocused = false
                    }
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
    }
    
    // MARK: - Actions
    
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

    var body: some View {
        VStack(spacing: 0) {
            // Amount input with toggle indicator
            HStack(alignment: .center, spacing: 12) {
                // Tap-to-toggle -/+ indicator
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        transactionType = transactionType == .expense ? .income : .expense
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(transactionType == .expense ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Text(transactionType.symbol)
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(transactionType == .expense ? .red : .green)
                    }
                }
                .buttonStyle(.plain)

                TextField("0", text: $amount)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
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
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)

            Divider()
        }
    }
}

struct MetadataRow: View {
    @Binding var selectedDate: Date
    let selectedAccount: Account?
    let showAccountSelector: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                if showAccountSelector, let account = selectedAccount {
                    Text("·")
                        .foregroundColor(.secondary)

                    Image(systemName: "creditcard")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(account.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
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
    let suggestedCategory: Category?
    @EnvironmentObject private var viewModel: TransactionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Опис")
                    .font(.headline)

                if suggestedCategory != nil && viewModel.categoryWasAutoDetected {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Категорія підібрана автоматично")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            TextField("Наприклад: Кава в Aroma", text: $description)
                .textFieldStyle(.roundedBorder)
                .focused($isDescriptionFocused)
                .submitLabel(.done)
                .onSubmit {
                    isDescriptionFocused = false
                }
        }
    }
}

struct AddTransactionButton: View {
    let isValid: Bool
    let isLoading: Bool
    let scale: CGFloat
    let action: () async -> Void

    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                    Text("Додати")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(isValid ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isValid ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .disabled(!isValid || isLoading)
        .scaleEffect(scale)
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
            HStack {
                Text("Останні транзакції")
                    .font(.headline)
                Spacer()

                // Only show "Всі" link if there are more than 3 items
                if totalCount > 3 {
                    Button {
                        showAllTransactions = true
                    } label: {
                        Text("Всі")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }

            // Use List for swipe actions
            List {
                ForEach(transactions) { transaction in
                    TransactionRow(transaction: transaction)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTransaction = transaction
                        }
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

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: TransactionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Сума")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(alignment: .center, spacing: 8) {
                            Text(transaction.type.symbol)
                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                .foregroundColor(transaction.type == .expense ? .red : .green)
                            Text(Formatters.currencyString(
                                amount: transaction.amount,
                                currency: (transaction.fromAccount ?? transaction.toAccount)?.currency ?? .uah
                            ))
                            .font(.system(size: 32, weight: .light, design: .rounded))
                        }
                    }

                    Divider()

                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Дата")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(transaction.transactionDate, style: .date)
                            .font(.body)
                    }

                    Divider()

                    // Account
                    if let account = transaction.fromAccount ?? transaction.toAccount {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Рахунок")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(account.name)
                                .font(.body)
                        }

                        Divider()
                    }

                    // Category
                    if let category = transaction.category {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категорія")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(hex: category.colorHex))
                                Text(category.name)
                                    .font(.body)
                            }
                        }

                        Divider()
                    }

                    // Description
                    if !transaction.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Опис")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(transaction.description)
                                .font(.body)
                        }
                    }
                }
                .padding()
            }
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
