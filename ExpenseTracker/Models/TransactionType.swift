//
//  TransactionType.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//


import Foundation

enum TransactionType: String, CaseIterable, Codable {
    case expense = "Expense"
    case income = "Income"
    case transferOut = "Transfer-Out"
    case transferIn = "Transfer-In"
    
    var symbol: String {
        switch self {
            case .expense, .transferOut: return "-"
            case .income, .transferIn: return "+"
        }
    }
    
    var color: String {
        switch self {
        case .expense, .transferOut: return "red"
        case .income, .transferIn: return "green"
        }
    }
    
}