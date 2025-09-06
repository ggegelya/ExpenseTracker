//
//  PendingTransactionView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct PendingTransactionsView: View {
    @EnvironmentObject var viewModel: PendingTransactionsViewModel
    @State private var selectedPending: PendingTransaction?
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.pendingTransactions.isEmpty {
                    EmptyStateView(
                        icon: "checkmark.circle.fill",
                        title: "Всі транзакції оброблені",
                        subtitle: "Нові транзакції з'являться тут після синхронізації з банком"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.pendingTransactions) { pending in
                        PendingTransactionRow(
                            pending: pending,
                            isProcessing: viewModel.processingIds.contains(pending.id)
                        ) {
                            selectedPending = pending
                        }
                    }
                }
            }
            .navigationTitle("Очікують обробки")
            .toolbar {
                if !viewModel.pendingTransactions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Обробити всі") {
                            Task {
                                await viewModel.processAllPending()
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedPending) { pending in
                ProcessPendingView(pending: pending)
            }
            .refreshable {
                await viewModel.loadPendingTransactions()
            }
        }
    }
}



