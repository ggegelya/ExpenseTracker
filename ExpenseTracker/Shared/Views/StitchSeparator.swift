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
        }
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
