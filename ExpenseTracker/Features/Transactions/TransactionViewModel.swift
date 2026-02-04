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
    @Published var filterDateRange: ClosedRange<Date>? {
        didSet {
            updateFilteredTransactions()
        }
    }
    @Published var filterCategory: Category? {
        didSet {
            updateFilteredTransactions()
        }
    }
    @Published var filterCategories: [Category] = []
    @Published var filterTypes: Set<TransactionType> = []
    @Published var filterAccounts: [Account] = []
    @Published var filterMinAmount: Decimal?
    @Published var filterMaxAmount: Decimal?
    @Published var searchText: String = ""
    @Published var expandedSplitParentIds: Set<Transaction.ID> = []
    @Published private(set) var recentCategories: [Category] = []

    // Bulk operations
    @Published var selectedTransactionIds: Set<Transaction.ID> = []
    @Published var isBulkEditMode: Bool = false

    @Published var errorHandler: ErrorHandlingService?
    
    private var cancellables = Set<AnyCancellable>()
    private var categorySuggestionTask: Task<Void, Never>?
    private let recentCategoryLimit = 6

    // MARK: - Cached Filtered Results
    @Published private(set) var filteredTransactions: [Transaction] = []

    var flattenedFilteredTransactions: [Transaction] {
        filteredTransactions.flatMap { transaction -> [Transaction] in
            if transaction.isSplitParent {
                var items: [Transaction] = [transaction]
                if expandedSplitParentIds.contains(transaction.id) {
                    items.append(contentsOf: transaction.effectiveSplits)
                }
                return items
            }
            return [transaction]
        }
    }
    
    var amountDecimal: Decimal? {
        guard !entryAmount.isEmpty else { return nil }
        // Handle both comma and dot as decimal separator
        let normalized = entryAmount.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }
    
    var isValidEntry: Bool {
        guard let amount = amountDecimal else { return false }
        return amount > 0 && selectedAccount != nil
    }
    
    var currentMonthTotal: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return transactions
            .filter { $0.transactionDate >= startOfMonth && $0.type == .expense }
            .reduce(0) { $0 + $1.effectiveAmount }
    }
    
    var currentMonthIncome: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        return transactions
            .filter { $0.transactionDate >= startOfMonth && $0.type == .income }
            .reduce(0) { $0 + $1.effectiveAmount }
    }
    
    // MARK: - Initialization
    
    init(repository: TransactionRepositoryProtocol,
         categorizationService: CategorizationServiceProtocol,
         analyticsService: AnalyticsServiceProtocol) {
        self.repository = repository
        self.categorizationService = categorizationService
        self.analyticsService = analyticsService
        
        setupSubscriptions()
        Task { @MainActor in
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
                let currentParentIds = Set(transactions.filter { $0.isSplitParent }.map { $0.id })
                self?.expandedSplitParentIds = self?.expandedSplitParentIds.intersection(currentParentIds) ?? []
                self?.updateRecentCategories()
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

        // Auto-categorization on description change (Fix #19: cancel previous task)
        $entryDescription
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] description in
                guard !description.isEmpty else { return }
                self?.categorySuggestionTask?.cancel()
                self?.categorySuggestionTask = Task { @MainActor [weak self] in
                    await self?.suggestCategory(for: description)
                }
            }
            .store(in: &cancellables)

        // Filter pipeline: recalculate filteredTransactions when any filter input changes
        let filterPublisher = Publishers.MergeMany([
            $transactions.map { _ in () }.eraseToAnyPublisher(),
            $searchText.map { _ in () }.eraseToAnyPublisher(),
            $filterCategory.map { _ in () }.eraseToAnyPublisher(),
            $filterCategories.map { _ in () }.eraseToAnyPublisher(),
            $filterTypes.map { _ in () }.eraseToAnyPublisher(),
            $filterAccounts.map { _ in () }.eraseToAnyPublisher(),
            $filterMinAmount.map { _ in () }.eraseToAnyPublisher(),
            $filterMaxAmount.map { _ in () }.eraseToAnyPublisher(),
            $filterDateRange.map { _ in () }.eraseToAnyPublisher()
        ])
        if TestingConfiguration.isRunningTests {
            filterPublisher
                .sink { [weak self] _ in
                    self?.updateFilteredTransactions()
                }
                .store(in: &cancellables)
        } else {
            filterPublisher
                .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateFilteredTransactions()
                }
                .store(in: &cancellables)
        }
    }

    private func updateFilteredTransactions() {
        var result = transactions

        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            result = result.filter { transaction in
                if transaction.description.localizedCaseInsensitiveContains(query) {
                    return true
                }
                if transaction.merchantName?.localizedCaseInsensitiveContains(query) == true {
                    return true
                }
                if transaction.category?.name.localizedCaseInsensitiveContains(query) ?? false {
                    return true
                }
                let splits = transaction.effectiveSplits
                return splits.contains { split in
                    split.description.localizedCaseInsensitiveContains(query) ||
                    (split.merchantName?.localizedCaseInsensitiveContains(query) ?? false) ||
                    (split.category?.name.localizedCaseInsensitiveContains(query) ?? false)
                }
            }
        }

        // Apply category filter (legacy single category)
        if let category = filterCategory {
            result = result.filter { transaction in
                transaction.category?.id == category.id ||
                transaction.effectiveSplits.contains { $0.category?.id == category.id }
            }
        }

        // Apply multi-category filter
        if !filterCategories.isEmpty {
            let categoryIds = Set(filterCategories.map { $0.id })
            result = result.filter { transaction in
                if let categoryId = transaction.category?.id, categoryIds.contains(categoryId) {
                    return true
                }
                return transaction.effectiveSplits.contains { split in
                    guard let splitCategoryId = split.category?.id else { return false }
                    return categoryIds.contains(splitCategoryId)
                }
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
                if transaction.isSplitParent {
                    return transaction.effectiveSplits.contains { split in
                        if let fromId = split.fromAccount?.id, accountIds.contains(fromId) { return true }
                        if let toId = split.toAccount?.id, accountIds.contains(toId) { return true }
                        return false
                    }
                }
                return false
            }
        }

        // Apply amount range filter
        if let minAmount = filterMinAmount {
            result = result.filter { $0.effectiveAmount >= minAmount }
        }
        if let maxAmount = filterMaxAmount {
            result = result.filter { $0.effectiveAmount <= maxAmount }
        }

        // Apply date range filter
        if let dateRange = filterDateRange {
            result = result.filter { dateRange.contains($0.transactionDate) }
        }

        filteredTransactions = result
    }

    private func updateRecentCategories() {
        let flattened = transactions.flatMap { transaction -> [Transaction] in
            if transaction.isSplitParent {
                return transaction.effectiveSplits
            }
            return [transaction]
        }

        let sortedByRecent = flattened.sorted { $0.transactionDate > $1.transactionDate }
        var seen = Set<UUID>()
        var recent: [Category] = []

        for transaction in sortedByRecent {
            guard let category = transaction.category else { continue }
            if seen.insert(category.id).inserted {
                recent.append(category)
            }
            if recent.count >= recentCategoryLimit {
                break
            }
        }

        recentCategories = recent
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedTransactions = try await repository.getAllTransactions()
            let loadedCategories = try await repository.getAllCategories()
            let loadedAccounts = try await repository.getAllAccounts()

            self.transactions = loadedTransactions
            self.categories = loadedCategories
            self.accounts = loadedAccounts
            updateFilteredTransactions()
            updateRecentCategories()
            
            // Select default account
            self.selectedAccount = loadedAccounts.first { $0.isDefault } ?? loadedAccounts.first
        } catch {
            handleError(error, context: "Loading data")
        }
    }
    
    // MARK: - Transaction Operations
    
    func addTransaction() async {
        error = nil
        guard let amount = amountDecimal, amount > 0 else {
            error = AppError.invalidAmount
            return
        }

        guard let account = selectedAccount else {
            error = AppError.accountRequired
            return
        }
        
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
        } catch {
            handleError(error, context: "Updating transaction")
        }
    }
    
    func deleteTransaction(_ transaction: Transaction) async {
        if transaction.isSplitParent {
            await deleteSplitTransaction(transaction, cascade: true)
            return
        }

        isLoading = true
        defer { isLoading = false }
        
        do {
            try await repository.deleteTransaction(transaction)
            analyticsService.trackEvent(.transactionDeleted)
        } catch {
            handleError(error, context: "Deleting transaction")
        }
    }
    
    func deleteTransactions(_ transactions: [Transaction]) async {
        isLoading = true
        defer { isLoading = false }

        do {
            for transaction in transactions {
                if transaction.isSplitParent {
                    if let splits = transaction.splitTransactions {
                        for split in splits {
                            try await repository.deleteTransaction(split)
                        }
                    }
                    try await repository.deleteTransaction(transaction)
                } else {
                    try await repository.deleteTransaction(transaction)
                }
            }
            analyticsService.trackEvent(.transactionDeleted)
        } catch {
            handleError(error, context: "Deleting transactions")
        }
    }

    // MARK: - Bulk Operations

    func selectAllTransactions() {
        selectedTransactionIds = Set(flattenedFilteredTransactions.map { $0.id })
    }

    func deselectAllTransactions() {
        selectedTransactionIds.removeAll()
    }

    func isSplitExpanded(_ id: Transaction.ID) -> Bool {
        expandedSplitParentIds.contains(id)
    }

    func toggleSplitExpansion(_ id: Transaction.ID) {
        if expandedSplitParentIds.contains(id) {
            expandedSplitParentIds.remove(id)
        } else {
            expandedSplitParentIds.insert(id)
        }
    }

    func toggleTransactionSelection(_ id: Transaction.ID) {
        if selectedTransactionIds.contains(id) {
            selectedTransactionIds.remove(id)
        } else {
            selectedTransactionIds.insert(id)
        }
    }

    func bulkDeleteSelectedTransactions() async {
        let transactionsToDelete = flattenedFilteredTransactions.filter { selectedTransactionIds.contains($0.id) }
        guard !transactionsToDelete.isEmpty else { return }

        isLoading = true
        defer {
            isLoading = false
            selectedTransactionIds.removeAll()
            isBulkEditMode = false
        }

        var deletedCount = 0
        do {
            for transaction in transactionsToDelete {
                if transaction.isSplitParent {
                    if let splits = transaction.splitTransactions {
                        for split in splits {
                            try await repository.deleteTransaction(split)
                        }
                    }
                    try await repository.deleteTransaction(transaction)
                } else {
                    try await repository.deleteTransaction(transaction)
                }
                deletedCount += 1
            }
            analyticsService.trackEvent(.transactionDeleted)
            errorHandler?.showToast("Видалено \(transactionsToDelete.count) транзакцій", type: .success)
        } catch {
            if deletedCount > 0 {
                errorHandler?.showToast("Видалено \(deletedCount) з \(transactionsToDelete.count) транзакцій", type: .warning)
            }
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
        filterCategory != nil ||
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
    
    // MARK: - Formatting Helpers
    
    func formatAmount(_ amount: Decimal) -> String {
        Formatters.currencyStringUAH(amount: amount,
                                     minFractionDigits: 2,
                                     maxFractionDigits: 2)
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
                Task { @MainActor in
                    await retryAction()
                }
            })
        }
    }

    // MARK: - Split Transaction Operations

    /// Create or update a split transaction
    func createSplitTransaction(from transaction: Transaction, splits: [SplitItem], retainParent: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.deleteTransaction(transaction)

            let totalAmount = splits.reduce(0) { $0 + $1.amount }

            if retainParent {
                let parentSummary = Transaction(
                    id: transaction.id,
                    timestamp: transaction.timestamp,
                    transactionDate: transaction.transactionDate,
                    type: transaction.type,
                    amount: 0, // summary placeholder
                    category: nil,
                    description: transaction.description,
                    fromAccount: transaction.fromAccount,
                    toAccount: transaction.toAccount,
                    parentTransactionId: nil,
                    splitTransactions: []
                )

                let createdParent = try await repository.createTransaction(parentSummary)

                for split in splits {
                    let child = Transaction(
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
                    _ = try await repository.createTransaction(child)
                }
            } else {
                for split in splits {
                    let standalone = Transaction(
                        timestamp: transaction.timestamp,
                        transactionDate: transaction.transactionDate,
                        type: transaction.type,
                        amount: split.amount,
                        category: split.category,
                        description: split.description.isEmpty ? transaction.description : split.description,
                        fromAccount: transaction.fromAccount,
                        toAccount: transaction.toAccount,
                        parentTransactionId: nil,
                        splitTransactions: nil
                    )
                    _ = try await repository.createTransaction(standalone)
                }
            }

            if retainParent {
                expandedSplitParentIds.insert(transaction.id)
            } else {
                expandedSplitParentIds.remove(transaction.id)
            }
            analyticsService.trackEvent(.transactionAdded(amount: totalAmount, category: nil))
        } catch {
            handleError(error, context: "Creating split transaction")
        }
    }

    /// Update an existing split transaction
    func updateSplitTransaction(_ transaction: Transaction, splits: [SplitItem], retainParent: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let totalAmount = splits.reduce(0) { $0 + $1.amount }

            if let existingSplits = transaction.splitTransactions {
                for split in existingSplits {
                    try await repository.deleteTransaction(split)
                }
            }

            if retainParent {
                let updatedParent = Transaction(
                    id: transaction.id,
                    timestamp: transaction.timestamp,
                    transactionDate: transaction.transactionDate,
                    type: transaction.type,
                    amount: 0,
                    category: nil,
                    description: transaction.description,
                    fromAccount: transaction.fromAccount,
                    toAccount: transaction.toAccount,
                    parentTransactionId: nil,
                    splitTransactions: []
                )

                _ = try await repository.updateTransaction(updatedParent)

                for split in splits {
                    let child = Transaction(
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

                    _ = try await repository.createTransaction(child)
                }
            } else {
                // Convert parent to standalone splits
                for split in splits {
                    let standalone = Transaction(
                        timestamp: transaction.timestamp,
                        transactionDate: transaction.transactionDate,
                        type: transaction.type,
                        amount: split.amount,
                        category: split.category,
                        description: split.description.isEmpty ? transaction.description : split.description,
                        fromAccount: transaction.fromAccount,
                        toAccount: transaction.toAccount,
                        parentTransactionId: nil,
                        splitTransactions: nil
                    )

                    _ = try await repository.createTransaction(standalone)
                }

                try await repository.deleteTransaction(transaction)
            }

            if retainParent {
                expandedSplitParentIds.insert(transaction.id)
            } else {
                expandedSplitParentIds.remove(transaction.id)
            }
            analyticsService.trackEvent(.transactionAdded(amount: totalAmount, category: nil))
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
            let totalAmount = transaction.effectiveAmount

            let regularTransaction = Transaction(
                id: transaction.id,
                timestamp: transaction.timestamp,
                transactionDate: transaction.transactionDate,
                type: transaction.type,
                amount: totalAmount,
                category: category,
                description: description ?? transaction.description,
                fromAccount: transaction.fromAccount,
                toAccount: transaction.toAccount,
                parentTransactionId: nil,
                splitTransactions: nil
            )

            _ = try await repository.updateTransaction(regularTransaction)

            analyticsService.trackEvent(.transactionAdded(amount: totalAmount, category: category.name))
        } catch {
            handleError(error, context: "Converting split to regular transaction")
        }
    }

    /// Delete a split transaction (parent and all children)
    func deleteSplitTransaction(_ transaction: Transaction, cascade: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete split transactions first
            if let splits = transaction.splitTransactions {
                for split in splits {
                    if cascade {
                        try await repository.deleteTransaction(split)
                    } else {
                        var standalone = split
                        standalone.parentTransactionId = nil
                        _ = try await repository.updateTransaction(standalone)
                    }
                }
            }

            // Delete parent
            try await repository.deleteTransaction(transaction)

            analyticsService.trackEvent(.transactionDeleted)
            expandedSplitParentIds.remove(transaction.id)
        } catch {
            handleError(error, context: "Deleting split transaction")
        }
    }
}
