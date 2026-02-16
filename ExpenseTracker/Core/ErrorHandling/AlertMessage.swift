//
//  AlertMessage.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 13.09.2025.
//


import Foundation
import SwiftUI

struct AlertMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?
    let retryAction: (() -> Void)?
    let isRetryable: Bool

    static func == (lhs: AlertMessage, rhs: AlertMessage) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.message == rhs.message && lhs.isRetryable == rhs.isRetryable
    }
}
