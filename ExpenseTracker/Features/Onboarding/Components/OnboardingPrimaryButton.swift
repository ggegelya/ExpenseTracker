//
//  OnboardingPrimaryButton.swift
//  ExpenseTracker
//

import SwiftUI

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.base)
                .background(Color.accentColor)
                .cornerRadius(Spacing.pillCornerRadius)
        }
        .buttonStyle(OnboardingButtonStyle())
        .padding(.horizontal, Spacing.paddingLG)
        .padding(.bottom, Spacing.hero + Spacing.xxxl)
    }
}

/// Replaces the default button highlight (opacity dim) with a subtle scale,
/// preventing the white flash visible during page transitions.
private struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
