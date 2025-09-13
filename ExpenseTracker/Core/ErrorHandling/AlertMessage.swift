//
//  AlertMessage.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//


import Foundation
import SwiftUICore

struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?
    let retryAction: (() -> Void)?
    let isRetryable: Bool
}