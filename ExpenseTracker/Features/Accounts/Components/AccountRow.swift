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
        HStack(spacing: 12) {
            // Account type icon with color
            ZStack {
                Circle()
                    .fill(accountTypeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: account.accountType.icon)
                    .font(.system(size: 18))
                    .foregroundColor(accountTypeColor)
            }

            // Account info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)

                    if account.isDefault {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                    }
                }

                HStack(spacing: 8) {
                    Text(account.tag)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(account.accountType.localizedName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Last transaction date
                if let lastDate = account.lastTransactionDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(timeAgo(from: lastDate))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text(account.formattedBalance())
                    .font(.headline)
                    .foregroundColor(balanceColor)

                if account.currency != .uah {
                    Text(account.currency.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var accountTypeColor: Color {
        switch account.accountType {
        case .cash: return .green
        case .card: return .blue
        case .savings: return .orange
        case .investment: return .purple
        }
    }

    private var balanceColor: Color {
        if account.balance > 0 {
            return .green
        } else if account.balance < 0 {
            return .red
        } else {
            return .primary
        }
    }

    // MARK: - Helper Methods

    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Сьогодні"
        } else if calendar.isDateInYesterday(date) {
            return "Вчора"
        } else if let days = calendar.dateComponents([.day], from: date, to: now).day {
            if days < 7 {
                return "\(days) дн. тому"
            } else if days < 30 {
                let weeks = days / 7
                return "\(weeks) тиж. тому"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "d MMM"
                return formatter.string(from: date)
            }
        }

        return ""
    }
}