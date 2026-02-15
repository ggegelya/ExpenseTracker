//
//  TransactionRow.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import SwiftUI

struct TransactionRow : View {
    let transaction: Transaction
    let onTapSplit: (() -> Void)?

    init(transaction: Transaction, onTapSplit: (() -> Void)? = nil) {
        self.transaction = transaction
        self.onTapSplit = onTapSplit
    }

    var displayCategory: Category? {
        transaction.primaryCategory
    }

    var body: some View {
        HStack {
            // Split indicator icon (if applicable)
            if transaction.isSplitParent {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)
                    .font(.caption)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.caption)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let category = displayCategory {
                        HStack(spacing: 2) {
                            Image(systemName: category.icon)
                                .font(.caption2)
                            Text("#\(category.displayName)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if transaction.isSplitParent, let splitCount = transaction.splitTransactions?.count {
                        Text(String(localized: "split.count \(splitCount)"))
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(transaction.transactionDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(transaction.type == .expense ? .red : .green)

                // Show split categories mini visualization
                if transaction.isSplitParent, let splits = transaction.splitTransactions, !splits.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(splits.prefix(3)) { split in
                            if let category = split.category {
                                Circle()
                                    .fill(Color(hex: category.colorHex))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        if splits.count > 3 {
                            Text("+\(splits.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if transaction.isSplitParent {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            if transaction.isSplitParent {
                onTapSplit?()
            }
        }
    }
}
