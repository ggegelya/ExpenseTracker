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
    
    @State private var showDatePicker = false
    @State private var showAccountPicker = false
    @State private var showSuccessFeedback = false
    @State private var showErrorAlert = false
    @State private var keyboardHeight: CGFloat = 0
    
    // Animation states
    @State private var successScale: CGFloat = 1.0
    @State private var pendingBadgeScale: CGFloat = 1.0
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                    
                    // Quick Actions Row
                    QuickActionsRow(
                        selectedDate: $viewModel.selectedDate,
                        selectedAccount: viewModel.selectedAccount,
                        onDateTap: { showDatePicker.toggle() },
                        onAccountTap: { showAccountPicker.toggle() }
                    )
                    
                    // Categories Section
                    CategoriesSection(
                        categories: viewModel.categories,
                        selectedCategory: $viewModel.selectedCategory
                    )
                    
                    // Description Section
                    DescriptionSection(
                        description: $viewModel.entryDescription,
                        isDescriptionFocused: _isDescriptionFocused,
                        suggestedCategory: viewModel.selectedCategory
                    )
                    
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
                            transactions: Array(viewModel.transactions.prefix(5))
                        )
                    }
                }
                .padding()
                .padding(.bottom, keyboardHeight)
            }
            .navigationTitle("Додати транзакцію")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isAmountFocused = false
                        isDescriptionFocused = false
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $viewModel.selectedDate)
            }
            .sheet(isPresented: $showAccountPicker) {
                AccountPickerSheet(
                    accounts: viewModel.accounts,
                    selectedAccount: $viewModel.selectedAccount
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
        .foregroundColor(.white)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
        .scaleEffect(scale)
    }
}

struct AmountInputSection: View {
    @Binding var amount: String
    @Binding var transactionType: TransactionType
    @FocusState var isAmountFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Transaction type selector
            Picker("Тип", selection: $transactionType) {
                Text("Витрата").tag(TransactionType.expense)
                Text("Дохід").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)
            
            // Amount input
            HStack(alignment: .center, spacing: 8) {
                Text(transactionType.symbol)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundColor(transactionType == .expense ? .red : .green)
                    .animation(.easeInOut, value: transactionType)
                
                TextField("0", text: $amount)
                    .font(.system(size: 48, weight: .light, design: .rounded))
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
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            
            // Quick amount buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach([50, 100, 200, 500, 1000], id: \.self) { quickAmount in
                        QuickAmountButton(amount: quickAmount) {
                            amount = String(quickAmount)
                            isAmountFocused = false
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct QuickAmountButton: View {
    let amount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("₴\(amount)")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(20)
        }
    }
}

struct QuickActionsRow: View {
    @Binding var selectedDate: Date
    let selectedAccount: Account?
    let onDateTap: () -> Void
    let onAccountTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Date selector
            Button(action: onDateTap) {
                HStack {
                    Image(systemName: "calendar")
                    Text(selectedDate, style: .date)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
            
            // Account selector
            Button(action: onAccountTap) {
                HStack {
                    Image(systemName: "creditcard")
                    Text(selectedAccount?.name ?? "Оберіть рахунок")
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundColor(selectedAccount != nil ? .primary : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
    }
}

struct CategoriesSection: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    @EnvironmentObject private var viewModel: TransactionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Категорія")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
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
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Додати транзакцію")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: isValid ? [.blue, .blue.opacity(0.8)] : [.gray, .gray.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: isValid ? .blue.opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .disabled(!isValid || isLoading)
        .scaleEffect(scale)
    }
}

struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    @EnvironmentObject private var viewModel: TransactionViewModel
    @State private var showAllTransactions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Останні транзакції")
                    .font(.headline)
                Spacer()
                Button {
                    showAllTransactions = true
                } label: {
                    Text("Всі")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
        .sheet(isPresented: $showAllTransactions) {
            TransactionListView()
                .environmentObject(viewModel)
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

#Preview {
    QuickEntryView()
        .environmentObject(DependencyContainer.makeForPreviews().makeTransactionViewModel())
        .environmentObject(DependencyContainer.makeForPreviews().makePendingTransactionsViewModel())
}
