//
//  CategoryGridItem.swift
//  ExpenseTracker
//

import SwiftUI

struct CategoryGridItem: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.body)
                    .foregroundColor(Color(hex: category.colorHex))

                Text(category.displayName)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.body)
                }
            }
            .foregroundColor(isSelected ? .blue : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? Color(hex: category.colorHex).opacity(0.1)
                    : Color(.systemGray6)
            )
            .cornerRadius(12)
        }
        .accessibilityIdentifier("Category_\(category.name)")
        .buttonStyle(.plain)
    }
}
