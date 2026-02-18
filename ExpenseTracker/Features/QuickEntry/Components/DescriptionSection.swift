//
//  DescriptionSection.swift
//  ExpenseTracker
//

import SwiftUI

struct DescriptionSection: View {
    @Binding var description: String
    @FocusState var isDescriptionFocused: Bool
    @Binding var selectedCategory: Category?
    let onShowCategoryPicker: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Plain text field with bottom border
            VStack(spacing: 0) {
                TextField(TestingConfiguration.isRunningTests ? "Description" : String(localized: "quickEntry.descriptionPlaceholder"), text: $description)
                    .font(.system(size: 17))
                    .focused($isDescriptionFocused)
                    .submitLabel(.done)
                    .tint(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .accessibilityIdentifier("DescriptionField")
                    .onSubmit {
                        isDescriptionFocused = false
                    }

                Divider()
            }

            // Category picker button
            Button {
                onShowCategoryPicker()
            } label: {
                HStack(spacing: 4) {
                    Text(selectedCategory == nil ? String(localized: "common.selectCategory") : "\(String(localized: "common.category")): \(selectedCategory?.displayName ?? "")")
                        .font(.system(size: 14))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(.blue)
            }
            .accessibilityIdentifier("CategoryPicker")
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }
}
