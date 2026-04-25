//
//  StitchSeparator.swift
//  ExpenseTracker
//
//  Three-rank separator primitive from the Banka design system.
//  Solid hairline for in-list rows; honey dashed for soft accent
//  (pending tile underline, celebration glow); ink dashed for
//  full-width section breaks. Use one rank per card.
//

import SwiftUI

enum StitchSeparatorRank {
    /// Apple-default 0.5pt hairline. Use inside lists between rows.
    case solid
    /// Honey dashed underline. Use for pending tile accent or
    /// celebration glow dividers — soft, decorative, optional.
    case honey
    /// Ink dashed full-width section break. The only place dashed
    /// ink appears in-app — reserve for analytics-export style page
    /// dividers and editorial section transitions.
    case ink
    /// Tiny vyshyvanka cross-and-diamond motif in honey. The most
    /// brand-loaded option; reserve for celebratory or editorial
    /// surfaces only (first-transaction overlay, PDF header decoration,
    /// onboarding intro). Never in a list, never as a row separator.
    case vyshyvanka
}

struct StitchSeparator: View {
    let rank: StitchSeparatorRank

    init(_ rank: StitchSeparatorRank = .solid) {
        self.rank = rank
    }

    var body: some View {
        switch rank {
        case .solid:
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        case .honey:
            DashedLine(dash: [4, 4], lineWidth: 1.5)
                .stroke(Color.signal.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(height: 1.5)
        case .ink:
            DashedLine(dash: [6, 6], lineWidth: 2)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .frame(height: 2)
        case .vyshyvanka:
            VyshyvankaStripe()
                .fill(Color.signal)
                .frame(height: 10)
        }
    }
}

/// Tiles a small vyshyvanka cross-and-diamond unit horizontally across
/// the bounds. Each unit is 12pt wide × 10pt tall: a 4pt-wide diamond
/// flanked by a 4pt-wide cross. In Ukrainian embroidery the actual
/// motif is far more elaborate; this is a deliberate abstraction so it
/// reads as honey-stitch decoration rather than pastiche.
struct VyshyvankaStripe: Shape {
    var unitWidth: CGFloat = 12
    var verticalInset: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cy = rect.midY
        let half: CGFloat = 3 // half of the 6pt motif size
        let count = max(0, Int(rect.width / unitWidth))
        // Padding so the row centers within the rect width
        let totalUsed = CGFloat(count) * unitWidth
        let startX = rect.minX + (rect.width - totalUsed) / 2

        for i in 0..<count {
            let unitCenter = startX + CGFloat(i) * unitWidth + unitWidth / 2

            if i % 2 == 0 {
                // Diamond unit
                path.move(to: CGPoint(x: unitCenter, y: cy - half))
                path.addLine(to: CGPoint(x: unitCenter + half, y: cy))
                path.addLine(to: CGPoint(x: unitCenter, y: cy + half))
                path.addLine(to: CGPoint(x: unitCenter - half, y: cy))
                path.closeSubpath()
            } else {
                // Cross unit — two short overlapping rectangles
                let arm: CGFloat = 1.4
                path.addRect(CGRect(
                    x: unitCenter - half,
                    y: cy - arm,
                    width: half * 2,
                    height: arm * 2
                ))
                path.addRect(CGRect(
                    x: unitCenter - arm,
                    y: cy - half,
                    width: arm * 2,
                    height: half * 2
                ))
            }
        }

        _ = verticalInset // reserved for future per-unit padding tweaks
        return path
    }
}

/// Horizontal dashed-line shape — Apple's `Path` doesn't dash for free,
/// and hr-style dashed borders need a deterministic single-line draw.
private struct DashedLine: Shape {
    let dash: [CGFloat]
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
