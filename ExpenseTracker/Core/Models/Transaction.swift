//
//  Transaction.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import Foundation

struct Transaction : Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let transactionDate: Date
    let type: TransactionType
    var amount: Decimal
    let category: Category?
    var description: String
    let fromAccount: Account?
    let toAccount: Account?
    let parentTransactionId: UUID?
    let splitTransactions: [Transaction]?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        transactionDate: Date = Date(),
        type: TransactionType,
        amount: Decimal,
        category: Category? = nil,
        description: String,
        fromAccount: Account? = nil,
        toAccount: Account? = nil,
        parentTransactionId: UUID? = nil,
        splitTransactions: [Transaction]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transactionDate = transactionDate
        self.type = type
        self.amount = amount
        self.category = category
        self.description = description
        self.fromAccount = fromAccount
        self.toAccount = toAccount
        self.parentTransactionId = parentTransactionId
        self.splitTransactions = splitTransactions
    }

    var isSplit: Bool {
        splitTransactions != nil && !(splitTransactions?.isEmpty ?? true)
    }

    var primaryCategory: Category? {
        // Return the category of the largest split, or the transaction's own category
        if let splits = splitTransactions, !splits.isEmpty {
            return splits.max(by: { $0.amount < $1.amount })?.category
        }
        return category
    }
    
    var formattedAmount : String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "UAH"
        formatter.currencySymbol = "₴"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        let number = NSDecimalNumber(decimal: amount)
        return "\(type.symbol)\(formatter.string(from: number) ?? "0")"
    }
    
    
}

