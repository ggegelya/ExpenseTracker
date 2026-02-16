//
//  OnboardingView.swift
//  ExpenseTracker
//

import SwiftUI

struct OnboardingView: View {
    let container: DependencyContainer
    let onComplete: () -> Void

    @EnvironmentObject var accountsViewModel: AccountsViewModel
    @State private var currentStep = 0
    @State private var isCompleting = false

    // Account setup state
    @State private var accountName = String(localized: "account.default_card")
    @State private var accountBalance = ""
    @State private var accountType: AccountType = .card

    // Category setup state
    @State private var categories: [Category] = []
    @State private var selectedCategoryIds: Set<UUID> = []

    private let totalSteps = 4

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $currentStep) {
                WelcomeStepView(onNext: advanceStep)
                    .tag(0)

                AccountSetupStepView(
                    accountName: $accountName,
                    accountBalance: $accountBalance,
                    accountType: $accountType,
                    onNext: advanceStep
                )
                .tag(1)

                CategorySetupStepView(
                    categories: categories,
                    selectedCategoryIds: $selectedCategoryIds,
                    onNext: advanceStep
                )
                .tag(2)

                ReadyStepView(onComplete: completeOnboarding)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .disabled(isCompleting)

            // Skip button
            Button(String(localized: "onboarding.skip")) {
                onComplete()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, Spacing.paddingLG)
            .padding(.top, Spacing.sm)
            .disabled(isCompleting)
            .accessibilityIdentifier("OnboardingSkipButton")
        }
        .accessibilityIdentifier("OnboardingView")
        .task {
            await loadCategories()
        }
    }

    private func advanceStep() {
        withAnimation {
            currentStep = min(currentStep + 1, totalSteps - 1)
        }
    }

    private func loadCategories() async {
        await container.ensureReady()
        do {
            categories = try await container.transactionRepository.getAllCategories()
            selectedCategoryIds = Set(categories.map(\.id))
        } catch {
            // Fallback: use all default categories
            categories = Category.defaults
            selectedCategoryIds = Set(categories.map(\.id))
        }
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }
        isCompleting = true

        Task { @MainActor in
            // Update default account with user's chosen settings
            if let defaultAccount = accountsViewModel.accounts.first(where: { $0.isDefault }) {
                let trimmedName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalName = trimmedName.isEmpty ? defaultAccount.name : trimmedName

                let updated = Account(
                    id: defaultAccount.id,
                    name: finalName,
                    tag: defaultAccount.tag,
                    balance: BalanceParser.parse(accountBalance),
                    isDefault: true,
                    accountType: accountType,
                    currency: defaultAccount.currency
                )

                await accountsViewModel.updateAccount(updated)
            }

            // Save favorite category IDs
            let favoriteIds = selectedCategoryIds.map(\.uuidString)
            UserDefaults.standard.set(favoriteIds, forKey: UserDefaultsKeys.favoriteCategoryIds)

            isCompleting = false
            onComplete()
        }
    }
}
