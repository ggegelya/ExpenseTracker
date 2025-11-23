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

    init() async throws {
        mockRepository = MockTransactionRepository()
        mockCategorizationService = MockCategorizationService()
        mockAnalyticsService = MockAnalyticsService()

        sut = TransactionViewModel(
            repository: mockRepository,
            categorizationService: mockCategorizationService,
            analyticsService: mockAnalyticsService
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

        // Then
        #expect(mockRepository.callCount(for: "deleteTransaction(_:)") == 2)
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
        #expect(mockRepository.callCount(for: "updateTransaction(_:)") == 2)
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
}

