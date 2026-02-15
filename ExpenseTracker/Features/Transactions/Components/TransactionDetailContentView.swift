//
//  TransactionDetailContentView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 16.11.2025.
//

import SwiftUI

/// Unified transaction detail content view used across the app
/// Supports both sheet and navigation presentation modes
struct TransactionDetailContentView: View {
    let transaction: Transaction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.betweenSections) {
                // Hero Amount Section
                VStack(alignment: .center, spacing: Spacing.xs) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(transaction.type.symbol)
                            .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                            .foregroundColor(transaction.type == .expense ? .red : .green)
                        Text(formatAmount(transaction.amount))
                            .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                            .accessibilityLabel(String(localized: "accessibility.amount \(formatAmount(transaction.amount))"))
                    }
                    .frame(maxWidth: .infinity)

                    // Metadata pills
                    HStack(spacing: Spacing.betweenPills) {
                        // Transaction type pill
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: transaction.type == .expense ? "arrow.down" : "arrow.up")
                                .font(.system(size: 10))
                            Text(typeLocalizedName(transaction.type))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(transaction.type == .expense ? .red : .green)
                        .padding(.horizontal, Spacing.pillHorizontal)
                        .padding(.vertical, Spacing.pillVertical)
                        .background(
                            (transaction.type == .expense ? Color.red : Color.green)
                                .opacity(0.1)
                        )
                        .cornerRadius(12)

                        // Date pill
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(transaction.transactionDate, style: .date)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, Spacing.pillHorizontal)
                        .padding(.vertical, Spacing.pillVertical)
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                    }
                }

                Divider()

                // Description Section
                if !transaction.description.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(String(localized: "common.description"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(transaction.description)
                            .font(.body)
                    }

                    Divider()
                }

                // Category Section
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(String(localized: "common.category"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let category = transaction.category {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(hex: category.colorHex))
                            Text(category.displayName)
                                .font(.body)
                        }
                    } else {
                        Text(String(localized: "analytics.uncategorized"))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Account Section
                if transaction.fromAccount != nil || transaction.toAccount != nil {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text(String(localized: "common.account"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let fromAccount = transaction.fromAccount {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "edit.fromAccount"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(fromAccount.name)
                                    .font(.body)
                                Text(fromAccount.tag)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let toAccount = transaction.toAccount {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "edit.toAccount"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(toAccount.name)
                                    .font(.body)
                                Text(toAccount.tag)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Balance impact
                        if let account = transaction.fromAccount ?? transaction.toAccount {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(String(localized: "detail.balanceImpact"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text(String(localized: "detail.was"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatBalance(calculateBalanceBefore(for: account)))
                                        .font(.body)
                                }

                                HStack {
                                    Text(String(localized: "detail.became"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatBalance(calculateBalanceAfter(for: account)))
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }

                    Divider()
                }

                // Timestamps Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text(String(localized: "detail.time"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text(String(localized: "detail.transactionDate"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(transaction.transactionDate, style: .date)
                                    .font(.body)
                                Text(transaction.transactionDate, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text(String(localized: "detail.recordDate"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(transaction.timestamp, style: .date)
                                    .font(.body)
                                Text(transaction.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
            }
        }
        .accessibilityIdentifier("TransactionDetailView")
    }
                }
            }
            .padding(Spacing.paddingBase)
        }
    }

    // MARK: - Helper Methods

    private func typeLocalizedName(_ type: TransactionType) -> String {
        switch type {
        case .expense:
            return String(localized: "transactionType.expense")
        case .income:
            return String(localized: "transactionType.income")
        case .transferOut:
            return String(localized: "transactionType.transferOut")
        case .transferIn:
            return String(localized: "transactionType.transferIn")
        }
    }

    private func calculateBalanceBefore(for account: Account) -> Decimal {
        let impact = transactionImpact(for: account)
        return account.balance - impact
    }

    private func calculateBalanceAfter(for account: Account) -> Decimal {
        return account.balance
    }

    private func transactionImpact(for account: Account) -> Decimal {
        if transaction.fromAccount?.id == account.id {
            return -transaction.amount
        } else if transaction.toAccount?.id == account.id {
            return transaction.amount
        }
        return 0
    }

    private func formatBalance(_ amount: Decimal) -> String {
        Formatters.currencyStringUAH(amount: amount,
                                     minFractionDigits: 0,
                                     maxFractionDigits: 2)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let account = transaction.fromAccount ?? transaction.toAccount
        return Formatters.currencyString(
            amount: amount,
            currency: account?.currency ?? .uah,
            minFractionDigits: 0,
            maxFractionDigits: 2
        )
    }
}
