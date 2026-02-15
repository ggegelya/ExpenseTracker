//
//  ErrorHandlingServiceProtocol.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//

import Foundation

@MainActor
protocol ErrorHandlingServiceProtocol {
    func handle(_ error: AppError, context: String?)
    func showToast(_ message: String, type: ToastType)
    func showAlert(_ error: AppError, retryAction: (() -> Void)?)
    func dismissAlert()
    func dismissToast()
}

extension ErrorHandlingServiceProtocol {
    /// Maps any error to `AppError` and forwards to `handle(_:context:)`.
    func handleAny(_ error: Error, context: String) -> AppError {
        let appError: AppError
        if let existing = error as? AppError {
            appError = existing
        } else if let repoError = error as? RepositoryError {
            appError = AppError(from: repoError)
        } else if let urlError = error as? URLError {
            appError = AppError(from: urlError)
        } else {
            appError = .syncFailed
        }
        handle(appError, context: context)
        return appError
    }
}
