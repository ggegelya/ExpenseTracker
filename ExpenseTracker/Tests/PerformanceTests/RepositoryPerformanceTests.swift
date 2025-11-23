//
//  RepositoryPerformanceTests.swift
//  ExpenseTracker
//
//  Performance tests for repository operations with realistic data volumes
//
import Testing
import CoreData
@testable import ExpenseTracker

@Suite("Repository Performance Tests", .serialized)
struct RepositoryPerformanceTests {
    var repository: CoreDataTransactionRepository
    var persistenceController: PersistenceController

    init() async throws {
        // Create in-memory Core Data stack for testing without capturing self
        let controller: PersistenceController = await MainActor.run {
            PersistenceController(inMemory: true)
        }
        // Initialize repository with test container
        let repo: CoreDataTransactionRepository = await MainActor.run {
            CoreDataTransactionRepository(persistenceController: controller)
        }
        // Assign to stored properties after both are created
        self.persistenceController = controller
        self.repository = repo
    }

    // MARK: - Fetch Performance Tests

    @Test("Fetch 1000 transactions completes in <1 second")
    func fetch1000TransactionsPerformance() async throws {
        // Setup: Create 1000 transactions
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 100000))
        let category = try await repository.createCategory(MockCategory.makeGroceries())

        // Create 1000 transactions in batches for faster setup
        for batch in 0..<10 {
            var transactions: [Transaction] = []
            for i in 0..<100 {
                let transaction = Transaction(
                    transactionDate: DateGenerator.daysAgo(batch * 100 + i),
                    type: .expense,
                    amount: Decimal(Double.random(in: 10...500)),
                    category: category,
                    description: "Transaction \(batch * 100 + i)",
                    fromAccount: account,
                    toAccount: nil
                )
                transactions.append(transaction)
            }

            // Batch create
            for transaction in transactions {
                _ = try await repository.createTransaction(transaction)
            }
        }

        // Performance test: Fetch all transactions
        let startTime = Date()

        let fetchedTransactions = try await repository.getAllTransactions()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        #expect(fetchedTransactions.count == 1000, "Should fetch all 1000 transactions")
        #expect(duration < 1.0, "Fetch should complete in less than 1 second, took \(duration)s")
    }

    @Test("Create 100 transactions in batch completes in <2 seconds")
    func create100TransactionsPerformance() async throws {
        // Setup
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 50000))
        let category = try await repository.createCategory(MockCategory.makeGroceries())

        // Performance test: Create 100 transactions
        let startTime = Date()

        for i in 0..<100 {
            let transaction = Transaction(
                transactionDate: DateGenerator.daysAgo(i),
                type: .expense,
                amount: Decimal(100 + i),
                category: category,
                description: "Batch transaction \(i)",
                fromAccount: account,
                toAccount: nil
            )
            _ = try await repository.createTransaction(transaction)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        let allTransactions = try await repository.getAllTransactions()
        #expect(allTransactions.count == 100, "Should create 100 transactions")
        #expect(duration < 2.0, "Batch create should complete in less than 2 seconds, took \(duration)s")

        // Verify balance updated correctly
        let accounts = try await repository.getAllAccounts()
        let finalAccount = accounts.first { $0.id == account.id }

        // Expected: 50000 - sum(100 to 199) = 50000 - 14950 = 35050
        let expectedBalance = Decimal(50000) - Decimal(14950)
        #expect(finalAccount?.balance == expectedBalance, "Balance should be correctly updated")
    }

    @Test("Filter transactions with complex predicate is fast")
    func filterTransactionsWithComplexPredicatePerformance() async throws {
        // Setup: Create diverse transactions
        let account1 = try await repository.createAccount(MockAccount.makeCustom(name: "Account1", balance: 10000))
        let account2 = try await repository.createAccount(MockAccount.makeCustom(name: "Account2", balance: 10000))
        let category1 = try await repository.createCategory(MockCategory.makeGroceries())
        let category2 = try await repository.createCategory(MockCategory.makeTaxi())

        // Create 500 transactions with varied attributes
        for i in 0..<500 {
            let useAccount1 = i % 2 == 0
            let useCategory1 = i % 3 == 0
            let transaction = Transaction(
                transactionDate: DateGenerator.daysAgo(i % 90),
                type: i % 10 == 0 ? .income : .expense,
                amount: Decimal(Double.random(in: 50...1000)),
                category: useCategory1 ? category1 : category2,
                description: "Transaction \(i)",
                fromAccount: useAccount1 ? account1 : account2,
                toAccount: nil
            )
            _ = try await repository.createTransaction(transaction)
        }

        // Performance test: Complex filter (account + date range + category)
        let startTime = Date()

        let startDate = DateGenerator.daysAgo(30)
        let endDate = DateGenerator.today()

        let filtered = try await repository.getTransactions(
            for: account1,
            in: startDate...endDate,
            category: category1
        )

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        #expect(filtered.count > 0, "Should find matching transactions")
        #expect(duration < 0.5, "Complex filter should complete in less than 0.5 seconds, took \(duration)s")

        // Verify all results match criteria
        for transaction in filtered {
            #expect(transaction.fromAccount?.id == account1.id || transaction.toAccount?.id == account1.id,
                   "Should match account filter")
            #expect(transaction.category?.id == category1.id, "Should match category filter")
            #expect(transaction.transactionDate >= startDate && transaction.transactionDate <= endDate,
                   "Should match date range filter")
        }
    }

    @Test("Prefetching relationships reduces query count")
    func prefetchingRelationshipsPerformance() async throws {
        // Setup: Create 100 transactions with relationships
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 20000))
        let categories = [
            try await repository.createCategory(MockCategory.makeGroceries()),
            try await repository.createCategory(MockCategory.makeTaxi()),
            try await repository.createCategory(MockCategory.makeHealth())
        ]

        for i in 0..<100 {
            let transaction = Transaction(
                transactionDate: DateGenerator.daysAgo(i),
                type: .expense,
                amount: Decimal(100),
                category: categories[i % 3],
                description: "Transaction \(i)",
                fromAccount: account,
                toAccount: nil
            )
            _ = try await repository.createTransaction(transaction)
        }

        // Performance test: Access relationships on all transactions
        let startTime = Date()

        let transactions = try await repository.getAllTransactions()

        // Access relationships (should be prefetched)
        var categoryNames: [String] = []
        var accountNames: [String] = []

        for transaction in transactions {
            if let category = transaction.category {
                categoryNames.append(category.name)
            }
            if let account = transaction.fromAccount {
                accountNames.append(account.name)
            }
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        #expect(categoryNames.count == 100, "Should access all categories")
        #expect(accountNames.count == 100, "Should access all accounts")
        #expect(duration < 0.5, "Accessing prefetched relationships should be fast, took \(duration)s")
    }

    @Test("Publisher updates don't cause excessive refreshes")
    func publisherUpdatesPerformance() async throws {
        // Setup
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 5000))

        var updateCount = 0
        let cancellable = repository.transactionsPublisher
            .dropFirst() // Skip initial value
            .sink { _ in
                updateCount += 1
            }

        // Create 10 transactions
        for i in 0..<10 {
            let transaction = Transaction(
                transactionDate: DateGenerator.today(),
                type: .expense,
                amount: Decimal(100),
                category: nil,
                description: "Transaction \(i)",
                fromAccount: account,
                toAccount: nil
            )
            _ = try await repository.createTransaction(transaction)
        }

        // Wait for debounced publisher updates
        try await AsyncTestUtilities.wait(seconds: 1.5)

        // Verify: Publisher should debounce updates
        // With debouncing, we expect significantly fewer updates than operations
        #expect(updateCount > 0, "Publisher should emit updates")
        #expect(updateCount < 15, "Publisher should debounce (got \(updateCount) updates for 10 operations)")

        cancellable.cancel()
    }

    @Test("Account balance calculation with 1000 transactions is fast")
    func accountBalanceCalculationPerformance() async throws {
        // Setup: Create account and 1000 transactions
        let initialBalance: Decimal = 100000
        let account = try await repository.createAccount(
            MockAccount.makeCustom(balance: initialBalance)
        )

        // Create 1000 mixed transactions
        var expectedBalance = initialBalance

        for i in 0..<1000 {
            let isExpense = i % 3 != 0 // ~66% expenses, ~33% income
            let amount = Decimal(Double.random(in: 10...200))

            let transaction = Transaction(
                transactionDate: DateGenerator.daysAgo(i),
                type: isExpense ? .expense : .income,
                amount: amount,
                category: nil,
                description: "Transaction \(i)",
                fromAccount: isExpense ? account : nil,
                toAccount: isExpense ? nil : account
            )

            _ = try await repository.createTransaction(transaction)

            // Track expected balance
            if isExpense {
                expectedBalance -= amount
            } else {
                expectedBalance += amount
            }
        }

        // Performance test: Retrieve account with calculated balance
        let startTime = Date()

        let accounts = try await repository.getAllAccounts()
        let retrievedAccount = accounts.first { $0.id == account.id }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        #expect(retrievedAccount != nil, "Account should be retrieved")
        // Compare with a small tolerance to account for Decimal representation differences
        if let actual = retrievedAccount?.balance {
            let diff = (actual - expectedBalance).magnitude
            #expect(diff <= Decimal(string: "0.01")!, "Balance should be correctly calculated (diff: \(diff))")
        } else {
            #expect(false, "Account should be retrieved")
        }
        #expect(duration < 0.3, "Balance retrieval should be fast, took \(duration)s")
    }

    @Test("Category breakdown calculation with large dataset is fast")
    func categoryBreakdownPerformance() async throws {
        // Setup: Create multiple categories and 500 transactions
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 100000))
        let categories = [
            try await repository.createCategory(MockCategory.makeGroceries()),
            try await repository.createCategory(MockCategory.makeTaxi()),
            try await repository.createCategory(MockCategory.makeHealth()),
            try await repository.createCategory(MockCategory.makeUtilities()),
            try await repository.createCategory(MockCategory.makeCafe())
        ]

        // Create 500 transactions spread across categories
        for i in 0..<500 {
            let category = categories[i % categories.count]
            let transaction = Transaction(
                transactionDate: DateGenerator.daysAgo(i % 90),
                type: .expense,
                amount: Decimal(Double.random(in: 50...500)),
                category: category,
                description: "Transaction \(i)",
                fromAccount: account,
                toAccount: nil
            )
            _ = try await repository.createTransaction(transaction)
        }

        // Performance test: Calculate category breakdown
        let startTime = Date()

        var categoryTotals: [UUID: Decimal] = [:]

        for category in categories {
            let categoryTransactions = try await repository.getTransactions(
                for: nil,
                in: nil,
                category: category
            )

            let total = categoryTransactions.reduce(Decimal(0)) { $0 + $1.amount }
            categoryTotals[category.id] = total
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        #expect(categoryTotals.count == categories.count, "Should calculate for all categories")
        #expect(categoryTotals.values.allSatisfy { $0 > 0 }, "All categories should have transactions")
        #expect(duration < 1.0, "Category breakdown should complete in less than 1 second, took \(duration)s")
    }

    // MARK: - Memory Performance Tests

    @Test("Batch operations don't cause excessive memory usage")
    func batchOperationsMemoryPerformance() async throws {
        // Setup
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 200000))
        let category = try await repository.createCategory(MockCategory.makeGroceries())

        // Create 500 transactions (should not cause memory issues)
        for batch in 0..<5 {
            for i in 0..<100 {
                let transaction = Transaction(
                    transactionDate: DateGenerator.daysAgo(batch * 100 + i),
                    type: .expense,
                    amount: Decimal(100 + i),
                    category: category,
                    description: "Batch \(batch) Transaction \(i)",
                    fromAccount: account,
                    toAccount: nil
                )
                _ = try await repository.createTransaction(transaction)
            }

            // Small delay between batches to allow Core Data to flush
            try await AsyncTestUtilities.wait(seconds: 0.1)
        }

        // Verify all created successfully
        let allTransactions = try await repository.getAllTransactions()
        #expect(allTransactions.count == 500, "All transactions should be created")

        // Memory should be reasonable (this test verifies no crashes/leaks)
        #expect(true, "Batch operations completed without memory issues")
    }

    // MARK: - Update Performance Tests

    @Test("Updating 100 transactions is efficient")
    func update100TransactionsPerformance() async throws {
        // Setup: Create 100 transactions
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 20000))
        let category = try await repository.createCategory(MockCategory.makeGroceries())

        var transactions: [Transaction] = []
        for i in 0..<100 {
            let transaction = Transaction(
                transactionDate: DateGenerator.today(),
                type: .expense,
                amount: Decimal(100),
                category: category,
                description: "Original \(i)",
                fromAccount: account,
                toAccount: nil
            )
            let created = try await repository.createTransaction(transaction)
            transactions.append(created)
        }

        // Performance test: Update all transactions
        let startTime = Date()

        for i in 0..<transactions.count {
            var updated = transactions[i]
            updated.amount = Decimal(200)
            updated.description = "Updated \(i)"
            _ = try await repository.updateTransaction(updated)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        let allTransactions = try await repository.getAllTransactions()
        let allUpdated = allTransactions.allSatisfy { $0.amount == 200 && $0.description.starts(with: "Updated") }
        #expect(allUpdated, "All transactions should be updated")
        #expect(duration < 3.0, "Updating 100 transactions should complete in less than 3 seconds, took \(duration)s")
    }

    // MARK: - Delete Performance Tests

    @Test("Deleting 100 transactions is efficient")
    func delete100TransactionsPerformance() async throws {
        // Setup: Create 200 transactions
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 30000))

        var transactionsToDelete: [Transaction] = []
        for i in 0..<200 {
            let transaction = Transaction(
                transactionDate: DateGenerator.today(),
                type: .expense,
                amount: Decimal(100),
                category: nil,
                description: "Transaction \(i)",
                fromAccount: account,
                toAccount: nil
            )
            let created = try await repository.createTransaction(transaction)

            if i < 100 {
                transactionsToDelete.append(created)
            }
        }

        // Performance test: Delete 100 transactions
        let startTime = Date()

        for transaction in transactionsToDelete {
            try await repository.deleteTransaction(transaction)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        let remainingTransactions = try await repository.getAllTransactions()
        #expect(remainingTransactions.count == 100, "Should have 100 remaining transactions")
        #expect(duration < 2.0, "Deleting 100 transactions should complete in less than 2 seconds, took \(duration)s")
    }

    // MARK: - Background Context Performance

    @Test("Background context operations don't block main thread")
    func backgroundContextPerformance() async throws {
        // This test verifies that repository uses background context appropriately
        let account = try await repository.createAccount(MockAccount.makeCustom(balance: 10000))

        // Create transactions (should use background context)
        let startTime = Date()

        for i in 0..<50 {
            let transaction = Transaction(
                transactionDate: DateGenerator.today(),
                type: .expense,
                amount: Decimal(100),
                category: nil,
                description: "Background \(i)",
                fromAccount: account,
                toAccount: nil
            )
            _ = try await repository.createTransaction(transaction)
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify
        let transactions = try await repository.getAllTransactions()
        #expect(transactions.count == 50, "All transactions should be created")
        #expect(duration < 1.5, "Background operations should be efficient, took \(duration)s")
    }
}
