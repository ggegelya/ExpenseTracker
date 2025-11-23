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
    
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: TransactionRepositoryProtocol,
         analyticsService: AnalyticsServiceProtocol) {
        self.repository = repository
        self.analyticsService = analyticsService
        
        repository.accountsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] accounts in
                self?.accounts = accounts
            }
            .store(in: &cancellables)
        
        Task {
            await loadAccounts()
        }
    }
    
    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            accounts = try await repository.getAllAccounts()
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Loading accounts")
        }
    }
    
    func createAccount(name: String, tag: String, initialBalance: Decimal = 0, accountType: AccountType = .card, currency: Currency = .uah, setAsDefault: Bool = false) async {
        // If setting as default, unset other defaults first
        if setAsDefault {
            for var account in accounts where account.isDefault {
                account.isDefault = false
                await updateAccount(account, silent: true)
            }
        }

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
            self.error = error
            analyticsService.trackError(error, context: "Creating account")
        }
    }
    
    func updateAccount(_ account: Account, silent: Bool = false) async {
        // If setting as default, unset other defaults first
        if account.isDefault {
            for var otherAccount in accounts where otherAccount.isDefault && otherAccount.id != account.id {
                otherAccount.isDefault = false
                do {
                    _ = try await repository.updateAccount(otherAccount)
                } catch {
                    if !silent {
                        self.error = error
                        analyticsService.trackError(error, context: "Unsetting default account")
                    }
                }
            }
        }

        do {
            _ = try await repository.updateAccount(account)
            if !silent {
                await loadAccounts()
            }
        } catch {
            if !silent {
                self.error = error
                analyticsService.trackError(error, context: "Updating account")
            }
        }
    }

    func deleteAccount(_ account: Account) async throws {
        // Check if account has transactions
        let transactions = try await repository.getAllTransactions()
        let hasTransactions = transactions.contains { transaction in
            transaction.fromAccount?.id == account.id || transaction.toAccount?.id == account.id
        }

        if hasTransactions {
            throw AccountError.hasTransactions
        }

        // Don't allow deleting the last account
        if accounts.count <= 1 {
            throw AccountError.cannotDeleteLastAccount
        }

        do {
            try await repository.deleteAccount(account)
            await loadAccounts()
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Deleting account")
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
            return "Неможливо видалити рахунок з транзакціями"
        case .cannotDeleteLastAccount:
            return "Неможливо видалити останній рахунок"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .hasTransactions:
            return "Спершу видаліть всі транзакції цього рахунку"
        case .cannotDeleteLastAccount:
            return "Створіть інший рахунок перед видаленням цього"
        }
    }
}
