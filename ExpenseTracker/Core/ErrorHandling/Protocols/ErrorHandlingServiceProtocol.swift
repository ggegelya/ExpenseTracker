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
}
