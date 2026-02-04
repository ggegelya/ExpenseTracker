//
//  CellAccessibilityIdentifier.swift
//  ExpenseTracker
//
//  Created by Claude Code on 22.11.2025.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

private struct CellAccessibilityIdentifierView: UIViewRepresentable {
    let identifier: String

    func makeUIView(context: Context) -> UIView {
        IdentifierProbeView(identifier: identifier)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? IdentifierProbeView)?.identifier = identifier
    }
}

private final class IdentifierProbeView: UIView {
    var identifier: String {
        didSet { applyIdentifier() }
    }

    init(identifier: String) {
        self.identifier = identifier
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applyIdentifier()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyIdentifier()
    }

    private func applyIdentifier() {
        var current: UIView? = self
        while let candidate = current?.superview {
            if let tableCell = candidate as? UITableViewCell {
                tableCell.accessibilityIdentifier = identifier
                return
            }
            if let collectionCell = candidate as? UICollectionViewCell {
                collectionCell.accessibilityIdentifier = identifier
                return
            }
            current = candidate
        }
    }
}

extension View {
    func cellAccessibilityIdentifier(_ identifier: String) -> some View {
        background(CellAccessibilityIdentifierView(identifier: identifier))
    }
}
#endif
#if !canImport(UIKit)
extension View {
    func cellAccessibilityIdentifier(_ identifier: String) -> some View {
        self
    }
}
#endif
