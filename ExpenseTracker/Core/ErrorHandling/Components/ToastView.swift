//
//  ToastView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//

import Foundation
import SwiftUI

struct ToastView : View {
    let toast: ToastMessage
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
            
            Text(toast.message)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ToastView(toast: ToastMessage(message: "This is a test error message.", type: .error), onDismiss: {})
        .padding()
        .background(Color.gray.opacity(0.2))
}
    
