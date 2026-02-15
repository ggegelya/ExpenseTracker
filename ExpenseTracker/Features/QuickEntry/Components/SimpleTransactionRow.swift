//
//  SimpleTransactionRow.swift
//  ExpenseTracker
//

import SwiftUI

struct SimpleTransactionRow: View {
    let transaction: Transaction

    var displayCategory: Category? {
        transaction.primaryCategory
    }

    private var plainAmountString: String {
        Formatters.decimalString(
            transaction.effectiveAmount,
            minFractionDigits: 0,
            maxFractionDigits: 2,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon and info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.system(size: 15))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let category = displayCategory {
                        Image(systemName: category.icon)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: category.colorHex))

                        Text(category.displayName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Text(transaction.transactionDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }

            Spacer()

            // Amount with color coding
            Text(transaction.formattedAmount)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(transaction.type == .expense ? .red : .green)
            if TestingConfiguration.isRunningTests {
                Text(plainAmountString)
                    .font(.system(size: 1))
                    .opacity(0.01)
                    .frame(width: 1, height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
