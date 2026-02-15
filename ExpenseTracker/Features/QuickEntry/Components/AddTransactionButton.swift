//
//  AddTransactionButton.swift
//  ExpenseTracker
//

import SwiftUI

struct AddTransactionButton: View {
    let isValid: Bool
    let isLoading: Bool
    let scale: CGFloat
    let action: () async -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            Task { @MainActor in
                await action()
            }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text(String(localized: "common.add"))
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isValid
                    ? Color.blue.opacity(0.95)
                    : Color.gray.opacity(0.3)
            )
            .cornerRadius(16)
            .shadow(
                color: isValid ? Color.blue.opacity(0.2) : .clear,
                radius: 8,
                y: 2
            )
        }
        .accessibilityIdentifier("SaveButton")
        .disabled(isLoading)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .scaleEffect(scale)
        .animation(.spring(response: 0.2), value: isPressed)
        .animation(.easeInOut(duration: 0.2), value: isValid)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .padding(.horizontal, 20)
    }
}
