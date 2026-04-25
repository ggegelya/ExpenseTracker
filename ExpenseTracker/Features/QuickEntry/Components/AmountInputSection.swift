//
//  AmountInputSection.swift
//  ExpenseTracker
//

import SwiftUI

struct AmountInputSection: View {
    @Binding var amount: String
    @Binding var transactionType: TransactionType
    @FocusState var isAmountFocused: Bool
    @Binding var selectedDate: Date
    let selectedAccount: Account?
    let showAccountSelector: Bool
    @Binding var toggleRotation: Double
    @Binding var datePillPressed: Bool
    @Binding var accountPillPressed: Bool
    let onMetadataTap: () -> Void

    @State private var toggleScale: CGFloat = 1.0

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "uk")
        return formatter
    }()

    var body: some View {
        VStack(spacing: 8) {
            // Amount input - Hero layout. Baseline-aligned so the smaller
            // currency glyph sits on the same line as the digits.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Tap-to-toggle -/+ sign only (no background)
                Button {
                    // Rotate 180° and pulse scale
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        toggleRotation += 180
                        transactionType = transactionType == .expense ? .income : .expense
                    }

                    // Scale pulse: 1.0 → 1.1 → 1.0
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        toggleScale = 1.1
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            toggleScale = 1.0
                        }
                    }
                } label: {
                    Text(transactionType.symbol)
                        .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                        .foregroundColor(transactionType == .expense ? .red : .green)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("TypeToggle")
                .buttonStyle(.plain)
                .rotationEffect(.degrees(toggleRotation))
                .scaleEffect(toggleScale)

                TextField("0", text: $amount)
                    .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
                    .tint(.blue)
                    .accessibilityIdentifier("AmountField")
                    .onChange(of: amount) { _, newValue in
                        // Format input to max 2 decimal places
                        if let dotIndex = newValue.lastIndex(of: ".") {
                            let decimals = newValue.distance(from: newValue.index(after: dotIndex), to: newValue.endIndex)
                            if decimals > 2 {
                                amount = String(newValue.prefix(newValue.count - (decimals - 2)))
                            }
                        }
                    }

                Text("₴")
                    .font(.system(size: 31, weight: .ultraLight, design: .rounded))
                    .foregroundColor(.primary.opacity(0.6))
            }

            // Merged context bar — single strip with hairline-divided segments.
            // Replaces two floating pills per Banka design (Add screen).
            HStack(spacing: 0) {
                // Date segment
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        datePillPressed = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        withAnimation(.easeOut(duration: 0.15)) {
                            datePillPressed = false
                        }
                    }
                    onMetadataTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(formattedDate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .accessibilityIdentifier("DatePicker")
                .buttonStyle(.plain)
                .scaleEffect(datePillPressed ? 0.97 : 1.0)

                if showAccountSelector, let account = selectedAccount {
                    Divider()
                        .frame(width: 0.5, height: 18)
                        .overlay(Color(.separator))

                    // Account segment
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            accountPillPressed = true
                        }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(150))
                            withAnimation(.easeOut(duration: 0.15)) {
                                accountPillPressed = false
                            }
                        }
                        onMetadataTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(account.displayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            if account.isDefault {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.signal)
                                    .padding(3)
                                    .background(Color.signalSoft)
                                    .clipShape(Circle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .accessibilityIdentifier("AccountSelector")
                    .buttonStyle(.plain)
                    .scaleEffect(accountPillPressed ? 0.97 : 1.0)
                }
            }
            .background(Color(.systemGray6).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return String(localized: "date.today")
        } else if calendar.isDateInYesterday(selectedDate) {
            return String(localized: "date.yesterday")
        } else {
            return Self.shortDateFormatter.string(from: selectedDate)
        }
    }
}
