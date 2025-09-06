//
//  PendingTransaction.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 01.09.2025.
//


import Foundation

struct PendingTransaction: Identifiable {
    let id: UUID
    let bankTransactionId: String?
    let amount: Decimal
    let descriptionText: String
    let merchantName: String?
    let transactionDate: Date
    let type: TransactionType
    let account: Account
    let suggestedCategory: Category?
    let confidence: Float
    let importedAt: Date
    let status: PendingStatus
    
    enum PendingStatus: String {
        case pending = "pending"
        case processing = "processing"
        case processed = "processed"
        case dismissed = "dismissed"
    }
}