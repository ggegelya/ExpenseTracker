//
//  PulsingRingModifier.swift
//  ExpenseTracker
//

import SwiftUI

/// A view modifier that adds a pulsing glow ring around its content.
struct PulsingRingModifier: ViewModifier {
    let color: Color
    let isActive: Bool
    let cornerRadius: CGFloat

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(color, lineWidth: 2)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: false)
                            ) {
                                scale = 1.15
                                opacity = 0
                            }
                        }
                }
            }
    }
}

extension View {
    /// Adds a pulsing glow ring around this view.
    func pulsingRing(color: Color = .blue, isActive: Bool, cornerRadius: CGFloat = 12) -> some View {
        modifier(PulsingRingModifier(color: color, isActive: isActive, cornerRadius: cornerRadius))
    }
}
