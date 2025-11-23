//
//  TransactionFlowIntegrationTests.swift
//  ExpenseTracker
//
//  Integration tests for end-to-end transaction flows with real Core Data stack
//
import Testing
import CoreData
@testable import ExpenseTracker

@Suite("Transaction Flow Integration Tests", .serialized)
struct TransactionFlowIntegrationTests {
    var repository: CoreDataTransactionRepository
    var persistenceController: PersistenceController

    init() async throws {
        // Create in-memory Core Data stack for testing
        let persistenceCtrl = await MainActor.run {
            PersistenceController(inMemory: true)
        }

        // Initialize repository with test container
        let repo = await MainActor.run {
            CoreDataTransactionRepository(persistenceController: persistenceCtrl)
        }
        self.repository = repo
        self.persistenceController = persistenceCtrl
    }

    // MARK: - Complete Transaction Entry Flow

    @Test("Complete transaction entry flow: Create account → category → transaction → verify balance")
    func completeTransactionEntryFlow() async throws {
        // Step 1: Create account
        let account = MockAccount.makeCustom(
            name: "Test Account",
            tag: "#test",
            balance: 1000.00,
            isDefault: true
        )
        let createdAccount = try await repository.createAccount(account)
        #expect(createdAccount.balance == 1000.00)

        // Step 2: Create category
        let category = MockCategory.makeCustom(
            name: "Test Category",
            icon: "cart.fill",
            colorHex: "#4CAF50"
        )
        let createdCategory = try await repository.createCategory(category)
        #expect(createdCategory.name == "Test Category")

        // Step 3: Create transaction
        let transaction = Transaction(
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 250.00,
            category: createdCategory,
            description: "Integration test expense",
            fromAccount: createdAccount,
            toAccount: nil
        )
        let createdTransaction = try await repository.createTransaction(transaction)

        // Step 4: Verify transaction created with relationships
        #expect(createdTransaction.amount == 250.00)
        #expect(createdTransaction.category?.id == createdCategory.id)
        #expect(createdTransaction.fromAccount?.id == createdAccount.id)

        // Step 5: Verify balance updated
        let accounts = try await repository.getAllAccounts()
        let updatedAccount = accounts.first { $0.id == createdAccount.id }
        #expect(updatedAccount?.balance == 750.00, "Balance should be 1000 - 250 = 750")
    }

    // MARK: - Split Transaction Flow

    @Test("Split transaction flow: Create parent → add splits → verify totals → update → delete")
    func splitTransactionFlow() async throws {
        // Step 1: Create account and categories
        let account = MockAccount.makeCustom(balance: 1000.00, isDefault: true)
        let category1 = MockCategory.makeGroceries()
        let category2 = MockCategory.makeHealth()

        let createdAccount = try await repository.createAccount(account)
        let createdCategory1 = try await repository.createCategory(category1)
        let createdCategory2 = try await repository.createCategory(category2)

        // Step 2: Create parent transaction
        let parentId = UUID()
        let parent = Transaction(
            id: parentId,
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 0.00,
            category: nil,
            description: "Split Parent",
            fromAccount: createdAccount,
            toAccount: nil
        )
        let createdParent = try await repository.createTransaction(parent)

        // Step 3: Add split components
        let child1 = Transaction(
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 300.00,
            category: createdCategory1,
            description: "Groceries Split",
            fromAccount: createdAccount,
            toAccount: nil,
            parentTransactionId: parentId
        )

        let child2 = Transaction(
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 200.00,
            category: createdCategory2,
            description: "Pharmacy Split",
            fromAccount: createdAccount,
            toAccount: nil,
            parentTransactionId: parentId
        )

        let createdChild1 = try await repository.createTransaction(child1)
        let createdChild2 = try await repository.createTransaction(child2)

        // Step 4: Verify parent-child relationships
        let fetchedParent = try await repository.getTransaction(by: parentId)
        #expect(fetchedParent != nil)
        #expect(fetchedParent?.splitTransactions?.count == 2)

        // Step 5: Verify totals
        let splitTransactions = fetchedParent?.splitTransactions ?? []
        let totalSplits = splitTransactions.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(totalSplits == 500.00, "Split components should sum to intended total (500)")

        // Step 6: Update split component
        var updatedChild1 = createdChild1
        updatedChild1.amount = 350.00
        let updatedChild = try await repository.updateTransaction(updatedChild1)
        #expect(updatedChild.amount == 350.00)

        // Step 7: Delete parent (should cascade to children)
        try await repository.deleteTransaction(createdParent)

        // Step 8: Verify parent and children deleted
        let deletedParent = try await repository.getTransaction(by: parentId)
        #expect(deletedParent == nil)

        let deletedChild1 = try await repository.getTransaction(by: createdChild1.id)
        let deletedChild2 = try await repository.getTransaction(by: createdChild2.id)
        #expect(deletedChild1 == nil)
        #expect(deletedChild2 == nil)

        // Step 9: Verify balance restored
        let accounts = try await repository.getAllAccounts()
        let finalAccount = accounts.first { $0.id == createdAccount.id }
        #expect(finalAccount?.balance == 1000.00, "Balance should be restored after deletion")
    }

    // MARK: - Banking Transaction Processing Flow

    @Test("Banking transaction processing flow: Create pending → categorize → process → verify created")
    func bankingTransactionProcessingFlow() async throws {
        // Step 1: Create account and category
        let account = MockAccount.makeBankConnected()
        let category = MockCategory.makeGroceries()

        let createdAccount = try await repository.createAccount(account)
        let createdCategory = try await repository.createCategory(category)

        // Step 2: Create pending transaction (simulating bank import)
        let pending = PendingTransaction(
            id: UUID(),
            bankTransactionId: "BANK_TEST_123",
            amount: 350.00,
            descriptionText: "Silpo супермаркет",
            merchantName: "Silpo",
            transactionDate: DateGenerator.yesterday(),
            type: .expense,
            account: createdAccount,
            suggestedCategory: createdCategory,
            confidence: 0.95,
            importedAt: DateGenerator.now(),
            status: .pending
        )

        let createdPending = try await repository.createPendingTransaction(pending)
        #expect(createdPending.status == .pending)

        // Step 3: Verify pending transaction appears in list
        let pendingList = try await repository.getPendingTransactions(for: createdAccount)
        #expect(pendingList.count == 1)
        #expect(pendingList.first?.bankTransactionId == "BANK_TEST_123")

        // Step 4: Process pending transaction (user confirms categorization)
        let transaction = Transaction(
            transactionDate: pending.transactionDate,
            type: pending.type,
            amount: pending.amount,
            category: createdCategory,
            description: pending.descriptionText,
            fromAccount: createdAccount,
            toAccount: nil
        )

        try await repository.processPendingTransaction(pending.id, as: transaction)

        // Step 5: Verify pending transaction removed
        let remainingPending = try await repository.getPendingTransactions(for: createdAccount)
        #expect(remainingPending.isEmpty, "Pending transaction should be removed after processing")

        // Step 6: Verify actual transaction created
        let transactions = try await repository.getAllTransactions()
        #expect(transactions.count == 1)
        let processedTransaction = transactions.first
        #expect(processedTransaction?.description == "Silpo супермаркет")
        #expect(processedTransaction?.category?.id == createdCategory.id)

        // Step 7: Verify balance updated
        let accounts = try await repository.getAllAccounts()
        let updatedAccount = accounts.first { $0.id == createdAccount.id }
        let expectedBalance = account.balance - 350.00
        #expect(updatedAccount?.balance == expectedBalance)
    }

    // MARK: - Account Deletion with Transaction History

    @Test("Account deletion with transaction history: Create transactions → attempt delete → verify error → delete transactions → delete account")
    func accountDeletionWithTransactionHistory() async throws {
        // Step 1: Create account
        let account = MockAccount.makeCustom(balance: 1000.00)
        let createdAccount = try await repository.createAccount(account)

        // Step 2: Create multiple transactions
        let transaction1 = Transaction(
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 100.00,
            category: nil,
            description: "Transaction 1",
            fromAccount: createdAccount,
            toAccount: nil
        )

        let transaction2 = Transaction(
            transactionDate: DateGenerator.yesterday(),
            type: .expense,
            amount: 150.00,
            category: nil,
            description: "Transaction 2",
            fromAccount: createdAccount,
            toAccount: nil
        )

        let created1 = try await repository.createTransaction(transaction1)
        let created2 = try await repository.createTransaction(transaction2)

        // Step 3: Attempt to delete account (should fail)
        await #expect(throws: RepositoryError.self) {
            try await repository.deleteAccount(createdAccount)
        }

        // Step 4: Verify account still exists
        let accounts = try await repository.getAllAccounts()
        #expect(accounts.contains { $0.id == createdAccount.id })

        // Step 5: Delete all transactions
        try await repository.deleteTransaction(created1)
        try await repository.deleteTransaction(created2)

        // Step 6: Verify transactions deleted
        let remainingTransactions = try await repository.getAllTransactions()
        #expect(remainingTransactions.isEmpty)

        // Step 7: Delete account (should succeed now)
        try await repository.deleteAccount(createdAccount)

        // Step 8: Verify account deleted
        let finalAccounts = try await repository.getAllAccounts()
        #expect(!finalAccounts.contains { $0.id == createdAccount.id })
    }

    // MARK: - Category Migration Flow

    @Test("Category migration flow: Create transactions → update category → verify transactions updated")
    func categoryMigrationFlow() async throws {
        // Step 1: Create account and category
        let account = MockAccount.makeCustom(balance: 2000.00)
        let originalCategory = MockCategory.makeCustom(
            name: "Original Category",
            icon: "star.fill",
            colorHex: "#FF0000"
        )

        let createdAccount = try await repository.createAccount(account)
        let createdCategory = try await repository.createCategory(originalCategory)

        // Step 2: Create multiple transactions with this category
        let transaction1 = Transaction(
            transactionDate: DateGenerator.today(),
            type: .expense,
            amount: 100.00,
            category: createdCategory,
            description: "Transaction 1",
            fromAccount: createdAccount,
            toAccount: nil
        )

        let transaction2 = Transaction(
            transactionDate: DateGenerator.yesterday(),
            type: .expense,
            amount: 200.00,
            category: createdCategory,
            description: "Transaction 2",
            fromAccount: createdAccount,
            toAccount: nil
        )

        _ = try await repository.createTransaction(transaction1)
        _ = try await repository.createTransaction(transaction2)

        // Step 3: Update category
        let updatedCategory = Category(
            id: createdCategory.id,
            name: "Updated Category",
            icon: "circle.fill",
            colorHex: "#00FF00"
        )

        let resultCategory = try await repository.updateCategory(updatedCategory)
        #expect(resultCategory.name == "Updated Category")
        #expect(resultCategory.icon == "circle.fill")

        // Step 4: Verify all transactions still reference the category
        let transactions = try await repository.getAllTransactions()
        #expect(transactions.count == 2)

        for transaction in transactions {
            #expect(transaction.category?.id == createdCategory.id)
        }

        // Step 5: Fetch transactions by category filter
        let filteredTransactions = try await repository.getTransactions(
            for: createdAccount,
            in: nil,
            category: updatedCategory
        )
        #expect(filteredTransactions.count == 2)
    }

    // MARK: - Export and Re-import Flow

    @Test("Export and re-import flow: Create transactions → export → verify data integrity")
    func exportAndReimportFlow() async throws {
        // Step 1: Create test data
        let account = MockAccount.makeCustom(
            name: "Export Test",
            tag: "#export",
            balance: 5000.00
        )
        let category = MockCategory.makeGroceries()

        let createdAccount = try await repository.createAccount(account)
        let createdCategory = try await repository.createCategory(category)

        // Step 2: Create diverse transactions
        let transactions = [
            Transaction(
                transactionDate: DateGenerator.date(year: 2025, month: 1, day: 15),
                type: .expense,
                amount: 250.50,
                category: createdCategory,
                description: "Groceries with decimal",
                fromAccount: createdAccount,
                toAccount: nil
            ),
            Transaction(
                transactionDate: DateGenerator.date(year: 2025, month: 1, day: 20),
                type: .income,
                amount: 5000.00,
                category: nil,
                description: "Salary payment",
                fromAccount: nil,
                toAccount: createdAccount
            ),
            Transaction(
                transactionDate: DateGenerator.date(year: 2025, month: 1, day: 25),
                type: .expense,
                amount: 1500.00,
                category: nil,
                description: "Transaction with special chars: quotes comma",
                fromAccount: createdAccount,
                toAccount: nil
            )
        ]

        var createdTransactions: [Transaction] = []
        for transaction in transactions {
            let created = try await repository.createTransaction(transaction)
            createdTransactions.append(created)
        }

        // Step 3: Fetch all data (simulating export)
        let exportedTransactions = try await repository.getAllTransactions()
        #expect(exportedTransactions.count == 3)

        // Step 4: Verify data integrity
        for exported in exportedTransactions {
            let original = createdTransactions.first { $0.id == exported.id }!

            #expect(exported.amount == original.amount)
            #expect(exported.description == original.description)
            #expect(exported.type == original.type)
            #expect(exported.category?.id == original.category?.id)

            // Verify date accuracy
            let timeDifference = abs(exported.transactionDate.timeIntervalSince(original.transactionDate))
            #expect(timeDifference < 1.0, "Date should be preserved accurately")
        }

        // Step 5: Verify account balance calculation
        let accounts = try await repository.getAllAccounts()
        let finalAccount = accounts.first { $0.id == createdAccount.id }

        // Expected: 5000 - 250.50 + 5000 - 1500 = 8249.50
        #expect(finalAccount?.balance == 8249.50)
    }
}

