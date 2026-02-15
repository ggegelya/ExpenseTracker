//
//  MockErrorHandlingService.swift
//  ExpenseTracker
//
//  Mock implementation of ErrorHandlingServiceProtocol for testing
//

import Foundation
@testable import ExpenseTracker

@MainActor
final class MockErrorHandlingService: ErrorHandlingServiceProtocol {
    private(set) var handledErrors: [(error: AppError, context: String?)] = []
    private(set) var toastMessages: [(message: String, type: ToastType)] = []
    private(set) var alertErrors: [(error: AppError, hasRetry: Bool)] = []

    func handle(_ error: AppError, context: String?) {
        handledErrors.append((error: error, context: context))
    }

    func showToast(_ message: String, type: ToastType) {
        toastMessages.append((message: message, type: type))
    }

    func showAlert(_ error: AppError, retryAction: (() -> Void)?) {
        alertErrors.append((error: error, hasRetry: retryAction != nil))
    }

    func dismissAlert() {}

    func dismissToast() {}

    func reset() {
        handledErrors.removeAll()
        toastMessages.removeAll()
        alertErrors.removeAll()
    }
}
