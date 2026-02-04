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
            self.error = error
            analyticsService.trackError(error, context: "Loading accounts")
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
            self.error = error
            analyticsService.trackError(error, context: "Creating account")
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
                self.error = error
                analyticsService.trackError(error, context: "Updating account")
            }
        }
    }

    func deleteAccount(_ account: Account) async throws {
        do {
            let transactions = try await repository.getAllTransactions()
            if transactions.contains(where: { $0.fromAccount?.id == account.id || $0.toAccount?.id == account.id }) {
                self.error = AccountError.hasTransactions
                throw AccountError.hasTransactions
            }
            // Don't allow deleting the last account
            if accounts.count <= 1 {
                throw AccountError.cannotDeleteLastAccount
            }
            try await repository.deleteAccount(account)
        } catch let error as RepositoryError {
            if case .conflictDetected = error {
                throw AccountError.hasTransactions
            }
            self.error = error
            analyticsService.trackError(error, context: "Deleting account")
            throw error
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
