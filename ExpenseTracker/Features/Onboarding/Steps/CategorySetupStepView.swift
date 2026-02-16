//
//  CategorySetupStepView.swift
//  ExpenseTracker
//

import SwiftUI

struct CategorySetupStepView: View {
    let categories: [Category]
    @Binding var selectedCategoryIds: Set<UUID>
    let onNext: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: Spacing.betweenSections) {
            // Title
            OnboardingHeaderView(
                title: String(localized: "onboarding.categories.title"),
                subtitle: String(localized: "onboarding.categories.subtitle")
            )
            .padding(.top, Spacing.xxxl)

            // Category grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(categories) { category in
                        CategoryGridItem(
                            category: category,
                            isSelected: selectedCategoryIds.contains(category.id)
                        ) {
                            if selectedCategoryIds.contains(category.id) {
                                selectedCategoryIds.remove(category.id)
                            } else {
                                selectedCategoryIds.insert(category.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.paddingLG)
            }

            OnboardingPrimaryButton(
                title: String(localized: "onboarding.next"),
                action: onNext
            )
        }
        .padding(.horizontal, Spacing.paddingBase)
        .accessibilityIdentifier("CategorySetupStepView")
    }
}
