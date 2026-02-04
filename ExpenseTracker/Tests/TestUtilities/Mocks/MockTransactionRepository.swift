//
//  MockTransactionRepository.swift
//  ExpenseTracker
//
//  Mock implementation of TransactionRepositoryProtocol for testing
//

import Foundation
import Combine
import CoreData

/// Mock implementation of TransactionRepositoryProtocol for testing
/// Supports both success and error scenarios, tracks method calls, and uses in-memory storage
@MainActor
final class MockTransactionRepository: TransactionRepositoryProtocol {

    // MARK: - In-Memory Storage

    var transactions: [Transaction] = []
    var accounts: [Account] = []
    var categories: [Category] = []
    var pendingTransactions: [PendingTransaction] = []

    // MARK: - Publishers

    private let transactionsSubject = CurrentValueSubject<[Transaction], Never>([])
    private let accountsSubject = CurrentValueSubject<[Account], Never>([])
    private let categoriesSubject = CurrentValueSubject<[Category], Never>([])

    var transactionsPublisher: AnyPublisher<[Transaction], Never> {
        transactionsSubject.eraseToAnyPublisher()
    }

    var accountsPublisher: AnyPublisher<[Account], Never> {
        accountsSubject.eraseToAnyPublisher()
    }

    var categoriesPublisher: AnyPublisher<[Category], Never> {
        categoriesSubject.eraseToAnyPublisher()
    }

    // MARK: - Call Tracking

    private(set) var methodCalls: [String] = []

    struct CallRecord {
        let method: String
        let timestamp: Date
        let parameters: [String: Any]
    }

    private(set) var detailedCalls: [CallRecord] = []

    // MARK: - Error Injection

    var shouldThrowError: Bool = false
    var errorToThrow: Error = RepositoryError.saveFailed(underlying: NSError(domain: "MockError", code: -1))
    var errorOnNextCall: Bool = false

    /// Configuration for specific method errors
    private var methodErrors: [String: Error] = [:]

    // MARK: - Response Configuration

    var createTransactionResult: Transaction?
    var updateTransactionResult: Transaction?
    var getTransactionResult: Transaction?

    // MARK: - Initialization

    init() {}

    /// Convenience initializer with pre-populated data
    init(
        transactions: [Transaction] = [],
        accounts: [Account] = [],
        categories: [Category] = [],
        pendingTransactions: [PendingTransaction] = []
    ) {
        self.transactions = transactions
        self.accounts = accounts
        self.categories = categories
        self.pendingTransactions = pendingTransactions

        publishChanges()
    }

    // MARK: - Helper Methods

    private func recordCall(_ method: String, parameters: [String: Any] = [:]) {
        methodCalls.append(method)
        detailedCalls.append(CallRecord(method: method, timestamp: Date(), parameters: parameters))
    }

    private func checkForError(method: String) throws {
        if errorOnNextCall {
            errorOnNextCall = false
            throw errorToThrow
        }

        if shouldThrowError {
            throw errorToThrow
        }

        if let error = methodErrors[method] {
            throw error
        }
    }

    private func publishChanges() {
        transactionsSubject.send(transactions)
        accountsSubject.send(accounts)
        categoriesSubject.send(categories)
    }

    /// Configures a specific error for a specific method
    func setError(_ error: Error, forMethod method: String) {
        methodErrors[method] = error
    }

    /// Clears all recorded method calls
    func clearCallHistory() {
        methodCalls.removeAll()
        detailedCalls.removeAll()
    }

    /// Resets all data and configuration
    func reset() {
        transactions.removeAll()
        accounts.removeAll()
        categories.removeAll()
        pendingTransactions.removeAll()
        methodCalls.removeAll()
        detailedCalls.removeAll()
        methodErrors.removeAll()
        shouldThrowError = false
        errorOnNextCall = false
        publishChanges()
    }

    // MARK: - Transaction Operations

    func createTransaction(_ transaction: Transaction) async throws -> Transaction {
        recordCall(#function, parameters: ["transaction": transaction])
        try checkForError(method: #function)

        if let result = createTransactionResult {
            transactions.append(result)
            publishChanges()
            return result
        }

        transactions.append(transaction)
        publishChanges()
        return transaction
    }

    func updateTransaction(_ transaction: Transaction) async throws -> Transaction {
        recordCall(#function, parameters: ["transaction": transaction])
        try checkForError(method: #function)

        if let result = updateTransactionResult {
            if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
                transactions[index] = result
                publishChanges()
            }
            return result
        }

        guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else {
            throw RepositoryError.entityNotFound
        }

        transactions[index] = transaction
        publishChanges()
        return transaction
    }

    func deleteTransaction(_ transaction: Transaction) async throws {
        recordCall(#function, parameters: ["transaction": transaction])
        try checkForError(method: #function)

        transactions.removeAll { $0.id == transaction.id }
        publishChanges()
    }

    func getTransaction(by id: UUID) async throws -> Transaction? {
        recordCall(#function, parameters: ["id": id])
        try checkForError(method: #function)

        if let result = getTransactionResult {
            return result
        }

        return transactions.first { $0.id == id }
    }

    func getAllTransactions() async throws -> [Transaction] {
        recordCall(#function)
        try checkForError(method: #function)

        return transactions
    }

    func getTransactions(
        for account: Account?,
        in dateRange: ClosedRange<Date>?,
        category: Category?
    ) async throws -> [Transaction] {
        recordCall(#function, parameters: [
            "account": account as Any,
            "dateRange": dateRange as Any,
            "category": category as Any
        ])
        try checkForError(method: #function)

        var filtered = transactions

        // Filter by account
        if let account = account {
            filtered = filtered.filter { transaction in
                transaction.fromAccount?.id == account.id ||
                transaction.toAccount?.id == account.id
            }
        }

        // Filter by date range
        if let dateRange = dateRange {
            filtered = filtered.filter { transaction in
                dateRange.contains(transaction.transactionDate)
            }
        }

        // Filter by category
        if let category = category {
            filtered = filtered.filter { transaction in
                transaction.category?.id == category.id
            }
        }

        return filtered
    }

    // MARK: - Pending Transaction Operations

    func createPendingTransaction(_ pending: PendingTransaction) async throws -> PendingTransaction {
        recordCall(#function, parameters: ["pending": pending])
        try checkForError(method: #function)

        pendingTransactions.append(pending)
        return pending
    }

    func getPendingTransactions(for account: Account?) async throws -> [PendingTransaction] {
        recordCall(#function, parameters: ["account": account as Any])
        try checkForError(method: #function)

        if let account = account {
            return pendingTransactions.filter { $0.account.id == account.id }
        }

        return pendingTransactions
    }

    func processPendingTransaction(_ pendingId: UUID, as transaction: Transaction) async throws {
        recordCall(#function, parameters: [
            "pendingId": pendingId,
            "transaction": transaction
        ])
        try checkForError(method: #function)

        // Remove from pending
        pendingTransactions.removeAll { $0.id == pendingId }

        // Add as regular transaction
        transactions.append(transaction)
        publishChanges()
    }

    func dismissPendingTransaction(_ pendingId: UUID) async throws {
        recordCall(#function, parameters: ["pendingId": pendingId])
        try checkForError(method: #function)

        pendingTransactions.removeAll { $0.id == pendingId }
    }

    // MARK: - Account Operations

    func createAccount(_ account: Account) async throws -> Account {
        recordCall(#function, parameters: ["account": account])
        try checkForError(method: #function)

        // If this is the default account, unset other defaults
        if account.isDefault {
            accounts = accounts.map { existingAccount in
                var updated = existingAccount
                updated.isDefault = false
                return updated
            }
        }

        accounts.append(account)
        publishChanges()
        return account
    }

    func updateAccount(_ account: Account) async throws -> Account {
        recordCall(#function, parameters: ["account": account])
        try checkForError(method: #function)

        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            throw RepositoryError.entityNotFound
        }

        // If setting as default, unset other defaults
        if account.isDefault {
            accounts = accounts.map { existingAccount in
                var updated = existingAccount
                if updated.id != account.id {
                    updated.isDefault = false
                }
                return updated
            }
        }

        accounts[index] = account
        publishChanges()
        return account
    }

    func deleteAccount(_ account: Account) async throws {
        recordCall(#function, parameters: ["account": account])
        try checkForError(method: #function)

        // Check if account has transactions
        let hasTransactions = transactions.contains { transaction in
            transaction.fromAccount?.id == account.id ||
            transaction.toAccount?.id == account.id
        }

        if hasTransactions {
            throw RepositoryError.invalidData("Cannot delete account with existing transactions")
        }

        accounts.removeAll { $0.id == account.id }
        publishChanges()
    }

    func getAllAccounts() async throws -> [Account] {
        recordCall(#function)
        try checkForError(method: #function)

        return accounts
    }

    func getDefaultAccount() async throws -> Account? {
        recordCall(#function)
        try checkForError(method: #function)

        return accounts.first { $0.isDefault }
    }

    // MARK: - Category Operations

    func createCategory(_ category: Category) async throws -> Category {
        recordCall(#function, parameters: ["category": category])
        try checkForError(method: #function)

        categories.append(category)
        publishChanges()
        return category
    }

    func updateCategory(_ category: Category) async throws -> Category {
        recordCall(#function, parameters: ["category": category])
        try checkForError(method: #function)

        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            throw RepositoryError.entityNotFound
        }

        categories[index] = category
        publishChanges()
        return category
    }

    func deleteCategory(_ category: Category) async throws {
        recordCall(#function, parameters: ["category": category])
        try checkForError(method: #function)

        // Check if category has transactions
        let hasTransactions = transactions.contains { transaction in
            transaction.category?.id == category.id
        }

        if hasTransactions {
            throw RepositoryError.invalidData("Cannot delete category with existing transactions")
        }

        categories.removeAll { $0.id == category.id }
        publishChanges()
    }

    func getAllCategories() async throws -> [Category] {
        recordCall(#function)
        try checkForError(method: #function)

        return categories
    }

    // MARK: - Batch Operations

    func performBatch(_ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void) async throws {
        recordCall(#function)
        try checkForError(method: #function)

        // Mock doesn't use Core Data, so we just record the call
        // In real tests, you might want to execute the operation with a mock context
    }

    // MARK: - Test Convenience Methods

    /// Seeds the repository with default test data
    func seedWithDefaultData() {
        accounts = MockAccount.makeMultiple()
        categories = MockCategory.makeDefaultCategories()
        transactions = MockTransaction.makeMultiple(count: 20)
        pendingTransactions = MockPendingTransaction.makeMultiple(count: 5)
        publishChanges()
    }

    /// Returns whether a specific method was called
    func wasCalled(_ method: String) -> Bool {
        methodCalls.contains(method)
    }

    /// Returns the number of times a method was called
    func callCount(for method: String) -> Int {
        methodCalls.filter { $0 == method }.count
    }

    /// Returns the most recent call record for a method
    func lastCall(for method: String) -> CallRecord? {
        detailedCalls.last { $0.method == method }
    }

    /// Returns all call records for a method
    func allCalls(for method: String) -> [CallRecord] {
        detailedCalls.filter { $0.method == method }
    }
}
