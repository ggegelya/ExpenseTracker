//  TransactionViewModelTests.swift
//  ExpenseTracker
//
//  Created by Claude Code on 22.11.2025.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("TransactionViewModel Tests", .serialized)
@MainActor
struct TransactionViewModelTests {
    var sut: TransactionViewModel
    var mockRepository: MockTransactionRepository
    var mockCategorizationService: MockCategorizationService
    var mockAnalyticsService: MockAnalyticsService
    var mockErrorHandler: MockErrorHandlingService

    init() async throws {
        mockRepository = MockTransactionRepository()
        mockCategorizationService = MockCategorizationService()
        mockAnalyticsService = MockAnalyticsService()
        mockErrorHandler = MockErrorHandlingService()

        sut = TransactionViewModel(
            repository: mockRepository,
            categorizationService: mockCategorizationService,
            analyticsService: mockAnalyticsService,
            errorHandler: mockErrorHandler
        )
    }

    // MARK: - Load Data Tests

    @Test("Load data populates transactions, categories, accounts")
    func loadDataPopulatesAll() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let categories = MockCategory.makeDefaultCategories()
        let transactions = MockTransaction.makeMultiple(count: 5, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = categories
        mockRepository.transactions = transactions

        // When
        await sut.loadData()

        // Then
        #expect(sut.transactions.count == 5)
        #expect(sut.categories.count == categories.count)
        #expect(sut.accounts.count == 1)
        #expect(mockRepository.wasCalled("getAllTransactions()"))
        #expect(mockRepository.wasCalled("getAllCategories()"))
        #expect(mockRepository.wasCalled("getAllAccounts()"))
    }

    // MARK: - Create Transaction Tests

    @Test("Create transaction clears entry form on success")
    func createTransactionClearsFormOnSuccess() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        mockRepository.accounts = [account]
        mockRepository.categories = [category]

        await sut.loadData()

        sut.entryAmount = "150.50"
        sut.entryDescription = "Test purchase"
        sut.selectedCategory = category
        sut.selectedAccount = account
        sut.transactionType = .expense

        // When
        await sut.addTransaction()

        // Then
        #expect(sut.entryAmount.isEmpty)
        #expect(sut.entryDescription.isEmpty)
        #expect(sut.selectedCategory == nil)
        #expect(mockRepository.wasCalled("createTransaction(_:)"))
        #expect(mockAnalyticsService.wasTransactionAdded())
    }

    @Test("Create transaction shows error on failure")
    func createTransactionShowsErrorOnFailure() async throws {
        // Given
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = NSError(domain: "Test", code: -1, userInfo: nil)

        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        mockRepository.accounts = [account]
        mockRepository.categories = [category]

        await sut.loadData()

        sut.entryAmount = "150.50"
        sut.selectedCategory = category
        sut.selectedAccount = account
        sut.transactionType = .expense

        // When
        await sut.addTransaction()

        // Then - entry form should not be cleared on error
        #expect(!sut.entryAmount.isEmpty)
    }

    // MARK: - Amount Validation Tests

    @Test("Amount validation rejects invalid input")
    func amountValidationRejectsInvalidInput() async throws {
        // Given invalid amounts
        let invalidAmounts = ["", "abc", "12.34.56", "-100", "0"]

        for amount in invalidAmounts {
            // When
            sut.entryAmount = amount

            // Then
            #expect(!sut.isValidEntry, "Amount '\(amount)' should be invalid")
        }
    }

    @Test("Amount validation accepts valid decimal input")
    func amountValidationAcceptsValidInput() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        await sut.loadData()

        sut.selectedAccount = account
        sut.selectedCategory = category

        let validAmounts = ["100", "150.50", "0.01", "999999.99"]

        for amount in validAmounts {
            // When
            sut.entryAmount = amount

            // Then
            #expect(sut.isValidEntry, "Amount '\(amount)' should be valid")
        }
    }

    // MARK: - Category Auto-Suggestion Tests

    @Test("Category auto-suggestion triggers on description change")
    func categoryAutoSuggestionTriggersOnDescriptionChange() async throws {
        // Given
        let category = MockCategory.makeGroceries()
        mockRepository.categories = [category]
        await sut.loadData()

        mockCategorizationService.setDescriptionRule("Сільпо", category: category, confidence: 0.95)

        // When
        sut.entryDescription = "Покупка в Сільпо"

        // Wait for debounce
        try await Task.sleep(for: .seconds(0.8))

        // Then
        #expect(mockCategorizationService.wasCalled)
        #expect(mockCategorizationService.wasDescriptionCategorized("Покупка в Сільпо"))
    }

    @Test("Category auto-suggestion only applies with high confidence")
    func categoryAutoSuggestionOnlyAppliesWithHighConfidence() async throws {
        // Given
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()
        mockRepository.categories = [groceries, transport]
        await sut.loadData()

        // Setup: high confidence suggestion
        mockCategorizationService.setDescriptionRule("Сільпо", category: groceries, confidence: 0.95)

        // When - high confidence
        sut.entryDescription = "Покупка в Сільпо"
        try await Task.sleep(for: .seconds(0.8))

        // Then - should auto-apply
        #expect(sut.selectedCategory?.id == groceries.id)

        // Given - low confidence
        mockCategorizationService.setDescriptionRule("Магазин", category: transport, confidence: 0.45)
        sut.selectedCategory = nil

        // When - low confidence
        sut.entryDescription = "Магазин"
        try await Task.sleep(for: .seconds(0.8))

        // Then - should not auto-apply
        #expect(sut.selectedCategory == nil)
    }

    // MARK: - Recent Categories Tests

    @Test("Recent categories are derived from most recent transactions")
    func recentCategoriesBasedOnTransactions() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let groceries = MockCategory.makeGroceries()
        let taxi = MockCategory.makeTaxi()
        let cafe = MockCategory.makeCafe()

        mockRepository.accounts = [account]
        mockRepository.categories = [groceries, taxi, cafe]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 10, category: groceries, account: account, date: DateGenerator.daysAgo(3)),
            MockTransaction.makeExpense(amount: 20, category: taxi, account: account, date: DateGenerator.daysAgo(2)),
            MockTransaction.makeExpense(amount: 30, category: cafe, account: account, date: DateGenerator.daysAgo(1)),
            MockTransaction.makeExpense(amount: 40, category: groceries, account: account, date: DateGenerator.today())
        ]

        // When
        await sut.loadData()

        // Then
        #expect(sut.recentCategories.count == 3)
        #expect(sut.recentCategories.first?.id == groceries.id)
        #expect(sut.recentCategories[1].id == cafe.id)
        #expect(sut.recentCategories[2].id == taxi.id)
    }

    // MARK: - Filter Tests

    @Test("Filter by category updates filtered transactions")
    func filterByCategoryUpdatesFilteredTransactions() async throws {
        // Given
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()
        let account = MockAccount.makeDefault()

        mockRepository.categories = [groceries, transport]
        mockRepository.accounts = [account]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: groceries, account: account),
            MockTransaction.makeExpense(amount: 200, category: transport, account: account),
            MockTransaction.makeExpense(amount: 300, category: groceries, account: account)
        ]

        await sut.loadData()

        // When
        sut.filterCategory = groceries

        // Then
        #expect(sut.filteredTransactions.count == 2)
        #expect(sut.filteredTransactions.allSatisfy { $0.category?.id == groceries.id })
    }

    @Test("Filter by date range updates filtered transactions")
    func filterByDateRangeUpdatesFilteredTransactions() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let startDate = DateGenerator.daysAgo(10)
        let endDate = DateGenerator.daysAgo(5)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: DateGenerator.daysAgo(15)), // Before range
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.daysAgo(7)),  // In range
            MockTransaction.makeExpense(amount: 300, category: category, account: account, date: DateGenerator.daysAgo(3))   // After range
        ]

        await sut.loadData()

        // When
        sut.filterDateRange = startDate...endDate

        // Then
        #expect(sut.filteredTransactions.count == 1)
        #expect(sut.filteredTransactions.first?.amount == Decimal(200))
    }

    @Test("Search filters transactions correctly")
    func searchFiltersTransactionsCorrectly() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, description: "Покупка хліба"),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, description: "Покупка молока"),
            MockTransaction.makeExpense(amount: 300, category: category, account: account, description: "Таксі додому")
        ]

        await sut.loadData()

        // When
        sut.searchText = "молока"
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.filteredTransactions.count == 1)
        #expect(sut.filteredTransactions.first?.description.contains("молока") == true)
    }

    @Test("Combine filters work together correctly")
    func combineFiltersWorkTogether() async throws {
        // Given
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()
        let account = MockAccount.makeDefault()

        mockRepository.categories = [groceries, transport]
        mockRepository.accounts = [account]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: groceries, account: account, description: "Хліб"),
            MockTransaction.makeExpense(amount: 200, category: groceries, account: account, description: "Молоко"),
            MockTransaction.makeExpense(amount: 300, category: transport, account: account, description: "Таксі"),
            MockTransaction.makeExpense(amount: 400, category: groceries, account: account, description: "Сир")
        ]

        await sut.loadData()

        // When - apply multiple filters
        sut.filterCategory = groceries
        sut.searchText = "Молоко"
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.filteredTransactions.count == 1)
        #expect(sut.filteredTransactions.first?.description == "Молоко")
        #expect(sut.filteredTransactions.first?.category?.id == groceries.id)
    }

    // MARK: - Bulk Selection Tests

    @Test("Bulk selection adds to selected set")
    func bulkSelectionAddsToSelectedSet() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = MockTransaction.makeMultiple(count: 3, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = transactions

        await sut.loadData()

        sut.isBulkEditMode = true

        // When
        let firstTransaction = sut.transactions[0]
        let secondTransaction = sut.transactions[1]

        sut.toggleTransactionSelection(firstTransaction.id)
        sut.toggleTransactionSelection(secondTransaction.id)

        // Then
        #expect(sut.selectedTransactionIds.count == 2)
        #expect(sut.selectedTransactionIds.contains(firstTransaction.id))
        #expect(sut.selectedTransactionIds.contains(secondTransaction.id))
    }

    // MARK: - Clear Entry Tests

    @Test("Clear entry resets form but keeps type and account")
    func clearEntryResetsFormButKeepsTypeAndAccount() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        await sut.loadData()

        sut.entryAmount = "150.50"
        sut.entryDescription = "Test"
        sut.selectedCategory = category
        sut.selectedAccount = account
        sut.transactionType = .expense

        // When
        sut.clearEntry()

        // Then
        #expect(sut.entryAmount.isEmpty)
        #expect(sut.entryDescription.isEmpty)
        #expect(sut.selectedCategory == nil)
        #expect(sut.selectedAccount?.id == account.id) // Account preserved
        #expect(sut.transactionType == .expense) // Type preserved
    }

    // MARK: - Format Amount Tests

    @Test("Format amount returns correct UAH format")
    func formatAmountReturnsCorrectUAHFormat() async throws {
        // Given
        let amounts: [(Decimal, String)] = [
            (Decimal(100), "100,00 ₴"),
            (Decimal(1234.56), "1 234,56 ₴"),
            (Decimal(0.50), "0,50 ₴"),
            (Decimal(999999.99), "999 999,99 ₴")
        ]

        for (amount, expected) in amounts {
            // When
            let formatted = sut.formatAmount(amount)

            // Then
            #expect(formatted == expected, "Amount \(amount) should format to '\(expected)', got '\(formatted)'")
        }
    }

    // MARK: - Transaction Type Tests

    @Test("Transaction type changes affect entry behavior")
    func transactionTypeChangesAffectEntryBehavior() async throws {
        // Given
        let account1 = MockAccount.makeDefault()
        let account2 = MockAccount.makeSecondary()
        let category = MockCategory.makeSalary()

        mockRepository.accounts = [account1, account2]
        mockRepository.categories = [category]
        await sut.loadData()

        // When - expense type
        sut.transactionType = .expense
        #expect(sut.transactionType == .expense)

        // When - income type
        sut.transactionType = .income
        #expect(sut.transactionType == .income)

        // When - transfer type
        sut.transactionType = .transferIn
        #expect(sut.transactionType == .transferIn)
    }

    // MARK: - Delete Transaction Tests

    @Test("Delete transaction removes from list")
    func deleteTransactionRemovesFromList() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(amount: 100, category: category, account: account)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [transaction]

        await sut.loadData()

        let initialCount = sut.transactions.count

        // When
        await sut.deleteTransaction(transaction)
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(mockRepository.wasCalled("deleteTransaction(_:)"))
        #expect(sut.transactions.count == initialCount - 1)
        #expect(mockAnalyticsService.wasTransactionDeleted())
    }

    // MARK: - Bulk Operations Tests

    @Test("Bulk delete removes selected transactions")
    func bulkDeleteRemovesSelectedTransactions() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = MockTransaction.makeMultiple(count: 5, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = transactions

        await sut.loadData()

        sut.isBulkEditMode = true
        sut.toggleTransactionSelection(sut.transactions[0].id)
        sut.toggleTransactionSelection(sut.transactions[1].id)

        // When
        await sut.bulkDeleteSelectedTransactions()
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(mockRepository.wasCalled("performAtomicTransactionOperations(delete:update:create:)"))
        #expect(sut.selectedTransactionIds.isEmpty)
        #expect(!sut.isBulkEditMode)
    }

    @Test("Bulk categorize updates selected transactions")
    func bulkCategorizeUpdatesSelectedTransactions() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let oldCategory = MockCategory.makeGroceries()
        let newCategory = MockCategory.makeTransport()
        let transactions = MockTransaction.makeMultiple(count: 3, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = [oldCategory, newCategory]
        mockRepository.transactions = transactions

        await sut.loadData()

        sut.isBulkEditMode = true
        sut.toggleTransactionSelection(sut.transactions[0].id)
        sut.toggleTransactionSelection(sut.transactions[1].id)

        // When
        await sut.bulkCategorizeSelectedTransactions(to: newCategory)

        // Then
        #expect(mockRepository.wasCalled("performAtomicTransactionOperations(delete:update:create:)"))
        #expect(sut.selectedTransactionIds.isEmpty)
        #expect(!sut.isBulkEditMode)
    }

    // MARK: - Computed Properties Tests

    @Test("Current month total calculates correctly")
    func currentMonthTotalCalculatesCorrectly() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        let currentMonthStart = DateGenerator.startOfMonth()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, date: currentMonthStart),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, date: DateGenerator.today()),
            MockTransaction.makeExpense(amount: 300, category: category, account: account, date: DateGenerator.daysAgo(60)) // Last month
        ]

        await sut.loadData()

        // Then
        #expect(sut.currentMonthTotal == Decimal(300)) // Only current month
    }

    @Test("Has active filters returns true when filters applied")
    func hasActiveFiltersReturnsTrueWhenFiltersApplied() async throws {
        // Given
        let category = MockCategory.makeGroceries()
        mockRepository.categories = [category]
        await sut.loadData()

        // When - no filters
        #expect(!sut.hasActiveFilters)

        // When - category filter
        sut.filterCategory = category
        #expect(sut.hasActiveFilters)

        // When - search filter
        sut.filterCategory = nil
        sut.searchText = "test"
        #expect(sut.hasActiveFilters)
    }

    // MARK: - Extended Filter Pipeline Tests

    @Test("Filter by search text matches merchant name")
    func filterBySearchTextMatchesMerchant() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account, description: "Покупки", merchantName: "Сільпо"),
            MockTransaction.makeExpense(amount: 200, category: category, account: account, description: "Покупки", merchantName: "АТБ"),
            MockTransaction.makeExpense(amount: 300, category: category, account: account, description: "Поїздка", merchantName: "Uber")
        ]

        await sut.loadData()

        // When
        sut.searchText = "Сільпо"
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.filteredTransactions.count == 1)
    }

    @Test("Filter by transaction type filters correctly")
    func filterByTransactionType() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account),
            MockTransaction.makeIncome(amount: 5000, category: category, account: account),
            MockTransaction.makeExpense(amount: 200, category: category, account: account)
        ]

        await sut.loadData()

        // When - filter by expense type only
        sut.filterTypes = [.expense]
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.filteredTransactions.allSatisfy { $0.type == .expense })
    }

    @Test("Filter by account filters correctly")
    func filterByAccount() async throws {
        // Given
        let account1 = MockAccount.makeDefault()
        let account2 = MockAccount.makeSecondary()
        let category = MockCategory.makeGroceries()

        mockRepository.accounts = [account1, account2]
        mockRepository.categories = [category]
        mockRepository.transactions = [
            MockTransaction.makeExpense(amount: 100, category: category, account: account1),
            MockTransaction.makeExpense(amount: 200, category: category, account: account2),
            MockTransaction.makeExpense(amount: 300, category: category, account: account1)
        ]

        await sut.loadData()

        // When - filter by account1 only
        sut.filterAccounts = [account1]
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(sut.filteredTransactions.count == 2)
    }

    @Test("clearAllFilters resets all filter properties")
    func clearAllFiltersResetsAll() async throws {
        // Given
        let category = MockCategory.makeGroceries()
        let account = MockAccount.makeDefault()
        mockRepository.categories = [category]
        mockRepository.accounts = [account]
        await sut.loadData()

        sut.filterCategory = category
        sut.searchText = "test"
        sut.filterTypes = [.expense]
        sut.filterAccounts = [account]

        // When
        sut.clearAllFilters()

        // Then
        #expect(sut.filterCategory == nil)
        #expect(sut.searchText.isEmpty)
        #expect(sut.filterTypes.isEmpty)
        #expect(sut.filterAccounts.isEmpty)
        #expect(!sut.hasActiveFilters)
    }

    // MARK: - Split Transaction Tests

    @Test("createSplitTransaction creates parent with children")
    func createSplitTransactionCreatesParentWithChildren() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()

        mockRepository.accounts = [account]
        mockRepository.categories = [groceries, transport]
        await sut.loadData()

        let parentTransaction = MockTransaction.makeExpense(amount: 500, category: groceries, account: account)
        mockRepository.transactions = [parentTransaction]
        await sut.loadData()

        let splits = [
            SplitItem(amount: 300, category: groceries, description: "Groceries part"),
            SplitItem(amount: 200, category: transport, description: "Transport part")
        ]

        // When
        await sut.createSplitTransaction(from: parentTransaction, splits: splits, retainParent: false)

        // Then — split operations now use atomic batch operations
        #expect(mockRepository.wasCalled("performAtomicTransactionOperations(delete:update:create:)"))
    }

    @Test("Split expansion toggle works")
    func splitExpansionToggleWorks() async throws {
        // Given
        let transactionId = UUID()

        // When
        sut.toggleSplitExpansion(transactionId)

        // Then
        #expect(sut.isSplitExpanded(transactionId))

        // When - toggle again
        sut.toggleSplitExpansion(transactionId)

        // Then
        #expect(!sut.isSplitExpanded(transactionId))
    }

    // MARK: - Extended Bulk Operations Tests

    @Test("selectAllTransactions selects all filtered transactions")
    func selectAllTransactionsSelectsAll() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = MockTransaction.makeMultiple(count: 5, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = transactions

        await sut.loadData()
        sut.isBulkEditMode = true

        // When
        sut.selectAllTransactions()

        // Then
        #expect(sut.selectedTransactionIds.count == sut.filteredTransactions.count)
    }

    @Test("deselectAllTransactions clears selection")
    func deselectAllTransactionsClearsSelection() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = MockTransaction.makeMultiple(count: 3, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = transactions

        await sut.loadData()
        sut.isBulkEditMode = true
        sut.selectAllTransactions()

        // When
        sut.deselectAllTransactions()

        // Then
        #expect(sut.selectedTransactionIds.isEmpty)
    }

    @Test("Bulk delete with expanded split parent does not double-delete children")
    func bulkDeleteWithExpandedSplitParentNoDoubleDelete() async throws {
        // Given — a split parent with 2 children
        let account = MockAccount.makeDefault()
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()

        let parentId = UUID()
        let child1 = Transaction(
            id: UUID(), type: .expense, amount: 300,
            category: groceries, description: "Part 1",
            fromAccount: account, parentTransactionId: parentId
        )
        let child2 = Transaction(
            id: UUID(), type: .expense, amount: 200,
            category: transport, description: "Part 2",
            fromAccount: account, parentTransactionId: parentId
        )
        let parent = Transaction(
            id: parentId, type: .expense, amount: 0,
            description: "Split parent",
            fromAccount: account,
            splitTransactions: [child1, child2]
        )

        mockRepository.accounts = [account]
        mockRepository.categories = [groceries, transport]
        mockRepository.transactions = [parent]

        await sut.loadData()

        // Expand the split parent
        sut.toggleSplitExpansion(parentId)

        // Select all — should only select parent (filteredTransactions), not flattened children
        sut.isBulkEditMode = true
        sut.selectAllTransactions()

        // When
        await sut.bulkDeleteSelectedTransactions()
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then — no error was triggered, and delete was called
        // The parent delete cascades to children in deleteSingleOrSplitTransaction
        #expect(sut.error == nil)
        #expect(mockRepository.wasCalled("performAtomicTransactionOperations(delete:update:create:)"))
        #expect(sut.selectedTransactionIds.isEmpty)
        #expect(!sut.isBulkEditMode)
    }

    @Test("selectedTransactionCount returns correct count")
    func selectedTransactionCountReturnsCorrect() async throws {
        // Given
        let transactions = MockTransaction.makeMultiple(count: 5, dateRange: 30)
        mockRepository.transactions = transactions
        await sut.loadData()

        sut.isBulkEditMode = true
        sut.toggleTransactionSelection(sut.transactions[0].id)
        sut.toggleTransactionSelection(sut.transactions[1].id)
        sut.toggleTransactionSelection(sut.transactions[2].id)

        // Then
        #expect(sut.selectedTransactionCount == 3)
    }

    // MARK: - Entry Validation Extended Tests

    @Test("amountDecimal parses comma decimal '100,50'")
    func amountDecimalParsesCommaDecimal() async throws {
        // When
        sut.entryAmount = "100,50"

        // Then
        #expect(sut.amountDecimal != nil)
        if let amount = sut.amountDecimal {
            #expect(DecimalComparison.areEqual(amount, Decimal(string: "100.50")!))
        }
    }

    @Test("amountDecimal returns nil for empty string")
    func amountDecimalReturnsNilForEmpty() async throws {
        // When
        sut.entryAmount = ""

        // Then
        #expect(sut.amountDecimal == nil)
    }

    @Test("isValidEntry requires amount > 0 and account")
    func isValidEntryRequiresAmountAndAccount() async throws {
        // Given
        let account = MockAccount.makeDefault()
        mockRepository.accounts = [account]
        await sut.loadData()

        // When - no amount
        sut.entryAmount = ""
        sut.selectedAccount = account
        #expect(!sut.isValidEntry)

        // When - zero amount
        sut.entryAmount = "0"
        #expect(!sut.isValidEntry)

        // When - valid amount, no account
        sut.entryAmount = "100"
        sut.selectedAccount = nil
        #expect(!sut.isValidEntry)

        // When - valid amount and account
        sut.entryAmount = "100"
        sut.selectedAccount = account
        #expect(sut.isValidEntry)
    }

    @Test("addTransaction fails with invalid amount")
    func addTransactionFailsWithInvalidAmount() async throws {
        // Given
        let account = MockAccount.makeDefault()
        mockRepository.accounts = [account]
        await sut.loadData()

        sut.entryAmount = "abc"
        sut.selectedAccount = account

        // When
        await sut.addTransaction()

        // Then - should not create transaction
        #expect(!mockRepository.wasCalled("createTransaction(_:)"))
    }

    // MARK: - Update Transaction Tests

    @Test("updateTransaction calls repository update")
    func updateTransactionCallsRepositoryUpdate() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(amount: 100, category: category, account: account)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [transaction]
        await sut.loadData()

        var updated = transaction
        updated.amount = 200

        // When
        await sut.updateTransaction(updated)

        // Then
        #expect(mockRepository.wasCalled("updateTransaction(_:)"))
    }

    // MARK: - Category Operations Tests

    @Test("createCategory calls repository")
    func createCategoryCallsRepository() async throws {
        // When
        await sut.createCategory(name: "New Category", icon: "tag.fill", color: "#FF0000")

        // Then
        #expect(mockRepository.wasCalled("createCategory(_:)"))
    }

    // MARK: - Current Month Income Tests

    @Test("currentMonthIncome calculates correctly")
    func currentMonthIncomeCalculatesCorrectly() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let salary = MockCategory.makeSalary()

        mockRepository.accounts = [account]
        mockRepository.categories = [salary]
        mockRepository.transactions = [
            MockTransaction.makeIncome(amount: 25000, category: salary, account: account, date: DateGenerator.today()),
            MockTransaction.makeIncome(amount: 5000, category: salary, account: account, date: DateGenerator.today()),
            MockTransaction.makeIncome(amount: 10000, category: salary, account: account, date: DateGenerator.daysAgo(60)) // Last month
        ]

        await sut.loadData()

        // Then - only current month
        #expect(sut.currentMonthIncome == Decimal(30000))
    }

    // MARK: - Stale Data Regression Tests
    // These tests verify that after ViewModel mutations (update/delete),
    // the ViewModel's published arrays contain fresh data — the precondition
    // for detail views to refresh correctly via lookup-by-ID.

    @Test("After updateTransaction, transactions array contains updated amount")
    func afterUpdateTransactionsArrayContainsUpdatedAmount() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(amount: 100, category: category, account: account)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [transaction]
        await sut.loadData()

        #expect(sut.transactions.first(where: { $0.id == transaction.id })?.amount == Decimal(100))

        // When — update amount
        var updated = transaction
        updated.amount = 999

        await sut.updateTransaction(updated)
        await AsyncTestUtilities.wait(seconds: 0.1)

        // Then — ViewModel lookup by ID returns updated amount
        let refreshed = sut.transactions.first(where: { $0.id == transaction.id })
        #expect(refreshed != nil, "Transaction should still exist in ViewModel after update")
        #expect(refreshed?.amount == Decimal(999), "Amount should reflect the update")
    }

    @Test("After updateTransaction, transactions array contains updated description")
    func afterUpdateTransactionsArrayContainsUpdatedDescription() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(amount: 50, category: category, account: account)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [transaction]
        await sut.loadData()

        // When — update description
        var updated = transaction
        updated.description = "New description after edit"

        await sut.updateTransaction(updated)
        await AsyncTestUtilities.wait(seconds: 0.1)

        // Then
        let refreshed = sut.transactions.first(where: { $0.id == transaction.id })
        #expect(refreshed?.description == "New description after edit")
    }

    @Test("After updateTransaction, transactions array contains updated category")
    func afterUpdateTransactionsArrayContainsUpdatedCategory() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let groceries = MockCategory.makeGroceries()
        let transport = MockCategory.makeTransport()
        let transaction = MockTransaction.makeExpense(amount: 50, category: groceries, account: account)

        mockRepository.accounts = [account]
        mockRepository.categories = [groceries, transport]
        mockRepository.transactions = [transaction]
        await sut.loadData()

        #expect(sut.transactions.first(where: { $0.id == transaction.id })?.category?.id == groceries.id)

        // When — change category (category is let, so create new Transaction)
        let updated = Transaction(
            id: transaction.id,
            timestamp: transaction.timestamp,
            transactionDate: transaction.transactionDate,
            type: transaction.type,
            amount: transaction.amount,
            category: transport,
            description: transaction.description,
            fromAccount: transaction.fromAccount
        )

        await sut.updateTransaction(updated)
        await AsyncTestUtilities.wait(seconds: 0.1)

        // Then
        let refreshed = sut.transactions.first(where: { $0.id == transaction.id })
        #expect(refreshed?.category?.id == transport.id)
    }

    @Test("After updateTransaction, filteredTransactions also reflects changes")
    func afterUpdateFilteredTransactionsAlsoReflectsChanges() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(amount: 100, category: category, account: account)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [transaction]
        await sut.loadData()

        // When
        var updated = transaction
        updated.amount = 777

        await sut.updateTransaction(updated)
        await AsyncTestUtilities.wait(seconds: 0.1)

        // Then — filteredTransactions (used by List) also has fresh data
        let refreshed = sut.filteredTransactions.first(where: { $0.id == transaction.id })
        #expect(refreshed?.amount == Decimal(777))
    }

    @Test("After deleteTransaction, lookup by ID returns nil")
    func afterDeleteTransactionLookupByIdReturnsNil() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(amount: 100, category: category, account: account)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = [transaction]
        await sut.loadData()

        #expect(sut.transactions.first(where: { $0.id == transaction.id }) != nil)

        // When
        await sut.deleteTransaction(transaction)
        await AsyncTestUtilities.wait(seconds: 0.1)

        // Then
        #expect(sut.transactions.first(where: { $0.id == transaction.id }) == nil)
    }

    // MARK: - Delete Multiple Transactions Tests

    @Test("deleteTransactions removes multiple transactions")
    func deleteTransactionsRemovesMultiple() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transactions = MockTransaction.makeMultiple(count: 3, dateRange: 30)

        mockRepository.accounts = [account]
        mockRepository.categories = [category]
        mockRepository.transactions = transactions

        await sut.loadData()

        // When
        let toDelete = Array(sut.transactions.prefix(2))
        await sut.deleteTransactions(toDelete)
        await AsyncTestUtilities.wait(seconds: 0.2)

        // Then
        #expect(mockRepository.wasCalled("performAtomicTransactionOperations(delete:update:create:)"))
    }
}
