//
//  AccountSetupStepView.swift
//  ExpenseTracker
//

import SwiftUI

struct AccountSetupStepView: View {
    @Binding var accountName: String
    @Binding var accountBalance: String
    @Binding var accountType: AccountType
    let onNext: () -> Void

    @FocusState private var isNameFocused: Bool
    @FocusState private var isBalanceFocused: Bool

    private let presets: [(name: String, type: AccountType)] = [
        (String(localized: "onboarding.account.preset.monobank"), .card),
        (String(localized: "onboarding.account.preset.privatbank"), .card),
        (String(localized: "onboarding.account.preset.cash"), .cash)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.betweenSections) {
                    // Title
                    OnboardingHeaderView(
                        title: String(localized: "onboarding.account.title"),
                        subtitle: String(localized: "onboarding.account.subtitle")
                    )
                    .padding(.top, Spacing.xxxl)

                    // Account name field
                    TextField(String(localized: "onboarding.account.namePlaceholder"), text: $accountName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(Spacing.base)
                        .background(Color(.systemGray6))
                        .cornerRadius(Spacing.pillCornerRadius)
                        .padding(.horizontal, Spacing.paddingLG)
                        .focused($isNameFocused)
                        .accessibilityIdentifier("AccountNameField")

                    // Quick presets
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.betweenPills) {
                            ForEach(presets, id: \.name) { preset in
                                Button {
                                    accountName = preset.name
                                    accountType = preset.type
                                } label: {
                                    Text(preset.name)
                                        .font(.subheadline)
                                        .foregroundColor(accountName == preset.name ? .white : .primary)
                                        .padding(.horizontal, Spacing.pillHorizontal)
                                        .padding(.vertical, Spacing.pillVertical)
                                        .background(accountName == preset.name ? Color.accentColor : Color(.systemGray5))
                                        .cornerRadius(Spacing.pillCornerRadius)
                                }
                                .accessibilityIdentifier("Preset_\(preset.name)")
                            }
                        }
                        .padding(.horizontal, Spacing.paddingLG)
                    }

                    // Balance input
                    VStack(spacing: Spacing.sm) {
                        Text(String(localized: "onboarding.account.balance"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                            TextField("0", text: $accountBalance)
                                .textFieldStyle(.plain)
                                .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused($isBalanceFocused)
                                .accessibilityIdentifier("BalanceField")

                            Text(Currency.uah.symbol)
                                .font(.system(size: 24, weight: .light, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, Spacing.lg)

                    // Account type picker
                    HStack(spacing: Spacing.base) {
                        ForEach([AccountType.card, .cash, .savings], id: \.self) { type in
                            Button {
                                accountType = type
                            } label: {
                                VStack(spacing: Spacing.xs) {
                                    Image(systemName: type.icon)
                                        .font(.title2)
                                        .foregroundColor(accountType == type ? .white : type.swiftUIColor)
                                    Text(type.localizedName)
                                        .font(.caption)
                                        .foregroundColor(accountType == type ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.base)
                                .background(accountType == type ? type.swiftUIColor : Color(.systemGray6))
                                .cornerRadius(Spacing.pillCornerRadius)
                            }
                            .accessibilityIdentifier("AccountType_\(type.rawValue)")
                        }
                    }
                    .padding(.horizontal, Spacing.paddingLG)
                }
            }
            .scrollDismissesKeyboard(.interactively)

            OnboardingPrimaryButton(
                title: String(localized: "onboarding.next"),
                action: onNext
            )
        }
        .padding(.horizontal, Spacing.paddingBase)
        .accessibilityIdentifier("AccountSetupStepView")
    }
}
