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
    
    func createAccount(name: String, tag: String, initialBalance: Decimal = 0) async {
        let account = Account(
            id: UUID(),
            name: name,
            tag: tag,
            balance: initialBalance,
            isDefault: accounts.isEmpty
        )
        
        do {
            _ = try await repository.createAccount(account)
            await loadAccounts()
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Creating account")
        }
    }
    
    func updateAccount(_ account: Account) async {
        do {
            _ = try await repository.updateAccount(account)
            await loadAccounts()
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Updating account")
        }
    }
    
    func deleteAccount(_ account: Account) async {
        do {
            try await repository.deleteAccount(account)
            await loadAccounts()
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Deleting account")
        }
    }
    
    func setAsDefault(_ account: Account) async {
        var updatedAccount = account
        updatedAccount.isDefault = true
        await updateAccount(updatedAccount)
    }
}
