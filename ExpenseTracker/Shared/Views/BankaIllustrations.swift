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

// MARK: - Empty Jar (Transactions empty)

/// Line-art glass jar with a single honey drop drifting in the middle.
/// Lines match SF Symbols stroke weight for visual coherence.
struct EmptyJarIllustration: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let stroke = GraphicsContext.Shading.color(.primary)

            // Lid
            let lid = Path(roundedRect: CGRect(x: w * 0.30, y: h * 0.18, width: w * 0.40, height: h * 0.07), cornerRadius: 2)
            ctx.stroke(lid, with: stroke, lineWidth: 2)

            // Body
            var body = Path()
            body.move(to: CGPoint(x: w * 0.27, y: h * 0.30))
            body.addLine(to: CGPoint(x: w * 0.73, y: h * 0.30))
            body.addLine(to: CGPoint(x: w * 0.73, y: h * 0.72))
            body.addQuadCurve(
                to: CGPoint(x: w * 0.62, y: h * 0.85),
                control: CGPoint(x: w * 0.73, y: h * 0.85)
            )
            body.addLine(to: CGPoint(x: w * 0.38, y: h * 0.85))
            body.addQuadCurve(
                to: CGPoint(x: w * 0.27, y: h * 0.72),
                control: CGPoint(x: w * 0.27, y: h * 0.85)
            )
            body.closeSubpath()
            ctx.stroke(body, with: stroke, lineWidth: 2)

            // Shine line — round caps via StrokeStyle
            var shine = Path()
            shine.move(to: CGPoint(x: w * 0.36, y: h * 0.36))
            shine.addLine(to: CGPoint(x: w * 0.36, y: h * 0.78))
            ctx.stroke(
                shine,
                with: stroke,
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )

            // Single honey drop — teardrop
            var drop = Path()
            let cx = w * 0.50
            let topY = h * 0.45
            let bottomY = h * 0.58
            drop.move(to: CGPoint(x: cx, y: topY))
            drop.addCurve(
                to: CGPoint(x: cx, y: bottomY),
                control1: CGPoint(x: cx - w * 0.06, y: topY + (bottomY - topY) * 0.5),
                control2: CGPoint(x: cx - w * 0.04, y: bottomY)
            )
            drop.addCurve(
                to: CGPoint(x: cx, y: topY),
                control1: CGPoint(x: cx + w * 0.04, y: bottomY),
                control2: CGPoint(x: cx + w * 0.06, y: topY + (bottomY - topY) * 0.5)
            )
            drop.closeSubpath()
            ctx.fill(drop, with: .color(.signal))
        }
        .frame(width: 140, height: 140)
        .accessibilityHidden(true)
    }
}

// MARK: - Receipt Scroll + Stamp (Pending empty)

/// Rolled receipt with a honey checkmark stamp — "inbox zero" metaphor.
struct ReceiptStampIllustration: View {
    var body: some View {
        ZStack {
            // Receipt body — a tall slim rounded rect with subtle horizontal lines
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: i % 2 == 0 ? 56 : 44, height: 1.5)
                }
            }
            .padding(16)
            .frame(width: 84, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.primary, lineWidth: 2)
            )

            // Honey checkmark stamp lower-right
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.signal)
                .background(
                    Circle().fill(Color(.systemBackground))
                )
                .offset(x: 28, y: 36)
        }
        .frame(width: 140, height: 140)
        .accessibilityHidden(true)
    }
}

// MARK: - Coin Stack (Accounts empty)

/// Three honey coins stacked, top one carrying ₴ glyph.
struct CoinStackIllustration: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let yOffset = CGFloat(index) * 14 - 14
                let scale = 1.0 - CGFloat(2 - index) * 0.12
                ZStack {
                    Capsule()
                        .fill(Color.signal)
                        .frame(width: 96, height: 28)

                    Capsule()
                        .stroke(Color.primary, lineWidth: 1.8)
                        .frame(width: 96, height: 28)

                    if index == 2 {
                        Text("₴")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .scaleEffect(scale)
                .offset(y: yOffset)
            }
        }
        .frame(width: 140, height: 140)
        .accessibilityHidden(true)
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

#Preview("Empty States") {
    HStack(spacing: 24) {
        EmptyJarIllustration()
        ReceiptStampIllustration()
        CoinStackIllustration()
    }
    .padding()
}
