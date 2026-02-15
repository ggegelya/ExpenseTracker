//
//  TransactionType.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//


import Foundation

enum TransactionType: String, CaseIterable, Codable {
    case expense = "expense"
    case income = "income"
    case transferOut = "transferOut"
    case transferIn = "transferIn"

    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "expense":
            self = .expense
        case "income":
            self = .income
        case "transferout", "transfer-out":
            self = .transferOut
        case "transferin", "transfer-in":
            self = .transferIn
        default:
            return nil
        }
    }
    
    var symbol: String {
        switch self {
            case .expense, .transferOut: return "-"
            case .income, .transferIn: return "+"
        }
    }

    var localizedName: String {
        switch self {
        case .expense:
            return String(localized: "transactionType.expense")
        case .income:
            return String(localized: "transactionType.income")
        case .transferOut:
            return String(localized: "transactionType.transferOut")
        case .transferIn:
            return String(localized: "transactionType.transferIn")
        }
    }
    
    var color: String {
        switch self {
        case .expense, .transferOut: return "red"
        case .income, .transferIn: return "green"
        }
    }
    
}
