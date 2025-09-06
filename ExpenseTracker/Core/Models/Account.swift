//
//  Account.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//


import Foundation

struct Account: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let tag: String
    var balance: Decimal
    var isDefault: Bool
    
    static let defaultAccount = Account(id: UUID(), name: "Основна картка", tag: "#main", balance: 0, isDefault: true)
}


