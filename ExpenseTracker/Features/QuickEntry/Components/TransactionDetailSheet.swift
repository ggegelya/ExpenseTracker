//
//  TransactionDetailSheet.swift
//  ExpenseTracker
//

import SwiftUI

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: TransactionViewModel

    var body: some View {
        NavigationStack {
            TransactionDetailContentView(transaction: transaction)
            .navigationTitle(String(localized: "transactionDetail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "common.delete")) {
                        Task { @MainActor in
                            await viewModel.deleteTransaction(transaction)
                            dismiss()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}
