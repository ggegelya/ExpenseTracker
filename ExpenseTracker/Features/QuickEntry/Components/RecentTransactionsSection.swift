//
//  RecentTransactionsSection.swift
//  ExpenseTracker
//

import SwiftUI

struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    let totalCount: Int
    @EnvironmentObject private var viewModel: TransactionViewModel
    @State private var showAllTransactions = false
    @State private var selectedTransaction: Transaction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(String(localized: "quickEntry.recent"))
                    .font(.system(size: 22, weight: .semibold))
                Spacer()

                // Only show "Всі" link if there are more than 3 items
                if totalCount > 3 {
                    Button {
                        showAllTransactions = true
                    } label: {
                        Text(String(localized: "common.all"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Use List for swipe actions
            List {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                    VStack(spacing: 0) {
                        SimpleTransactionRow(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTransaction = transaction
                            }

                        // Add divider except for last item
                        if index < transactions.count - 1 {
                            Divider()
                                .background(Color(.systemGray4))
                                .padding(.leading, 20)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteTransaction(transaction)
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            duplicateTransaction(transaction)
                        } label: {
                            Label(String(localized: "common.duplicate"), systemImage: "doc.on.doc")
                        }
                        .tint(.blue)
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: CGFloat(transactions.count * 60))
            .scrollDisabled(true)
        }
        .sheet(isPresented: $showAllTransactions) {
            TransactionListView()
                .environmentObject(viewModel)
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailSheet(transaction: transaction)
                .environmentObject(viewModel)
        }
    }

    private func deleteTransaction(_ transaction: Transaction) {
        Task { @MainActor in
            await viewModel.deleteTransaction(transaction)
        }
    }

    private func duplicateTransaction(_ transaction: Transaction) {
        // Pre-fill the form with transaction data
        viewModel.entryAmount = String(format: "%.2f", NSDecimalNumber(decimal: transaction.amount).doubleValue)
        viewModel.transactionType = transaction.type
        viewModel.selectedCategory = transaction.category
        viewModel.entryDescription = transaction.description
        viewModel.selectedAccount = transaction.fromAccount ?? transaction.toAccount
        viewModel.selectedDate = transaction.transactionDate
    }
}
