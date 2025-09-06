//
//  AccountRow.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//


import Foundation
import SwiftUI

struct AccountRow: View {
    let account: Account
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.headline)
                Text(account.tag)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(formatAmount(account.balance))
                .foregroundColor(account.balance >= 0 ? .primary : .red)
            if account.isDefault {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₴0"
    }
}