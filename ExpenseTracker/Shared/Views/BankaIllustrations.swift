//
//  BankaIllustrations.swift
//  ExpenseTracker
//
//  Line-art illustrations for empty states from the Banka design pack.
//  One style only — 1.5pt strokes matching SF Symbols, ink + honey
//  accents, no other illustrations anywhere else in the product.
//

import SwiftUI

// MARK: - Locked Analytics

/// Blurred concentric rings + honey padlock. Used for the analytics
/// "unlock at 3 transactions" gate. The blur is decorative — no real
/// data is rendered behind it; we render fake stand-in arcs just to
/// give the user a hint of what's coming.
struct LockedAnalyticsIllustration: View {
    var body: some View {
        ZStack {
            // Blurred stand-in rings — no real data.
            ZStack {
                Circle()
                    .stroke(Color(.separator), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: 0.35)
                    .stroke(Color.signal.opacity(0.45), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0, to: 0.55)
                    .stroke(Color.green.opacity(0.45), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue.opacity(0.45), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
            }
            .blur(radius: 4)
            .opacity(0.7)

            // Honey padlock — sits in the center of the rings.
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
                    .frame(width: 44, height: 44)

                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.signal)
            }
        }
        .frame(width: 140, height: 140)
        .accessibilityHidden(true)
    }
}

// MARK: - Honey progress chip

/// Three-dot honey progress indicator on a `signalSoft` capsule —
/// used for "1 of 3 to unlock" style progressive-disclosure gates.
/// Caps at 3 because that's the unlock threshold; for other thresholds
/// fall back to a regular ProgressView.
struct HoneyProgressChip: View {
    let current: Int
    let total: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(0..<total, id: \.self) { index in
                    Circle()
                        .fill(index < current ? Color.signal : Color.signal.opacity(0.25))
                        .frame(width: 8, height: 8)
                }
            }

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.signal)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.signalSoft, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

// MARK: - Previews

#Preview("Locked Analytics") {
    VStack(spacing: 16) {
        LockedAnalyticsIllustration()
        HoneyProgressChip(current: 1, total: 3, label: "1 of 3 to unlock")
    }
    .padding()
}
