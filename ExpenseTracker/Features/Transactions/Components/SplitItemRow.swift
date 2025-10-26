//
//  SplitItemRow.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import SwiftUI

struct SplitItem: Identifiable, Equatable {
    let id: UUID
    var amount: Decimal
    var category: Category?
    var description: String

    init(id: UUID = UUID(), amount: Decimal = 0, category: Category? = nil, description: String = "") {
        self.id = id
        self.amount = amount
        self.category = category
        self.description = description
    }
}

struct SplitItemRow: View {
    @Binding var splitItem: SplitItem
    let totalAmount: Decimal
    let onDelete: () -> Void
    let onCategorySelect: () -> Void

    @State private var amountText: String = ""
    @FocusState private var isAmountFocused: Bool
    @FocusState private var isDescriptionFocused: Bool

    var percentageOfTotal: Double {
        guard totalAmount > 0 else { return 0 }
        let percentage = (splitItem.amount as NSDecimalNumber).doubleValue / (totalAmount as NSDecimalNumber).doubleValue
        return min(max(percentage, 0), 1) * 100
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Category Button
                Button {
                    onCategorySelect()
                } label: {
                    if let category = splitItem.category {
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .foregroundColor(Color(hex: category.colorHex))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: category.colorHex).opacity(0.2))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name.capitalized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text("\(percentageOfTotal, specifier: "%.1f")%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.orange)
                                .frame(width: 32, height: 32)
                                .background(Color.orange.opacity(0.2))
                                .clipShape(Circle())

                            Text("Оберіть категорію")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Amount Input
                HStack(spacing: 4) {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.headline)
                        .frame(width: 80)
                        .focused($isAmountFocused)
                        .onChange(of: amountText) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                            if trimmed.isEmpty {
                                splitItem.amount = 0
                                return
                            }

                            if let value = Formatters.decimalValue(from: trimmed),
                               value != splitItem.amount {
                                splitItem.amount = value
                            }
                        }
                        .onChange(of: isAmountFocused) { _, focused in
                            if focused {
                                // When focused, show raw value
                                if splitItem.amount == 0 {
                                    amountText = ""
                                } else {
                                    amountText = String(describing: splitItem.amount)
                                }
                            } else {
                                // When unfocused, format nicely
                                syncAmountText()
                            }
                        }
                        .onAppear {
                            syncAmountText()
                        }

                    Text("₴")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            // Description Input
            TextField("Опис (опціонально)", text: $splitItem.description)
                .font(.caption)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .focused($isDescriptionFocused)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(splitItem.category != nil ? Color(hex: splitItem.category!.colorHex).opacity(0.3) : Color(.systemGray4), lineWidth: 1)
        )
    }

    private func syncAmountText() {
        if splitItem.amount == 0 {
            amountText = ""
        } else {
            amountText = Formatters.decimalString(splitItem.amount)
        }
    }
}
