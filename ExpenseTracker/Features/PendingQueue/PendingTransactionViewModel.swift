//
//  PendingTransactionViewModel.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI
import Combine


@MainActor
final class PendingTransactionsViewModel: ObservableObject {
    private let repository: TransactionRepositoryProtocol
    private let categorizationService: CategorizationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    @Published var pendingTransactions: [PendingTransaction] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var processingIds: Set<UUID> = []
    
    init(repository: TransactionRepositoryProtocol,
         categorizationService: CategorizationServiceProtocol,
         analyticsService: AnalyticsServiceProtocol) {
        self.repository = repository
        self.categorizationService = categorizationService
        self.analyticsService = analyticsService
        
        Task {
            await loadPendingTransactions()
        }
    }
    
    func loadPendingTransactions(for account: Account? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            pendingTransactions = try await repository.getPendingTransactions(for: account)
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Loading pending transactions")
        }
    }
    
    func processPendingTransaction(_ pending: PendingTransaction,
                                  with category: Category? = nil,
                                  description: String? = nil) async {
        processingIds.insert(pending.id)
        defer { processingIds.remove(pending.id) }
        
        let finalCategory = category ?? pending.suggestedCategory
        let finalDescription = description ?? pending.descriptionText
        
        let transaction = Transaction(
            transactionDate: pending.transactionDate,
            type: pending.type,
            amount: pending.amount,
            category: finalCategory,
            description: finalDescription,
            fromAccount: pending.type == .expense ? pending.account : nil,
            toAccount: pending.type == .income ? pending.account : nil
        )
        
        do {
            try await repository.processPendingTransaction(pending.id, as: transaction)
            
            // Learn from the categorization if it was corrected
            if let finalCategory = finalCategory,
               finalCategory.id != pending.suggestedCategory?.id {
                await categorizationService.learnFromCorrection(
                    description: pending.descriptionText,
                    merchantName: pending.merchantName,
                    correctCategory: finalCategory
                )
            }
            
            await loadPendingTransactions()
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Processing pending transaction")
        }
    }
    
    func dismissPendingTransaction(_ pending: PendingTransaction) async {
        processingIds.insert(pending.id)
        defer { processingIds.remove(pending.id) }
        
        do {
            try await repository.dismissPendingTransaction(pending.id)
            await loadPendingTransactions()
        } catch {
            self.error = error
            analyticsService.trackError(error, context: "Dismissing pending transaction")
        }
    }
    
    func processAllPending() async {
        for pending in pendingTransactions {
            await processPendingTransaction(pending)
        }
    }
}
