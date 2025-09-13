//
//  ErrorAlertView.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//

import Foundation
import SwiftUI

struct ErrorAlertView: View {
    let alertMessage: AlertMessage
    let onDismiss: (() -> Void)
    let onRetry: (() async -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Text(alertMessage.title)
                .font(.headline)
                
            Text(alertMessage.message)
                .font(.body)
                .multilineTextAlignment(.center)
            
            if let recoverySuggestion = alertMessage.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button("Закрити", action: onDismiss)
                    .buttonStyle(.bordered)
                
                if alertMessage.isRetryable, let retryAction = onRetry {
                    Button("Спробувати ще раз") {
                        Task {
                            await retryAction()
                            onDismiss();
                        }
                    }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 20)
    }
}

#Preview {
    ErrorAlertView(
        alertMessage: AlertMessage(
            title: "Помилка",
            message: "Сталася помилка під час завантаження даних.",
            recoverySuggestion: "Перевірте підключення до інтернету та спробуйте ще раз.",
            retryAction: nil,
            isRetryable: true
        ),
        onDismiss: {},
        onRetry: {
            // Retry action
        }
    )
}
