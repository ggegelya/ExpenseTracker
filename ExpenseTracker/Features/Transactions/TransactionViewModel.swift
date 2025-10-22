//
//  TransactionViewModel.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import SwiftUI
import Combine

@MainActor
final class TransactionViewModel: ObservableObject {
    // MARK: - Dependencies
    private let repository: TransactionRepositoryProtocol
    private let categorizationService: CategorizationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    // MARK: - Published Properties
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var selectedAccount: Account?
    
    // Quick entry
    @Published var entryAmount: String = ""
    @Published var entryDescription: String = ""
    @Published var selectedCategory: Category?
    @Published var categoryWasAutoDetected: Bool = false
    @Published var selectedDate: Date = Date()
    @Published var transactionType: TransactionType = .expense
    
    // UI State
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    
    // Filtering
    @Published var filterDateRange: ClosedRange<Date>?
    @Published var filterCategory: Category?
    @Published var filterCategories: [Category] = []
    @Published var filterTypes: Set<TransactionType> = []
    @Published var filterAccounts: [Account] = []
    @Published var filterMinAmount: Decimal?
    @Published var filterMaxAmount: Decimal?
    @Published var searchText: String = ""

    // Bulk operations
    @Published var selectedTransactionIds: Set<Transaction.ID> = []
    @Published var isBulkEditMode: Bool = false

    @Published var errorHandler: ErrorHandlingService?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredTransactions: [Transaction] {
        var result = transactions

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { transaction in
                transaction.description.localizedCaseInsensitiveContains(searchText) ||
                transaction.category?.name.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        // Apply category filter (legacy single category)
        if let category = filterCategory {
            result = result.filter { $0.category?.id == category.id }
        }

        // Apply multi-category filter
        if !filterCategories.isEmpty {
            let categoryIds = Set(filterCategories.map { $0.id })
            result = result.filter { transaction in
                guard let categoryId = transaction.category?.id else { return false }
                return categoryIds.contains(categoryId)
            }
        }

        // Apply transaction type filter
        if !filterTypes.isEmpty {
            result = result.filter { filterTypes.contains($0.type) }
        }

        // Apply account filter
        if !filterAccounts.isEmpty {
            let accountIds = Set(filterAccounts.map { $0.id })
            result = result.filter { transaction in
                if let fromAccountId = transaction.fromAccount?.id, accountIds.contains(fromAccountId) {
                    return true
                }
                if let toAccountId = transaction.toAccount?.id, accountIds.contains(toAccountId) {
                    return true
                }
                return false
            }
        }

        // Apply amount range filter
        if let minAmount = filterMinAmount {
            result = result.filter { $0.amount >= minAmount }
        }
        if let maxAmount = filterMaxAmount {
            result = result.filter { $0.amount <= maxAmount }
        }

        // Apply date range filter
        if let dateRange = filterDateRange {
            result = result.filter { dateRange.contains($0.transactionDate) }
        }

        return result
    }
    
    var amountDecimal: Decimal? {
        guard !entryAmount.isEmpty else { return nil }
        // Handle both comma and dot as decimal separator
        let normalized = entryAmount.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }
    
    var isValidEntry: Bool {
        amountDecimal != nil &&
        amountDecimal! > 0 &&
        !entryDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedAccount != nil
    }
    
    var currentMonthTotal: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return transactions
            .filter { $0.transactionDate >= startOfMonth && $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }
    
    var currentMonthIncome: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return transactions
            .filter { $0.transactionDate >= startOfMonth && $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Initialization
    
    init(repository: TransactionRepositoryProtocol,
         categorizationService: CategorizationServiceProtocol,
         analyticsService: AnalyticsServiceProtocol) {
        self.repository = repository
        self.categorizationService = categorizationService
        self.analyticsService = analyticsService
        
        setupSubscriptions()
        Task {
            await loadData()
        }
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        // Subscribe to repository updates
        repository.transactionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transactions in
                self?.transactions = transactions
            }
            .store(in: &cancellables)
        
        repository.categoriesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] categories in
                self?.categories = categories
            }
            .store(in: &cancellables)
        
        repository.accountsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] accounts in
                self?.accounts = accounts
                // Auto-select default account if not selected
                if self?.selectedAccount == nil {
                    self?.selectedAccount = accounts.first { $0.isDefault } ?? accounts.first
                }
            }
            .store(in: &cancellables)
        
        // Auto-categorization on description change
        $entryDescription
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] description in
                guard !description.isEmpty else { return }
                Task {
                    await self?.suggestCategory(for: description)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let transactions = repository.getAllTransactions()
            async let categories = repository.getAllCategories()
            async let accounts = repository.getAllAccounts()
            
            let (loadedTransactions, loadedCategories, loadedAccounts) = try await (transactions, categories, accounts)
            
            self.transactions = loadedTransactions
            self.categories = loadedCategories
            self.accounts = loadedAccounts
            
            // Select default account
            self.selectedAccount = loadedAccounts.first { $0.isDefault } ?? loadedAccounts.first
        } catch {
            handleError(error, context: "Loading data")
        }
    }
    
    // MARK: - Transaction Operations
    
    func addTransaction() async {
        guard isValidEntry,
              let amount = amountDecimal,
              let account = selectedAccount else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let transaction = Transaction(
            transactionDate: selectedDate,
            type: transactionType,
            amount: amount,
            category: selectedCategory,
            description: entryDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            fromAccount: transactionType == .expense || transactionType == .transferOut ? account : nil,
            toAccount: transactionType == .income || transactionType == .transferIn ? account : nil
        )
        
        do {
            let created = try await repository.createTransaction(transaction)
            
            // Track analytics
            analyticsService.trackEvent(.transactionAdded(
                amount: created.amount,
                category: created.category?.name
            ))
            
            errorHandler?.showToast("Транзакцію успішно додано", type: .success)
            // Clear entry form
            clearEntry()
            
            // Reload data
            await loadData()
        } catch {
            handleError(error, context: "Adding transaction") {
                await self.addTransaction() // Retry action
            }
            
        }
    }
    
    func updateTransaction(_ transaction: Transaction) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await repository.updateTransaction(transaction)
            await loadData()
        } catch {
            handleError(error, context: "Updating transaction")
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await repository.deleteTransaction(transaction)
            analyticsService.trackEvent(.transactionDeleted)
            await loadData()
        } catch {
            handleError(error, context: "Deleting transaction")
        }
    }
    
    func deleteTransactions(_ transactions: [Transaction]) async {
        isLoading = true
        defer { isLoading = false }

        do {
            for transaction in transactions {
                try await repository.deleteTransaction(transaction)
            }
            analyticsService.trackEvent(.transactionDeleted)
            await loadData()
        } catch {
            handleError(error, context: "Deleting transactions")
        }
    }

    // MARK: - Bulk Operations

    func selectAllTransactions() {
        selectedTransactionIds = Set(filteredTransactions.map { $0.id })
    }

    func deselectAllTransactions() {
        selectedTransactionIds.removeAll()
    }

    func toggleTransactionSelection(_ id: Transaction.ID) {
        if selectedTransactionIds.contains(id) {
            selectedTransactionIds.remove(id)
        } else {
            selectedTransactionIds.insert(id)
        }
    }

    func bulkDeleteSelectedTransactions() async {
        let transactionsToDelete = transactions.filter { selectedTransactionIds.contains($0.id) }
        guard !transactionsToDelete.isEmpty else { return }

        isLoading = true
        defer {
            isLoading = false
            selectedTransactionIds.removeAll()
            isBulkEditMode = false
        }

        do {
            for transaction in transactionsToDelete {
                try await repository.deleteTransaction(transaction)
            }
            analyticsService.trackEvent(.transactionDeleted)
            errorHandler?.showToast("Видалено \(transactionsToDelete.count) транзакцій", type: .success)
            await loadData()
        } catch {
            handleError(error, context: "Bulk deleting transactions")
        }
    }

    func bulkCategorizeSelectedTransactions(to category: Category) async {
        let transactionsToUpdate = transactions.filter { selectedTransactionIds.contains($0.id) }
        guard !transactionsToUpdate.isEmpty else { return }

        isLoading = true
        defer {
            isLoading = false
            selectedTransactionIds.removeAll()
            isBulkEditMode = false
        }

        do {
            for transaction in transactionsToUpdate {
                // Create new transaction with updated category (since category is immutable)
                let updatedTransaction = Transaction(
                    id: transaction.id,
                    timestamp: transaction.timestamp,
                    transactionDate: transaction.transactionDate,
                    type: transaction.type,
                    amount: transaction.amount,
                    category: category,
                    description: transaction.description,
                    fromAccount: transaction.fromAccount,
                    toAccount: transaction.toAccount
                )
                _ = try await repository.updateTransaction(updatedTransaction)
            }
            errorHandler?.showToast("Категоризовано \(transactionsToUpdate.count) транзакцій", type: .success)
            await loadData()
        } catch {
            handleError(error, context: "Bulk categorizing transactions")
        }
    }

    var selectedTransactionCount: Int {
        selectedTransactionIds.count
    }

    var hasActiveFilters: Bool {
        !filterCategories.isEmpty ||
        !filterTypes.isEmpty ||
        !filterAccounts.isEmpty ||
        filterMinAmount != nil ||
        filterMaxAmount != nil ||
        filterDateRange != nil ||
        !searchText.isEmpty
    }

    func clearAllFilters() {
        filterDateRange = nil
        filterCategory = nil
        filterCategories = []
        filterTypes = []
        filterAccounts = []
        filterMinAmount = nil
        filterMaxAmount = nil
        searchText = ""
    }

    // MARK: - Category Operations
    
    func createCategory(name: String, icon: String, color: String) async {
        let category = Category(
            id: UUID(),
            name: name,
            icon: icon,
            colorHex: color
        )
        
        do {
            _ = try await repository.createCategory(category)
            analyticsService.trackEvent(.categoryCreated)
            await loadData()
        } catch {
            handleError(error, context: "Creating category")
        }
    }
    
    // MARK: - Helper Methods
    
    func clearEntry() {
        entryAmount = ""
        entryDescription = ""
        selectedCategory = nil
        selectedDate = Date()
        // Keep type and account for convenience
    }
    
    private func suggestCategory(for description: String) async {
        let (category, confidence) = await categorizationService.suggestCategory(
            for: description,
            merchantName: nil
        )

        // Only auto-select if confidence is high enough and no category is manually selected
        if confidence > 0.7 && selectedCategory == nil {
            selectedCategory = category
            categoryWasAutoDetected = true
        }
    }
    
    func learnCategoryCorrection(for transaction: Transaction, correctCategory: Category) async {
        await categorizationService.learnFromCorrection(
            description: transaction.description,
            merchantName: nil,
            correctCategory: correctCategory
        )
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error, context: String) {
        self.error = error
        self.showError = true
        analyticsService.trackError(error, context: context)
        
#if DEBUG
        print("Error in \(context): \(error)")
#endif
    }
    
    // MARK: - Formatting Helpers
    
    func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "₴0"
    }
    
    func handleError(_ error: Error, context: String, retryAction: (() async -> Void)? = nil) {
        let appError: AppError

        if let repoError = error as? RepositoryError {
            appError = AppError(from: repoError)
        } else if let urlError = error as? URLError {
            appError = AppError(from: urlError)
        } else {
            appError = .syncFailed // Default mapping
        }

        errorHandler?.handle(appError, context: context)

        if let retryAction = retryAction {
            errorHandler?.showAlert(appError, retryAction: {
                Task {
                    await retryAction()
                }
            })
        }
    }

    // MARK: - Split Transaction Operations

    /// Create or update a split transaction
    func createSplitTransaction(from transaction: Transaction, splits: [SplitItem]) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete the original transaction first (if converting)
            if !transaction.isSplit {
                try await repository.deleteTransaction(transaction)
            }

            // Create the parent transaction with no category (since it's split)
            let parentTransaction = Transaction(
                id: transaction.id,
                timestamp: transaction.timestamp,
                transactionDate: transaction.transactionDate,
                type: transaction.type,
                amount: transaction.amount,
                category: nil, // Parent has no category
                description: transaction.description,
                fromAccount: transaction.fromAccount,
                toAccount: transaction.toAccount,
                parentTransactionId: nil,
                splitTransactions: []
            )

            let createdParent = try await repository.createTransaction(parentTransaction)

            // Create each split as a child transaction
            for split in splits {
                let splitTransaction = Transaction(
                    timestamp: transaction.timestamp,
                    transactionDate: transaction.transactionDate,
                    type: transaction.type,
                    amount: split.amount,
                    category: split.category,
                    description: split.description.isEmpty ? transaction.description : split.description,
                    fromAccount: transaction.fromAccount,
                    toAccount: transaction.toAccount,
                    parentTransactionId: createdParent.id,
                    splitTransactions: nil
                )

                _ = try await repository.createTransaction(splitTransaction)
            }

            await loadData()
            analyticsService.trackEvent(.transactionAdded(amount: transaction.amount, category: nil))
        } catch {
            handleError(error, context: "Creating split transaction")
        }
    }

    /// Update an existing split transaction
    func updateSplitTransaction(_ transaction: Transaction, splits: [SplitItem]) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete existing split transactions
            if let existingSplits = transaction.splitTransactions {
                for split in existingSplits {
                    try await repository.deleteTransaction(split)
                }
            }

            // Create new splits
            for split in splits {
                let splitTransaction = Transaction(
                    timestamp: transaction.timestamp,
                    transactionDate: transaction.transactionDate,
                    type: transaction.type,
                    amount: split.amount,
                    category: split.category,
                    description: split.description.isEmpty ? transaction.description : split.description,
                    fromAccount: transaction.fromAccount,
                    toAccount: transaction.toAccount,
                    parentTransactionId: transaction.id,
                    splitTransactions: nil
                )

                _ = try await repository.createTransaction(splitTransaction)
            }

            await loadData()
            analyticsService.trackEvent(.transactionAdded(amount: transaction.amount, category: nil))
        } catch {
            handleError(error, context: "Updating split transaction")
        }
    }

    /// Convert a split transaction back to a regular transaction
    func convertSplitToRegular(_ transaction: Transaction, category: Category, description: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete all split transactions
            if let splits = transaction.splitTransactions {
                for split in splits {
                    try await repository.deleteTransaction(split)
                }
            }

            // Update the parent to be a regular transaction with a category
            let regularTransaction = Transaction(
                id: transaction.id,
                timestamp: transaction.timestamp,
                transactionDate: transaction.transactionDate,
                type: transaction.type,
                amount: transaction.amount,
                category: category,
                description: description ?? transaction.description,
                fromAccount: transaction.fromAccount,
                toAccount: transaction.toAccount,
                parentTransactionId: nil,
                splitTransactions: nil
            )

            _ = try await repository.updateTransaction(regularTransaction)

            await loadData()
            analyticsService.trackEvent(.transactionAdded(amount: transaction.amount, category: category.name))
        } catch {
            handleError(error, context: "Converting split to regular transaction")
        }
    }

    /// Delete a split transaction (parent and all children)
    func deleteSplitTransaction(_ transaction: Transaction) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete split transactions first
            if let splits = transaction.splitTransactions {
                for split in splits {
                    try await repository.deleteTransaction(split)
                }
            }

            // Delete parent
            try await repository.deleteTransaction(transaction)

            await loadData()
            analyticsService.trackEvent(.transactionDeleted)
        } catch {
            handleError(error, context: "Deleting split transaction")
        }
    }
}

