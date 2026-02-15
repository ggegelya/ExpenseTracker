//
//  AccountsViewModel.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI
import Combine


@MainActor
final class AccountsViewModel: ObservableObject {
    private let repository: TransactionRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let errorHandler: ErrorHandlingServiceProtocol

    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var error: AppError?

    private var cancellables = Set<AnyCancellable>()

    init(repository: TransactionRepositoryProtocol,
         analyticsService: AnalyticsServiceProtocol,
         errorHandler: ErrorHandlingServiceProtocol) {
        self.repository = repository
        self.analyticsService = analyticsService
        self.errorHandler = errorHandler
        
        repository.accountsPublisher
            .sink { [weak self] accounts in
                self?.accounts = accounts
            }
            .store(in: &cancellables)
        
        Task { @MainActor in
            await loadAccounts()
        }
    }
    
    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            accounts = try await repository.getAllAccounts()
        } catch {
            self.error = errorHandler.handleAny(error, context: "Loading accounts")
        }
    }

    func createAccount(name: String, tag: String, initialBalance: Decimal = 0, accountType: AccountType = .card, currency: Currency = .uah, setAsDefault: Bool = false) async {
        let account = Account(
            id: UUID(),
            name: name,
            tag: tag,
            balance: initialBalance,
            isDefault: setAsDefault || accounts.isEmpty,
            accountType: accountType,
            currency: currency
        )

        do {
            _ = try await repository.createAccount(account)
            await loadAccounts()
        } catch {
            self.error = errorHandler.handleAny(error, context: "Creating account")
        }
    }

    func updateAccount(_ account: Account, silent: Bool = false) async {
        do {
            _ = try await repository.updateAccount(account)
            if !silent {
                await loadAccounts()
            }
        } catch {
            if !silent {
                self.error = errorHandler.handleAny(error, context: "Updating account")
            }
        }
    }

    func deleteAccount(_ account: Account) async throws {
        let transactions = try await repository.getAllTransactions()
        if transactions.contains(where: { $0.fromAccount?.id == account.id || $0.toAccount?.id == account.id }) {
            throw AccountError.hasTransactions
        }
        // Don't allow deleting the last account
        if accounts.count <= 1 {
            throw AccountError.cannotDeleteLastAccount
        }
        do {
            try await repository.deleteAccount(account)
        } catch let error as RepositoryError {
            if case .conflictDetected = error {
                throw AccountError.hasTransactions
            }
            throw error
        }
    }

    func setAsDefault(_ account: Account) async {
        var updatedAccount = account
        updatedAccount.isDefault = true
        await updateAccount(updatedAccount)
    }

    // Helper to check if tag is unique
    func isTagUnique(_ tag: String, excludingAccountId: UUID? = nil) -> Bool {
        !accounts.contains { account in
            account.tag.lowercased() == tag.lowercased() && account.id != excludingAccountId
        }
    }
}

// MARK: - Account Errors

enum AccountError: LocalizedError {
    case hasTransactions
    case cannotDeleteLastAccount

    var errorDescription: String? {
        switch self {
        case .hasTransactions:
            return String(localized: "error.account.hasTransactions")
        case .cannotDeleteLastAccount:
            return String(localized: "error.account.cannotDeleteLast")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .hasTransactions:
            return String(localized: "error.account.deleteTransactionsFirst")
        case .cannotDeleteLastAccount:
            return String(localized: "error.account.createAnotherFirst")
        }
    }
}
