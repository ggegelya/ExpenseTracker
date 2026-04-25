//
//  EmptyStateView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 03.09.2025.
//

import Foundation
import SwiftUI

struct EmptyStateView<Illustration: View>: View {
    let illustration: Illustration
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            illustration

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(20)
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("EmptyStateView")
    }
}

// SF Symbol convenience init — preserves existing call sites that pass an `icon` string.
extension EmptyStateView where Illustration == SFSymbolEmptyIllustration {
    init(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.illustration = SFSymbolEmptyIllustration(name: icon)
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
}

struct SFSymbolEmptyIllustration: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 60))
            .foregroundColor(.secondary)
    }
}


// Placeholder views - implement these based on your needs
