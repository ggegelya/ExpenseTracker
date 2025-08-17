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
    let amount: Decimal
    let category: Category?
    let description: String
    let fromAccount: Account?
    let toAccount: Account?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), transactionDate: Date = Date(), type: TransactionType, amount: Decimal, category: Category? = nil, description: String, fromAccount: Account? = nil, toAccount: Account? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.transactionDate = transactionDate
        self.type = type
        self.amount = amount
        self.category = category
        self.description = description
        self.fromAccount = fromAccount
        self.toAccount = toAccount
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

