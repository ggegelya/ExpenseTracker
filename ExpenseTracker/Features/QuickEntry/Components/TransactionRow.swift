//
//  TransactionRow.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import SwiftUI

struct TransactionRow : View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.caption)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let category = transaction.category {
                        Text("#\(category.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(transaction.transactionDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            
            }
            
            Spacer()
            
            Text(transaction.formattedAmount)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}
