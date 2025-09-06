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
    @Published var selectedDate: Date = Date()
    @Published var transactionType: TransactionType = .expense
    
    // UI State
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showError = false
    
    // Filtering
    @Published var filterDateRange: ClosedRange<Date>?
    @Published var filterCategory: Category?
    @Published var searchText: String = ""
    
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
        
        // Apply category filter
        if let category = filterCategory {
            result = result.filter { $0.category?.id == category.id }
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
            
            // Clear entry form
            clearEntry()
            
            // Reload data
            await loadData()
        } catch {
            handleError(error, context: "Adding transaction")
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
}
