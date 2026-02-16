//
//  CelebrationOverlayView.swift
//  ExpenseTracker
//

import SwiftUI

struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGFloat
    let offset: (x: CGFloat, y: CGFloat)
}

struct CelebrationOverlayView: View {
    let onDismiss: () -> Void

    @State private var checkmarkScale: CGFloat = 0
    @State private var showContent = false
    @State private var confettiVisible = false
    @State private var isDismissed = false

    private let confetti: [ConfettiParticle] = {
        let colors: [Color] = [.blue, .green, .orange, .pink, .purple, .yellow, .red, .cyan, .mint, .teal]
        return (0..<10).map { index in
            ConfettiParticle(
                id: index,
                color: colors[index],
                size: CGFloat.random(in: 8...16),
                offset: (CGFloat.random(in: -150...150), CGFloat.random(in: -200...200))
            )
        }
    }()

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismissOnce() }

            // Confetti circles
            ForEach(confetti) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: confettiVisible ? particle.offset.x : 0,
                        y: confettiVisible ? particle.offset.y : 0
                    )
                    .opacity(confettiVisible ? 0 : 1)
                    .scaleEffect(confettiVisible ? 0.3 : 1)
            }

            // Center card
            VStack(spacing: Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(checkmarkScale)

                if showContent {
                    VStack(spacing: Spacing.sm) {
                        Text(String(localized: "celebration.title"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(String(localized: "celebration.subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(Spacing.betweenSections)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal, Spacing.paddingXL)
        }
        .accessibilityIdentifier("CelebrationOverlay")
        .onAppear {
            // Checkmark scale animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkmarkScale = 1.2
            }
            // Confetti burst
            withAnimation(.easeOut(duration: 0.8)) {
                confettiVisible = true
            }
        }
        .task {
            // Settle checkmark to 1.0
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                checkmarkScale = 1.0
            }
        }
        .task {
            // Show content
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
        }
        .task {
            // Auto-dismiss after 3 seconds (cancelled if view disappears)
            try? await Task.sleep(for: .seconds(3))
            dismissOnce()
        }
    }

    private func dismissOnce() {
        guard !isDismissed else { return }
        isDismissed = true
        onDismiss()
    }
}
