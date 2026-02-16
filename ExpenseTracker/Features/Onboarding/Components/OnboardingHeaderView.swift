//
//  OnboardingHeaderView.swift
//  ExpenseTracker
//

import SwiftUI

struct OnboardingHeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.paddingLG)
        }
    }
}
