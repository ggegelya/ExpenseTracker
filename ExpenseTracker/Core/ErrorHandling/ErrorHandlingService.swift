//
//  ErrorHandlingService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//

import Foundation

@MainActor
final class ErrorHandlingService : ErrorHandlingServiceProtocol, ObservableObject {
    var currentToast: ToastMessage?
    var currentMessage: AlertMessage?
    
    private let analyticsService: AnalyticsServiceProtocol
    
    init(analyticsService: AnalyticsServiceProtocol) {
        self.analyticsService = analyticsService
    }
    
    func handle(_ error: AppError, context: String?) {
        analyticsService.trackError(error, context: context)
        
        switch error.severity {
        case .low:
            showToast(error.localizedDescription, type: .error)
        case .medium, .high:
            showAlert(error, retryAction: nil)
        case .critical:
            showAlert(error, retryAction: nil)
            // Additional critical error handling can be added here (e.g., logging to a remote server)
        }
        
    }
    
    func showToast(_ message: String, type: ToastType) {
        currentToast = ToastMessage(message: message, type: type)
        
        Task {
            try await Task.sleep(for: .seconds(3))
            currentToast = nil
        }
    }
    
    func showAlert(_ error: AppError, retryAction: (() -> Void)?) {
        currentMessage = AlertMessage(
            title: "Помилка",
            message: error.localizedDescription,
            recoverySuggestion: error.recoverySuggestion,
            retryAction: retryAction,
            isRetryable: error.isRetryable
        )
    }
    func dismissAlert() {
        currentMessage = nil
    }
    func dismissToast() {
        currentToast = nil
    }
    
    
}
