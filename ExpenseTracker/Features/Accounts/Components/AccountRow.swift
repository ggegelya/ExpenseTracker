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
            // Account type icon - smaller and cleaner
            Image(systemName: account.accountType.icon)
                .font(.system(size: 16))
                .foregroundColor(account.accountType.swiftUIColor)
                .frame(width: 32, height: 32)
                .background(account.accountType.swiftUIColor.opacity(0.1))
                .clipShape(Circle())

            // Account info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.displayName)
                        .font(.system(size: 15))
                        .fontWeight(.medium)

                    if account.isDefault {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                    }
                }

                HStack(spacing: 6) {
                    Text(account.tag)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(account.accountType.localizedName)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Balance
            VStack(alignment: .trailing, spacing: 2) {
                Text(account.formattedBalance())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(account.balanceColor)

                if account.currency != .uah {
                    Text(account.currency.symbol)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

}
