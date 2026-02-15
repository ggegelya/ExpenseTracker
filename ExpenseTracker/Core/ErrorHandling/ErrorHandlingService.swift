//
//  ErrorHandlingService.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//

import Foundation

@MainActor
final class ErrorHandlingService: ErrorHandlingServiceProtocol, ObservableObject {
    @Published var currentToast: ToastMessage?
    @Published var currentMessage: AlertMessage?

    private let analyticsService: AnalyticsServiceProtocol
    private var toastDismissTask: Task<Void, Never>?

    init(analyticsService: AnalyticsServiceProtocol) {
        self.analyticsService = analyticsService
    }

    func handle(_ error: AppError, context: String?) {
        analyticsService.trackError(error, context: context)

        switch error.severity {
        case .low:
            showToast(error.localizedDescription, type: .error)
        case .medium, .high, .critical:
            showAlert(error, retryAction: nil)
        }
    }

    func showToast(_ message: String, type: ToastType) {
        toastDismissTask?.cancel()
        currentToast = ToastMessage(message: message, type: type)

        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.currentToast = nil
        }
    }

    func showAlert(_ error: AppError, retryAction: (() -> Void)?) {
        currentMessage = AlertMessage(
            title: String(localized: "error.title"),
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
        toastDismissTask?.cancel()
        currentToast = nil
    }
}
