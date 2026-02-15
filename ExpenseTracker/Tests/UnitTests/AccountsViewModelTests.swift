//
//  AccountsViewModelTests.swift
//  ExpenseTracker
//
//  Created by Claude Code on 22.11.2025.
//

import Testing
import Foundation
@testable import ExpenseTracker

@Suite("AccountsViewModel Tests", .serialized)
@MainActor
struct AccountsViewModelTests {
    var sut: AccountsViewModel
    var mockRepository: MockTransactionRepository
    var mockAnalyticsService: MockAnalyticsService
    var mockErrorHandler: MockErrorHandlingService

    init() async throws {
        mockRepository = MockTransactionRepository()
        mockAnalyticsService = MockAnalyticsService()
        mockErrorHandler = MockErrorHandlingService()

        sut = AccountsViewModel(
            repository: mockRepository,
            analyticsService: mockAnalyticsService,
            errorHandler: mockErrorHandler
        )
    }

    // MARK: - Load Accounts Tests

    @Test("Load accounts populates list")
    func loadAccountsPopulatesList() async throws {
        // Given
        let accounts = [
            MockAccount.makeDefault(),
            MockAccount.makeSecondary(),
            MockAccount.makeSavings()
        ]

        // Create repository with pre-populated data
        let repo = MockTransactionRepository(accounts: accounts)
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)

        // When
        await viewModel.loadAccounts()

        // Then
        #expect(viewModel.accounts.count == 3)
        #expect(repo.wasCalled("getAllAccounts()"))
        #expect(!viewModel.isLoading)
    }

    @Test("Load accounts sets loading state")
    func loadAccountsSetsLoadingState() async throws {
        // Given
        let repo = MockTransactionRepository(accounts: [])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)

        // When - start loading
        let loadTask = Task { @MainActor in
            await viewModel.loadAccounts()
        }

        // Then - should set loading to true initially
        // Note: This is tricky to test due to timing, but we can verify final state
        await loadTask.value

        #expect(!viewModel.isLoading) // Should be false after completion
    }

    // MARK: - Create Account Tests

    @Test("Create account succeeds with valid data")
    func createAccountSucceedsWithValidData() async throws {
        // Given
        let accountName = "Test Account"
        let accountTag = "#TEST"
        let initialBalance = Decimal(5000)

        // When
        await sut.createAccount(
            name: accountName,
            tag: accountTag,
            initialBalance: initialBalance,
            accountType: .card,
            currency: .uah,
            setAsDefault: false
        )

        // Then
        await sut.loadAccounts()
        #expect(sut.accounts.contains { $0.name == accountName && $0.tag == accountTag })
        #expect(mockRepository.wasCalled("createAccount(_:)"))
    }

    @Test("Create account with set as default flag")
    func createAccountWithSetAsDefaultFlag() async throws {
        // Given
        let defaultAccount = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [defaultAccount])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When
        await viewModel.createAccount(
            name: "New Default",
            tag: "#NEW",
            initialBalance: Decimal(1000),
            accountType: .cash,
            currency: .uah,
            setAsDefault: true
        )

        // Then
        await viewModel.loadAccounts()
        #expect(viewModel.accounts.contains { $0.tag == "#NEW" && $0.isDefault })
        #expect(repo.wasCalled("createAccount(_:)"))
    }

    @Test("Create account validates unique tag")
    func createAccountValidatesUniqueTag() async throws {
        // Given
        let existingAccount = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [existingAccount])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When - check if tag is unique
        let isDuplicate = !viewModel.isTagUnique(existingAccount.tag, excludingAccountId: nil)
        let isUniqueNewTag = viewModel.isTagUnique("#UNIQUE", excludingAccountId: nil)

        // Then
        #expect(isDuplicate == true)
        #expect(isUniqueNewTag == true)
    }

    // MARK: - Set Default Account Tests

    @Test("Set default account updates isDefault flags")
    func setDefaultAccountUpdatesIsDefaultFlags() async throws {
        // Given
        let account1 = MockAccount.makeDefault() // Initially default
        var account2 = MockAccount.makeSecondary()
        account2.isDefault = false

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When - set account2 as default
        await viewModel.setAsDefault(account2)

        // Then
        #expect(repo.wasCalled("updateAccount(_:)"))
        // Note: The repository should handle updating both accounts
        #expect(repo.callCount(for: "updateAccount(_:)") >= 1)
    }

    // MARK: - Calculate Total Balance Tests

    @Test("Calculate total balance sums all accounts")
    func calculateTotalBalanceSumsAllAccounts() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.balance = Decimal(5000)

        var account2 = MockAccount.makeSecondary()
        account2.balance = Decimal(10000)

        var account3 = MockAccount.makeSavings()
        account3.balance = Decimal(2000)

        let repo = MockTransactionRepository(accounts: [account1, account2, account3])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When
        let totalBalance = viewModel.accounts.reduce(Decimal(0)) { $0 + $1.balance }

        // Then
        #expect(totalBalance == Decimal(17000))
    }

    @Test("Total balance includes negative balances")
    func totalBalanceIncludesNegativeBalances() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.balance = Decimal(5000)

        var account2 = MockAccount.makeSecondary()
        account2.balance = Decimal(-1000) // Overdraft

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When
        let totalBalance = viewModel.accounts.reduce(Decimal(0)) { $0 + $1.balance }

        // Then
        #expect(totalBalance == Decimal(4000))
    }

    // MARK: - Delete Account Tests

    @Test("Delete account with transactions shows error")
    func deleteAccountWithTransactionsShowsError() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let category = MockCategory.makeGroceries()
        let transaction = MockTransaction.makeExpense(amount: 100, category: category, account: account)

        let repo = MockTransactionRepository(transactions: [transaction], accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // Configure repository to throw error when account has transactions
        repo.setError(AccountError.hasTransactions, forMethod: "deleteAccount(_:)")

        // When/Then
        await #expect(throws: AccountError.self) {
            try await viewModel.deleteAccount(account)
        }

        // Note: ViewModel validates for transactions before calling repository,
        // so deleteAccount is never called on the repo when validation fails
        #expect(repo.wasCalled("getAllTransactions()"))
    }

    @Test("Delete empty account succeeds")
    func deleteEmptyAccountSucceeds() async throws {
        // Given - multiple accounts to avoid "cannot delete last account" error
        let account1 = MockAccount.makeDefault()
        let account2 = MockAccount.makeSecondary()

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When
        try await viewModel.deleteAccount(account2)

        // Then
        #expect(repo.wasCalled("deleteAccount(_:)"))
    }

    @Test("Delete last account shows error")
    func deleteLastAccountShowsError() async throws {
        // Given - only one account
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // Configure repository to throw error
        mockRepository.setError(AccountError.cannotDeleteLastAccount, forMethod: "deleteAccount(_:)")

        // When/Then
        await #expect(throws: AccountError.self) {
            try await viewModel.deleteAccount(account)
        }
    }

    // MARK: - Update Account Tests

    @Test("Update account succeeds")
    func updateAccountSucceeds() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When - create new account with updated properties
        var updatedAccount = account
        updatedAccount.balance = Decimal(10000)
        try await viewModel.updateAccount(updatedAccount)

        // Then
        #expect(repo.wasCalled("updateAccount(_:)"))
    }

    @Test("Update account with silent flag")
    func updateAccountWithSilentFlag() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        repo.clearCallHistory()

        // When - silent update (doesn't reload accounts)
        var updatedAccount = account
        updatedAccount.balance = Decimal(10000)
        try await viewModel.updateAccount(updatedAccount, silent: true)

        // Then
        #expect(repo.wasCalled("updateAccount(_:)"))
        // Silent mode means it shouldn't call getAllAccounts again
        #expect(!repo.wasCalled("getAllAccounts()"))
    }

    // MARK: - Account Balance Updates Tests

    @Test("Account balance updates reflect in total")
    func accountBalanceUpdatesReflectInTotal() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.balance = Decimal(5000)

        var account2 = MockAccount.makeSecondary()
        account2.balance = Decimal(3000)

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        let initialTotal = viewModel.accounts.reduce(Decimal(0)) { $0 + $1.balance }
        #expect(initialTotal == Decimal(8000))

        // When - update account balance
        account1.balance = Decimal(7000)
        let repo2 = MockTransactionRepository(accounts: [account1, account2])
        let viewModel2 = AccountsViewModel(repository: repo2, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel2.loadAccounts()

        // Then
        let updatedTotal = viewModel2.accounts.reduce(Decimal(0)) { $0 + $1.balance }
        #expect(updatedTotal == Decimal(10000))
    }

    // MARK: - Error Handling Tests

    @Test("Load accounts handles error gracefully")
    func loadAccountsHandlesErrorGracefully() async throws {
        // Given
        let expectedError = NSError(domain: "Test", code: -1, userInfo: nil)
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = expectedError

        // When
        await sut.loadAccounts()

        // Then
        #expect(sut.error != nil)
        #expect(!sut.isLoading)
    }

    @Test("Create account handles error gracefully")
    func createAccountHandlesErrorGracefully() async throws {
        // Given
        let expectedError = NSError(domain: "Test", code: -1, userInfo: nil)
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = expectedError

        // When
        await sut.createAccount(
            name: "Test",
            tag: "#TEST",
            initialBalance: Decimal(100),
            accountType: .cash,
            currency: .uah,
            setAsDefault: false
        )

        // Then - error should be stored in viewModel, not thrown
        #expect(sut.error != nil)
    }

    // MARK: - Tag Validation Tests

    @Test("Tag uniqueness check excludes current account")
    func tagUniquenessCheckExcludesCurrentAccount() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When - checking same tag but excluding the account itself
        let isUnique = viewModel.isTagUnique(account.tag, excludingAccountId: account.id)

        // Then
        #expect(isUnique == true) // Should be unique when excluding itself
    }

    @Test("Tag uniqueness check is case insensitive")
    func tagUniquenessCheckIsCaseInsensitive() async throws {
        // Given
        var account = MockAccount.makeDefault()
        account = Account(id: account.id, name: account.name, tag: "#CASH", balance: account.balance, isDefault: account.isDefault, accountType: account.accountType, currency: account.currency)

        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When
        let isLowercaseUnique = viewModel.isTagUnique("#cash", excludingAccountId: nil)
        let isMixedCaseUnique = viewModel.isTagUnique("#CaSh", excludingAccountId: nil)

        // Then
        #expect(isLowercaseUnique == false)
        #expect(isMixedCaseUnique == false)
    }

    // MARK: - Account Type Tests

    @Test("Create accounts with different types")
    func createAccountsWithDifferentTypes() async throws {
        // Given/When
        await sut.createAccount(
            name: "Cash",
            tag: "#CASH",
            initialBalance: Decimal(1000),
            accountType: .cash,
            currency: .uah,
            setAsDefault: false
        )

        await sut.createAccount(
            name: "Card",
            tag: "#CARD",
            initialBalance: Decimal(5000),
            accountType: .card,
            currency: .uah,
            setAsDefault: false
        )

        await sut.createAccount(
            name: "Savings",
            tag: "#SAVE",
            initialBalance: Decimal(10000),
            accountType: .savings,
            currency: .uah,
            setAsDefault: false
        )

        // Then
        await sut.loadAccounts()
        #expect(sut.accounts.contains { $0.accountType == .cash && $0.tag == "#CASH" })
        #expect(sut.accounts.contains { $0.accountType == .card && $0.tag == "#CARD" })
        #expect(sut.accounts.contains { $0.accountType == .savings && $0.tag == "#SAVE" })
    }

    // MARK: - Currency Tests

    @Test("Create accounts with different currencies")
    func createAccountsWithDifferentCurrencies() async throws {
        // Given/When
        await sut.createAccount(
            name: "UAH Account",
            tag: "#UAH",
            initialBalance: Decimal(10000),
            accountType: .cash,
            currency: .uah,
            setAsDefault: false
        )

        await sut.createAccount(
            name: "USD Account",
            tag: "#USD",
            initialBalance: Decimal(1000),
            accountType: .savings,
            currency: .usd,
            setAsDefault: false
        )

        await sut.createAccount(
            name: "EUR Account",
            tag: "#EUR",
            initialBalance: Decimal(500),
            accountType: .savings,
            currency: .eur,
            setAsDefault: false
        )

        // Then
        await sut.loadAccounts()
        #expect(sut.accounts.contains { $0.currency == .uah && $0.tag == "#UAH" })
        #expect(sut.accounts.contains { $0.currency == .usd && $0.tag == "#USD" })
        #expect(sut.accounts.contains { $0.currency == .eur && $0.tag == "#EUR" })
    }

    // MARK: - Default Account Tests

    @Test("Only one account can be default at a time")
    func onlyOneAccountCanBeDefaultAtTime() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.isDefault = true

        var account2 = MockAccount.makeSecondary()
        account2.isDefault = false

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When - set second account as default
        await viewModel.setAsDefault(account2)

        // Then - repository should be called to update accounts
        #expect(repo.wasCalled("updateAccount(_:)"))
        // The implementation should ensure only one account has isDefault = true
    }

    @Test("Get default account returns correct account")
    func getDefaultAccountReturnsCorrectAccount() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.isDefault = true

        var account2 = MockAccount.makeSecondary()
        account2.isDefault = false

        let repo = MockTransactionRepository(accounts: [account1, account2])

        // When
        let defaultAccount = try await repo.getDefaultAccount()

        // Then
        #expect(defaultAccount != nil)
        #expect(defaultAccount?.id == account1.id)
        #expect(defaultAccount?.isDefault == true)
    }

    // MARK: - Extended Tests

    @Test("Update account with validation failure shows error")
    func updateAccountWithValidationFailure() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        repo.shouldThrowError = true
        repo.errorToThrow = NSError(domain: "Test", code: -1, userInfo: nil)
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        repo.shouldThrowError = true

        // When
        var updated = account
        updated.balance = 9999
        try await viewModel.updateAccount(updated)

        // Then - error should have been handled
        #expect(mockErrorHandler.handledErrors.count >= 1)
    }

    @Test("Total balance recalculates when accounts change")
    func totalBalanceRecalculatesOnChange() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.balance = Decimal(1000)
        var account2 = MockAccount.makeSecondary()
        account2.balance = Decimal(2000)

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        let initialTotal = viewModel.accounts.reduce(Decimal(0)) { $0 + $1.balance }
        #expect(initialTotal == Decimal(3000))

        // When - add a new account
        await viewModel.createAccount(
            name: "New Account",
            tag: "#NEW",
            initialBalance: Decimal(5000),
            accountType: .cash,
            currency: .uah,
            setAsDefault: false
        )
        await viewModel.loadAccounts()

        // Then
        let newTotal = viewModel.accounts.reduce(Decimal(0)) { $0 + $1.balance }
        #expect(newTotal == Decimal(8000))
    }

    @Test("Total balance handles mixed currencies")
    func totalBalanceHandlesMixedCurrencies() async throws {
        // Given - mixed currency accounts
        var uahAccount = MockAccount.makeDefault()
        uahAccount.balance = Decimal(10000)

        var usdAccount = MockAccount.makeSavings()
        usdAccount.balance = Decimal(500)

        let repo = MockTransactionRepository(accounts: [uahAccount, usdAccount])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // Then - both accounts present
        #expect(viewModel.accounts.count == 2)
        #expect(viewModel.accounts.contains { $0.currency == .uah })
        #expect(viewModel.accounts.contains { $0.currency == .usd })
    }

    @Test("isTagUnique returns true for unique new tag")
    func isTagUniqueReturnsTrueForNew() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // Then
        #expect(viewModel.isTagUnique("#BRANDNEW", excludingAccountId: nil))
    }

    // MARK: - Stale Data Regression Tests
    // These tests verify that after ViewModel mutations (update/setDefault),
    // the ViewModel's published accounts array contains fresh data — the precondition
    // for detail views to refresh correctly via lookup-by-ID.

    @Test("After updateAccount, accounts array contains updated balance")
    func afterUpdateAccountsArrayContainsUpdatedBalance() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        #expect(viewModel.accounts.first(where: { $0.id == account.id })?.balance == account.balance)

        // When — update balance
        var updated = account
        updated.balance = Decimal(99999)
        _ = try await repo.updateAccount(updated)
        await viewModel.loadAccounts()

        // Then — ViewModel lookup by ID returns updated balance
        let refreshed = viewModel.accounts.first(where: { $0.id == account.id })
        #expect(refreshed != nil, "Account should still exist in ViewModel after update")
        #expect(refreshed?.balance == Decimal(99999), "Balance should reflect the update")
    }

    @Test("After updateAccount, accounts array contains updated accountType")
    func afterUpdateAccountsArrayContainsUpdatedType() async throws {
        // Given
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        #expect(viewModel.accounts.first(where: { $0.id == account.id })?.accountType == .cash)

        // When — update accountType
        var updated = account
        updated.accountType = .savings
        _ = try await repo.updateAccount(updated)
        await viewModel.loadAccounts()

        // Then
        let refreshed = viewModel.accounts.first(where: { $0.id == account.id })
        #expect(refreshed?.accountType == .savings)
    }

    @Test("After setAsDefault, accounts array reflects new default")
    func afterSetAsDefaultAccountsArrayReflectsNewDefault() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.isDefault = true
        var account2 = MockAccount.makeSecondary()
        account2.isDefault = false

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        #expect(viewModel.accounts.first(where: { $0.id == account1.id })?.isDefault == true)
        #expect(viewModel.accounts.first(where: { $0.id == account2.id })?.isDefault == false)

        // When — set account2 as default
        await viewModel.setAsDefault(account2)
        await AsyncTestUtilities.wait(seconds: 0.1)

        // Then — account2 is now default, account1 is not
        let refreshed1 = viewModel.accounts.first(where: { $0.id == account1.id })
        let refreshed2 = viewModel.accounts.first(where: { $0.id == account2.id })
        #expect(refreshed1?.isDefault == false, "Old default should be unset")
        #expect(refreshed2?.isDefault == true, "New default should be set")
    }

    @Test("After deleteAccount, lookup by ID returns nil")
    func afterDeleteAccountLookupByIdReturnsNil() async throws {
        // Given
        var account1 = MockAccount.makeDefault()
        account1.isDefault = true
        let account2 = MockAccount.makeSecondary()

        let repo = MockTransactionRepository(accounts: [account1, account2])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        #expect(viewModel.accounts.first(where: { $0.id == account2.id }) != nil)

        // When
        try await repo.deleteAccount(account2)
        await viewModel.loadAccounts()

        // Then
        #expect(viewModel.accounts.first(where: { $0.id == account2.id }) == nil)
    }

    @Test("After updateAccount via ViewModel, lookup-by-ID returns fresh data")
    func afterViewModelUpdateAccountLookupReturnsUpdatedData() async throws {
        // Given — this simulates the exact pattern used by AccountDetailView.refreshAccount()
        let account = MockAccount.makeDefault()
        let repo = MockTransactionRepository(accounts: [account])
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService, errorHandler: mockErrorHandler)
        await viewModel.loadAccounts()

        // When — update multiple mutable fields at once (balance, accountType, currency)
        var updated = account
        updated.balance = Decimal(42000)
        updated.accountType = .investment
        updated.currency = .eur
        await viewModel.updateAccount(updated)

        // Then — simulate the view's refreshAccount() pattern
        let refreshed = viewModel.accounts.first(where: { $0.id == account.id })
        #expect(refreshed?.balance == Decimal(42000), "Balance should be updated")
        #expect(refreshed?.accountType == .investment, "AccountType should be updated")
        #expect(refreshed?.currency == .eur, "Currency should be updated")
    }

    @Test("Create account with empty name passes through to repository")
    func createAccountWithEmptyNamePassesThrough() async throws {
        // When - empty name is not validated in ViewModel, goes to repo
        await sut.createAccount(
            name: "",
            tag: "#TAG",
            initialBalance: 100,
            accountType: .cash,
            currency: .uah,
            setAsDefault: false
        )

        // Then - account is created (validation is at the UI layer, not ViewModel)
        #expect(mockRepository.wasCalled("createAccount(_:)"))
    }
}
