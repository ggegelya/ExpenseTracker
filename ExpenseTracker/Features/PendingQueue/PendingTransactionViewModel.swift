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
    @Published var learningNotification: LearningNotification?
    @Published var showLearningToast = false

    var pendingCount: Int {
        pendingTransactions.count
    }

    var hasPendingTransactions: Bool {
        !pendingTransactions.isEmpty
    }

    private var isActive = false
    private var pollingTask: Task<Void, Never>?
    private var toastDismissTask: Task<Void, Never>?

    struct LearningNotification: Identifiable {
        let id = UUID()
        let merchantName: String
        let categoryName: String
    }
    
    init(repository: TransactionRepositoryProtocol,
         categorizationService: CategorizationServiceProtocol,
         analyticsService: AnalyticsServiceProtocol) {
        self.repository = repository
        self.categorizationService = categorizationService
        self.analyticsService = analyticsService
        
        startMonitoring()
    }
    
    deinit {
        pollingTask?.cancel()
        toastDismissTask?.cancel()
    }
    
    func startMonitoring() {
        guard !isActive else { return }
        isActive = true
        
        pollingTask = Task { @MainActor in
            await loadPendingTransactions()
            
            while !Task.isCancelled && isActive {
                try? await Task.sleep(for: .seconds(120))
                if !Task.isCancelled && isActive {
                    await loadPendingTransactions()
                }
            }
        }
    }
    
    func stopMonitoring() {
        isActive = false
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    func pauseMonitoring() {
        isActive = false
    }
    
    func resumeMonitoring() {
        isActive = true
        if pollingTask?.isCancelled != false {
            startMonitoring()
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
                                   description: String? = nil,
                                   shouldLearn: Bool = true) async {
        processingIds.insert(pending.id)
        defer { processingIds.remove(pending.id) }

        let finalCategory = category ?? pending.suggestedCategory
        let finalDescription = description ?? pending.descriptionText

        guard let finalCategory = finalCategory else {
            self.error = RepositoryError.invalidData("Category is required")
            return
        }

        let transaction = Transaction(
            transactionDate: pending.transactionDate,
            type: pending.type,
            amount: pending.amount,
            category: finalCategory,
            description: finalDescription,
            merchantName: pending.merchantName,
            fromAccount: pending.type == .expense ? pending.account : nil,
            toAccount: pending.type == .income ? pending.account : nil
        )

        do {
            try await repository.processPendingTransaction(pending.id, as: transaction)

            // Track analytics for transaction creation
            analyticsService.trackEvent(.transactionAdded(
                amount: transaction.amount,
                category: transaction.category?.id.uuidString
            ))

            // Learn from the categorization if requested
            if shouldLearn,
               let merchantName = pending.merchantName {
                await categorizationService.learnFromCorrection(
                    description: pending.descriptionText,
                    merchantName: pending.merchantName,
                    correctCategory: finalCategory
                )

                // Show learning notification only if category was corrected
                if finalCategory.id != pending.suggestedCategory?.id {
                    learningNotification = LearningNotification(
                        merchantName: merchantName,
                        categoryName: finalCategory.name
                    )
                    showLearningToast = true

                    // Auto-hide after 3 seconds (cancel previous dismiss task)
                    toastDismissTask?.cancel()
                    toastDismissTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        showLearningToast = false
                    }
                }
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
