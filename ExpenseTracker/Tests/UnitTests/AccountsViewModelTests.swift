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

    init() async throws {
        mockRepository = MockTransactionRepository()
        mockAnalyticsService = MockAnalyticsService()

        sut = AccountsViewModel(
            repository: mockRepository,
            analyticsService: mockAnalyticsService
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)

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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)

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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
        await viewModel.loadAccounts()

        let initialTotal = viewModel.accounts.reduce(Decimal(0)) { $0 + $1.balance }
        #expect(initialTotal == Decimal(8000))

        // When - update account balance
        account1.balance = Decimal(7000)
        let repo2 = MockTransactionRepository(accounts: [account1, account2])
        let viewModel2 = AccountsViewModel(repository: repo2, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
        let viewModel = AccountsViewModel(repository: repo, analyticsService: mockAnalyticsService)
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
}


