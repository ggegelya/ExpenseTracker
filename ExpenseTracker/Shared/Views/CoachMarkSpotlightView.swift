//
//  CoachMarkSpotlightView.swift
//  ExpenseTracker
//
//  Full-screen spotlight overlay with a curved arrow pointing to a target tab.
//  Appears above everything including the tab bar.
//

import SwiftUI

struct CoachMarkSpotlightView: View {
    let text: String
    let icon: String
    let targetTab: AppTab
    let onDismiss: () -> Void

    @State private var isDismissed = false
    @State private var isVisible = false
    @State private var arrowProgress: CGFloat = 0

    var body: some View {
        if !isDismissed {
            GeometryReader { geo in
                let screen = geo.size
                let bottomSafe = geo.safeAreaInsets.bottom

                // Target: center of the tab icon area
                let tabCount: CGFloat = 5
                let tabWidth = screen.width / tabCount
                let tabCenterX = tabWidth * (CGFloat(targetTab.rawValue) + 0.5)
                let tabIconY = screen.height - bottomSafe - 28

                // Text position: vertically centered, slightly above mid
                let textCenterY = screen.height * 0.42

                // Arrow endpoints
                let arrowFrom = CGPoint(x: screen.width / 2, y: textCenterY + 48)
                let arrowTo = CGPoint(x: tabCenterX, y: tabIconY)

                ZStack {
                    // Semi-transparent frosted backdrop
                    Color(.systemBackground)
                        .opacity(0.88)
                        .ignoresSafeArea()

                    VStack(spacing: Spacing.base) {
                        Image(systemName: icon)
                            .font(.system(size: 32))
                            .foregroundStyle(.tint)

                        Text(text)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 48)
                    .position(x: screen.width / 2, y: textCenterY)

                    // Curved arrow from text to target tab
                    CurvedArrowShape(from: arrowFrom, to: arrowTo)
                        .trim(from: 0, to: arrowProgress)
                        .stroke(
                            Color.accentColor.opacity(0.7),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                    // Arrowhead — appears after arrow finishes drawing
                    if arrowProgress >= 1.0 {
                        ArrowheadShape(
                            tip: arrowTo,
                            approachFrom: CGPoint(x: arrowTo.x, y: arrowTo.y - 60)
                        )
                        .stroke(
                            Color.accentColor.opacity(0.7),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .transition(.opacity)
                    }

                    // Dismiss hint
                    Text(String(localized: "coachMark.dismiss"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .position(x: screen.width / 2, y: screen.height - bottomSafe - 72)
                }
                .opacity(isVisible ? 1 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { dismissOnce() }
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = true
                }
                withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
                    arrowProgress = 1.0
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
            .accessibilityHint(String(localized: "coachMark.dismiss"))
            .accessibilityAddTraits(.isButton)
        }
    }

    private func dismissOnce() {
        guard !isDismissed else { return }
        isDismissed = true
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        onDismiss()
    }
}

// MARK: - Curved Arrow Shape

/// A smooth cubic bezier curve from one point to another.
private struct CurvedArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)

        // Control points: creates a natural flowing curve
        // Goes down first, then curves horizontally, then arrives from above
        let midY = (from.y + to.y) / 2
        let control1 = CGPoint(x: from.x, y: midY)
        let control2 = CGPoint(x: to.x, y: midY)

        path.addCurve(to: to, control1: control1, control2: control2)
        return path
    }
}

/// Two short lines forming a "V" arrowhead at the tip.
private struct ArrowheadShape: Shape {
    let tip: CGPoint
    let approachFrom: CGPoint

    func path(in rect: CGRect) -> Path {
        let angle = atan2(tip.y - approachFrom.y, tip.x - approachFrom.x)
        let length: CGFloat = 10
        let spread: CGFloat = .pi / 5

        var path = Path()
        path.move(to: CGPoint(
            x: tip.x - length * cos(angle - spread),
            y: tip.y - length * sin(angle - spread)
        ))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(
            x: tip.x - length * cos(angle + spread),
            y: tip.y - length * sin(angle + spread)
        ))
        return path
    }
}

// MARK: - Spotlight Layer

/// Thin wrapper that observes CoachMarkManager and renders the appropriate spotlight.
/// Used in ExpenseTrackerApp's ZStack where @EnvironmentObject isn't available.
struct CoachMarkSpotlightLayer: View {
    @ObservedObject var coachMarkManager: CoachMarkManager

    var body: some View {
        if coachMarkManager.shouldShow(.firstTransactionSaved) {
            CoachMarkSpotlightView(
                text: String(localized: "coachMark.transactionsTab"),
                icon: "list.bullet",
                targetTab: .transactions,
                onDismiss: { coachMarkManager.deactivate(.firstTransactionSaved) }
            )
        } else if coachMarkManager.shouldShow(.analyticsReady) {
            CoachMarkSpotlightView(
                text: String(localized: "coachMark.analyticsReady"),
                icon: "chart.pie.fill",
                targetTab: .analytics,
                onDismiss: { coachMarkManager.deactivate(.analyticsReady) }
            )
        }
    }
}

#Preview("Transactions Tab") {
    CoachMarkSpotlightView(
        text: "View your transactions here",
        icon: "list.bullet",
        targetTab: .transactions,
        onDismiss: {}
    )
}

#Preview("Analytics Tab") {
    CoachMarkSpotlightView(
        text: "Your analytics are ready!",
        icon: "chart.pie.fill",
        targetTab: .analytics,
        onDismiss: {}
    )
}
