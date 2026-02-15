//
//  PendingTransactionsBadge.swift
//  ExpenseTracker
//

import SwiftUI

struct PendingTransactionsBadge: View {
    let count: Int
    let scale: CGFloat

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
            Text(String(localized: "pending.badge \(count)"))
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
        }
        .foregroundColor(.orange)
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(scale)
    }
}
