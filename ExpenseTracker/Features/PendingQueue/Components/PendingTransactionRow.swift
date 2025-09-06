//
//  PendingTransactionRow.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import SwiftUI

struct PendingTransactionRow: View {
    let pending: PendingTransaction
    let isProcessing: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(pending.descriptionText)
                    Text(pending.merchantName ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isProcessing {
                    ProgressView()
                } else {
                    Text(formatAmount(pending.amount))
                        .foregroundColor(pending.type == .expense ? .red : .green)
                }
            }
        }
        .disabled(isProcessing)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴0"
    }
}


