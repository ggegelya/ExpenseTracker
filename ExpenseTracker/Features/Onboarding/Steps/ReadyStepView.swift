//
//  ReadyStepView.swift
//  ExpenseTracker
//

import SwiftUI

struct ReadyStepView: View {
    let onComplete: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: Spacing.betweenSections) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(pulseScale)
                .task {
                    withAnimation(
                        .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulseScale = 1.1
                    }
                }

            OnboardingHeaderView(
                title: String(localized: "onboarding.ready.title"),
                subtitle: String(localized: "onboarding.ready.subtitle")
            )

            Spacer()

            OnboardingPrimaryButton(
                title: String(localized: "onboarding.ready.start"),
                action: onComplete
            )
        }
        .padding(.horizontal, Spacing.paddingBase)
        .accessibilityIdentifier("ReadyStepView")
    }
}
