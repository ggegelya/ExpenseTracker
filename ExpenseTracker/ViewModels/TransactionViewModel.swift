//
//  TransactionViewModel.swift
//  ExpenseTracker
//
//  Created by Heorhii Hehelia on 15.08.2025.
//

import SwiftUI
import Combine

@MainActor
class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var categories = Category.defaults
    @Published var accounts = [Account.defaultAccount]
    
    // Quick entry props
    @Published var entryAmount: String = ""
    @Published var entryDescription: String = ""
    @Published var selectedCategory: Category?
    @Published var selectedDate: Date = Date()
    @Published var selectedAccount: Account = Account.defaultAccount
    @Published var transactionType: TransactionType = .expense
    
    var amountDecimal: Decimal? {
        guard !entryAmount.isEmpty else { return nil }
        return Decimal(string: entryAmount.replacingOccurrences(of: ",", with: "."))
    }
    
    var isValidEntry: Bool {
        amountDecimal != nil && !entryDescription.isEmpty
    }
    
    func addTransaction() {
        guard let amount = amountDecimal else {return}
        
        let transaction = Transaction(
            transactionDate: selectedDate,
            type: transactionType,
            amount: amount,
            category: selectedCategory,
            description: entryDescription,
            fromAccount: transactionType == .expense ? selectedAccount : nil,
            toAccount: transactionType == .income ? selectedAccount : nil
        )
        
        transactions.insert(transaction, at: 0)
        
        // update accounts balance
        
        if transactionType == .expense {
            if let index = accounts.firstIndex(where: {$0.id == selectedAccount.id}) {
                accounts[index].balance -= amount
                
            }
        } else if transactionType == .income {
            if let index = accounts.firstIndex(where: {$0.id == selectedAccount.id}) {
                accounts[index].balance += amount
            }
        }
        
        // reset
        clearEntry()
        
        saveTransactions()
        
    }
    
    func clearEntry() {
        entryAmount = ""
        entryDescription = ""
        selectedCategory = nil
        selectedDate = Date()
        //selectedAccount = Account.defaultAccount
        //transactionType = .expense
    }
    
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        saveTransactions()
    }
    
    func suggestCategory(for description: String) -> Category? {
        let lowercased = description.lowercased()
        
        // TODO: Make smart patterns based on history analysis
        let patterns: [String: String] = [
            "нетфлікс" : "підписки",
            "netflix" : "підписки",
            "spotify" : "підписки",
            "photoshop" : "підписки",
            "apple" : "підписки",
            "сільпо" : "продукти",
            "фора" : "продукти",
            "метро" : "продукти"
            ]
        
        for (pattern, categoryName) in patterns {
            if lowercased.contains(pattern) {
                return categories.first { $0.name == categoryName }
            }
        }
        
        return nil
        
    }
    
    private func saveTransactions() {
        // TODO: Implement core data or other persistence
        print("Saving transactions...")
    }
}
