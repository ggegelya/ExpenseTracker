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
    var parentTransactionId: UUID?
    var splitTransactions: [Transaction]?

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

    var isSplitParent: Bool {
        !(splitTransactions?.isEmpty ?? true)
    }

    var isSplitChild: Bool {
        parentTransactionId != nil && (splitTransactions?.isEmpty ?? true)
    }

    var effectiveSplits: [Transaction] {
        splitTransactions ?? []
    }

    var effectiveAmount: Decimal {
        if isSplitParent {
            return effectiveSplits.reduce(0) { $0 + $1.amount }
        }
        return amount
    }

    var primaryCategory: Category? {
        // Return the category of the largest split, or the transaction's own category
        if isSplitParent {
            let splits = effectiveSplits
            return splits.max(by: { $0.amount < $1.amount })?.category
        }
        return category
    }
    
    var formattedAmount : String {
        let baseAmount = effectiveAmount
        let formatted = Formatters.currencyStringUAH(amount: baseAmount,
                                                     minFractionDigits: 0,
                                                     maxFractionDigits: 2)
        return "\(type.symbol)\(formatted)"
    }
    
    
}
