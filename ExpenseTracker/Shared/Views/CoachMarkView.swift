//
//  CoachMarkView.swift
//  ExpenseTracker
//

import SwiftUI

/// Arrow direction for the coach mark tooltip bubble.
enum CoachMarkArrowDirection {
    case up, down
}

/// A reusable tooltip bubble with a directional arrow for contextual coach marks.
/// Uses a frosted-glass material background for a light, friendly appearance.
struct CoachMarkView: View {
    let text: String
    let arrowDirection: CoachMarkArrowDirection
    var autoDismissSeconds: Double? = nil
    let onDismiss: () -> Void

    @State private var isDismissed = false
    @State private var isVisible = false

    var body: some View {
        if !isDismissed {
            VStack(spacing: 0) {
                if arrowDirection == .up {
                    arrowTriangle
                        .frame(width: 16, height: 8)
                }

                HStack(spacing: Spacing.sm) {
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismissOnce()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.paddingSM)
                .padding(.vertical, Spacing.sm)
                .background(.ultraThickMaterial)
                .cornerRadius(Spacing.pillCornerRadius)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                if arrowDirection == .down {
                    arrowTriangle
                        .rotationEffect(.degrees(180))
                        .frame(width: 16, height: 8)
                }
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isVisible = true
                }
            }
            .onTapGesture {
                dismissOnce()
            }
            .task {
                if let seconds = autoDismissSeconds {
                    try? await Task.sleep(for: .seconds(seconds))
                    dismissOnce()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
            .accessibilityHint(String(localized: "coachMark.dismiss"))
            .accessibilityAddTraits(.isButton)
        }
    }

    /// Arrow triangle using frosted material — rendered as an overlay on a filled shape.
    private var arrowTriangle: some View {
        Triangle()
            .fill(.ultraThickMaterial)
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

/// A simple triangle shape used for the tooltip arrow.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Arrow Up") {
    CoachMarkView(
        text: "Введіть суму покупки",
        arrowDirection: .up,
        onDismiss: {}
    )
    .padding()
}

#Preview("Arrow Down") {
    CoachMarkView(
        text: "Перегляньте свої транзакції тут",
        arrowDirection: .down,
        onDismiss: {}
    )
    .padding()
}
