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

            // Banka jar — same primitive as the no-transactions empty state.
            // Pulses softly to read as "ready to fill", not "system success".
            EmptyJarIllustration()
                .scaleEffect(pulseScale)
                .task {
                    withAnimation(
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulseScale = 1.06
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
