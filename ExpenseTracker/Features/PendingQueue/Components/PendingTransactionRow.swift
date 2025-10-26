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
    let onAccept: (() -> Void)?
    let onDismiss: (() -> Void)?

    @State private var offset: CGFloat = 0
    @State private var showingFullContent = false

    private let swipeThreshold: CGFloat = 100
    private let acceptColor = Color.green
    private let dismissColor = Color.red

    init(
        pending: PendingTransaction,
        isProcessing: Bool,
        onTap: @escaping () -> Void,
        onAccept: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.pending = pending
        self.isProcessing = isProcessing
        self.onTap = onTap
        self.onAccept = onAccept
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // Background swipe actions
            HStack {
                // Left swipe action (Dismiss)
                if offset < 0 {
                    Spacer()
                    dismissBackground
                }
                // Right swipe action (Accept)
                if offset > 0 {
                    acceptBackground
                    Spacer()
                }
            }

            // Main content
            Button(action: onTap) {
                rowContent
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Only allow swipe if actions are provided
                        let translation = gesture.translation.width
                        if translation > 0 && onAccept != nil {
                            offset = min(translation, 150)
                        } else if translation < 0 && onDismiss != nil {
                            offset = max(translation, -150)
                        }
                    }
                    .onEnded { gesture in
                        let translation = gesture.translation.width

                        // Right swipe - Accept
                        if translation > swipeThreshold && onAccept != nil {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            onAccept?()
                        }
                        // Left swipe - Dismiss
                        else if translation < -swipeThreshold && onDismiss != nil {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                            onDismiss?()
                        }
                        // Reset
                        else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                offset = 0
                            }
                        }
                    }
            )
            .disabled(isProcessing)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            // Category indicator
            if let category = pending.suggestedCategory {
                VStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Color(hex: category.colorHex))
                        .frame(width: 40, height: 40)
                        .background(Color(hex: category.colorHex).opacity(0.2))
                        .clipShape(Circle())
                }
            } else {
                VStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Circle())
                }
            }

            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                Text(pending.descriptionText)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let merchant = pending.merchantName {
                        Text(merchant)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let category = pending.suggestedCategory {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text(category.name.capitalized)
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Amount and status
            VStack(alignment: .trailing, spacing: 4) {
                if isProcessing {
                    ProgressView()
                } else {
                    Text(formatAmount(pending.amount))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(pending.type == .expense ? .red : .green)

                    Text(formatDate(pending.transactionDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var acceptBackground: some View {
        HStack {
            VStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                Text("Прийняти")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(width: 80)
            .padding(.leading, 16)
        }
        .frame(maxHeight: .infinity)
        .background(acceptColor)
        .cornerRadius(12)
    }

    private var dismissBackground: some View {
        HStack {
            VStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                Text("Відхилити")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(width: 80)
            .padding(.trailing, 16)
        }
        .frame(maxHeight: .infinity)
        .background(dismissColor)
        .cornerRadius(12)
    }

    private func formatAmount(_ amount: Decimal) -> String {
        Formatters.currencyStringUAH(amount: amount,
                                     minFractionDigits: 0,
                                     maxFractionDigits: 0)
    }

    private func formatDate(_ date: Date) -> String {
        Formatters.dateString(date,
                              dateStyle: .short)
    }
}
