//
//  RepositoryTests.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 07.09.2025.
//

import Testing
import CoreData
@testable import ExpenseTracker

@Suite("Repository Tests")
struct RepositoryTests {
   var sut: CoreDataTransactionRepository
   var testContainer: NSPersistentContainer
   
   init() async throws {
       // Create in-memory Core Data stack for testing
       let container = NSPersistentContainer(name: "ExpenseTracker")
       let description = NSPersistentStoreDescription()
       description.type = NSInMemoryStoreType
       description.shouldAddStoreAsynchronously = false
       container.persistentStoreDescriptions = [description]
   
       try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
           container.loadPersistentStores { _, error in
               if let error = error {
                   continuation.resume(throwing: error)
               } else {
                   continuation.resume(returning: ())
               }
           }
       }
       testContainer = container
       // Create test persistence controller
       let testPersistenceController = PersistenceController(inMemory: true)
   
       // Initialize repository with test container
       sut = await MainActor.run {
           CoreDataTransactionRepository(persistenceController: testPersistenceController)
       }
   }
   
   // MARK: - Transaction Tests
   
   @Test("Create transaction successfully")
   func createTransaction() async throws {
       // Given
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: 1000, isDefault: true)
       let category = Category(id: UUID(), name: "Test Category", icon: "circle", colorHex: "#000000")
       
       _ = try await sut.createAccount(account)
       _ = try await sut.createCategory(category)
       
       let transaction = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: 100,
           category: category,
           description: "Test transaction",
           fromAccount: account,
           toAccount: nil
       )
       
       // When
       let created = try await sut.createTransaction(transaction)
       
       // Then
       #expect(created.amount == 100)
       #expect(created.description == "Test transaction")
       #expect(created.category?.id == category.id)
       #expect(created.fromAccount?.id == account.id)
   }
   
   @Test("Update transaction changes values")
   func updateTransaction() async throws {
       // Given
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: 1000, isDefault: true)
       _ = try await sut.createAccount(account)
       
       let original = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: 100,
           category: nil,
           description: "Original",
           fromAccount: account,
           toAccount: nil
       )
       
       let created = try await sut.createTransaction(original)
       
       // When
       var updated = created
       updated.amount = 200
       updated.description = "Updated"
       
       let result = try await sut.updateTransaction(updated)
       
       // Then
       #expect(result.amount == 200)
       #expect(result.description == "Updated")
   }
   
   @Test("Delete transaction removes from database")
   func deleteTransaction() async throws {
       // Given
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: 1000, isDefault: true)
       _ = try await sut.createAccount(account)
       
       let transaction = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: 100,
           category: nil,
           description: "To delete",
           fromAccount: account,
           toAccount: nil
       )
       
       let created = try await sut.createTransaction(transaction)
       
       // When
       try await sut.deleteTransaction(created)
       let found = try await sut.getTransaction(by: created.id)
       
       // Then
       #expect(found == nil)
   }
   
   @Test("Account balance updates on expense")
   func accountBalanceUpdatesOnExpense() async throws {
       // Given
       let initialBalance: Decimal = 1000
       let expenseAmount: Decimal = 100
       
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: initialBalance, isDefault: true)
       _ = try await sut.createAccount(account)
       
       let transaction = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: expenseAmount,
           category: nil,
           description: "Test expense",
           fromAccount: account,
           toAccount: nil
       )
       
       // When
       _ = try await sut.createTransaction(transaction)
       let accounts = try await sut.getAllAccounts()
       
       // Then
       let updatedAccount = accounts.first { $0.id == account.id }
       #expect(updatedAccount != nil)
       #expect(updatedAccount?.balance == initialBalance - expenseAmount)
   }
   
   @Test("Account balance updates on income")
   func accountBalanceUpdatesOnIncome() async throws {
       // Given
       let initialBalance: Decimal = 1000
       let incomeAmount: Decimal = 500
       
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: initialBalance, isDefault: true)
       _ = try await sut.createAccount(account)
       
       let transaction = Transaction(
           transactionDate: Date(),
           type: .income,
           amount: incomeAmount,
           category: nil,
           description: "Test income",
           fromAccount: nil,
           toAccount: account
       )
       
       // When
       _ = try await sut.createTransaction(transaction)
       let accounts = try await sut.getAllAccounts()
       
       // Then
       let updatedAccount = accounts.first { $0.id == account.id }
       #expect(updatedAccount != nil)
       #expect(updatedAccount?.balance == initialBalance + incomeAmount)
   }
   
   // MARK: - Pending Transaction Tests
   
   @Test("Create and process pending transaction")
   func createAndProcessPendingTransaction() async throws {
       // Given
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: 1000, isDefault: true)
       let category = Category(id: UUID(), name: "Test Category", icon: "circle", colorHex: "#000000")
       
       _ = try await sut.createAccount(account)
       _ = try await sut.createCategory(category)
       
       let pending = PendingTransaction(
           id: UUID(),
           bankTransactionId: "BANK123",
           amount: 150,
           descriptionText: "Test pending",
           merchantName: "Test Merchant",
           transactionDate: Date(),
           type: .expense,
           account: account,
           suggestedCategory: category,
           confidence: 0.85,
           importedAt: Date(),
           status: .pending
       )
       
       // When
       _ = try await sut.createPendingTransaction(pending)
       let pendingList = try await sut.getPendingTransactions(for: nil)
       
       // Then
       #expect(pendingList.count == 1)
       #expect(pendingList.first?.bankTransactionId == "BANK123")
       
       // Process the pending transaction
       let transaction = Transaction(
           transactionDate: pending.transactionDate,
           type: pending.type,
           amount: pending.amount,
           category: category,
           description: pending.descriptionText,
           fromAccount: account,
           toAccount: nil
       )
       
       try await sut.processPendingTransaction(pending.id, as: transaction)
       
       // Verify it's no longer pending
       let remainingPending = try await sut.getPendingTransactions(for: nil)
       #expect(remainingPending.count == 0)
       
       // Verify transaction was created
       let transactions = try await sut.getAllTransactions()
       #expect(transactions.count == 1)
       #expect(transactions.first?.description == "Test pending")
   }
   
   // MARK: - Account Tests
   
   @Test("Create account successfully")
   func createAccount() async throws {
       // Given
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: 0, isDefault: false)
       
       // When
       let created = try await sut.createAccount(account)
       
       // Then
       #expect(created.name == "Test Account")
       #expect(created.tag == "#test")
       #expect(created.balance == 0)
   }
   
   @Test("Set default account ensures only one default")
   func setDefaultAccount() async throws {
       // Given
       let account1 = Account(id: UUID(), name: "Account 1", tag: "#1", balance: 0, isDefault: true)
       let account2 = Account(id: UUID(), name: "Account 2", tag: "#2", balance: 0, isDefault: false)
       
       _ = try await sut.createAccount(account1)
       _ = try await sut.createAccount(account2)
       
       // When
       var updated = account2
       updated.isDefault = true
       _ = try await sut.updateAccount(updated)
       
       let accounts = try await sut.getAllAccounts()
       
       // Then
       let defaultAccounts = accounts.filter { $0.isDefault }
       #expect(defaultAccounts.count == 1)
       #expect(defaultAccounts.first?.id == account2.id)
   }
   
   @Test("Delete account with transactions fails")
   func deleteAccountWithTransactionsFails() async throws {
       // Given
       let account = Account(id: UUID(), name: "Test Account", tag: "#test", balance: 1000, isDefault: true)
       _ = try await sut.createAccount(account)
       
       let transaction = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: 100,
           category: nil,
           description: "Test",
           fromAccount: account,
           toAccount: nil
       )
       _ = try await sut.createTransaction(transaction)
       
       // When/Then
       await #expect(throws: RepositoryError.self) {
           try await sut.deleteAccount(account)
       }
   }
   
   // MARK: - Category Tests
   
   @Test("Create category successfully")
   func createCategory() async throws {
       // Given
       let category = Category(id: UUID(), name: "Test", icon: "circle", colorHex: "#FF0000")
       
       // When
       let created = try await sut.createCategory(category)
       
       // Then
       #expect(created.name == "Test")
       #expect(created.icon == "circle")
       #expect(created.colorHex == "#FF0000")
   }
   
   @Test("Delete category with transactions fails")
   func deleteCategoryWithTransactionsFails() async throws {
       // Given
       let account = Account(id: UUID(), name: "Account", tag: "#test", balance: 1000, isDefault: true)
       let category = Category(id: UUID(), name: "Test", icon: "circle", colorHex: "#000000")
       
       _ = try await sut.createAccount(account)
       _ = try await sut.createCategory(category)
       
       let transaction = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: 100,
           category: category,
           description: "Test",
           fromAccount: account,
           toAccount: nil
       )
       _ = try await sut.createTransaction(transaction)
       
       // When/Then
       await #expect(throws: RepositoryError.self) {
           try await sut.deleteCategory(category)
       }
   }
   
   // MARK: - Query Tests
   
   @Test("Get transactions by date range filters correctly")
   func getTransactionsByDateRange() async throws {
       // Given
       let account = Account(id: UUID(), name: "Account", tag: "#test", balance: 1000, isDefault: true)
       _ = try await sut.createAccount(account)
       
       let calendar = Calendar.current
       let today = Date()
       let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
       let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
       
       // Create transactions for different dates
       let transactions = [
           Transaction(transactionDate: yesterday, type: .expense, amount: 100, category: nil, description: "Yesterday", fromAccount: account, toAccount: nil),
           Transaction(transactionDate: today, type: .expense, amount: 200, category: nil, description: "Today", fromAccount: account, toAccount: nil),
           Transaction(transactionDate: tomorrow, type: .expense, amount: 300, category: nil, description: "Tomorrow", fromAccount: account, toAccount: nil)
       ]
       
       for transaction in transactions {
           _ = try await sut.createTransaction(transaction)
       }
       
       // When
       let startOfToday = calendar.startOfDay(for: today)
       let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!.addingTimeInterval(-1)
       
       let todayTransactions = try await sut.getTransactions(
           for: nil,
           in: startOfToday...endOfToday,
           category: nil
       )
       
       // Then
       #expect(todayTransactions.count == 1)
       #expect(todayTransactions.first?.description == "Today")
   }
   
   @Test("Get transactions by category filters correctly", arguments: ["Category1", "Category2"])
   func getTransactionsByCategory(categoryName: String) async throws {
       // Given
       let account = Account(id: UUID(), name: "Account", tag: "#test", balance: 1000, isDefault: true)
       let category1 = Category(id: UUID(), name: "Category1", icon: "circle", colorHex: "#000000")
       let category2 = Category(id: UUID(), name: "Category2", icon: "square", colorHex: "#FFFFFF")
       
       _ = try await sut.createAccount(account)
       _ = try await sut.createCategory(category1)
       _ = try await sut.createCategory(category2)
       
       let transaction1 = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: 100,
           category: category1,
           description: "Cat1 Transaction",
           fromAccount: account,
           toAccount: nil
       )
       
       let transaction2 = Transaction(
           transactionDate: Date(),
           type: .expense,
           amount: 200,
           category: category2,
           description: "Cat2 Transaction",
           fromAccount: account,
           toAccount: nil
       )
       
       _ = try await sut.createTransaction(transaction1)
       _ = try await sut.createTransaction(transaction2)
       
       // When
       let targetCategory = categoryName == "Category1" ? category1 : category2
       let filteredTransactions = try await sut.getTransactions(
           for: nil,
           in: nil,
           category: targetCategory
       )
       
       // Then
       #expect(filteredTransactions.count == 1)
       let expectedDescription = categoryName == "Category1" ? "Cat1 Transaction" : "Cat2 Transaction"
       #expect(filteredTransactions.first?.description == expectedDescription)
   }
}
