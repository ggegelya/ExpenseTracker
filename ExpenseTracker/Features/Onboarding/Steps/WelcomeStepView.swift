//
//  WelcomeStepView.swift
//  ExpenseTracker
//

import SwiftUI

struct WelcomeStepView: View {
    let onNext: () -> Void

    private static let coinFaces: [(symbol: String, color: Color)] = [
        ("hryvniasign.circle.fill", .accentColor),
        ("dollarsign.circle.fill", Color(.systemTeal)),
        ("eurosign.circle.fill", Color(.systemIndigo)),
    ]

    @State private var currentFaceIndex = 0
    @State private var rotationAngle: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - Flipping Coin
            coinView
                .padding(.bottom, Spacing.betweenSections)

            // MARK: - Title & Subtitle
            OnboardingHeaderView(
                title: String(localized: "onboarding.welcome.title"),
                subtitle: String(localized: "onboarding.welcome.subtitle")
            )

            // MARK: - Feature Highlights
            VStack(alignment: .leading, spacing: Spacing.lg) {
                featureRow(
                    icon: "bolt.fill",
                    text: String(localized: "onboarding.feature.quick")
                )
                featureRow(
                    icon: "chart.pie.fill",
                    text: String(localized: "onboarding.feature.analytics")
                )
                featureRow(
                    icon: "building.columns.fill",
                    text: String(localized: "onboarding.feature.accounts")
                )
            }
            .padding(.top, Spacing.hero)
            .padding(.horizontal, Spacing.hero)

            // Double-weight spacer pushes content above center, giving button breathing room
            Spacer().frame(minHeight: Spacing.hero)

            OnboardingPrimaryButton(
                title: String(localized: "onboarding.welcome.start"),
                action: onNext
            )
        }
        .padding(.horizontal, Spacing.paddingBase)
        .accessibilityIdentifier("WelcomeStepView")
        .task { await spinCoinLoop() }
    }

    // MARK: - Coin View

    private var coinView: some View {
        let face = Self.coinFaces[currentFaceIndex]
        return Image(systemName: face.symbol)
            .font(.system(size: 80))
            .foregroundColor(face.color)
            .rotation3DEffect(
                .degrees(rotationAngle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .accessibilityLabel(String(localized: "onboarding.welcome.title"))
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.base) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Spin Animation
    //
    // Spin 1 (slow) → Spin 2 (fast, swap currency) → Spin 3 (slow) → wobble settle → pause

    private func spinCoinLoop() async {
        while !Task.isCancelled {
            // Spin 1: Slow start — accelerating into the spin
            withAnimation(.easeIn(duration: 0.7)) {
                rotationAngle += 360
            }
            try? await Task.sleep(for: .seconds(0.7))

            // Spin 2: Peak speed — swap currency while edge-on (~90° in)
            withAnimation(.linear(duration: 0.4)) {
                rotationAngle += 360
            }
            // Swap at quarter-turn (edge-on, invisible)
            try? await Task.sleep(for: .seconds(0.1))
            currentFaceIndex = (currentFaceIndex + 1) % Self.coinFaces.count
            try? await Task.sleep(for: .seconds(0.3))

            // Spin 3: Decelerating — easing to a stop
            withAnimation(.easeOut(duration: 0.9)) {
                rotationAngle += 360
            }
            try? await Task.sleep(for: .seconds(0.9))

            // Wobble settle — coin rocks back and forth with decreasing amplitude
            withAnimation(.easeOut(duration: 0.18)) {
                rotationAngle += 15
            }
            try? await Task.sleep(for: .seconds(0.18))

            withAnimation(.easeInOut(duration: 0.22)) {
                rotationAngle -= 10
            }
            try? await Task.sleep(for: .seconds(0.22))

            withAnimation(.easeInOut(duration: 0.18)) {
                rotationAngle += 5
            }
            try? await Task.sleep(for: .seconds(0.18))

            withAnimation(.easeInOut(duration: 0.14)) {
                rotationAngle -= 2
            }
            try? await Task.sleep(for: .seconds(0.14))

            // Settle wobble drift, then reset to 0 during pause to prevent unbounded growth
            let rest = (rotationAngle / 360).rounded() * 360
            withAnimation(.easeOut(duration: 0.12)) {
                rotationAngle = rest
            }
            try? await Task.sleep(for: .seconds(0.12))

            // Reset while at rest (visually identical — any multiple of 360° looks like 0°)
            rotationAngle = 0

            // Pause before next cycle
            try? await Task.sleep(for: .seconds(2.2))
        }
    }
}
